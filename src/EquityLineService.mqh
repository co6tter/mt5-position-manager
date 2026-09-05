#ifndef __MT5_POSITION_MANAGER_EQUITY_LINE_SERVICE_MQH__
#define __MT5_POSITION_MANAGER_EQUITY_LINE_SERVICE_MQH__

#include "Models.mqh"
#include "Constants.mqh"

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
   bool m_created;
   bool m_visibility_known;
   bool m_visible;
   bool m_price_known;
   double m_price;

public:
   CEquityLineService()
     {
      m_error_reported = false;
      m_created = false;
      m_visibility_known = false;
      m_visible = false;
      m_price_known = false;
      m_price = 0.0;
     }

   // Returns true only when a chart redraw is needed.
   bool Render(const string symbol, const PMPosition &positions[])
     {
      double price = 0.0;
      if(!PMCalculateEquityLinePrice(positions, symbol, price))
        {
         if(!EnsureCreated(PlaceholderPrice(symbol)))
            return false;
         bool changed = false;
         if(!SetLineVisibility(false, changed))
            return false;
         m_error_reported = false;
         return changed;
        }

      const double tick_size = SymbolInfoDouble(symbol,
                                                SYMBOL_TRADE_TICK_SIZE);
      const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      price = PMNormalizePrice(price, tick_size, digits);
      if(price <= 0.0)
        {
         if(!EnsureCreated(PlaceholderPrice(symbol)))
            return false;
         bool changed = false;
         if(!SetLineVisibility(false, changed))
            return false;
         m_error_reported = false;
         return changed;
        }

      if(!EnsureCreated(price))
         return false;

      bool changed = false;
      if(!SetLineVisibility(true, changed))
         return false;
      if(!m_price_known || price != m_price)
        {
         ResetLastError();
         if(!ObjectSetDouble(0, PM_EQUITY_LINE_OBJECT_NAME,
                             OBJPROP_PRICE, price))
           {
            const int error_code = GetLastError();
            Delete();
            ReportError("update", error_code);
            return false;
           }
         m_price = price;
         m_price_known = true;
         changed = true;
        }
      m_error_reported = false;
      return changed;
     }

   void Destroy()
     {
      Delete();
     }

private:
   bool EnsureCreated(const double price)
     {
      if(m_created)
         return true;
      const bool exists = ObjectFind(0, PM_EQUITY_LINE_OBJECT_NAME) >= 0;
      if(!exists)
        {
         ResetLastError();
         if(!ObjectCreate(0, PM_EQUITY_LINE_OBJECT_NAME, OBJ_HLINE,
                          0, 0, price))
           {
            ReportError("create", GetLastError());
            return false;
           }
        }
      m_created = true;
      m_visibility_known = false;
      m_price_known = !exists;
      m_price = price;
      ObjectSetInteger(0, PM_EQUITY_LINE_OBJECT_NAME, OBJPROP_COLOR,
                       PM_EQUITY_LINE_COLOR);
      ObjectSetInteger(0, PM_EQUITY_LINE_OBJECT_NAME, OBJPROP_STYLE,
                       STYLE_DOT);
      ObjectSetInteger(0, PM_EQUITY_LINE_OBJECT_NAME, OBJPROP_WIDTH, 1);
      // Draw the line in the chart background so the panel foreground
      // rectangle and controls always remain visually on top of it.
      ObjectSetInteger(0, PM_EQUITY_LINE_OBJECT_NAME, OBJPROP_BACK, true);
      ObjectSetInteger(0, PM_EQUITY_LINE_OBJECT_NAME, OBJPROP_ZORDER, 0);
      ObjectSetInteger(0, PM_EQUITY_LINE_OBJECT_NAME,
                       OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, PM_EQUITY_LINE_OBJECT_NAME, OBJPROP_HIDDEN, true);
      ObjectSetString(0, PM_EQUITY_LINE_OBJECT_NAME, OBJPROP_TEXT,
                      "Equity / Break-even");
      return true;
     }
   double PlaceholderPrice(const string symbol)
     {
      const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      if(MathIsValidNumber(bid) && bid > 0.0)
         return bid;
      return 1.0;
     }
   bool SetLineVisibility(const bool visible, bool &changed)
     {
      changed = false;
      if(m_visibility_known && visible == m_visible)
         return true;
      ResetLastError();
      if(!ObjectSetInteger(0, PM_EQUITY_LINE_OBJECT_NAME,
                           OBJPROP_TIMEFRAMES,
                           visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS))
        {
         const int error_code = GetLastError();
         Delete();
         ReportError("change visibility of", error_code);
         return false;
        }
      m_visible = visible;
      m_visibility_known = true;
      changed = true;
      return true;
     }
   void Delete()
     {
      ObjectDelete(0, PM_EQUITY_LINE_OBJECT_NAME);
      m_created = false;
      m_visibility_known = false;
      m_price_known = false;
     }

   void ReportError(const string operation, const int error_code)
     {
      if(m_error_reported)
         return;
      PrintFormat("[ERROR] Unable to %s Equity / Break-even line. error=%d",
                  operation, error_code);
      m_error_reported = true;
     }
  };

#endif
