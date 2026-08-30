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
      if(FindPending(PM_TRADE_OPERATION_CLOSE, ticket) >= 0)
        {
         SetFailure(failure, ticket, 0,
                    "A close retry is already pending for this position.", 0);
         return PM_TRADE_ATTEMPT_QUEUED;
        }
      RemovePending(PM_TRADE_OPERATION_MODIFY, ticket);
      bool wait_only = false;
      const PMTradeAttemptStatus status = ExecuteCloseAttempt(ticket, 1,
                                                              wait_only, failure);
      if(status != PM_TRADE_ATTEMPT_QUEUED)
        {
         if(status == PM_TRADE_ATTEMPT_SUCCESS)
            RemovePending(PM_TRADE_OPERATION_CLOSE, ticket);
         return status;
        }
      return QueueRetry(PM_TRADE_OPERATION_CLOSE, ticket, 0.0, 0.0,
                        1, wait_only, failure);
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

   int ProcessRetries(const datetime now, string &status_text)
     {
      status_text = "";
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
            PrintFormat("[ERROR] Retry exhausted operation=%s ticket=%I64u retcode=%u description=%s",
                        OperationName(pending.operation), pending.ticket,
                        failure.retcode, failure.description);
            ArrayRemove(m_pending, index, 1);
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
      return ArraySize(m_pending);
     }

   bool HasPending(const ulong ticket)
     {
      return FindPending(PM_TRADE_OPERATION_CLOSE, ticket) >= 0 ||
             FindPending(PM_TRADE_OPERATION_MODIFY, ticket) >= 0;
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
