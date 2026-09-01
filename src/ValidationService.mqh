#ifndef __MT5_POSITION_MANAGER_VALIDATION_SERVICE_MQH__
#define __MT5_POSITION_MANAGER_VALIDATION_SERVICE_MQH__

#include "Models.mqh"

class CValidationService
  {
public:
   bool CalculateTarget(const PMPosition &position,
                        const bool is_sl,
                        const PMPriceMode mode,
                        const double value,
                        double &target,
                        string &reason)
     {
      reason = "";
      target = 0.0;
      if(value <= 0.0 || !MathIsValidNumber(value))
        {
         reason = "Value must be greater than zero.";
         return false;
        }

      target = value;
      if(mode == PM_PRICE_PIPS)
        {
         MqlTick tick = {};
         if(!SymbolInfoTick(position.symbol, tick))
           {
            reason = "No current tick is available for " + position.symbol + ".";
            return false;
           }
         const double base = position.type == POSITION_TYPE_BUY ? tick.bid : tick.ask;
         if(base <= 0.0)
           {
            reason = "Current price is unavailable for " + position.symbol + ".";
            return false;
           }
         const double point = SymbolInfoDouble(position.symbol, SYMBOL_POINT);
         const int digits = (int)SymbolInfoInteger(position.symbol, SYMBOL_DIGITS);
         if(point <= 0.0)
           {
            reason = "Point size is unavailable for " + position.symbol + ".";
            return false;
           }
         const double points = PMPipsToPointDistance(value, digits);
         if(is_sl)
            target = position.type == POSITION_TYPE_BUY ? base - points * point : base + points * point;
         else
            target = position.type == POSITION_TYPE_BUY ? base + points * point : base - points * point;
        }

      target = NormalizeToTick(position.symbol, target);
      if(target <= 0.0)
        {
         reason = "The normalized price is invalid.";
         return false;
        }

      MqlTick tick = {};
      if(!SymbolInfoTick(position.symbol, tick))
        {
         reason = "No current tick is available for " + position.symbol + ".";
         return false;
        }
      const double close_price = position.type == POSITION_TYPE_BUY ? tick.bid : tick.ask;
      const double point = SymbolInfoDouble(position.symbol, SYMBOL_POINT);
      const long stops_level = SymbolInfoInteger(position.symbol, SYMBOL_TRADE_STOPS_LEVEL);
      const long freeze_level = SymbolInfoInteger(position.symbol, SYMBOL_TRADE_FREEZE_LEVEL);
      const double minimum_distance = (double)MathMax(stops_level, freeze_level) * point;

      if(position.type == POSITION_TYPE_BUY)
        {
         if(is_sl && target >= close_price - minimum_distance)
           {
            reason = "Long SL must be below Bid by the broker's Stops/Freeze Level.";
            return false;
           }
         if(!is_sl && target <= close_price + minimum_distance)
           {
            reason = "Long TP must be above Bid by the broker's Stops/Freeze Level.";
            return false;
           }
        }
      else
        {
         if(is_sl && target <= close_price + minimum_distance)
           {
            reason = "Short SL must be above Ask by the broker's Stops/Freeze Level.";
            return false;
           }
         if(!is_sl && target >= close_price - minimum_distance)
           {
            reason = "Short TP must be below Ask by the broker's Stops/Freeze Level.";
            return false;
           }
        }
      return true;
     }

   bool CalculateEntryStops(const string symbol,
                            const PMEntrySide side,
                            const int sl_points,
                            const int tp_points,
                            double &sl,
                            double &tp,
                            string &reason)
     {
      sl = 0.0;
      tp = 0.0;
      reason = "";
      MqlTick tick = {};
      if(!SymbolInfoTick(symbol, tick) || tick.bid <= 0.0 || tick.ask <= 0.0)
        {
         reason = "No current tick is available for " + symbol + ".";
         return false;
        }
      const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      const double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      const long stops_level = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
      const long freeze_level = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
      if(!PMCalculateEntryStops(side, tick.bid, tick.ask, point, tick_size, digits,
                                stops_level, freeze_level, sl_points, tp_points,
                                sl, tp, reason))
         return false;
      return true;
     }

   double NormalizeToTick(const string symbol, const double price)
     {
      const double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      if(tick_size <= 0.0)
         return NormalizeDouble(price, digits);
      return NormalizeDouble(MathRound(price / tick_size) * tick_size, digits);
     }
  };

#endif
