#ifndef __MT5_POSITION_MANAGER_POSITION_SERVICE_MQH__
#define __MT5_POSITION_MANAGER_POSITION_SERVICE_MQH__

#include "Models.mqh"
#include "Constants.mqh"

class CPositionService
  {
public:
   int Collect(PMPosition &positions[])
     {
      ArrayResize(positions, 0);
      const int total = PositionsTotal();
      for(int index = 0; index < total; index++)
        {
         const ulong ticket = PositionGetTicket(index);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;

         const int count = ArraySize(positions);
         ArrayResize(positions, count + 1);
         positions[count].ticket = ticket;
         positions[count].symbol = PositionGetString(POSITION_SYMBOL);
         positions[count].type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         positions[count].volume = PositionGetDouble(POSITION_VOLUME);
         positions[count].open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         positions[count].current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
         positions[count].sl = PositionGetDouble(POSITION_SL);
         positions[count].tp = PositionGetDouble(POSITION_TP);
         positions[count].profit = PositionGetDouble(POSITION_PROFIT);
        }
      return ArraySize(positions);
     }

   int CollectTickets(const string symbol,
                      const PMDirection direction,
                      ulong &tickets[])
     {
      ArrayResize(tickets, 0);
      PMPosition positions[];
      Collect(positions);
      for(int i = 0; i < ArraySize(positions); i++)
        {
         if(symbol != "" && positions[i].symbol != symbol)
            continue;
         if(!PMDirectionMatches(direction, positions[i].type))
            continue;
         const int count = ArraySize(tickets);
         ArrayResize(tickets, count + 1);
         tickets[count] = positions[i].ticket;
        }
      return ArraySize(tickets);
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
      for(int i = 0; i < ArraySize(positions); i++)
         AddUniqueSymbol(symbols, positions[i].symbol);
      AddUniqueSymbol(symbols, _Symbol);
      CollectPanelChartSymbols(symbols);
      return ArraySize(symbols);
     }

private:
   void CollectPanelChartSymbols(string &symbols[])
     {
      long chart_id = ChartFirst();
      int chart_count = 0;
      while(chart_id >= 0 && chart_count < 100)
        {
         if(ObjectFind(chart_id, PM_OBJECT_PREFIX + "BACKGROUND") >= 0)
            AddUniqueSymbol(symbols, ChartSymbol(chart_id));
         chart_id = ChartNext(chart_id);
         chart_count++;
        }
     }

   void AddUniqueSymbol(string &symbols[], const string symbol)
     {
      if(symbol == "")
         return;
      for(int i = 0; i < ArraySize(symbols); i++)
         if(symbols[i] == symbol)
            return;
      const int count = ArraySize(symbols);
      ArrayResize(symbols, count + 1);
      symbols[count] = symbol;
     }
  };

#endif
