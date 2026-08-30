#ifndef __MT5_POSITION_MANAGER_TRAILING_STOP_SERVICE_MQH__
#define __MT5_POSITION_MANAGER_TRAILING_STOP_SERVICE_MQH__

#include "Models.mqh"
#include "Constants.mqh"
#include "PositionService.mqh"
#include "TradeManager.mqh"
#include "ValidationService.mqh"

bool PMBreakEvenCandidate(const double open_price,
                          const ENUM_POSITION_TYPE type,
                          const double current_price,
                          const double point,
                          const int trigger_points,
                          const int lock_points,
                          double &candidate)
  {
   candidate = 0.0;
   if(trigger_points <= 0 || point <= 0.0)
      return false;
   const double profit_points = PMProfitPoints(open_price, type, current_price, point);
   // Tolerate floating-point noise (e.g. 19.999999999999996 for an exact 20-point
   // move) so a price that has genuinely reached the trigger isn't spuriously
   // rejected for one tick.
   if(profit_points < trigger_points - 0.0000001)
      return false;
   candidate = type == POSITION_TYPE_BUY ?
              open_price + lock_points * point :
              open_price - lock_points * point;
   return true;
  }

bool PMTrailingCandidate(const double open_price,
                         const ENUM_POSITION_TYPE type,
                         const double current_price,
                         const double point,
                         const int trail_points,
                         double &candidate)
  {
   candidate = 0.0;
   if(trail_points <= 0 || point <= 0.0)
      return false;
   const double profit_points = PMProfitPoints(open_price, type, current_price, point);
   if(profit_points < trail_points - 0.0000001)
      return false;
   candidate = type == POSITION_TYPE_BUY ?
              current_price - trail_points * point :
              current_price + trail_points * point;
   return true;
  }

bool PMIsMoreFavorableStop(const ENUM_POSITION_TYPE type,
                           const double candidate,
                           const double current)
  {
   if(current <= 0.0)
      return true;
   if(type == POSITION_TYPE_BUY)
      return candidate > current;
   return candidate < current;
  }

bool PMBestStopCandidate(const ENUM_POSITION_TYPE type,
                         const bool has_break_even,
                         const double break_even_candidate,
                         const bool has_trailing,
                         const double trailing_candidate,
                         double &best)
  {
   best = 0.0;
   if(!has_break_even && !has_trailing)
      return false;
   if(has_break_even && !has_trailing)
     {
      best = break_even_candidate;
      return true;
     }
   if(!has_break_even && has_trailing)
     {
      best = trailing_candidate;
      return true;
     }
   best = PMIsMoreFavorableStop(type, trailing_candidate, break_even_candidate) ?
         trailing_candidate : break_even_candidate;
   return true;
  }

class CTrailingStopService
  {
public:
   bool Evaluate(const TrailingStopConfig &config,
                 CPositionService &positions,
                 CTradeManager &trades,
                 CValidationService &validator,
                 string &status)
     {
      status = "";
      if(!config.enabled_break_even && !config.enabled_trailing)
         return false;

      PMPosition all_positions[];
      positions.Collect(all_positions);
      if(ArraySize(all_positions) == 0)
         return false;

      const bool has_symbol_scope = config.symbol != "";
      const double scoped_point = has_symbol_scope ?
                                  SymbolInfoDouble(config.symbol, SYMBOL_POINT) : 0.0;
      if(has_symbol_scope && scoped_point <= 0.0)
        {
         PrintFormat("[WARN] Trailing/Break Even: point size unavailable for %s.", config.symbol);
         return false;
        }

      int modified = 0;
      int queued = 0;
      int failed = 0;
      ulong first_failed_ticket = 0;
      string first_failure_description = "";

      for(int i = 0; i < ArraySize(all_positions); i++)
        {
         if(has_symbol_scope && all_positions[i].symbol != config.symbol)
            continue;
         if(!PMDirectionMatches(config.direction, all_positions[i].type))
            continue;
         if(trades.HasPending(all_positions[i].ticket))
            continue;

         PMPosition position = all_positions[i];
         const double point = has_symbol_scope ? scoped_point :
                              SymbolInfoDouble(position.symbol, SYMBOL_POINT);
         if(point <= 0.0)
            continue;

         double break_even_candidate = 0.0;
         const bool has_break_even = config.enabled_break_even &&
            PMBreakEvenCandidate(position.open_price, position.type, position.current_price,
                                 point, config.be_trigger_points, config.be_lock_points,
                                 break_even_candidate);

         double trailing_candidate = 0.0;
         const bool has_trailing = config.enabled_trailing &&
            PMTrailingCandidate(position.open_price, position.type, position.current_price,
                                point, config.trail_points, trailing_candidate);

         double best = 0.0;
         if(!PMBestStopCandidate(position.type, has_break_even, break_even_candidate,
                                 has_trailing, trailing_candidate, best))
            continue;

         double target = 0.0;
         string reason = "";
         bool accepted = validator.CalculateTarget(position, true, PM_PRICE_ABSOLUTE, best, target, reason);
         if(!accepted && has_break_even && has_trailing)
           {
            const double fallback = best == trailing_candidate ? break_even_candidate : trailing_candidate;
            accepted = validator.CalculateTarget(position, true, PM_PRICE_ABSOLUTE, fallback, target, reason);
           }
         if(!accepted)
           {
            PrintFormat("[WARN] Trailing/Break Even candidate rejected ticket=%I64u reason=%s",
                        position.ticket, reason);
            continue;
           }
         if(!PMIsMoreFavorableStop(position.type, target, position.sl))
            continue;

         PMTradeFailure failure = {};
         const PMTradeAttemptStatus attempt_status =
            trades.ModifyTicket(position.ticket, target, position.tp, failure);
         if(attempt_status == PM_TRADE_ATTEMPT_SUCCESS)
            modified++;
         else if(attempt_status == PM_TRADE_ATTEMPT_QUEUED)
            queued++;
         else
           {
            failed++;
            if(first_failed_ticket == 0)
             {
               first_failed_ticket = position.ticket;
               first_failure_description = failure.description;
            }
            PrintFormat("[ERROR] Trailing/Break Even modify failed ticket=%I64u description=%s",
                        position.ticket, failure.description);
           }
        }

      if(modified == 0 && queued == 0 && failed == 0)
         return false;

      status = StringFormat("Trailing/Break Even: %d updated, %d queued, %d failed",
                            modified, queued, failed);
      if(first_failed_ticket != 0)
         status += StringFormat("; ticket=%I64u (%s)",
                                first_failed_ticket, first_failure_description);
      return true;
     }
  };

#endif
