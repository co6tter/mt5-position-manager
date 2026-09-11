#ifndef __MT5_POSITION_MANAGER_PRICE_EDITOR_MQH__
#define __MT5_POSITION_MANAGER_PRICE_EDITOR_MQH__

// No chart or trade calls: the draft survives rendering, but never a context change.
class CPriceEditDrag
  {
private:
   int m_index;
   string m_context;
   double m_price;
public:
   CPriceEditDrag() { Cancel(); }
   void Cancel() { m_index = -1; m_context = ""; m_price = 0.0; }
   int Index() { return m_index; }
   double Price() { return m_price; }
   void Begin(const int index, const string context, const double price)
     {
      Cancel();
      if(index < 0 || index > 1 || !MathIsValidNumber(price) || price <= 0.0)
         return;
      m_index = index;
      m_context = context;
      m_price = price;
     }
   bool Matches(const string context)
     {
      return m_index >= 0 && m_context == context;
     }
   void Move(const double price)
     {
      if(m_index >= 0 && MathIsValidNumber(price) && price > 0.0)
         m_price = price;
     }
   bool Finish(const string context, int &index, double &price)
     {
      index = -1;
      price = 0.0;
      const bool valid = Matches(context);
      if(valid) { index = m_index; price = m_price; }
      Cancel();
      return valid;
     }
  };

// Points stay meaningful per side even when one monetary estimate is unavailable.
class CPriceEditEstimate
  {
private:
   double m_buy_volume, m_sell_volume, m_buy_points, m_sell_points, m_money;
   bool m_money_known;
public:
   CPriceEditEstimate()
     {
      m_buy_volume = 0.0; m_sell_volume = 0.0;
      m_buy_points = 0.0; m_sell_points = 0.0;
      m_money = 0.0; m_money_known = true;
     }
   void Add(const bool buy, const double volume, const double points,
             const bool money_known, const double money)
     {
      if(buy) { m_buy_volume += volume; m_buy_points += volume * points; }
      else { m_sell_volume += volume; m_sell_points += volume * points; }
      if(money_known && MathIsValidNumber(money)) m_money += money;
      else m_money_known = false;
     }
   bool HasBuy() { return m_buy_volume > 0.0; }
   bool HasSell() { return m_sell_volume > 0.0; }
   double BuyPoints() { return HasBuy() ? m_buy_points / m_buy_volume : 0.0; }
   double SellPoints() { return HasSell() ? m_sell_points / m_sell_volume : 0.0; }
   bool MoneyKnown() { return m_money_known && MathIsValidNumber(m_money); }
   double Money() { return m_money; }
  };

bool PMRectOverlaps(const int x, const int y, const int width, const int height,
                    const int other_x, const int other_y,
                    const int other_width, const int other_height)
  {
   return width > 0 && height > 0 && other_width > 0 && other_height > 0 &&
          x < other_x + other_width && x + width > other_x &&
          y < other_y + other_height && y + height > other_y;
  }

// Find a readable label near the price without moving the price itself.
bool PMPlacePriceLabel(const int chart_width, const int chart_height,
                       const int price_y, const int width, const int height,
                       const int panel_x, const int panel_y,
                       const int panel_width, const int panel_height,
                       const int other_x, const int other_y,
                       const int other_width, const int other_height,
                       int &x, int &y)
  {
   if(width + 16 > chart_width || height + 16 > chart_height)
      return false;
   const int preferred = (int)MathMax(8, MathMin(price_y - height - 4,
                                                chart_height - height - 8));
   for(int offset = 0; offset < chart_height; offset += height + 4)
      for(int direction = 0; direction < 2; direction++)
         for(int side = 0; side < 2; side++)
           {
            x = side == 0 ? chart_width - width - 8 : 8;
            y = preferred + (direction == 0 ? offset : -offset);
            if(y < 8 || y + height > chart_height - 8)
               continue;
            if(!PMRectOverlaps(x, y, width, height, panel_x, panel_y,
                               panel_width, panel_height) &&
               !PMRectOverlaps(x, y, width, height, other_x, other_y,
                               other_width, other_height))
               return true;
           }
   return false;
  }

#endif
