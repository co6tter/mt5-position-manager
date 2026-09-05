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
#include "EquityGuardService.mqh"
#include "EquityLineService.mqh"
#include "TrailingStopService.mqh"
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
CEquityGuardService g_equity_guard;
CEquityLineService g_equity_line;
CTrailingStopService g_trailing_stop;
CUiPanel g_ui;

int OnInit()
  {
   g_trades.Configure(InpDeviationPoints, InpRetryCount, InpRetryIntervalSeconds);
   PMPosition positions[];
   g_positions.Collect(positions);
   // Create the chart line before the foreground panel so the panel remains on top.
   g_equity_line.Render(_Symbol, positions);
   if(!g_ui.Create(InpMaxPositionRows))
     {
      g_equity_line.Destroy();
      return INIT_FAILED;
     }
   g_ui.Refresh(positions, g_positions);
   g_ui.Render();
   ResetLastError();
   if(!EventSetTimer(PM_TIMER_SECONDS))
     {
      PrintFormat("[ERROR] EventSetTimer failed. error=%d", GetLastError());
      g_equity_line.Destroy();
      g_ui.Destroy();
      return INIT_FAILED;
     }
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   g_ui.SavePosition();
   g_equity_line.Destroy();
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
   PMPosition positions[];
   g_positions.Collect(positions);
   g_ui.Refresh(positions, g_positions);
   if(g_equity_line.Render(_Symbol, positions))
      g_ui.RequestRedraw();
   AutoCloseConfig config = {};
   g_ui.GetAutoCloseConfig(config);
   string auto_status = "";
   const bool auto_close_handled =
      g_auto_close.Evaluate(config, now, g_sessions, positions,
                            g_positions, g_trades, auto_status);
   // Read-only timer cycles use one shared snapshot. Refresh only after a
   // service may have changed positions so downstream state and actions stay
   // consistent with the original evaluation order.
   if(auto_close_handled)
      g_positions.Collect(positions);
   g_ui.SetAutoSchedule(g_auto_close.SessionClose(), g_auto_close.AutoCloseAt());
   EquityGuardConfig equity_guard_config = {};
   g_ui.GetEquityGuardConfig(equity_guard_config);
   string equity_guard_status = "";
   const bool equity_guard_handled =
      g_equity_guard.Evaluate(equity_guard_config, positions,
                              g_trades, equity_guard_status);
   if(equity_guard_handled)
      g_positions.Collect(positions);
   TrailingStopConfig trailing_stop_config = {};
   g_ui.GetTrailingStopConfig(trailing_stop_config);
   string trailing_stop_status = "";
   g_trailing_stop.Evaluate(trailing_stop_config, positions, g_positions,
                            g_trades, g_validation, trailing_stop_status);
   if(equity_guard_status != "")
      g_ui.SetStatus(equity_guard_status);
   else if(auto_status != "")
      g_ui.SetStatus(auto_status);
   else if(retry_status != "")
      g_ui.SetStatus(retry_status);
   else if(trailing_stop_status != "")
      g_ui.SetStatus(trailing_stop_status);
   g_ui.Render();
  }

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   g_ui.HandleChartEvent(id, lparam, dparam, sparam, g_positions, g_trades,
                         g_validation, g_actions);
  }
