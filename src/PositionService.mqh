#ifndef __MT5_POSITION_MANAGER_POSITION_SERVICE_MQH__
#define __MT5_POSITION_MANAGER_POSITION_SERVICE_MQH__

#include "Models.mqh"
#include "Constants.mqh"

class CPositionService
  {
private:
   string m_panel_symbols[];
   datetime m_panel_symbols_refreshed_at;

public:
   CPositionService()
     {
      m_panel_symbols_refreshed_at = 0;
     }

   int Collect(PMPosition &positions[])
     {
      const int total = PositionsTotal();
      ArrayResize(positions, total);
      int count = 0;
      for(int index = 0; index < total; index++)
        {
         const ulong ticket = PositionGetTicket(index);
         // PositionGetTicket selects the position for the following property
         // reads, so selecting the same ticket again only duplicates work.
         if(ticket == 0)
            continue;

         positions[count].ticket = ticket;
         positions[count].symbol = PositionGetString(POSITION_SYMBOL);
         positions[count].type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         positions[count].volume = PositionGetDouble(POSITION_VOLUME);
         positions[count].open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         positions[count].current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
         positions[count].sl = PositionGetDouble(POSITION_SL);
         positions[count].tp = PositionGetDouble(POSITION_TP);
         positions[count].profit = PositionGetDouble(POSITION_PROFIT);
         count++;
        }
      ArrayResize(positions, count);
      return count;
     }

   int CollectTickets(const string symbol,
                      const PMDirection direction,
                      ulong &tickets[])
     {
      ArrayResize(tickets, 0);
      PMPosition positions[];
      Collect(positions);
      return CollectTickets(positions, symbol, direction, tickets);
     }

   int CollectTickets(const PMPosition &positions[],
                      const string symbol,
                      const PMDirection direction,
                      ulong &tickets[])
     {
      ArrayResize(tickets, ArraySize(positions));
      int count = 0;
      for(int i = 0; i < ArraySize(positions); i++)
        {
         if(symbol != "" && positions[i].symbol != symbol)
            continue;
         if(!PMDirectionMatches(direction, positions[i].type))
            continue;
         tickets[count] = positions[i].ticket;
         count++;
        }
      ArrayResize(tickets, count);
      return count;
     }

   bool Get(const ulong ticket, PMPosition &position)
     {
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         return false;
      position.ticket = ticket;
      position.symbol = PositionGetString(POSITION_SYMBOL);
      position.type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      position.volume = PositionGetDouble(POSITION_VOLUME);
      position.open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      position.current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
      position.sl = PositionGetDouble(POSITION_SL);
      position.tp = PositionGetDouble(POSITION_TP);
      position.profit = PositionGetDouble(POSITION_PROFIT);
      return true;
     }

   int CollectSymbols(string &symbols[])
     {
      ArrayResize(symbols, 0);
      PMPosition positions[];
      Collect(positions);
      return CollectSymbols(positions, symbols);
     }

   int CollectSymbols(const PMPosition &positions[], string &symbols[])
     {
      ArrayResize(symbols, 0);
      for(int i = 0; i < ArraySize(positions); i++)
         AddUniqueSymbol(symbols, positions[i].symbol);
      AddUniqueSymbol(symbols, _Symbol);
      RefreshPanelChartSymbols();
      for(int i = 0; i < ArraySize(m_panel_symbols); i++)
         AddUniqueSymbol(symbols, m_panel_symbols[i]);
      return ArraySize(symbols);
     }

private:
   void RefreshPanelChartSymbols()
     {
      const datetime now = TimeLocal();
      if(m_panel_symbols_refreshed_at > 0 && now > 0 &&
         now >= m_panel_symbols_refreshed_at &&
         now - m_panel_symbols_refreshed_at < PM_PANEL_SYMBOL_REFRESH_SECONDS)
         return;

      ArrayResize(m_panel_symbols, 0, 8);
      long chart_id = ChartFirst();
      int chart_count = 0;
      while(chart_id >= 0 && chart_count < 100)
        {
         if(ObjectFind(chart_id, PM_OBJECT_PREFIX + "BACKGROUND") >= 0)
            AddUniqueSymbol(m_panel_symbols, ChartSymbol(chart_id));
         chart_id = ChartNext(chart_id);
         chart_count++;
        }
      m_panel_symbols_refreshed_at = now;
     }

   void AddUniqueSymbol(string &symbols[], const string symbol)
     {
      if(symbol == "")
         return;
      for(int i = 0; i < ArraySize(symbols); i++)
         if(symbols[i] == symbol)
            return;
      const int count = ArraySize(symbols);
      ArrayResize(symbols, count + 1, 8);
      symbols[count] = symbol;
     }
  };

#endif
