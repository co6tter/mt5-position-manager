#ifndef __MT5_POSITION_MANAGER_SESSION_SERVICE_MQH__
#define __MT5_POSITION_MANAGER_SESSION_SERVICE_MQH__

bool PMResolveSessionClose(const datetime now,
                           const datetime midnight,
                           const datetime &today_closes[],
                           const datetime &previous_starts[],
                           const datetime &previous_closes[],
                           datetime &session_close)
  {
   session_close = 0;
   // Preserve a previous weekday's overnight session until it ends.
   for(int i = 0;
       i < ArraySize(previous_closes) && i < ArraySize(previous_starts);
       i++)
     {
      if(previous_starts[i] < midnight &&
         previous_closes[i] >= now &&
         previous_closes[i] >= midnight &&
         previous_closes[i] > session_close)
         session_close = previous_closes[i];
     }
   if(session_close > 0)
      return true;

   if(ArraySize(today_closes) == 0)
      return false;
   // Intraday breaks are not daily closes: select the final close.
   session_close = today_closes[0];
   for(int i = 1; i < ArraySize(today_closes); i++)
      if(today_closes[i] > session_close)
         session_close = today_closes[i];
   return session_close > 0;
  }

class CSessionService
  {
public:
   bool GetTodayClose(const string symbol,
                      const datetime now,
                      datetime &session_close)
     {
      session_close = 0;
      if(symbol == "" || now <= 0)
         return false;

      MqlDateTime now_parts = {};
      TimeToStruct(now, now_parts);
      const datetime midnight = now - (now_parts.hour * 3600 + now_parts.min * 60 + now_parts.sec);
      datetime starts[];
      datetime closes[];
      const ENUM_DAY_OF_WEEK day = (ENUM_DAY_OF_WEEK)now_parts.day_of_week;
      AppendDaySessions(symbol, day, midnight, starts, closes);

      const datetime previous_midnight = midnight - 86400;
      MqlDateTime previous_parts = {};
      TimeToStruct(previous_midnight, previous_parts);
      datetime previous_starts[];
      datetime previous_closes[];
      AppendDaySessions(symbol,
                        (ENUM_DAY_OF_WEEK)previous_parts.day_of_week,
                        previous_midnight,
                        previous_starts,
                        previous_closes);

      return PMResolveSessionClose(now, midnight, closes,
                                   previous_starts, previous_closes,
                                   session_close);
     }

private:
   void AppendDaySessions(const string symbol,
                          const ENUM_DAY_OF_WEEK day,
                          const datetime midnight,
                          datetime &starts[],
                          datetime &closes[])
     {
      for(uint index = 0; index < 32; index++)
        {
         datetime from = 0;
         datetime to = 0;
         if(!SymbolInfoSessionTrade(symbol, day, index, from, to))
            break;
         const long from_seconds = SessionSeconds(from);
         long to_seconds = SessionSeconds(to);
         if(to_seconds == 0 && from_seconds > 0)
            to_seconds = 86400;
         const datetime open_time = (datetime)(midnight + from_seconds);
         datetime close_time = (datetime)(midnight + to_seconds);
         if(to_seconds <= from_seconds)
            close_time += 86400;
         const int count = ArraySize(closes);
         ArrayResize(starts, count + 1);
         ArrayResize(closes, count + 1);
         starts[count] = open_time;
         closes[count] = close_time;
        }
     }

   long SessionSeconds(const datetime value)
     {
      const long seconds = (long)value;
      if(seconds < 0)
         return 0;
      if(seconds >= 86400)
         return 86400;
      return seconds;
     }
  };

#endif
