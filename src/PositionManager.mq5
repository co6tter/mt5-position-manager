#property strict
#property version "1.00"
#property description "Safe position management EA for MetaTrader 5"

#include "Models.mqh"
#include "Constants.mqh"
#include "PositionService.mqh"
#include "TradeManager.mqh"
#include "ValidationService.mqh"
#include "PositionActionService.mqh"
#include "SessionService.mqh"
#include "AutoCloseService.mqh"
#include "UiPanel.mqh"

input int InpMaxPositionRows = PM_DEFAULT_MAX_ROWS;
input int InpDeviationPoints = PM_DEFAULT_DEVIATION_POINTS;
input int InpRetryCount = PM_DEFAULT_RETRY_COUNT;
input int InpRetryIntervalSeconds = PM_DEFAULT_RETRY_INTERVAL_SECONDS;

CPositionService g_positions;
CTradeManager g_trades;
CValidationService g_validation;
CPositionActionService g_actions;
CSessionService g_sessions;
CAutoCloseService g_auto_close;
CUiPanel g_ui;

int OnInit()
  {
   g_trades.Configure(InpDeviationPoints, InpRetryCount, InpRetryIntervalSeconds);
   if(!g_ui.Create(InpMaxPositionRows))
      return INIT_FAILED;
   g_ui.Refresh(g_positions);
   g_ui.Render();
   ResetLastError();
   if(!EventSetTimer(PM_TIMER_SECONDS))
     {
      PrintFormat("[ERROR] EventSetTimer failed. error=%d", GetLastError());
      g_ui.Destroy();
      return INIT_FAILED;
     }
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   g_ui.Destroy();
  }

void OnTick()
  {
   // All monitoring is intentionally timer-driven so a quiet market still updates the panel.
  }

void OnTimer()
  {
   datetime now = TimeTradeServer();
   if(now <= 0)
      now = TimeCurrent();
   string retry_status = "";
   g_trades.ProcessRetries(now, retry_status);
   g_ui.Refresh(g_positions);
   AutoCloseConfig config = {};
   g_ui.GetAutoCloseConfig(config);
   string auto_status = "";
   g_auto_close.Evaluate(config, now, g_sessions, g_positions, g_trades, auto_status);
   g_ui.SetAutoSchedule(g_auto_close.SessionClose(), g_auto_close.AutoCloseAt());
   if(auto_status != "")
      g_ui.SetStatus(auto_status);
   else if(retry_status != "")
      g_ui.SetStatus(retry_status);
   g_ui.Render();
  }

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   g_ui.HandleChartEvent(id, sparam, g_positions, g_trades,
                         g_validation, g_actions);
  }
