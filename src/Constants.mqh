#ifndef __MT5_POSITION_MANAGER_CONSTANTS_MQH__
#define __MT5_POSITION_MANAGER_CONSTANTS_MQH__

#include "Models.mqh"

#define PM_OBJECT_PREFIX "MT5PM_"
#define PM_TIMER_SECONDS 1
#define PM_DEFAULT_MAX_ROWS 12
#define PM_MIN_POSITION_ROWS 3
#define PM_MAX_POSITION_ROWS 50
#define PM_MAX_AUTO_CLOSE_MINUTES 1440
#define PM_DEFAULT_DEVIATION_POINTS 20
#define PM_DEFAULT_RETRY_COUNT 5
#define PM_DEFAULT_RETRY_INTERVAL_SECONDS 3
#define PM_DEFAULT_PANEL_WIDTH 780
#define PM_MIN_PANEL_WIDTH 780
#define PM_MAX_PANEL_WIDTH 1600
#define PM_TITLEBAR_HEIGHT 28
#define PM_RESIZE_HANDLE_SIZE 14

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
