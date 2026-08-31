#ifndef __MT5_POSITION_MANAGER_TRADE_MANAGER_MQH__
#define __MT5_POSITION_MANAGER_TRADE_MANAGER_MQH__

#include <Trade/Trade.mqh>
#include "Models.mqh"
#include "Constants.mqh"

class CTradeManager
  {
private:
   CTrade m_trade;
   int m_deviation_points;
   int m_retry_count;
   int m_retry_interval_seconds;
   PMPendingTrade m_pending[];

public:
   void Configure(const int deviation_points,
                  const int retry_count,
                  const int retry_interval_seconds)
     {
      m_deviation_points = MathMax(0, deviation_points);
      m_retry_count = MathMax(1, retry_count);
      m_retry_interval_seconds = MathMax(0, retry_interval_seconds);
      m_trade.SetAsyncMode(false);
      m_trade.SetDeviationInPoints(m_deviation_points);
      m_trade.LogLevel(LOG_LEVEL_ERRORS);
      ArrayResize(m_pending, 0);
     }

   int CloseTickets(const ulong &tickets[], PMBatchResult &result)
     {
      PMResetBatchResult(result, ArraySize(tickets));
      for(int i = 0; i < ArraySize(tickets); i++)
        {
         PMTradeFailure failure = {};
         const PMTradeAttemptStatus status = CloseTicket(tickets[i], failure);
         if(status == PM_TRADE_ATTEMPT_SUCCESS)
            result.successful++;
         else if(status == PM_TRADE_ATTEMPT_QUEUED)
            result.queued++;
         else
           {
            PMAddFailure(result, failure.ticket, failure.retcode,
                         failure.description, failure.attempts);
            PrintFormat("[ERROR] Failed to close ticket=%I64u retcode=%u description=%s attempts=%d",
                        failure.ticket, failure.retcode,
                        failure.description, failure.attempts);
           }
        }
      return result.requested;
     }

   PMTradeAttemptStatus CloseTicket(const ulong ticket,
                                    PMTradeFailure &failure)
     {
      CleanupClosedPending();
      const int pending_close = FindPending(PM_TRADE_OPERATION_CLOSE, ticket);
      if(pending_close >= 0 && !m_pending[pending_close].terminal_failure)
        {
         SetFailure(failure, ticket, 0,
                    "A close retry is already pending for this position.", 0);
         return PM_TRADE_ATTEMPT_QUEUED;
        }
      if(pending_close >= 0)
         ArrayRemove(m_pending, pending_close, 1);
      RemovePending(PM_TRADE_OPERATION_MODIFY, ticket);
      bool wait_only = false;
      const PMTradeAttemptStatus status = ExecuteCloseAttempt(ticket, 1,
                                                              wait_only, failure);
      if(status != PM_TRADE_ATTEMPT_QUEUED)
        {
         if(status == PM_TRADE_ATTEMPT_SUCCESS)
            RemovePending(PM_TRADE_OPERATION_CLOSE, ticket);
         else
            RememberCloseFailure(ticket, failure);
         return status;
        }
      const PMTradeAttemptStatus queued_status =
         QueueRetry(PM_TRADE_OPERATION_CLOSE, ticket, 0.0, 0.0,
                    1, wait_only, failure);
      if(queued_status == PM_TRADE_ATTEMPT_FAILED)
         RememberCloseFailure(ticket, failure);
      return queued_status;
     }

   PMTradeAttemptStatus ModifyTicket(const ulong ticket,
                                     const double sl,
                                     const double tp,
                                     PMTradeFailure &failure)
     {
      if(FindPending(PM_TRADE_OPERATION_CLOSE, ticket) >= 0)
        {
         SetFailure(failure, ticket, 0,
                    "A close retry is pending for this position.", 0);
         return PM_TRADE_ATTEMPT_FAILED;
        }
      const int pending_modify = FindPending(PM_TRADE_OPERATION_MODIFY, ticket);
      if(pending_modify >= 0)
        {
         PrintFormat("[INFO] Superseding pending modification ticket=%I64u old_sl=%s old_tp=%s new_sl=%s new_tp=%s",
                     ticket,
                     DoubleToString(m_pending[pending_modify].sl, 8),
                     DoubleToString(m_pending[pending_modify].tp, 8),
                     DoubleToString(sl, 8), DoubleToString(tp, 8));
         ArrayRemove(m_pending, pending_modify, 1);
        }

      bool wait_only = false;
      const PMTradeAttemptStatus status = ExecuteModifyAttempt(ticket, sl, tp, 1,
                                                               wait_only, failure);
      if(status != PM_TRADE_ATTEMPT_QUEUED)
        {
         if(status == PM_TRADE_ATTEMPT_SUCCESS)
            RemovePending(PM_TRADE_OPERATION_MODIFY, ticket);
         return status;
        }
      return QueueRetry(PM_TRADE_OPERATION_MODIFY, ticket, sl, tp,
                        1, wait_only, failure);
     }

   bool OpenMarket(const string symbol,
                   const PMEntrySide side,
                   const double volume,
                   const double sl,
                   const double tp,
                   PMMarketEntryResult &result)
     {
      PMResetMarketEntryResult(result);
      if(symbol == "" || !MathIsValidNumber(volume) || volume <= 0.0 ||
         !MathIsValidNumber(sl) || sl < 0.0 ||
         !MathIsValidNumber(tp) || tp < 0.0 ||
         (side != PM_ENTRY_BUY && side != PM_ENTRY_SELL))
        {
         result.description = "Entry symbol, side, volume, SL, or TP is invalid.";
         PrintFormat("[ERROR] Market entry rejected before send symbol=%s volume=%s sl=%s tp=%s side=%d description=%s",
                     symbol, DoubleToString(volume, 8), DoubleToString(sl, 8),
                     DoubleToString(tp, 8), (int)side,
                     result.description);
         return false;
        }
      CTrade entry_trade;
      entry_trade.SetAsyncMode(false);
      entry_trade.SetDeviationInPoints(m_deviation_points);
      entry_trade.LogLevel(LOG_LEVEL_ERRORS);
      ResetLastError();
      if(!entry_trade.SetTypeFillingBySymbol(symbol))
        {
         result.description = "Unable to determine the symbol filling mode.";
         PrintFormat("[ERROR] Market entry setup failed symbol=%s description=%s last_error=%d",
                     symbol, result.description, GetLastError());
         return false;
        }

      ResetLastError();
      const bool request_ok = side == PM_ENTRY_BUY ?
         entry_trade.Buy(volume, symbol, 0.0, sl, tp, "MT5 Position Manager") :
         entry_trade.Sell(volume, symbol, 0.0, sl, tp, "MT5 Position Manager");
      const int last_error = GetLastError();
      result.request_ok = request_ok;
      result.retcode = entry_trade.ResultRetcode();
      result.description = entry_trade.ResultRetcodeDescription();
      result.deal = entry_trade.ResultDeal();
      result.order = entry_trade.ResultOrder();
      result.volume = entry_trade.ResultVolume();
      result.price = entry_trade.ResultPrice();
      if(request_ok && PMIsMarketEntrySuccessRetcode(result.retcode))
        {
         PrintFormat("[INFO] Market %s accepted symbol=%s requested_volume=%s result_volume=%s price=%s sl=%s tp=%s deal=%I64u order=%I64u retcode=%u",
                     side == PM_ENTRY_BUY ? "Buy" : "Sell", symbol,
                     DoubleToString(volume, 8), DoubleToString(result.volume, 8),
                     DoubleToString(result.price, 8),
                     DoubleToString(sl, 8), DoubleToString(tp, 8),
                     result.deal, result.order, result.retcode);
         return true;
        }
      PrintFormat("[ERROR] Market %s failed symbol=%s volume=%s retcode=%u description=%s last_error=%d",
                  side == PM_ENTRY_BUY ? "Buy" : "Sell", symbol,
                  DoubleToString(volume, 8), result.retcode,
                  result.description, last_error);
      return false;
     }

   int ProcessRetries(const datetime now, string &status_text)
     {
      status_text = "";
      CleanupClosedPending();
      int processed = 0;
      int successful = 0;
      int failed = 0;
      ulong first_failed_ticket = 0;
      string first_failure_description = "";

      for(int index = ArraySize(m_pending) - 1; index >= 0; index--)
        {
         if(now < m_pending[index].next_attempt_at)
            continue;

         processed++;
         PMPendingTrade pending = m_pending[index];
         PMTradeFailure failure = {};
         PMTradeAttemptStatus attempt_status = PM_TRADE_ATTEMPT_FAILED;
         bool wait_only = pending.wait_only;
         const int next_attempt = pending.attempts + 1;

         if(pending.wait_only)
            attempt_status = CheckPendingState(pending, failure);
         else if(pending.operation == PM_TRADE_OPERATION_CLOSE)
            attempt_status = ExecuteCloseAttempt(pending.ticket, next_attempt,
                                                 wait_only, failure);
         else
            attempt_status = ExecuteModifyAttempt(pending.ticket, pending.sl,
                                                  pending.tp, next_attempt,
                                                  wait_only, failure);

         if(attempt_status == PM_TRADE_ATTEMPT_SUCCESS)
           {
            successful++;
            ArrayRemove(m_pending, index, 1);
            continue;
           }

         if(attempt_status == PM_TRADE_ATTEMPT_FAILED || next_attempt >= m_retry_count)
           {
            failed++;
            if(attempt_status != PM_TRADE_ATTEMPT_FAILED)
               SetFailure(failure, pending.ticket, failure.retcode,
                          "Retry limit reached: " + failure.description,
                          next_attempt);
            if(first_failed_ticket == 0)
              {
               first_failed_ticket = pending.ticket;
               first_failure_description = failure.description;
              }
            // A close failure is safety-critical: keep an unresolved close intent
            // instead of dropping it when the bounded retry cycle is exhausted.
            // It is retried on later timer cycles until the position disappears.
            if(pending.operation == PM_TRADE_OPERATION_CLOSE)
              {
               PrintFormat("[WARN] Close retry deferred ticket=%I64u retcode=%u description=%s",
                           pending.ticket, failure.retcode, failure.description);
               RememberCloseFailureAt(index, failure);
              }
            else
              {
               PrintFormat("[ERROR] Retry exhausted operation=%s ticket=%I64u retcode=%u description=%s",
                           OperationName(pending.operation), pending.ticket,
                           failure.retcode, failure.description);
               ArrayRemove(m_pending, index, 1);
              }
            continue;
           }

         m_pending[index].attempts = next_attempt;
         m_pending[index].next_attempt_at = now + m_retry_interval_seconds;
         m_pending[index].wait_only = wait_only;
         m_pending[index].last_retcode = failure.retcode;
         m_pending[index].last_description = failure.description;
        }

      if(processed > 0)
        {
         status_text = StringFormat("Retries: %d succeeded, %d failed, %d pending",
                                    successful, failed, ArraySize(m_pending));
         if(first_failed_ticket != 0)
            status_text += StringFormat("; ticket=%I64u (%s)",
                                        first_failed_ticket,
                                        first_failure_description);
        }
      return processed;
     }

   int PendingCount()
     {
      CleanupClosedPending();
      return ArraySize(m_pending);
     }

   bool HasPending(const ulong ticket)
     {
      for(int i = 0; i < ArraySize(m_pending); i++)
         if(m_pending[i].ticket == ticket)
            return true;
      return false;
     }

   bool HasFailedClose()
     {
      for(int i = 0; i < ArraySize(m_pending); i++)
         if(m_pending[i].operation == PM_TRADE_OPERATION_CLOSE &&
            m_pending[i].terminal_failure)
            return true;
      return false;
     }

private:
   PMTradeAttemptStatus ExecuteCloseAttempt(const ulong ticket,
                                            const int attempt,
                                            bool &wait_only,
                                            PMTradeFailure &failure)
     {
      wait_only = false;
      PMResetTradeFailure(failure);
      if(!PositionSelectByTicket(ticket))
         return PM_TRADE_ATTEMPT_SUCCESS;

      const string symbol = PositionGetString(POSITION_SYMBOL);
      if(!m_trade.SetTypeFillingBySymbol(symbol))
        {
         SetFailure(failure, ticket, 0,
                    "Unable to determine the symbol filling mode.", attempt);
         return PM_TRADE_ATTEMPT_FAILED;
        }

      ResetLastError();
      if(attempt > 1)
         PrintFormat("[WARN] Retrying close ticket=%I64u attempt=%d/%d",
                     ticket, attempt, m_retry_count);
      else
         PrintFormat("[INFO] Closing position ticket=%I64u", ticket);
      const bool request_ok = m_trade.PositionClose(ticket, (ulong)m_deviation_points);
      const uint retcode = m_trade.ResultRetcode();
      const string description = m_trade.ResultRetcodeDescription();
      LogResult("close", ticket, request_ok, retcode, description);

      if(!PositionSelectByTicket(ticket))
        {
         PrintFormat("[INFO] Position closed ticket=%I64u deal=%I64u order=%I64u",
                     ticket, m_trade.ResultDeal(), m_trade.ResultOrder());
         return PM_TRADE_ATTEMPT_SUCCESS;
        }

      if(request_ok && retcode == TRADE_RETCODE_DONE_PARTIAL)
        {
         SetFailure(failure, ticket, retcode, description, attempt);
         return PM_TRADE_ATTEMPT_QUEUED;
        }
      if(request_ok && (retcode == TRADE_RETCODE_DONE ||
                        retcode == TRADE_RETCODE_PLACED ||
                        retcode == TRADE_RETCODE_CLOSE_ORDER_EXIST ||
                        retcode == TRADE_RETCODE_POSITION_CLOSED))
        {
         wait_only = true;
         SetFailure(failure, ticket, retcode, description, attempt);
         return PM_TRADE_ATTEMPT_QUEUED;
        }
      if(PMIsTransientTradeRetcode(retcode))
        {
         SetFailure(failure, ticket, retcode, description, attempt);
         return PM_TRADE_ATTEMPT_QUEUED;
        }

      SetFailure(failure, ticket, retcode, description, attempt);
      return PM_TRADE_ATTEMPT_FAILED;
     }

   PMTradeAttemptStatus ExecuteModifyAttempt(const ulong ticket,
                                             const double sl,
                                             const double tp,
                                             const int attempt,
                                             bool &wait_only,
                                             PMTradeFailure &failure)
     {
      wait_only = false;
      PMResetTradeFailure(failure);
      if(!PositionSelectByTicket(ticket))
        {
         SetFailure(failure, ticket, 0, "Position no longer exists.", attempt);
         return PM_TRADE_ATTEMPT_FAILED;
        }

      const string symbol = PositionGetString(POSITION_SYMBOL);
      if(!m_trade.SetTypeFillingBySymbol(symbol))
        {
         SetFailure(failure, ticket, 0,
                    "Unable to determine the symbol filling mode.", attempt);
         return PM_TRADE_ATTEMPT_FAILED;
        }

      ResetLastError();
      if(attempt > 1)
         PrintFormat("[WARN] Retrying modification ticket=%I64u attempt=%d/%d",
                     ticket, attempt, m_retry_count);
      const bool request_ok = m_trade.PositionModify(ticket, sl, tp);
      const uint retcode = m_trade.ResultRetcode();
      const string description = m_trade.ResultRetcodeDescription();
      LogResult("modify", ticket, request_ok, retcode, description);

      if(request_ok && (retcode == TRADE_RETCODE_DONE ||
                        retcode == TRADE_RETCODE_NO_CHANGES) &&
         StopsMatch(ticket, sl, tp))
        {
         PrintFormat("[INFO] Position modified ticket=%I64u sl=%s tp=%s deal=%I64u order=%I64u",
                     ticket, DoubleToString(sl, 8), DoubleToString(tp, 8),
                     m_trade.ResultDeal(), m_trade.ResultOrder());
         return PM_TRADE_ATTEMPT_SUCCESS;
        }

      if(request_ok && (retcode == TRADE_RETCODE_DONE ||
                        retcode == TRADE_RETCODE_NO_CHANGES ||
                        retcode == TRADE_RETCODE_PLACED))
        {
         wait_only = true;
         SetFailure(failure, ticket, retcode, description, attempt);
         return PM_TRADE_ATTEMPT_QUEUED;
        }
      if(PMIsTransientTradeRetcode(retcode))
        {
         SetFailure(failure, ticket, retcode, description, attempt);
         return PM_TRADE_ATTEMPT_QUEUED;
        }

      SetFailure(failure, ticket, retcode, description, attempt);
      return PM_TRADE_ATTEMPT_FAILED;
     }

   PMTradeAttemptStatus CheckPendingState(const PMPendingTrade &pending,
                                          PMTradeFailure &failure)
     {
      if(pending.operation == PM_TRADE_OPERATION_CLOSE)
        {
         if(!PositionSelectByTicket(pending.ticket))
           {
            PrintFormat("[INFO] Pending close completed ticket=%I64u", pending.ticket);
            return PM_TRADE_ATTEMPT_SUCCESS;
           }
         SetFailure(failure, pending.ticket, pending.last_retcode,
                    pending.last_description, pending.attempts + 1);
         return PM_TRADE_ATTEMPT_QUEUED;
        }

      if(!PositionSelectByTicket(pending.ticket))
        {
         SetFailure(failure, pending.ticket, 0,
                    "Position disappeared while waiting for modification.",
                    pending.attempts + 1);
         return PM_TRADE_ATTEMPT_FAILED;
        }
      if(StopsMatch(pending.ticket, pending.sl, pending.tp))
        {
         PrintFormat("[INFO] Pending modification completed ticket=%I64u", pending.ticket);
         return PM_TRADE_ATTEMPT_SUCCESS;
        }
      SetFailure(failure, pending.ticket, pending.last_retcode,
                 pending.last_description, pending.attempts + 1);
      return PM_TRADE_ATTEMPT_QUEUED;
     }

   PMTradeAttemptStatus QueueRetry(const PMTradeOperationType operation,
                                   const ulong ticket,
                                   const double sl,
                                   const double tp,
                                   const int attempts,
                                   const bool wait_only,
                                   PMTradeFailure &failure)
     {
      if(attempts >= m_retry_count)
         return PM_TRADE_ATTEMPT_FAILED;

      PMPendingTrade pending = {};
      pending.operation = operation;
      pending.ticket = ticket;
      pending.sl = sl;
      pending.tp = tp;
      pending.attempts = attempts;
      pending.next_attempt_at = CurrentTime() + m_retry_interval_seconds;
      pending.wait_only = wait_only;
      pending.terminal_failure = false;
      pending.last_retcode = failure.retcode;
      pending.last_description = failure.description;

      const int existing = FindPending(operation, ticket);
      if(existing >= 0)
         m_pending[existing] = pending;
      else
        {
         const int count = ArraySize(m_pending);
         ArrayResize(m_pending, count + 1);
         m_pending[count] = pending;
        }
      PrintFormat("[WARN] Queued retry operation=%s ticket=%I64u attempt=%d/%d retcode=%u",
                  OperationName(operation), ticket, attempts + 1,
                  m_retry_count, failure.retcode);
      return PM_TRADE_ATTEMPT_QUEUED;
     }

   void RememberCloseFailure(const ulong ticket, PMTradeFailure &failure)
     {
      const int existing = FindPending(PM_TRADE_OPERATION_CLOSE, ticket);
      if(existing >= 0)
        {
         RememberCloseFailureAt(existing, failure);
         return;
        }

      PMPendingTrade blocked = {};
      blocked.operation = PM_TRADE_OPERATION_CLOSE;
      blocked.ticket = ticket;
      blocked.attempts = failure.attempts;
      blocked.next_attempt_at = CurrentTime() + m_retry_interval_seconds;
      blocked.wait_only = false;
      blocked.terminal_failure = true;
      blocked.last_retcode = failure.retcode;
      blocked.last_description = failure.description;
      const int count = ArraySize(m_pending);
      ArrayResize(m_pending, count + 1);
      m_pending[count] = blocked;
     }

   void RememberCloseFailureAt(const int index, PMTradeFailure &failure)
     {
      m_pending[index].attempts = failure.attempts;
      m_pending[index].next_attempt_at = CurrentTime() + m_retry_interval_seconds;
      m_pending[index].wait_only = false;
      m_pending[index].terminal_failure = true;
      m_pending[index].last_retcode = failure.retcode;
      m_pending[index].last_description = failure.description;
     }

   void CleanupClosedPending()
     {
      for(int i = ArraySize(m_pending) - 1; i >= 0; i--)
         if(!PositionSelectByTicket(m_pending[i].ticket))
            ArrayRemove(m_pending, i, 1);
     }

   bool StopsMatch(const ulong ticket, const double sl, const double tp)
     {
      if(!PositionSelectByTicket(ticket))
         return false;
      const string symbol = PositionGetString(POSITION_SYMBOL);
      double tolerance = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE) / 2.0;
      if(tolerance <= 0.0)
         tolerance = SymbolInfoDouble(symbol, SYMBOL_POINT) / 2.0;
      if(tolerance <= 0.0)
         tolerance = 0.000000001;
      return MathAbs(PositionGetDouble(POSITION_SL) - sl) <= tolerance &&
             MathAbs(PositionGetDouble(POSITION_TP) - tp) <= tolerance;
     }

   int FindPending(const PMTradeOperationType operation, const ulong ticket)
     {
      for(int i = 0; i < ArraySize(m_pending); i++)
         if(m_pending[i].operation == operation && m_pending[i].ticket == ticket)
            return i;
      return -1;
     }

   void RemovePending(const PMTradeOperationType operation, const ulong ticket)
     {
      for(int i = ArraySize(m_pending) - 1; i >= 0; i--)
         if(m_pending[i].operation == operation && m_pending[i].ticket == ticket)
            ArrayRemove(m_pending, i, 1);
     }

   datetime CurrentTime()
     {
      datetime now = TimeTradeServer();
      if(now <= 0)
         now = TimeCurrent();
      return now;
     }

   void SetFailure(PMTradeFailure &failure,
                   const ulong ticket,
                   const uint retcode,
                   const string description,
                   const int attempts)
     {
      failure.ticket = ticket;
      failure.retcode = retcode;
      failure.description = description == "" ? "Unknown trade error." : description;
      failure.attempts = attempts;
     }

   string OperationName(const PMTradeOperationType operation)
     {
      return operation == PM_TRADE_OPERATION_CLOSE ? "close" : "modify";
     }

   void LogResult(const string operation,
                  const ulong ticket,
                  const bool request_ok,
                  const uint retcode,
                  const string description)
     {
      if(!request_ok || (retcode != TRADE_RETCODE_DONE &&
                         retcode != TRADE_RETCODE_DONE_PARTIAL &&
                         retcode != TRADE_RETCODE_NO_CHANGES &&
                         retcode != TRADE_RETCODE_PLACED))
         PrintFormat("[ERROR] %s request ticket=%I64u bool=%s retcode=%u description=%s last_error=%d",
                     operation, ticket, request_ok ? "true" : "false",
                     retcode, description, GetLastError());
     }
  };

#endif
