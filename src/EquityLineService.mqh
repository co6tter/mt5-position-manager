#ifndef __MT5_POSITION_MANAGER_EQUITY_LINE_SERVICE_MQH__
#define __MT5_POSITION_MANAGER_EQUITY_LINE_SERVICE_MQH__

#include "Models.mqh"
#include "Constants.mqh"
#include "PositionService.mqh"

#define PM_EQUITY_LINE_OBJECT_NAME "MT5PMEquityBreakEvenLine"

bool PMCalculateEquityLinePrice(const PMPosition &positions[],
                                const string symbol,
                                double &price)
  {
   price = 0.0;
   if(symbol == "")
      return false;

   double net_volume = 0.0;
   double signed_price_volume = 0.0;
   for(int index = 0; index < ArraySize(positions); index++)
     {
      if(positions[index].symbol != symbol ||
         !MathIsValidNumber(positions[index].volume) ||
         !MathIsValidNumber(positions[index].open_price) ||
         positions[index].volume <= 0.0 ||
         positions[index].open_price <= 0.0)
         continue;

      const double direction = positions[index].type == POSITION_TYPE_BUY ?
                               1.0 : -1.0;
      const double signed_volume = direction * positions[index].volume;
      net_volume += signed_volume;
      signed_price_volume += signed_volume * positions[index].open_price;
     }

   if(MathAbs(net_volume) <= 0.00000001)
      return false;
   price = signed_price_volume / net_volume;
   return MathIsValidNumber(price) && price > 0.0;
  }

class CEquityLineService
  {
private:
   bool m_error_reported;

public:
   CEquityLineService()
     {
      m_error_reported = false;
     }

   bool Render(const string symbol, CPositionService &position_service)
     {
      PMPosition positions[];
      position_service.Collect(positions);
      double price = 0.0;
      if(!PMCalculateEquityLinePrice(positions, symbol, price))
        {
         if(!EnsureCreated(PlaceholderPrice(symbol)))
            return false;
         SetLineVisibility(false);
         m_error_reported = false;
         return false;
        }

      const double tick_size = SymbolInfoDouble(symbol,
                                                SYMBOL_TRADE_TICK_SIZE);
      const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      price = PMNormalizePrice(price, tick_size, digits);
      if(price <= 0.0)
        {
         SetLineVisibility(false);
         return false;
        }

      if(!EnsureCreated(price))
         return false;

      ObjectSetInteger(0, PM_EQUITY_LINE_OBJECT_NAME, OBJPROP_COLOR,
                       PM_EQUITY_LINE_COLOR);
      ObjectSetInteger(0, PM_EQUITY_LINE_OBJECT_NAME, OBJPROP_STYLE,
                       STYLE_DOT);
      ObjectSetInteger(0, PM_EQUITY_LINE_OBJECT_NAME, OBJPROP_WIDTH, 1);
      // Keep the line above broker entry/trade levels while the panel's
      // foreground rectangle and controls remain visually on top of it.
      ObjectSetInteger(0, PM_EQUITY_LINE_OBJECT_NAME, OBJPROP_BACK, false);
      ObjectSetInteger(0, PM_EQUITY_LINE_OBJECT_NAME, OBJPROP_ZORDER, 0);
      ObjectSetInteger(0, PM_EQUITY_LINE_OBJECT_NAME,
                       OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, PM_EQUITY_LINE_OBJECT_NAME, OBJPROP_HIDDEN, true);
      SetLineVisibility(true);
      ObjectSetString(0, PM_EQUITY_LINE_OBJECT_NAME, OBJPROP_TEXT,
                      "Equity / Break-even");
      ResetLastError();
      if(!ObjectSetDouble(0, PM_EQUITY_LINE_OBJECT_NAME, OBJPROP_PRICE, price))
        {
         ReportError("update");
         return false;
        }
      m_error_reported = false;
      return true;
     }

   void Destroy()
     {
      Delete();
     }

private:
   bool EnsureCreated(const double price)
     {
      if(ObjectFind(0, PM_EQUITY_LINE_OBJECT_NAME) >= 0)
         return true;
      ResetLastError();
      if(!ObjectCreate(0, PM_EQUITY_LINE_OBJECT_NAME, OBJ_HLINE,
                       0, 0, price))
        {
         ReportError("create");
         return false;
        }
      return true;
     }
   double PlaceholderPrice(const string symbol)
     {
      const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      if(MathIsValidNumber(bid) && bid > 0.0)
         return bid;
      return 1.0;
     }
   void SetLineVisibility(const bool visible)
     {
      ObjectSetInteger(0, PM_EQUITY_LINE_OBJECT_NAME,
                       OBJPROP_TIMEFRAMES,
                       visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
     }
   void Delete()
     {
      if(ObjectFind(0, PM_EQUITY_LINE_OBJECT_NAME) >= 0)
         ObjectDelete(0, PM_EQUITY_LINE_OBJECT_NAME);
     }

   void ReportError(const string operation)
     {
      if(m_error_reported)
         return;
      PrintFormat("[ERROR] Unable to %s Equity / Break-even line. error=%d",
                  operation, GetLastError());
      m_error_reported = true;
     }
  };

#endif
