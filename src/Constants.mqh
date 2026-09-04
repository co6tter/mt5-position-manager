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
#define PM_DEFAULT_PANEL_WIDTH 560
#define PM_MIN_PANEL_WIDTH 560
#define PM_MAX_PANEL_WIDTH 1200
#define PM_PANEL_STATUS_LINE_HEIGHT 18
#define PM_PANEL_CONTENT_GAP 10
#define PM_STATUS_FONT_SIZE 10
#define PM_PANEL_ENTRY_HEIGHT 178
#define PM_PANEL_POSITIONS_HEADER_HEIGHT 80
#define PM_PANEL_POSITION_ROW_HEIGHT 24
#define PM_PANEL_STOPS_HEIGHT 92
#define PM_PANEL_AUTO_HEIGHT 108
#define PM_PANEL_GUARD_HEIGHT 92
#define PM_PANEL_TRAIL_HEIGHT 138
#define PM_STOPS_MODE_X 42
#define PM_STOPS_DEC_X 123
#define PM_STOPS_VALUE_X 153
#define PM_STOPS_INC_X 269
#define PM_STOPS_SET_BUTTON_X 301
#define PM_STOPS_SET_BUTTON_WIDTH 105
#define PM_STOPS_BUTTON_GAP 6
#define PM_STOPS_CLEAR_BUTTON_WIDTH 90
#define PM_MAX_STATUS_LINES 20
#define PM_TITLEBAR_HEIGHT 28
#define PM_TAB_BAR_HEIGHT 26
#define PM_RESIZE_HANDLE_HIT_SIZE 28
#define PM_EQUITY_LINE_COLOR C'255,182,193'
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
   return NormalizeDouble(value + direction * step, digits);
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
