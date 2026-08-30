#ifndef __MT5_POSITION_MANAGER_AUTO_CLOSE_SERVICE_MQH__
#define __MT5_POSITION_MANAGER_AUTO_CLOSE_SERVICE_MQH__

#include "Models.mqh"
#include "Constants.mqh"
#include "PositionService.mqh"
#include "TradeManager.mqh"
#include "SessionService.mqh"

class CAutoCloseService
  {
private:
   bool m_started;
   bool m_watched_before_close;
   bool m_schedule_reported;
   int m_watched_date;
   int m_executed_date;
   string m_config_key;
   datetime m_session_close;
   datetime m_auto_close_at;

public:
   CAutoCloseService()
     {
      m_started = false;
      m_watched_before_close = false;
      m_schedule_reported = false;
      m_watched_date = 0;
      m_executed_date = 0;
      m_config_key = "";
      m_session_close = 0;
      m_auto_close_at = 0;
     }

   bool Evaluate(const AutoCloseConfig &config,
                 const datetime now,
                 CSessionService &sessions,
                 CPositionService &positions,
                 CTradeManager &trades,
                 string &status)
     {
      status = "";
      const string key = PMAutoCloseConfigKey(config);
      if(key != m_config_key)
        {
         m_config_key = key;
         m_started = false;
         m_watched_before_close = false;
         m_schedule_reported = false;
         m_watched_date = 0;
         m_session_close = 0;
         m_auto_close_at = 0;
        }
      if(!config.enabled || config.symbol == "")
         return false;

      const int today = PMDateKey(now);
      if(m_watched_date != today)
        {
         m_watched_date = today;
         m_watched_before_close = false;
         m_schedule_reported = false;
         m_started = false;
        }

      if(!sessions.GetTodayClose(config.symbol, now, m_session_close))
        {
         status = "Auto Close: session close unavailable for " + config.symbol;
         return false;
        }
      m_auto_close_at = m_session_close - MathMax(0, config.minutes_before_close) * 60;
      if(now < m_auto_close_at)
        {
         m_watched_before_close = true;
         if(!m_schedule_reported)
           {
            m_schedule_reported = true;
            status = StringFormat("Auto Close scheduled at %s", PMFormatDateTime(m_auto_close_at));
            PrintFormat("[INFO] Auto close scheduled at %s for %s %s",
                        PMFormatDateTime(m_auto_close_at), config.symbol,
                        PMDirectionToString(config.direction));
           }
         return false;
        }
      if(m_started && m_executed_date == PMDateKey(now))
         return false;

      m_started = true;
      m_executed_date = PMDateKey(now);
      if(!m_watched_before_close &&
         config.passed_behavior == PM_PASSED_CLOSE_DO_NOTHING)
        {
         status = "Auto Close skipped: scheduled time already passed.";
         PrintFormat("[WARN] Auto close skipped because scheduled time passed for %s",
                     config.symbol);
         return false;
        }

      ulong tickets[];
      positions.CollectTickets(config.symbol, config.direction, tickets);
      if(ArraySize(tickets) == 0)
        {
         status = "Auto Close: no matching positions.";
         PrintFormat("[INFO] Auto close found no matching positions for %s %s",
                     config.symbol, PMDirectionToString(config.direction));
         return true;
        }
      PMBatchResult result;
      trades.CloseTickets(tickets, result);
      status = StringFormat("Auto Close: %d closed, %d queued, %d failed / %d",
                            result.successful, result.queued,
                            ArraySize(result.failures), result.requested);
      return true;
     }

   datetime SessionClose()
     {
      return m_session_close;
     }

   datetime AutoCloseAt()
     {
      return m_auto_close_at;
     }

  };

#endif
