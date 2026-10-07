#ifndef __MT5_POSITION_MANAGER_AUTO_SL_SERVICE_MQH__
#define __MT5_POSITION_MANAGER_AUTO_SL_SERVICE_MQH__

#include "Models.mqh"
#include "Constants.mqh"
#include "PositionService.mqh"
#include "TradeManager.mqh"
#include "ValidationService.mqh"

// Auto SL for a position opened anywhere (another chart, the mobile app, the
// panel itself): only a position of the configured symbol that opened at or
// after Auto SL was switched ON and still has no SL qualifies. The SL is
// measured from the entry price with the same pips conversion as the Entry
// draft. Switching Auto SL OFF before entering is how a position stays
// without an SL; positions from before the latest ON are never touched.
bool PMAutoSlPositionCandidate(const PMPosition &position,
                               const AutoSlConfig &config,
                               const double point,
                               const double tick_size,
                               const int digits,
                               double &candidate)
  {
   candidate = 0.0;
   if(!config.enabled || !MathIsValidNumber(config.pips) || config.pips <= 0.0 ||
      config.enabled_at <= 0 || config.symbol == "" || point <= 0.0 ||
      position.ticket == 0 || position.symbol != config.symbol ||
      position.open_time < config.enabled_at ||
      !MathIsValidNumber(position.sl) || position.sl > 0.0 ||
      !MathIsValidNumber(position.open_price) || position.open_price <= 0.0)
      return false;
   const double distance = PMPipsToPointDistance(config.pips, digits) * point;
   const double raw = position.type == POSITION_TYPE_BUY ?
                      position.open_price - distance : position.open_price + distance;
   if(raw <= 0.0)
      return false;
   candidate = PMNormalizePrice(raw, tick_size, digits);
   return candidate > 0.0;
  }

class CAutoSlService
  {
private:
   // A stop that was rejected (e.g. price already beyond it) or failed is not
   // resent every second; the ticket waits PM_AUTO_SL_RETRY_SECONDS instead.
   ulong m_wait_tickets[];
   datetime m_wait_until[];

public:
   bool Evaluate(const AutoSlConfig &config,
                 const datetime now,
                 const PMPosition &all_positions[],
                 CPositionService &positions,
                 CTradeManager &trades,
                 CValidationService &validator,
                 string &status)
     {
      status = "";
      ForgetExpiredWaits(now);
      if(!config.enabled || config.pips <= 0.0 || config.enabled_at <= 0 || config.symbol == "")
         return false;
      const double point = SymbolInfoDouble(config.symbol, SYMBOL_POINT);
      const double tick_size = SymbolInfoDouble(config.symbol, SYMBOL_TRADE_TICK_SIZE);
      const int digits = (int)SymbolInfoInteger(config.symbol, SYMBOL_DIGITS);

      int set = 0;
      int queued = 0;
      int failed = 0;
      ulong first_failed_ticket = 0;
      string first_failure_description = "";
      for(int i = 0; i < ArraySize(all_positions); i++)
        {
         double candidate = 0.0;
         const ulong ticket = all_positions[i].ticket;
         if(!PMAutoSlPositionCandidate(all_positions[i], config, point, tick_size, digits, candidate) ||
            trades.HasPending(ticket) || IsWaiting(ticket, now))
            continue;
         // Trail, another chart or the user may have set an SL since the
         // snapshot was taken: decide again from the latest position.
         PMPosition latest = {};
         if(!positions.Get(ticket, latest) ||
            !PMAutoSlPositionCandidate(latest, config, point, tick_size, digits, candidate))
            continue;

         double target = 0.0;
         string reason = "";
         if(!validator.CalculateTarget(latest, true, PM_PRICE_ABSOLUTE, candidate, target, reason))
           {
            PrintFormat("[WARN] Auto SL rejected ticket=%I64u sl=%s reason=%s",
                        ticket, DoubleToString(candidate, digits), reason);
            RecordFailure(ticket, now, reason, failed, first_failed_ticket, first_failure_description);
            continue;
           }

         PMTradeFailure failure = {};
         const PMTradeAttemptStatus attempt = trades.ModifyTicket(ticket, target, latest.tp, failure);
         if(attempt == PM_TRADE_ATTEMPT_SUCCESS || attempt == PM_TRADE_ATTEMPT_UNCHANGED)
            set++;
         else if(attempt == PM_TRADE_ATTEMPT_QUEUED)
            queued++;
         else
           {
            PrintFormat("[ERROR] Auto SL modify failed ticket=%I64u description=%s",
                        ticket, failure.description);
            RecordFailure(ticket, now, failure.description, failed,
                          first_failed_ticket, first_failure_description);
           }
        }

      if(set == 0 && queued == 0 && failed == 0)
         return false;
      status = StringFormat("Auto SL: %d set, %d queued, %d failed", set, queued, failed);
      if(first_failed_ticket != 0)
         status += StringFormat("; ticket=%I64u (%s)", first_failed_ticket, first_failure_description);
      return true;
     }

private:
   void RecordFailure(const ulong ticket,
                      const datetime now,
                      const string description,
                      int &failed,
                      ulong &first_failed_ticket,
                      string &first_failure_description)
     {
      failed++;
      if(first_failed_ticket == 0)
        {
         first_failed_ticket = ticket;
         first_failure_description = description;
        }
      const int count = ArraySize(m_wait_tickets);
      ArrayResize(m_wait_tickets, count + 1);
      ArrayResize(m_wait_until, count + 1);
      m_wait_tickets[count] = ticket;
      m_wait_until[count] = now + PM_AUTO_SL_RETRY_SECONDS;
     }

   bool IsWaiting(const ulong ticket, const datetime now)
     {
      for(int i = 0; i < ArraySize(m_wait_tickets); i++)
         if(m_wait_tickets[i] == ticket && now < m_wait_until[i])
            return true;
      return false;
     }

   void ForgetExpiredWaits(const datetime now)
     {
      for(int i = ArraySize(m_wait_tickets) - 1; i >= 0; i--)
         if(now >= m_wait_until[i])
           {
            ArrayRemove(m_wait_tickets, i, 1);
            ArrayRemove(m_wait_until, i, 1);
           }
     }
  };

#endif
