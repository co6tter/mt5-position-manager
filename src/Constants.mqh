#ifndef __MT5_POSITION_MANAGER_CONSTANTS_MQH__
#define __MT5_POSITION_MANAGER_CONSTANTS_MQH__

#include "Models.mqh"

#define PM_OBJECT_PREFIX "MT5PM_"
#define PM_PANEL_POSITION_KEY_PREFIX "MT5PM_PANEL_POSITION_"
#define PM_TIMER_SECONDS 1
#define PM_DEFAULT_MAX_ROWS 10
#define PM_MIN_POSITION_ROWS 3
#define PM_MAX_POSITION_ROWS 50
#define PM_MAX_AUTO_CLOSE_MINUTES 1440
#define PM_MAX_TRAILING_POINTS 1000000
#define PM_MAX_EQUITY_THRESHOLD 1000000000.0
#define PM_DEFAULT_DEVIATION_POINTS 20
#define PM_DEFAULT_RETRY_COUNT 5
#define PM_DEFAULT_RETRY_INTERVAL_SECONDS 3
#define PM_PANEL_SYMBOL_REFRESH_SECONDS 5
#define PM_SESSION_REFRESH_SECONDS 60
#define PM_SESSION_RETRY_SECONDS 5
#define PM_DEFAULT_PANEL_WIDTH 560
#define PM_MIN_PANEL_WIDTH 560
#define PM_MAX_PANEL_WIDTH 1200
#define PM_PANEL_STATUS_LINE_HEIGHT 18
#define PM_PANEL_CONTENT_GAP 10
#define PM_STATUS_FONT_SIZE 10
#define PM_PANEL_ENTRY_HEIGHT 300
#define PM_PANEL_POSITIONS_HEADER_HEIGHT 80
#define PM_PANEL_POSITION_ROW_HEIGHT 24
#define PM_PANEL_STOPS_HEIGHT 92
#define PM_PANEL_AUTO_HEIGHT 108
#define PM_PANEL_GUARD_HEIGHT 126
#define PM_PANEL_TRAIL_HEIGHT 140
#define PM_TRAIL_TOGGLE_X 100
#define PM_TRAIL_LABEL1_X 170
#define PM_TRAIL_INPUT1_X 215
#define PM_TRAIL_LABEL2_X 345
#define PM_TRAIL_INPUT2_X 400
#define PM_TRAIL_INPUT_WIDTH 60
#define PM_TRAIL_BASIS_ROW_Y 32
#define PM_TRAIL_BASIS_TOGGLE_WIDTH 150
#define PM_TRAIL_BE_ROW_Y 60
#define PM_TRAIL_ROW_Y 88
#define PM_TRAIL_HINT_ROW_Y 120
#define PM_STOPS_MODE_X 42
#define PM_STOPS_DEC_X 123
#define PM_STOPS_VALUE_X 153
#define PM_STOPS_INC_X 269
#define PM_STOPS_SET_BUTTON_X 301
#define PM_STOPS_SET_BUTTON_WIDTH 105
#define PM_STOPS_BUTTON_GAP 6
#define PM_STOPS_CLEAR_BUTTON_WIDTH 90
#define PM_MAX_STATUS_LINES 20
// MT5 silently cuts OBJ_LABEL text after this many characters.
#define PM_MAX_LABEL_TEXT_LENGTH 63
#define PM_TITLEBAR_HEIGHT 28
#define PM_TAB_BAR_HEIGHT 26
#define PM_RESIZE_HANDLE_HIT_SIZE 28
#define PM_EQUITY_LINE_COLOR C'255,182,193'
#define PM_SL_EDIT_LINE_NAME "MT5PM_SL_EDIT_LINE"
#define PM_TP_EDIT_LINE_NAME "MT5PM_TP_EDIT_LINE"
#define PM_SL_EDIT_LABEL_NAME "MT5PM_SL_EDIT_LABEL"
#define PM_TP_EDIT_LABEL_NAME "MT5PM_TP_EDIT_LABEL"
#define PM_SL_EDIT_LINE_COLOR C'255,120,120'
#define PM_TP_EDIT_LINE_COLOR C'120,190,255'
#define PM_ACTIVE_TAB_COLOR C'65,105,145'
#define PM_INACTIVE_TAB_COLOR C'38,48,62'
#define PM_ACTIVE_TAB_BORDER_COLOR C'130,190,230'
#define PM_INACTIVE_TAB_BORDER_COLOR C'70,85,105'
#define PM_STATUS_COLOR C'220,230,245'
#define PM_STATUS_SUCCESS_COLOR C'150,235,180'
#define PM_STATUS_WARNING_COLOR C'255,210,120'
#define PM_STATUS_ERROR_COLOR C'255,145,145'

string PMDirectionToString(const PMDirection direction)
  {
   if(direction == PM_DIRECTION_LONG)
      return "Long";
   if(direction == PM_DIRECTION_SHORT)
      return "Short";
   return "Both";
  }

string PMPositionTypeToString(const ENUM_POSITION_TYPE type)
  {
   return type == POSITION_TYPE_BUY ? "Long" : "Short";
  }

string PMTrailBasisToString(const PMTrailBasis basis)
  {
   return basis == PM_TRAIL_BASIS_PER_POSITION ? "Per Position" : "Average";
  }

PMTrailBasis PMToggleTrailBasis(const PMTrailBasis basis)
  {
   return basis == PM_TRAIL_BASIS_AVERAGE ? PM_TRAIL_BASIS_PER_POSITION : PM_TRAIL_BASIS_AVERAGE;
  }

bool PMDirectionMatches(const PMDirection direction,
                        const ENUM_POSITION_TYPE type)
  {
   if(direction == PM_DIRECTION_BOTH)
      return true;
   if(direction == PM_DIRECTION_LONG)
      return type == POSITION_TYPE_BUY;
   return type == POSITION_TYPE_SELL;
  }

double PMProfitPoints(const double open_price,
                      const ENUM_POSITION_TYPE type,
                      const double current_price,
                      const double point)
  {
   if(point <= 0.0)
      return 0.0;
   return type == POSITION_TYPE_BUY ?
          (current_price - open_price) / point :
          (open_price - current_price) / point;
  }

int PMPointsPerPip(const int digits)
  {
   return digits == 3 || digits == 5 ? 10 : 1;
  }

int PMPipsToPoints(const int pips, const int digits)
  {
   if(pips <= 0)
      return 0;
   return pips * PMPointsPerPip(digits);
  }

double PMPipsToPointDistance(const double pips, const int digits)
  {
   if(pips <= 0.0)
      return 0.0;
   return pips * PMPointsPerPip(digits);
  }

string PMAutoCloseConfigKey(const AutoCloseConfig &config)
  {
   return StringFormat("%s|%d|%d|%d|%d", config.symbol,
                       (int)config.direction, config.minutes_before_close,
                       (int)config.passed_behavior, config.enabled ? 1 : 0);
  }

string PMEquityGuardConfigKey(const EquityGuardConfig &config)
  {
   return StringFormat("%d|%d|%.8f|%.8f", config.enabled ? 1 : 0,
                       (int)config.mode, config.loss_threshold,
                       config.profit_threshold);
  }

bool PMIsTransientTradeRetcode(const uint retcode)
  {
   return retcode == TRADE_RETCODE_REQUOTE ||
          retcode == TRADE_RETCODE_PRICE_CHANGED ||
          retcode == TRADE_RETCODE_PRICE_OFF ||
          retcode == TRADE_RETCODE_TIMEOUT ||
          retcode == TRADE_RETCODE_CONNECTION ||
          retcode == TRADE_RETCODE_LOCKED ||
          retcode == TRADE_RETCODE_TOO_MANY_REQUESTS;
  }

bool PMIsTradingUnavailableRetcode(const uint retcode)
  {
   return retcode == TRADE_RETCODE_TRADE_DISABLED ||
          retcode == TRADE_RETCODE_MARKET_CLOSED ||
          retcode == TRADE_RETCODE_SERVER_DISABLES_AT ||
          retcode == TRADE_RETCODE_CLIENT_DISABLES_AT;
  }

bool PMIsMarketEntrySuccessRetcode(const uint retcode)
  {
   return retcode == TRADE_RETCODE_DONE ||
          retcode == TRADE_RETCODE_DONE_PARTIAL ||
          retcode == TRADE_RETCODE_PLACED;
  }

bool PMIsUnsignedIntegerText(const string text)
  {
   const int length = StringLen(text);
   if(length == 0)
      return false;
   for(int index = 0; index < length; index++)
     {
      const ushort character = StringGetCharacter(text, index);
      if(character < 48 || character > 57)
         return false;
     }
   return true;
  }

bool PMIsUnsignedDecimalText(const string text)
  {
   const int length = StringLen(text);
   if(length == 0)
      return false;
   bool decimal_point_seen = false;
   int digit_count = 0;
   for(int index = 0; index < length; index++)
     {
      const ushort character = StringGetCharacter(text, index);
      if(character >= 48 && character <= 57)
        {
         digit_count++;
         continue;
        }
      if(character == 46 && !decimal_point_seen)
        {
         decimal_point_seen = true;
         continue;
        }
      return false;
     }
   return digit_count > 0;
  }

int PMStepInteger(const int value,
                 const int delta,
                 const int minimum,
                 const int maximum)
  {
   if(maximum < minimum)
      return minimum;
   return (int)MathMax(minimum, MathMin(maximum, (long)value + delta));
  }

double PMStepDecimal(const double value,
                     const double delta,
                     const double minimum,
                     const double maximum,
                     const int digits)
  {
   if(maximum < minimum)
      return minimum;
   if(!MathIsValidNumber(value) || !MathIsValidNumber(delta))
      return minimum;
   const double stepped = MathMax(minimum, MathMin(maximum, value + delta));
   return NormalizeDouble(stepped, digits);
  }

double PMNormalizeVolume(const double value,
                         const double minimum,
                         const double maximum,
                         const double step)
  {
   if(!MathIsValidNumber(value) || !MathIsValidNumber(minimum) ||
      !MathIsValidNumber(maximum) || !MathIsValidNumber(step) ||
      minimum <= 0.0 || maximum < minimum || step <= 0.0)
      return 0.0;
   const double maximum_steps = MathFloor((maximum - minimum) / step + 0.00000001);
   const double aligned_maximum = minimum + maximum_steps * step;
   double clamped = MathMax(minimum, MathMin(value, aligned_maximum));
   const double steps = MathFloor((clamped - minimum) / step + 0.5);
   double normalized = minimum + steps * step;
   if(normalized < minimum)
      normalized = minimum;
   if(normalized > aligned_maximum)
      normalized = aligned_maximum;
   return NormalizeDouble(normalized, 8);
  }

double PMNormalizePrice(const double price,
                        const double tick_size,
                        const int digits)
  {
   if(!MathIsValidNumber(price) || price <= 0.0)
      return 0.0;
   if(tick_size <= 0.0)
      return NormalizeDouble(price, digits);
   return NormalizeDouble(MathRound(price / tick_size) * tick_size, digits);
  }

double PMPriceEditorStep(const double point,
                         const double tick_size,
                         const int digits)
  {
   if(MathIsValidNumber(point) && point > 0.0)
      return (digits == 3 || digits == 5) ? point * 10.0 : point;
   if(MathIsValidNumber(tick_size) && tick_size > 0.0)
      return tick_size;
   return 0.0;
  }

double PMShiftPriceEditorValue(const double value,
                               const double point,
                               const double tick_size,
                               const int direction,
                               const int digits)
  {
   if(!MathIsValidNumber(value) || value <= 0.0 || direction == 0)
      return value;
   const double step = PMPriceEditorStep(point, tick_size, digits);
   if(step <= 0.0)
      return value;
   if(!MathIsValidNumber(tick_size) || tick_size <= 0.0)
      return NormalizeDouble(MathMax(step, value + direction * step), digits);
   // At least one tick in the requested direction, including off-grid input.
   const double steps = MathMax(1.0, MathCeil(step / tick_size - 0.00000001));
   const double ticks = direction > 0 ?
                        MathFloor(value / tick_size + 0.00000001) + steps :
                        MathCeil(value / tick_size - 0.00000001) - steps;
   return NormalizeDouble(MathMax(1.0, ticks) * tick_size, digits);
  }

bool PMCalculateEntryStops(const PMEntrySide side,
                           const double bid,
                           const double ask,
                           const double point,
                           const double tick_size,
                           const int digits,
                           const long stops_level,
                           const long freeze_level,
                           const int sl_points,
                           const int tp_points,
                           double &sl,
                           double &tp,
                           string &reason)
  {
   sl = 0.0;
   tp = 0.0;
   reason = "";
   if((side != PM_ENTRY_BUY && side != PM_ENTRY_SELL) ||
      bid <= 0.0 || ask <= 0.0 || point <= 0.0 || tick_size <= 0.0 ||
      digits < 0 || stops_level < 0 || freeze_level < 0 ||
      sl_points < 0 || tp_points < 0)
     {
      reason = "Current price or entry distance is invalid.";
      return false;
     }

   const double reference = side == PM_ENTRY_BUY ? bid : ask;
   const double minimum_distance = (double)MathMax(stops_level, freeze_level) * point;
   if(sl_points > 0)
     {
      sl = side == PM_ENTRY_BUY ? reference - sl_points * point :
                                  reference + sl_points * point;
      sl = PMNormalizePrice(sl, tick_size, digits);
      if(sl <= 0.0 || (side == PM_ENTRY_BUY ?
                       sl >= reference - minimum_distance :
                       sl <= reference + minimum_distance))
        {
         reason = side == PM_ENTRY_BUY ?
                  "Buy SL is inside the broker's Stops/Freeze Level." :
                  "Sell SL is inside the broker's Stops/Freeze Level.";
         return false;
        }
     }
   if(tp_points > 0)
     {
      tp = side == PM_ENTRY_BUY ? reference + tp_points * point :
                                  reference - tp_points * point;
      tp = PMNormalizePrice(tp, tick_size, digits);
      if(tp <= 0.0 || (side == PM_ENTRY_BUY ?
                       tp <= reference + minimum_distance :
                       tp >= reference - minimum_distance))
        {
         reason = side == PM_ENTRY_BUY ?
                  "Buy TP is inside the broker's Stops/Freeze Level." :
                  "Sell TP is inside the broker's Stops/Freeze Level.";
         return false;
        }
     }
   return true;
  }

bool PMCalculateAssumedEntryPrice(const PMEntryOrderType order_type,
                                  const PMEntrySide side,
                                  const double bid,
                                  const double ask,
                                  const double order_price,
                                  double &entry,
                                  string &reason)
  {
   entry = 0.0;
   reason = "";
   if(side != PM_ENTRY_BUY && side != PM_ENTRY_SELL)
     {
      reason = "Direction is invalid.";
      return false;
     }
   if(order_type == PM_ENTRY_ORDER_MARKET)
     {
      if(bid <= 0.0 || ask <= 0.0 || !MathIsValidNumber(bid) || !MathIsValidNumber(ask))
        {
         reason = "Current price is unavailable.";
         return false;
        }
      entry = side == PM_ENTRY_BUY ? ask : bid;
      return true;
     }
   if(order_type == PM_ENTRY_ORDER_LIMIT || order_type == PM_ENTRY_ORDER_STOP)
     {
      if(order_price <= 0.0 || !MathIsValidNumber(order_price))
        {
         reason = "Order price must be greater than zero.";
         return false;
        }
      entry = order_price;
      return true;
     }
   reason = "Order type is invalid.";
   return false;
  }

bool PMIsStopLossOnLossSide(const PMEntrySide side, const double entry, const double sl)
  {
   if(!MathIsValidNumber(entry) || !MathIsValidNumber(sl) || entry <= 0.0 || sl <= 0.0)
      return false;
   if(side != PM_ENTRY_BUY && side != PM_ENTRY_SELL)
      return false;
   return side == PM_ENTRY_BUY ? sl < entry : sl > entry;
  }

bool PMIsTakeProfitOnProfitSide(const PMEntrySide side, const double entry, const double tp)
  {
   if(!MathIsValidNumber(entry) || !MathIsValidNumber(tp) || entry <= 0.0 || tp <= 0.0)
      return false;
   if(side != PM_ENTRY_BUY && side != PM_ENTRY_SELL)
      return false;
   return side == PM_ENTRY_BUY ? tp > entry : tp < entry;
  }

PMRRStatus PMCalculateCurrentRR(const PMEntrySide side,
                                const double entry,
                                const double sl,
                                const double tp,
                                double &rr,
                                string &reason)
  {
   rr = 0.0;
   reason = "";
   if(!MathIsValidNumber(entry) || entry <= 0.0 ||
      (side != PM_ENTRY_BUY && side != PM_ENTRY_SELL))
     {
      reason = "Entry price or direction is invalid.";
      return PM_RR_INVALID;
     }
   if(!MathIsValidNumber(sl) || !MathIsValidNumber(tp) || sl < 0.0 || tp < 0.0)
     {
      reason = "SL or TP price is invalid.";
      return PM_RR_INVALID;
     }
   if(sl == 0.0)
     {
      reason = "SL is not set.";
      return PM_RR_NOT_AVAILABLE;
     }
   if(tp == 0.0)
     {
      reason = "TP is not set.";
      return PM_RR_NOT_AVAILABLE;
     }
   if(!PMIsStopLossOnLossSide(side, entry, sl))
     {
      reason = "SL is not on the loss side of the entry price.";
      return PM_RR_INVALID;
     }
   if(!PMIsTakeProfitOnProfitSide(side, entry, tp))
     {
      reason = "TP is not on the profit side of the entry price.";
      return PM_RR_INVALID;
     }
   const double risk = MathAbs(entry - sl);
   const double reward = MathAbs(tp - entry);
   if(risk <= 0.0)
     {
      // Defensive: PMIsStopLossOnLossSide already implies risk > 0.
      reason = "SL distance is zero.";
      return PM_RR_INVALID;
     }
   rr = reward / risk;
   if(!MathIsValidNumber(rr) || rr <= 0.0)
     {
      reason = "RR is not finite.";
      rr = 0.0;
      return PM_RR_INVALID;
     }
   reason = "";
   return PM_RR_VALID;
  }

bool PMCalculateAutoTakeProfit(const PMEntrySide side,
                               const double entry,
                               const double sl,
                               const double rr_multiplier,
                               const double point,
                               const double tick_size,
                               const int digits,
                               const long stops_level,
                               const long freeze_level,
                               double &tp,
                               string &reason)
  {
   tp = 0.0;
   reason = "";
   if(!MathIsValidNumber(entry) || entry <= 0.0)
     {
      reason = "Entry price is invalid.";
      return false;
     }
   // This single check covers unset SL, wrong-side SL, and an invalid side at once.
   if(!PMIsStopLossOnLossSide(side, entry, sl))
     {
      reason = "Set a valid SL on the loss side of the entry price before generating an automatic Take Profit.";
      return false;
     }
   if(!MathIsValidNumber(rr_multiplier) || rr_multiplier <= 0.0)
     {
      reason = "RR multiplier must be a positive number.";
      return false;
     }
   if(!MathIsValidNumber(point) || !MathIsValidNumber(tick_size) ||
      point <= 0.0 || tick_size <= 0.0 || digits < 0 || digits > 8 ||
      stops_level < 0 || freeze_level < 0)
     {
      reason = "Current price or entry distance is invalid.";
      return false;
     }
   const double distance = MathAbs(entry - sl);
   const double raw = side == PM_ENTRY_BUY ? entry + distance * rr_multiplier :
                                              entry - distance * rr_multiplier;
   const double candidate = PMNormalizePrice(raw, tick_size, digits);
   if(!MathIsValidNumber(candidate) || candidate <= 0.0)
     {
      reason = "The normalized take-profit price is invalid.";
      return false;
     }
   const double minimum_distance = (double)MathMax(stops_level, freeze_level) * point;
   if(!MathIsValidNumber(minimum_distance))
     {
      reason = "The minimum take-profit distance is invalid.";
      return false;
     }
   if(side == PM_ENTRY_BUY ? candidate <= entry + minimum_distance :
                             candidate >= entry - minimum_distance)
     {
      reason = side == PM_ENTRY_BUY ?
               "Buy TP is inside the broker's Stops/Freeze Level." :
               "Sell TP is inside the broker's Stops/Freeze Level.";
      return false;
     }
   tp = candidate;
   return true;
  }

bool PMNextTakeProfitState(const PMTpState current_state,
                           const PMTpEvent event,
                           const bool has_valid_stop_loss,
                           PMTpState &next_state,
                           string &reason)
  {
   reason = "";
   next_state = current_state;
   switch(event)
     {
      case PM_TP_EVENT_SL_CHANGED:
         // Auto recomputes the TP price elsewhere; Manual/Off stay untouched.
         return true;
      case PM_TP_EVENT_SL_CANCELED:
         // The caller freezes whatever TP price was already displayed.
         if(current_state == PM_TP_STATE_AUTO)
            next_state = PM_TP_STATE_MANUAL;
         return true;
      case PM_TP_EVENT_TP_SET_MANUAL:
         next_state = PM_TP_STATE_MANUAL;
         return true;
      case PM_TP_EVENT_TP_CANCELED:
         // The caller sets the TP price to 0.
         next_state = PM_TP_STATE_OFF;
         return true;
      case PM_TP_EVENT_RR_CHANGED:
         // Auto recomputes the TP price elsewhere; Manual/Off ignore RR changes.
         return true;
      case PM_TP_EVENT_REVERT_TO_AUTO:
         if(has_valid_stop_loss)
           {
            next_state = PM_TP_STATE_AUTO;
            return true;
           }
         reason = "Set a valid SL before reverting to automatic Take Profit.";
         return false;
      default:
         reason = "Unknown Take Profit event.";
         return false;
     }
  }

bool PMCalculateRiskBudget(const PMQuantityMode mode,
                           const double manual_amount,
                           const double balance,
                           const double percent,
                           double &budget,
                           string &reason)
  {
   budget = 0.0;
   reason = "";
   if(mode == PM_QUANTITY_RISK_AMOUNT)
     {
      if(!MathIsValidNumber(manual_amount) || manual_amount <= 0.0)
        {
         reason = "Risk amount must be greater than zero.";
         return false;
        }
      budget = manual_amount;
      return true;
     }
   if(mode == PM_QUANTITY_RISK_PERCENT)
     {
      if(!MathIsValidNumber(balance) || balance <= 0.0)
        {
         reason = "Account balance must be greater than zero.";
         return false;
        }
      if(!MathIsValidNumber(percent) || percent <= 0.0 || percent > 100.0)
        {
         reason = "Risk percent must be greater than zero and at most 100.";
         return false;
        }
      // Divide the percentage first so a finite budget cannot overflow
      // merely because balance * percent exceeds the double range.
      budget = balance * (percent / 100.0);
      if(!MathIsValidNumber(budget) || budget <= 0.0)
        {
         budget = 0.0;
         reason = "Calculated risk budget is invalid.";
         return false;
        }
      return true;
     }
   // PM_QUANTITY_MANUAL_LOT (and any other value) never uses a risk budget;
   // the caller in a later task never calls this function in Manual Lot mode.
   reason = "Manual Lot mode does not use a risk budget.";
   return false;
  }

bool PMCalculateRiskLot(const double budget,
                        const double reference_volume,
                        const double reference_loss,
                        const double volume_min,
                        const double volume_max,
                        const double volume_step,
                        double &lot,
                        double &estimated_loss,
                        string &reason)
  {
   lot = 0.0;
   estimated_loss = 0.0;
   reason = "";
   if(!MathIsValidNumber(budget) || budget <= 0.0)
     {
      reason = "Risk budget must be greater than zero.";
      return false;
     }
   if(!MathIsValidNumber(reference_volume) || reference_volume <= 0.0)
     {
      reason = "Reference volume is invalid.";
      return false;
     }
   if(!MathIsValidNumber(reference_loss) || reference_loss <= 0.0)
     {
      reason = "Calculated loss is invalid.";
      return false;
     }
   if(!MathIsValidNumber(volume_min) || !MathIsValidNumber(volume_max) ||
      !MathIsValidNumber(volume_step) || volume_min <= 0.0 ||
      volume_max < volume_min || volume_step <= 0.0)
     {
      reason = "Symbol volume limits are invalid.";
      return false;
     }
   const double raw_lot = budget * reference_volume / reference_loss;
   if(!MathIsValidNumber(raw_lot) || raw_lot <= 0.0)
     {
      reason = "Calculated lot is invalid.";
      return false;
     }
   // Same epsilon as PMNormalizeVolume; intentionally floors instead of
   // rounding to nearest (do not call PMNormalizeVolume from here -- it
   // could round a risk-derived lot up past the budget).
   const double aligned_maximum = volume_min +
                                  MathFloor((volume_max - volume_min) / volume_step + 0.00000001) * volume_step;
   if(!MathIsValidNumber(aligned_maximum) || aligned_maximum < volume_min)
     {
      reason = "Symbol volume limits cannot be aligned.";
      return false;
     }
   if(raw_lot < volume_min)
     {
      reason = "Calculated lot is below the symbol's minimum volume.";
      lot = 0.0;
      estimated_loss = 0.0;
      return false;
     }
   const double bounded = MathMin(raw_lot, aligned_maximum);
   double steps = MathFloor((bounded - volume_min) / volume_step + 0.00000001);
   // The epsilon recovers exact step boundaries lost to floating point,
   // but can also round a just-unaffordable lot up. Check the final loss
   // and, in that case, try exactly one lower step before accepting it.
   for(int attempt = 0; attempt < 2; attempt++)
     {
      const double candidate = NormalizeDouble(volume_min + steps * volume_step, 8);
      const double candidate_loss = candidate / reference_volume * reference_loss;
      if(!MathIsValidNumber(candidate) || !MathIsValidNumber(candidate_loss) ||
         candidate < volume_min || candidate_loss <= 0.0 || steps < 0.0)
        {
         reason = "Calculated lot or loss is invalid.";
         return false;
        }
      if(candidate <= volume_max && candidate_loss <= budget)
        {
         lot = candidate;
         estimated_loss = candidate_loss;
         return true;
        }
      steps -= 1.0;
     }
   reason = "No valid lot fits the risk budget and symbol volume limits.";
   return false;
  }

void PMRecomputeEntry(const PMEntrySnapshot &snapshot, PMEntryComputation &computation)
  {
   // Clear derived prices first; a canceled TP must never reuse stale input.
   computation.entry_ok = false;
   computation.entry = 0.0;
   computation.entry_reason = "";
   computation.effective_tp = snapshot.tp_state == PM_TP_STATE_MANUAL ? snapshot.tp_price : 0.0;
   computation.tp_auto_ok = false;
   computation.tp_reason = "";
   computation.rr_status = PM_RR_NOT_AVAILABLE;
   computation.rr = 0.0;
   computation.rr_reason = "";
   computation.lot_ok = false;
   computation.lot = 0.0;
   computation.estimated_loss = 0.0;
   computation.lot_reason = "";

   // 1. Entry price. Nothing downstream is meaningful without a valid entry.
   computation.entry_ok = PMCalculateAssumedEntryPrice(snapshot.order_type, snapshot.side,
                             snapshot.bid, snapshot.ask, snapshot.order_price,
                             computation.entry, computation.entry_reason);
   if(!computation.entry_ok)
     {
      computation.rr_status = PM_RR_INVALID;
      computation.rr_reason = computation.entry_reason;
      computation.tp_reason = computation.entry_reason;
      computation.lot_reason = computation.entry_reason;
      return;
     }

   // 2. Effective TP.
   if(snapshot.tp_state == PM_TP_STATE_AUTO)
     {
      if(PMIsStopLossOnLossSide(snapshot.side, computation.entry, snapshot.sl_price))
        {
         computation.tp_auto_ok = PMCalculateAutoTakeProfit(snapshot.side, computation.entry, snapshot.sl_price,
                                     snapshot.rr_multiplier, snapshot.point, snapshot.tick_size, snapshot.digits,
                                     snapshot.stops_level, snapshot.freeze_level,
                                     computation.effective_tp, computation.tp_reason);
         if(!computation.tp_auto_ok)
            computation.effective_tp = 0.0;
        }
      else
        {
         // No valid SL yet -- the normal "Auto but nothing to derive from" case, not an error.
         computation.tp_auto_ok = false;
         computation.effective_tp = 0.0;
         computation.tp_reason = "Set a valid SL to generate an automatic Take Profit.";
        }
     }
   else
     {
      // Only Manual may retain a price; Off always wins over old input.
      computation.effective_tp = snapshot.tp_state == PM_TP_STATE_MANUAL ? snapshot.tp_price : 0.0;
      computation.tp_auto_ok = true;
      computation.tp_reason = "";
     }

   // 3. Current RR.
   computation.rr_status = PMCalculateCurrentRR(snapshot.side, computation.entry,
                              snapshot.sl_price, computation.effective_tp,
                              computation.rr, computation.rr_reason);

   // 4. Lot.
   if(snapshot.quantity_mode == PM_QUANTITY_MANUAL_LOT)
     {
      if(!MathIsValidNumber(snapshot.manual_lot) || snapshot.manual_lot <= 0.0)
         computation.lot_reason = "Entry lot must be greater than zero.";
      else
        {
         computation.lot = PMNormalizeVolume(snapshot.manual_lot, snapshot.volume_min,
                                             snapshot.volume_max, snapshot.volume_step);
         computation.lot_ok = MathIsValidNumber(computation.lot) && computation.lot > 0.0;
         if(!computation.lot_ok)
           {
            computation.lot = 0.0;
            computation.lot_reason = "Symbol volume limits are invalid.";
           }
        }
     }
   else
     {
      double budget = 0.0;
      string budget_reason = "";
      const bool budget_ok = PMCalculateRiskBudget(snapshot.quantity_mode, snapshot.risk_amount,
                                snapshot.balance, snapshot.risk_percent, budget, budget_reason);
      if(!budget_ok)
        {
         computation.lot_ok = false;
         computation.lot = 0.0;
         computation.estimated_loss = 0.0;
         computation.lot_reason = budget_reason;
        }
      else if(!PMIsStopLossOnLossSide(snapshot.side, computation.entry, snapshot.sl_price))
        {
         computation.lot_ok = false;
         computation.lot = 0.0;
         computation.estimated_loss = 0.0;
         computation.lot_reason = "Set a valid SL on the loss side of the entry price to use risk-based sizing.";
        }
      else
        {
         computation.lot_ok = PMCalculateRiskLot(budget, snapshot.reference_volume, snapshot.reference_loss,
                                 snapshot.volume_min, snapshot.volume_max, snapshot.volume_step,
                                 computation.lot, computation.estimated_loss, computation.lot_reason);
        }
     }
  }

// Price geometry for a new order. Market protections are constrained by the
// current close quote; pending protections are constrained by the order price.
bool PMValidateEntryGeometry(const PMEntryOrderType order_type, const PMEntrySide side,
                             const double entry, const double bid, const double ask,
                             const double sl, const double tp, const double point,
                             const double tick_size, const int digits,
                             const long stops_level, const long freeze_level, string &reason)
  {
   reason = "";
   if(!MathIsValidNumber(entry) || entry <= 0.0 || !MathIsValidNumber(bid) || bid <= 0.0 ||
      !MathIsValidNumber(ask) || ask < bid || !MathIsValidNumber(sl) || sl < 0.0 ||
      !MathIsValidNumber(tp) || tp < 0.0 || !MathIsValidNumber(point) || point <= 0.0 ||
      !MathIsValidNumber(tick_size) || tick_size <= 0.0 || digits < 0 || digits > 8 ||
      stops_level < 0 || freeze_level < 0 || (side != PM_ENTRY_BUY && side != PM_ENTRY_SELL))
     { reason = "Entry prices or symbol constraints are invalid."; return false; }
   const double minimum = MathMax(stops_level, freeze_level) * point;
   if(!MathIsValidNumber(minimum)) { reason = "Broker distance is invalid."; return false; }
   if(order_type != PM_ENTRY_ORDER_MARKET)
     {
      double distance = 0.0;
      if(order_type == PM_ENTRY_ORDER_LIMIT) distance = side == PM_ENTRY_BUY ? ask - entry : entry - bid;
      else if(order_type == PM_ENTRY_ORDER_STOP) distance = side == PM_ENTRY_BUY ? entry - ask : bid - entry;
      else { reason = "Order type is invalid."; return false; }
      if(distance <= minimum) { reason = "Pending price is on the wrong side or inside the broker distance."; return false; }
      if(MathAbs(PMNormalizePrice(entry, tick_size, digits) - entry) > tick_size * 0.000001)
        { reason = "Order price is not aligned to Tick Size."; return false; }
     }
   const double base = order_type == PM_ENTRY_ORDER_MARKET ? (side == PM_ENTRY_BUY ? bid : ask) : entry;
   if(sl > 0.0 && (!PMIsStopLossOnLossSide(side, entry, sl) ||
                   (side == PM_ENTRY_BUY ? sl >= base - minimum : sl <= base + minimum)))
     { reason = "SL is on the wrong side or inside the broker distance."; return false; }
   if(tp > 0.0 && (!PMIsTakeProfitOnProfitSide(side, entry, tp) ||
                   (side == PM_ENTRY_BUY ? tp <= base + minimum : tp >= base - minimum)))
     { reason = "TP is on the wrong side or inside the broker distance."; return false; }
   if((sl > 0.0 && MathAbs(PMNormalizePrice(sl, tick_size, digits) - sl) > tick_size * 0.000001) ||
      (tp > 0.0 && MathAbs(PMNormalizePrice(tp, tick_size, digits) - tp) > tick_size * 0.000001))
     { reason = "SL/TP is not aligned to Tick Size."; return false; }
   return true;
  }

int PMWrapStatus(const string text,
                 const int max_chars,
                 string &lines[])
  {
   ArrayResize(lines, 0);
   const int width = MathMax(1, max_chars);
   string remaining = text;
   while(StringLen(remaining) > width)
     {
      int cut = width;
      while(cut > 1 && StringGetCharacter(remaining, cut) != 32)
         cut--;
      if(cut <= 1)
         cut = width;
      const int count = ArraySize(lines);
      ArrayResize(lines, count + 1);
      lines[count] = StringSubstr(remaining, 0, cut);
      remaining = StringSubstr(remaining, cut);
      while(StringLen(remaining) > 0 && StringGetCharacter(remaining, 0) == 32)
         remaining = StringSubstr(remaining, 1);
     }
   const int count = ArraySize(lines);
   ArrayResize(lines, count + 1);
   lines[count] = remaining;
   return ArraySize(lines);
  }

bool PMStatusHasNonZeroFailure(const string text)
  {
   const string marker = "failed";
   int search_from = 0;
   while(true)
     {
      const int marker_at = StringFind(text, marker, search_from);
      if(marker_at < 0)
         return false;

      int number_end = marker_at - 1;
      while(number_end >= 0 && StringGetCharacter(text, number_end) == 32)
         number_end--;
      int number_start = number_end;
      while(number_start >= 0)
        {
         const ushort character = StringGetCharacter(text, number_start);
         if(character < 48 || character > 57)
            break;
         number_start--;
        }
      number_start++;
      if(number_start > number_end ||
         StringToInteger(StringSubstr(text, number_start, number_end - number_start + 1)) > 0)
         return true;
      search_from = marker_at + StringLen(marker);
     }
  }

PMStatusSeverity PMResolveStatusSeverity(const string text)
  {
   if(PMStatusHasNonZeroFailure(text) ||
      StringFind(text, "error") >= 0 ||
      StringFind(text, "Error") >= 0 ||
      StringFind(text, "ERROR") >= 0 ||
      StringFind(text, "stopped") >= 0 ||
      StringFind(text, "unavailable") >= 0 ||
      StringFind(text, "invalid") >= 0 ||
      StringFind(text, "Invalid") >= 0 ||
      StringFind(text, "could not") >= 0 ||
      StringFind(text, "must be") >= 0)
      return PM_STATUS_ERROR;

   if(StringFind(text, "scheduled") >= 0 ||
      StringFind(text, "queued") >= 0 ||
      StringFind(text, "retry") >= 0 ||
      StringFind(text, "pending") >= 0)
      return PM_STATUS_WARNING;

   if(StringFind(text, "accepted") >= 0 ||
      StringFind(text, "updated") >= 0 ||
      StringFind(text, "Updated") >= 0 ||
      StringFind(text, "set") >= 0 ||
      StringFind(text, "closed") >= 0 ||
      StringFind(text, "succeeded") >= 0 ||
      StringFind(text, "unchanged") >= 0)
      return PM_STATUS_SUCCESS;

   return PM_STATUS_NORMAL;
  }

int PMResolvePanelHeight(const int required_height,
                         const int requested_height)
  {
   int resolved = required_height;
   if(resolved < 1)
      resolved = 1;
   if(requested_height > resolved)
      resolved = requested_height;
   return resolved;
  }

// Characters that belong on the current label row: the pixel fit capped by the
// OBJ_LABEL limit, ending after a space when the row must break.
int PMLabelLineBreak(const string text, const int fitting)
  {
   const int length = StringLen(text);
   const int limit = MathMax(1, MathMin(fitting, PM_MAX_LABEL_TEXT_LENGTH));
   if(limit >= length)
      return length;
   int cut = limit;
   while(cut > 1 && StringGetCharacter(text, cut - 1) != 32)
      cut--;
   return cut > 1 ? cut : limit;
  }

string PMTruncateLabelText(const string text)
  {
   if(StringLen(text) <= PM_MAX_LABEL_TEXT_LENGTH)
      return text;
   return StringSubstr(text, 0, PM_MAX_LABEL_TEXT_LENGTH - 3) + "...";
  }

string PMFormatPrice(const string symbol, const double price)
  {
   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(price == 0.0)
      return "-";
   return DoubleToString(price, digits);
  }

string PMFormatDateTime(const datetime value)
  {
   if(value <= 0)
      return "-";
   return TimeToString(value, TIME_DATE | TIME_MINUTES);
  }

int PMDateKey(const datetime value)
  {
   MqlDateTime tm = {};
   TimeToStruct(value, tm);
   return tm.year * 10000 + tm.mon * 100 + tm.day;
  }

void PMResetBatchResult(PMBatchResult &result, const int requested = 0)
  {
   result.requested = requested;
   result.successful = 0;
   result.unchanged = 0;
   result.queued = 0;
   ArrayResize(result.failures, 0);
  }

void PMResetTradeFailure(PMTradeFailure &failure)
  {
   failure.ticket = 0;
   failure.retcode = 0;
   failure.description = "";
   failure.attempts = 0;
  }

void PMResetMarketEntryResult(PMMarketEntryResult &result)
  {
   result.request_ok = false;
   result.retcode = 0;
   result.description = "";
   result.deal = 0;
   result.order = 0;
   result.volume = 0.0;
   result.price = 0.0;
  }

void PMAddFailure(PMBatchResult &result,
                  const ulong ticket,
                  const uint retcode,
                  const string description,
                  const int attempts)
  {
   const int count = ArraySize(result.failures);
   ArrayResize(result.failures, count + 1);
   result.failures[count].ticket = ticket;
   result.failures[count].retcode = retcode;
   result.failures[count].description = description;
   result.failures[count].attempts = attempts;
  }

#endif
