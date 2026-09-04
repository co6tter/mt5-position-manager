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
                         const int trigger_points,
                         const int trail_points,
                         double &candidate)
  {
   candidate = 0.0;
   if(trigger_points <= 0 || trail_points <= 0 || point <= 0.0)
      return false;
   const double profit_points = PMProfitPoints(open_price, type, current_price, point);
   if(profit_points < trigger_points - 0.0000001)
      return false;
   candidate = type == POSITION_TYPE_BUY ?
              current_price - trail_points * point :
              current_price + trail_points * point;
   if((type == POSITION_TYPE_BUY && candidate < open_price) ||
      (type == POSITION_TYPE_SELL && candidate > open_price))
      return false;
   return true;
  }

bool PMBuildPositionBasket(const PMPosition &positions[],
                           const string symbol,
                           const ENUM_POSITION_TYPE type,
                           double &open_price,
                           double &current_price,
                           ulong &tickets[])
  {
   open_price = 0.0;
   current_price = 0.0;
   ArrayResize(tickets, 0);
   if(symbol == "")
      return false;

   double total_volume = 0.0;
   double open_price_volume = 0.0;
   double current_price_volume = 0.0;
   for(int index = 0; index < ArraySize(positions); index++)
     {
      if(positions[index].symbol != symbol ||
         positions[index].type != type ||
         positions[index].ticket == 0 ||
         !MathIsValidNumber(positions[index].volume) ||
         !MathIsValidNumber(positions[index].open_price) ||
         !MathIsValidNumber(positions[index].current_price) ||
         positions[index].volume <= 0.0 ||
         positions[index].open_price <= 0.0 ||
         positions[index].current_price <= 0.0)
         continue;

      total_volume += positions[index].volume;
      open_price_volume += positions[index].open_price * positions[index].volume;
      current_price_volume += positions[index].current_price * positions[index].volume;
      const int count = ArraySize(tickets);
      ArrayResize(tickets, count + 1);
      tickets[count] = positions[index].ticket;
     }

   if(total_volume <= 0.0 || ArraySize(tickets) == 0)
      return false;
   open_price = open_price_volume / total_volume;
   current_price = current_price_volume / total_volume;
   return MathIsValidNumber(open_price) && open_price > 0.0 &&
          MathIsValidNumber(current_price) && current_price > 0.0;
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
      int unchanged = 0;
      int queued = 0;
      int failed = 0;
      ulong first_failed_ticket = 0;
      string first_failure_description = "";
      bool processed[];
      ArrayResize(processed, ArraySize(all_positions));
      ArrayInitialize(processed, false);

      for(int i = 0; i < ArraySize(all_positions); i++)
        {
         if(processed[i])
            continue;
         if((has_symbol_scope && all_positions[i].symbol != config.symbol) ||
            !PMDirectionMatches(config.direction, all_positions[i].type))
           {
            processed[i] = true;
            continue;
           }

         const string basket_symbol = all_positions[i].symbol;
         const ENUM_POSITION_TYPE basket_type = all_positions[i].type;
         ulong basket_tickets[];
         double basket_open_price = 0.0;
         double basket_current_price = 0.0;
         if(!PMBuildPositionBasket(all_positions, basket_symbol, basket_type,
                                    basket_open_price, basket_current_price,
                                    basket_tickets))
           {
            processed[i] = true;
            continue;
           }
         for(int position_index = 0; position_index < ArraySize(all_positions); position_index++)
            if(all_positions[position_index].symbol == basket_symbol &&
               all_positions[position_index].type == basket_type)
               processed[position_index] = true;

         if(HasPendingBasket(basket_tickets, trades))
            continue;

         const double point = has_symbol_scope ? scoped_point :
                              SymbolInfoDouble(basket_symbol, SYMBOL_POINT);
         if(point <= 0.0)
            continue;

         double break_even_candidate = 0.0;
         const bool has_break_even = config.enabled_break_even &&
            PMBreakEvenCandidate(basket_open_price, basket_type, basket_current_price,
                                 point, config.be_trigger_points, config.be_lock_points,
                                 break_even_candidate);

         double trailing_candidate = 0.0;
         const bool has_trailing = config.enabled_trailing &&
            PMTrailingCandidate(basket_open_price, basket_type, basket_current_price,
                                point, config.trail_trigger_points, config.trail_points,
                                trailing_candidate);

         double best = 0.0;
         if(!PMBestStopCandidate(basket_type, has_break_even, break_even_candidate,
                                 has_trailing, trailing_candidate, best))
            continue;

         double targets[];
         string reason = "";
         bool accepted = CalculateBasketTargets(basket_tickets, best, positions,
                                                validator, targets, reason);
         if(!accepted && has_break_even && has_trailing)
           {
            const double fallback = best == trailing_candidate ? break_even_candidate : trailing_candidate;
            accepted = CalculateBasketTargets(basket_tickets, fallback, positions,
                                              validator, targets, reason);
           }
         if(!accepted)
           {
            PrintFormat("[WARN] Trailing/Break Even candidate rejected basket=%s %s reason=%s",
                        basket_symbol, PMPositionTypeToString(basket_type), reason);
            continue;
           }

         for(int ticket_index = 0; ticket_index < ArraySize(basket_tickets); ticket_index++)
           {
            PMPosition position = {};
            if(!positions.Get(basket_tickets[ticket_index], position))
             {
               failed++;
               if(first_failed_ticket == 0)
                 {
                  first_failed_ticket = basket_tickets[ticket_index];
                  first_failure_description = "Position no longer exists.";
                 }
               PrintFormat("[ERROR] Trailing/Break Even modify skipped ticket=%I64u description=%s",
                           basket_tickets[ticket_index], "Position no longer exists.");
               continue;
             }

            if(!PMIsMoreFavorableStop(position.type, targets[ticket_index], position.sl))
               continue;

            PMTradeFailure failure = {};
            const PMTradeAttemptStatus attempt_status =
               trades.ModifyTicket(position.ticket, targets[ticket_index], position.tp, failure);
            if(attempt_status == PM_TRADE_ATTEMPT_SUCCESS)
               modified++;
            else if(attempt_status == PM_TRADE_ATTEMPT_UNCHANGED)
               unchanged++;
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
        }

      if(modified == 0 && unchanged == 0 && queued == 0 && failed == 0)
         return false;

      status = StringFormat("Trailing/Break Even: %d updated, %d unchanged, %d queued, %d failed",
                            modified, unchanged, queued, failed);
      if(first_failed_ticket != 0)
         status += StringFormat("; ticket=%I64u (%s)",
                                first_failed_ticket, first_failure_description);
      return true;
     }

private:
   bool HasPendingBasket(const ulong &tickets[], CTradeManager &trades)
     {
      for(int index = 0; index < ArraySize(tickets); index++)
         if(trades.HasPending(tickets[index]))
            return true;
      return false;
     }

   bool CalculateBasketTargets(const ulong &tickets[],
                              const double candidate,
                              CPositionService &positions,
                              CValidationService &validator,
                              double &targets[],
                              string &reason)
     {
      reason = "";
      ArrayResize(targets, ArraySize(tickets));
      for(int index = 0; index < ArraySize(tickets); index++)
        {
         PMPosition position = {};
         if(!positions.Get(tickets[index], position))
           {
            reason = "Position no longer exists.";
            return false;
           }
         if(!validator.CalculateTarget(position, true, PM_PRICE_ABSOLUTE,
                                       candidate, targets[index], reason))
            return false;
        }
      return true;
     }
  };

#endif
