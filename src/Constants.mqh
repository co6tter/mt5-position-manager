#ifndef __MT5_POSITION_MANAGER_CONSTANTS_MQH__
#define __MT5_POSITION_MANAGER_CONSTANTS_MQH__

#include "Models.mqh"

#define PM_OBJECT_PREFIX "MT5PM_"
#define PM_TIMER_SECONDS 1
#define PM_DEFAULT_MAX_ROWS 12
#define PM_MIN_POSITION_ROWS 3
#define PM_MAX_POSITION_ROWS 50
#define PM_MAX_AUTO_CLOSE_MINUTES 1440
#define PM_MAX_TRAILING_POINTS 1000000
#define PM_MAX_EQUITY_THRESHOLD 1000000000.0
#define PM_DEFAULT_DEVIATION_POINTS 20
#define PM_DEFAULT_RETRY_COUNT 5
#define PM_DEFAULT_RETRY_INTERVAL_SECONDS 3
#define PM_DEFAULT_PANEL_WIDTH 780
#define PM_MIN_PANEL_WIDTH 780
#define PM_MAX_PANEL_WIDTH 1600
#define PM_PANEL_CHROME_HEIGHT 301
#define PM_PANEL_SL_Y 0
#define PM_PANEL_SL_LABEL_Y 3
#define PM_PANEL_TP_Y 33
#define PM_PANEL_TP_LABEL_Y 36
#define PM_PANEL_AUTO_Y 67
#define PM_PANEL_AUTO_LABEL_Y 70
#define PM_PANEL_EQUITY_Y 100
#define PM_PANEL_EQUITY_LABEL_Y 103
#define PM_PANEL_TRAILING_SCOPE_Y 134
#define PM_PANEL_TRAILING_SCOPE_LABEL_Y 137
#define PM_PANEL_BREAK_EVEN_Y 168
#define PM_PANEL_BREAK_EVEN_LABEL_Y 171
#define PM_PANEL_TRAIL_Y 202
#define PM_PANEL_TRAIL_LABEL_Y 205
#define PM_PANEL_SESSION_Y 236
#define PM_PANEL_STATUS_Y 262
#define PM_TITLEBAR_HEIGHT 28
#define PM_RESIZE_HANDLE_HIT_SIZE 28

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
