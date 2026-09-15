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
   if(symbol == "")
     {
      ArrayResize(tickets, 0);
      return false;
     }
   ArrayResize(tickets, ArraySize(positions));

   double total_volume = 0.0;
   double open_price_volume = 0.0;
   double current_price_volume = 0.0;
   int ticket_count = 0;
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
      tickets[ticket_count] = positions[index].ticket;
      ticket_count++;
     }

   ArrayResize(tickets, ticket_count);
   if(total_volume <= 0.0 || ticket_count == 0)
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

// Appends one resolved candidate to the parallel result arrays produced by
// PMResolveTrailingCandidates.
void PMAppendTrailingCandidateResult(ulong &tickets[],
                                     int &basis_index[],
                                     double &candidates[],
                                     double &fallback_candidates[],
                                     const ulong ticket,
                                     const int index,
                                     const double candidate,
                                     const double fallback)
  {
   const int count = ArraySize(tickets);
   ArrayResize(tickets, count + 1);
   ArrayResize(basis_index, count + 1);
   ArrayResize(candidates, count + 1);
   ArrayResize(fallback_candidates, count + 1);
   tickets[count] = ticket;
   basis_index[count] = index;
   candidates[count] = candidate;
   fallback_candidates[count] = fallback;
  }

// Decides, for every position, whether a Break Even / Trailing candidate
// applies and which reference price it is measured from -- the volume-weighted
// basket average for PM_TRAIL_BASIS_AVERAGE, or the position's own entry for
// PM_TRAIL_BASIS_PER_POSITION. Pure and side-effect free: point sizes and
// pending flags are supplied by the caller (index-aligned with all_positions)
// instead of being fetched here, so the exact basis-selection logic the
// service runs can be unit tested without a live terminal connection.
//
// result_basis_index[] points back into all_positions[] with a position that
// shares the candidate's symbol/type, for callers that need it to run broker
// validation (e.g. CValidationService::CalculateTarget only reads symbol/type).
// result_fallback_candidates[] is the alternate Break Even/Trailing candidate
// to retry when the primary one is rejected, or 0.0 when there is none.
int PMResolveTrailingCandidates(const PMPosition &all_positions[],
                                const PMTrailBasis basis,
                                const string scope_symbol,
                                const PMDirection scope_direction,
                                const double &point_for_position[],
                                const bool &pending_for_position[],
                                const bool enabled_break_even,
                                const bool enabled_trailing,
                                const int be_trigger_points,
                                const int be_lock_points,
                                const int trail_trigger_points,
                                const int trail_points,
                                ulong &result_tickets[],
                                int &result_basis_index[],
                                double &result_candidates[],
                                double &result_fallback_candidates[])
  {
   ArrayResize(result_tickets, 0);
   ArrayResize(result_basis_index, 0);
   ArrayResize(result_candidates, 0);
   ArrayResize(result_fallback_candidates, 0);
   const bool has_symbol_scope = scope_symbol != "";
   const int total = ArraySize(all_positions);

   if(basis == PM_TRAIL_BASIS_PER_POSITION)
     {
      for(int i = 0; i < total; i++)
        {
         if((has_symbol_scope && all_positions[i].symbol != scope_symbol) ||
            !PMDirectionMatches(scope_direction, all_positions[i].type) ||
            all_positions[i].ticket == 0 ||
            !MathIsValidNumber(all_positions[i].volume) || all_positions[i].volume <= 0.0 ||
            !MathIsValidNumber(all_positions[i].open_price) || all_positions[i].open_price <= 0.0 ||
            !MathIsValidNumber(all_positions[i].current_price) || all_positions[i].current_price <= 0.0 ||
            pending_for_position[i] || point_for_position[i] <= 0.0)
            continue;

         double break_even_candidate = 0.0;
         double trailing_candidate = 0.0;
         double best = 0.0;
         const bool has_break_even = enabled_break_even &&
            PMBreakEvenCandidate(all_positions[i].open_price, all_positions[i].type,
                                 all_positions[i].current_price, point_for_position[i],
                                 be_trigger_points, be_lock_points, break_even_candidate);
         const bool has_trailing = enabled_trailing &&
            PMTrailingCandidate(all_positions[i].open_price, all_positions[i].type,
                                all_positions[i].current_price, point_for_position[i],
                                trail_trigger_points, trail_points, trailing_candidate);
         if(!PMBestStopCandidate(all_positions[i].type, has_break_even, break_even_candidate,
                                 has_trailing, trailing_candidate, best))
            continue;

         const double fallback = (has_break_even && has_trailing) ?
                                 (best == trailing_candidate ? break_even_candidate : trailing_candidate) :
                                 0.0;
         PMAppendTrailingCandidateResult(result_tickets, result_basis_index,
                                        result_candidates, result_fallback_candidates,
                                        all_positions[i].ticket, i, best, fallback);
        }
      return ArraySize(result_tickets);
     }

   bool processed[];
   ArrayResize(processed, total);
   ArrayInitialize(processed, false);
   for(int i = 0; i < total; i++)
     {
      if(processed[i])
         continue;
      if((has_symbol_scope && all_positions[i].symbol != scope_symbol) ||
         !PMDirectionMatches(scope_direction, all_positions[i].type))
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

      bool basket_pending = false;
      for(int j = 0; j < total; j++)
         if(all_positions[j].symbol == basket_symbol && all_positions[j].type == basket_type)
           {
            processed[j] = true;
            if(pending_for_position[j])
               basket_pending = true;
           }
      if(basket_pending)
         continue;

      const double point = point_for_position[i];
      if(point <= 0.0)
         continue;

      double break_even_candidate = 0.0;
      double trailing_candidate = 0.0;
      double best = 0.0;
      const bool has_break_even = enabled_break_even &&
         PMBreakEvenCandidate(basket_open_price, basket_type, basket_current_price, point,
                              be_trigger_points, be_lock_points, break_even_candidate);
      const bool has_trailing = enabled_trailing &&
         PMTrailingCandidate(basket_open_price, basket_type, basket_current_price, point,
                             trail_trigger_points, trail_points, trailing_candidate);
      if(!PMBestStopCandidate(basket_type, has_break_even, break_even_candidate,
                              has_trailing, trailing_candidate, best))
         continue;

      const double fallback = (has_break_even && has_trailing) ?
                              (best == trailing_candidate ? break_even_candidate : trailing_candidate) :
                              0.0;
      for(int t = 0; t < ArraySize(basket_tickets); t++)
         PMAppendTrailingCandidateResult(result_tickets, result_basis_index,
                                        result_candidates, result_fallback_candidates,
                                        basket_tickets[t], i, best, fallback);
     }
   return ArraySize(result_tickets);
  }

class CTrailingStopService
  {
public:
   bool Evaluate(const TrailingStopConfig &config,
                 const PMPosition &all_positions[],
                 CPositionService &positions,
                 CTradeManager &trades,
                 CValidationService &validator,
                 string &status)
     {
      status = "";
      if(!config.enabled_break_even && !config.enabled_trailing)
         return false;

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

      const int total = ArraySize(all_positions);
      double point_for_position[];
      bool pending_for_position[];
      ArrayResize(point_for_position, total);
      ArrayResize(pending_for_position, total);
      for(int i = 0; i < total; i++)
        {
         point_for_position[i] = has_symbol_scope ? scoped_point :
                                 SymbolInfoDouble(all_positions[i].symbol, SYMBOL_POINT);
         pending_for_position[i] = trades.HasPending(all_positions[i].ticket);
        }

      ulong result_tickets[];
      int result_basis_index[];
      double result_candidates[];
      double result_fallback_candidates[];
      PMResolveTrailingCandidates(all_positions, config.basis, config.symbol, config.direction,
                                  point_for_position, pending_for_position,
                                  config.enabled_break_even, config.enabled_trailing,
                                  config.be_trigger_points, config.be_lock_points,
                                  config.trail_trigger_points, config.trail_points,
                                  result_tickets, result_basis_index,
                                  result_candidates, result_fallback_candidates);

      int modified = 0;
      int unchanged = 0;
      int queued = 0;
      int failed = 0;
      ulong first_failed_ticket = 0;
      string first_failure_description = "";
      int validated_basis_index = -1;
      double target = 0.0;
      bool accepted = false;

      for(int r = 0; r < ArraySize(result_tickets); r++)
        {
         // The resolver emits each basket contiguously. Resolve its common
         // target once, including rejection/fallback, before sending trades:
         // fresh quotes between sends must not change the basket's target.
         // Per-position results each have their own basis index.
         if(validated_basis_index != result_basis_index[r])
           {
            validated_basis_index = result_basis_index[r];
            const PMPosition basis_position = all_positions[validated_basis_index];
            string reason = "";
            accepted = CalculateModifyTarget(result_candidates[r], basis_position,
                                             validator, target, reason);
            if(!accepted && result_fallback_candidates[r] > 0.0)
               accepted = CalculateModifyTarget(result_fallback_candidates[r], basis_position,
                                                validator, target, reason);
            if(!accepted)
               PrintFormat("[WARN] Trailing/Break Even candidate rejected ticket=%I64u %s reason=%s",
                           result_tickets[r], PMPositionTypeToString(basis_position.type), reason);
           }
         if(!accepted)
            continue;

         ApplyTargetToTicket(result_tickets[r], target, positions, trades,
                             modified, unchanged, queued, failed,
                             first_failed_ticket, first_failure_description);
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
   bool CalculateModifyTarget(const double candidate,
                              const PMPosition &basis_position,
                              CValidationService &validator,
                              double &target,
                              string &reason)
     {
      reason = "";
      target = 0.0;
      if(!validator.CalculateTarget(basis_position, true,
                                    PM_PRICE_ABSOLUTE, candidate,
                                    target, reason))
         return false;
      return true;
     }

   void ApplyTargetToTicket(const ulong ticket,
                            const double target,
                            CPositionService &positions,
                            CTradeManager &trades,
                            int &modified,
                            int &unchanged,
                            int &queued,
                            int &failed,
                            ulong &first_failed_ticket,
                            string &first_failure_description)
     {
      PMPosition position = {};
      if(!positions.Get(ticket, position))
        {
         failed++;
         if(first_failed_ticket == 0)
           {
            first_failed_ticket = ticket;
            first_failure_description = "Position no longer exists.";
           }
         PrintFormat("[ERROR] Trailing/Break Even modify skipped ticket=%I64u description=%s",
                     ticket, "Position no longer exists.");
         return;
        }

      if(!PMIsMoreFavorableStop(position.type, target, position.sl))
         return;

      PMTradeFailure failure = {};
      const PMTradeAttemptStatus attempt_status =
         trades.ModifyTicket(position.ticket, target, position.tp, failure);
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
  };

#endif
