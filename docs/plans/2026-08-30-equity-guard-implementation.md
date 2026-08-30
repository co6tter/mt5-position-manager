# Equity Guard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an "Equity Guard" feature that watches the account-wide floating profit/loss total and automatically closes every open position once a configured loss or profit threshold is crossed.

**Architecture:** Follow the existing `CAutoCloseService` pattern exactly: a small testable pure function (`PMEvaluateEquityGuard`, mirroring `PMResolveSessionClose` in `SessionService.mqh`) decides whether a threshold is crossed, and a thin `CEquityGuardService` class wraps it with edge-triggered state (fires once per crossing, resets when the total returns to the safe zone) and calls the existing `CTradeManager::CloseTickets()` to execute the close. The panel gets one new row (enable toggle, Amount/Percent mode toggle, Max Loss edit, Max Profit edit), following the same button/edit/label conventions already used for the Auto Close row.

**Tech Stack:** MQL5 (MetaTrader 5), no external dependencies beyond what the project already uses (`Trade/Trade.mqh` via the existing `CTradeManager`).

**Spec:** `docs/specification.md` — "Equity Guard" section.

## Global Constraints

- No MetaEditor/MT5 runtime is available in this sandbox (macOS, no CLI compiler for MQL5). Every task's verification step must be performed by the user in their own MetaTrader 5 installation (MetaEditor compile, or `scripts\compile.ps1` on Windows, then running the affected script/EA). Do not claim a task "passes" without the user confirming the actual compile/run result.
- Never create a git commit unless the user explicitly asks for one in that moment. Do not add "commit" as an automatic step — leave changes staged/unstaged and mention what changed.
- Follow existing code style exactly: MetaEditor's default brace style (opening brace of a block on its own line, indented one level deeper than the statement that owns it — see any existing method in `src/UiPanel.mqh` or `src/TradeManager.mqh` for the exact pattern), 3-space indentation, `PM_` prefix for free functions/enums/structs, `CXxxService` naming for service classes, `m_` prefix for class members, `g_` prefix for globals in `PositionManager.mq5`.
- Percent-mode thresholds are computed against `AccountInfoDouble(ACCOUNT_BALANCE)`, not equity (equity moves with the floating P/L being measured, which would make the threshold a moving target).
- Equity Guard never shows a confirmation dialog (it runs from `OnTimer`, like Auto Close — there is no user click to block on).

---

### Task 1: Equity Guard core logic (pure function + service class + unit tests)

**Files:**
- Modify: `src/Models.mqh`
- Create: `src/EquityGuardService.mqh`
- Modify: `tests/PositionManagerPureTests.mq5`

**Interfaces:**
- Consumes: `PMPosition` struct, `PMDirection` enum, `PMBatchResult` struct (all in `src/Models.mqh`, already defined); `CPositionService::CollectTickets(const string symbol, const PMDirection direction, ulong &tickets[])` and `CPositionService::Collect(PMPosition &positions[])` (both already defined in `src/PositionService.mqh`); `CTradeManager::CloseTickets(const ulong &tickets[], PMBatchResult &result)` (already defined in `src/TradeManager.mqh`).
- Produces: `enum PMEquityThresholdMode { PM_EQUITY_THRESHOLD_AMOUNT, PM_EQUITY_THRESHOLD_PERCENT }`; `struct EquityGuardConfig { bool enabled; PMEquityThresholdMode mode; double loss_threshold; double profit_threshold; }`; free function `bool PMEvaluateEquityGuard(const double total_profit, const EquityGuardConfig &config, const double balance, bool &loss_triggered, bool &profit_triggered)`; class `CEquityGuardService` with `bool Evaluate(const EquityGuardConfig &config, CPositionService &positions, CTradeManager &trades, string &status)`. Task 2 and Task 3 depend on these exact names and signatures.

- [ ] **Step 1: Add `PMEquityThresholdMode` and `EquityGuardConfig` to Models.mqh**

In `src/Models.mqh`, find:

```mql5
enum PMPassedCloseBehavior
  {
   PM_PASSED_CLOSE_DO_NOTHING = 0,
   PM_PASSED_CLOSE_IMMEDIATELY = 1
  };
```

Add immediately after it:

```mql5
enum PMEquityThresholdMode
  {
   PM_EQUITY_THRESHOLD_AMOUNT = 0,
   PM_EQUITY_THRESHOLD_PERCENT = 1
  };
```

Then find:

```mql5
struct AutoCloseConfig
  {
   bool enabled;
   string symbol;
   PMDirection direction;
   int minutes_before_close;
   PMPassedCloseBehavior passed_behavior;
  };

#endif
```

Replace with:

```mql5
struct AutoCloseConfig
  {
   bool enabled;
   string symbol;
   PMDirection direction;
   int minutes_before_close;
   PMPassedCloseBehavior passed_behavior;
  };

struct EquityGuardConfig
  {
   bool enabled;
   PMEquityThresholdMode mode;
   double loss_threshold;
   double profit_threshold;
  };

#endif
```

- [ ] **Step 2: Create `src/EquityGuardService.mqh`**

Create the file with this exact content:

```mql5
#ifndef __MT5_POSITION_MANAGER_EQUITY_GUARD_SERVICE_MQH__
#define __MT5_POSITION_MANAGER_EQUITY_GUARD_SERVICE_MQH__

#include "Models.mqh"
#include "Constants.mqh"
#include "PositionService.mqh"
#include "TradeManager.mqh"

bool PMEvaluateEquityGuard(const double total_profit,
                           const EquityGuardConfig &config,
                           const double balance,
                           bool &loss_triggered,
                           bool &profit_triggered)
  {
   loss_triggered = false;
   profit_triggered = false;
   if(!config.enabled)
      return false;

   if(config.loss_threshold > 0.0)
     {
      const double loss_amount = config.mode == PM_EQUITY_THRESHOLD_PERCENT ?
                                 balance * config.loss_threshold / 100.0 :
                                 config.loss_threshold;
      if(loss_amount > 0.0 && total_profit <= -loss_amount)
         loss_triggered = true;
     }

   if(config.profit_threshold > 0.0)
     {
      const double profit_amount = config.mode == PM_EQUITY_THRESHOLD_PERCENT ?
                                   balance * config.profit_threshold / 100.0 :
                                   config.profit_threshold;
      if(profit_amount > 0.0 && total_profit >= profit_amount)
         profit_triggered = true;
     }

   return loss_triggered || profit_triggered;
  }

class CEquityGuardService
  {
private:
   bool m_triggered;
   string m_config_key;

public:
   CEquityGuardService()
     {
      m_triggered = false;
      m_config_key = "";
     }

   bool Evaluate(const EquityGuardConfig &config,
                 CPositionService &positions,
                 CTradeManager &trades,
                 string &status)
     {
      status = "";
      const string key = ConfigKey(config);
      if(key != m_config_key)
        {
         m_config_key = key;
         m_triggered = false;
        }
      if(!config.enabled)
         return false;

      PMPosition all_positions[];
      positions.Collect(all_positions);
      double total_profit = 0.0;
      for(int i = 0; i < ArraySize(all_positions); i++)
         total_profit += all_positions[i].profit;

      const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      bool loss_triggered = false;
      bool profit_triggered = false;
      const bool should_trigger = PMEvaluateEquityGuard(total_profit, config, balance,
                                                        loss_triggered, profit_triggered);

      if(!should_trigger)
        {
         m_triggered = false;
         return false;
        }
      if(m_triggered)
         return false;
      m_triggered = true;

      const string side = loss_triggered ? "loss" : "profit";
      ulong tickets[];
      positions.CollectTickets("", PM_DIRECTION_BOTH, tickets);
      if(ArraySize(tickets) == 0)
        {
         status = StringFormat("Equity Guard: %s threshold reached (%.2f) but no positions to close.",
                               side, total_profit);
         PrintFormat("[WARN] Equity Guard %s threshold reached (%.2f) with no open positions.",
                     side, total_profit);
         return true;
        }

      PMBatchResult result;
      trades.CloseTickets(tickets, result);
      status = StringFormat("Equity Guard: %s threshold reached (%.2f). Closing all positions: %d closed, %d queued, %d failed / %d",
                            side, total_profit, result.successful, result.queued,
                            ArraySize(result.failures), result.requested);
      PrintFormat("[WARN] Equity Guard triggered by %s threshold. total_profit=%.2f closed=%d queued=%d failed=%d requested=%d",
                  side, total_profit, result.successful, result.queued,
                  ArraySize(result.failures), result.requested);
      return true;
     }

private:
   string ConfigKey(const EquityGuardConfig &config)
     {
      return StringFormat("%d|%d|%.2f|%.2f", config.enabled ? 1 : 0,
                          (int)config.mode, config.loss_threshold, config.profit_threshold);
     }
  };

#endif
```

- [ ] **Step 3: Add unit tests for `PMEvaluateEquityGuard`**

In `tests/PositionManagerPureTests.mq5`, find:

```mql5
#include "..\src\Models.mqh"
#include "..\src\Constants.mqh"
#include "..\src\SessionService.mqh"
```

Replace with:

```mql5
#include "..\src\Models.mqh"
#include "..\src\Constants.mqh"
#include "..\src\SessionService.mqh"
#include "..\src\EquityGuardService.mqh"
```

Then find:

```mql5
void OnStart()
  {
   TestDirectionMatching();
   TestBatchResultHelpers();
   TestTransientRetcodes();
   TestSessionCloseResolution();
   if(g_failures == 0)
      Print("[PASS] All Position Manager pure tests passed.");
   else
      PrintFormat("[FAIL] %d Position Manager pure tests failed.", g_failures);
  }
```

Replace with:

```mql5
void TestEquityGuardEvaluation()
  {
   EquityGuardConfig config;
   config.enabled = true;
   config.mode = PM_EQUITY_THRESHOLD_AMOUNT;
   config.loss_threshold = 500.0;
   config.profit_threshold = 1000.0;
   bool loss_triggered = false;
   bool profit_triggered = false;

   AssertTrue(PMEvaluateEquityGuard(-500.0, config, 10000.0, loss_triggered, profit_triggered) &&
              loss_triggered && !profit_triggered,
              "Amount mode triggers on loss threshold");

   AssertTrue(PMEvaluateEquityGuard(1000.0, config, 10000.0, loss_triggered, profit_triggered) &&
              !loss_triggered && profit_triggered,
              "Amount mode triggers on profit threshold");

   AssertTrue(!PMEvaluateEquityGuard(-100.0, config, 10000.0, loss_triggered, profit_triggered) &&
              !loss_triggered && !profit_triggered,
              "Amount mode does not trigger inside the safe zone");

   config.mode = PM_EQUITY_THRESHOLD_PERCENT;
   config.loss_threshold = 5.0;
   config.profit_threshold = 10.0;
   AssertTrue(PMEvaluateEquityGuard(-500.0, config, 10000.0, loss_triggered, profit_triggered) &&
              loss_triggered && !profit_triggered,
              "Percent mode converts the loss threshold against balance");
   AssertTrue(PMEvaluateEquityGuard(1000.0, config, 10000.0, loss_triggered, profit_triggered) &&
              !loss_triggered && profit_triggered,
              "Percent mode converts the profit threshold against balance");

   config.mode = PM_EQUITY_THRESHOLD_AMOUNT;
   config.loss_threshold = 0.0;
   config.profit_threshold = 0.0;
   AssertTrue(!PMEvaluateEquityGuard(-999999.0, config, 10000.0, loss_triggered, profit_triggered),
              "Zero thresholds disable both sides");

   config.enabled = false;
   config.loss_threshold = 500.0;
   AssertTrue(!PMEvaluateEquityGuard(-999999.0, config, 10000.0, loss_triggered, profit_triggered),
              "Disabled guard never triggers");
  }

void OnStart()
  {
   TestDirectionMatching();
   TestBatchResultHelpers();
   TestTransientRetcodes();
   TestSessionCloseResolution();
   TestEquityGuardEvaluation();
   if(g_failures == 0)
      Print("[PASS] All Position Manager pure tests passed.");
   else
      PrintFormat("[FAIL] %d Position Manager pure tests failed.", g_failures);
  }
```

- [ ] **Step 4: Ask the user to compile and run the tests**

There is no MetaEditor in this sandbox. Ask the user to:
1. Open `tests/PositionManagerPureTests.mq5` in MetaEditor and compile it (or run `scripts\compile.ps1 -SourcePath tests\PositionManagerPureTests.mq5 -MetaEditorPath "<path to metaeditor64.exe>"` on Windows).
2. Run it as a script on any chart.
3. Confirm the Experts log shows `[PASS] All Position Manager pure tests passed.` with no `[FAIL]` lines, specifically the 6 new lines from `TestEquityGuardEvaluation`.

Expected: all `[PASS]` lines, `0` failures reported.

---

### Task 2: Equity Guard panel section in UiPanel.mqh

**Files:**
- Modify: `src/UiPanel.mqh`

**Interfaces:**
- Consumes: `PMEquityThresholdMode`, `EquityGuardConfig` (from Task 1's `src/Models.mqh` change).
- Produces: `CUiPanel::GetEquityGuardConfig(EquityGuardConfig &config)` — Task 3 calls this exact method from `PositionManager.mq5`.

This task only adds the panel controls and the config getter; nothing consumes `GetEquityGuardConfig()` yet until Task 3, so toggling the new "Equity Guard" row's ON/OFF or Amount/Percent buttons will visibly change their own label but have no other effect until Task 3 is done. That is expected, not a bug.

- [ ] **Step 1: Add member variables**

In `src/UiPanel.mqh`, find:

```mql5
   PMPassedCloseBehavior m_passed_behavior;
   bool m_auto_enabled;
   int m_max_rows;
```

Replace with:

```mql5
   PMPassedCloseBehavior m_passed_behavior;
   bool m_auto_enabled;
   bool m_equity_guard_enabled;
   PMEquityThresholdMode m_equity_guard_mode;
   int m_max_rows;
```

- [ ] **Step 2: Initialize the new members in the constructor**

Find:

```mql5
      m_passed_behavior = PM_PASSED_CLOSE_DO_NOTHING;
      m_auto_enabled = false;
      m_max_rows = PM_DEFAULT_MAX_ROWS;
```

Replace with:

```mql5
      m_passed_behavior = PM_PASSED_CLOSE_DO_NOTHING;
      m_auto_enabled = false;
      m_equity_guard_enabled = false;
      m_equity_guard_mode = PM_EQUITY_THRESHOLD_AMOUNT;
      m_max_rows = PM_DEFAULT_MAX_ROWS;
```

- [ ] **Step 3: Create the new controls and shift Session/Status down**

Find:

```mql5
      created = CreateEdit("AUTO_MINUTES", "10", 525, section_y + 67, 55, 22) && created;
      created = CreateButton("PASSED_BEHAVIOR", "Passed: Do Nothing", 590, section_y + 67, 155, 22) && created;
      created = CreateLabel("SESSION_LABEL", "Today's Close: -    Auto Close At: -", 12, section_y + 100, clrSilver, 9) && created;
      created = CreateLabel("STATUS_LABEL", "Status: Ready", 12, section_y + 126, clrWhite, 9) && created;
```

Replace with:

```mql5
      created = CreateEdit("AUTO_MINUTES", "10", 525, section_y + 67, 55, 22) && created;
      created = CreateButton("PASSED_BEHAVIOR", "Passed: Do Nothing", 590, section_y + 67, 155, 22) && created;

      created = CreateLabel("EQ_LABEL", "Equity Guard", 12, section_y + 103, clrSilver, 9) && created;
      created = CreateButton("EQ_ENABLED", "OFF", 95, section_y + 100, 65, 22) && created;
      created = CreateButton("EQ_MODE", "Amount", 170, section_y + 100, 85, 22) && created;
      created = CreateLabel("EQ_LOSS_LABEL", "Max Loss", 265, section_y + 103, clrSilver, 9) && created;
      created = CreateEdit("EQ_LOSS_VALUE", "", 330, section_y + 100, 100, 22) && created;
      created = CreateLabel("EQ_PROFIT_LABEL", "Max Profit", 440, section_y + 103, clrSilver, 9) && created;
      created = CreateEdit("EQ_PROFIT_VALUE", "", 515, section_y + 100, 100, 22) && created;

      created = CreateLabel("SESSION_LABEL", "Today's Close: -    Auto Close At: -", 12, section_y + 134, clrSilver, 9) && created;
      created = CreateLabel("STATUS_LABEL", "Status: Ready", 12, section_y + 160, clrWhite, 9) && created;
```

- [ ] **Step 4: Grow the panel height by one row**

Find:

```mql5
   int PanelHeight()
     {
      return SectionY() + 165;
     }
```

Replace with:

```mql5
   int PanelHeight()
     {
      return SectionY() + 199;
     }
```

- [ ] **Step 5: Reposition the new controls (and the shifted Session/Status labels) on resize**

In `ApplyLayout()`, find:

```mql5
      RepositionY("PASSED_BEHAVIOR", section_y + 67);
      RepositionY("SESSION_LABEL", section_y + 100);
      RepositionY("STATUS_LABEL", section_y + 126);
     }
```

Replace with:

```mql5
      RepositionY("PASSED_BEHAVIOR", section_y + 67);
      RepositionY("EQ_LABEL", section_y + 103);
      RepositionY("EQ_ENABLED", section_y + 100);
      RepositionY("EQ_MODE", section_y + 100);
      RepositionY("EQ_LOSS_LABEL", section_y + 103);
      RepositionY("EQ_LOSS_VALUE", section_y + 100);
      RepositionY("EQ_PROFIT_LABEL", section_y + 103);
      RepositionY("EQ_PROFIT_VALUE", section_y + 100);
      RepositionY("SESSION_LABEL", section_y + 134);
      RepositionY("STATUS_LABEL", section_y + 160);
     }
```

- [ ] **Step 6: Refresh the new buttons' text in Render()**

Find:

```mql5
      ObjectSetString(0, Name("PASSED_BEHAVIOR"), OBJPROP_TEXT,
                      m_passed_behavior == PM_PASSED_CLOSE_IMMEDIATELY ? "Passed: Close Now" : "Passed: Do Nothing");
      ObjectSetString(0, Name("SESSION_LABEL"), OBJPROP_TEXT,
```

Replace with:

```mql5
      ObjectSetString(0, Name("PASSED_BEHAVIOR"), OBJPROP_TEXT,
                      m_passed_behavior == PM_PASSED_CLOSE_IMMEDIATELY ? "Passed: Close Now" : "Passed: Do Nothing");
      ObjectSetString(0, Name("EQ_ENABLED"), OBJPROP_TEXT, m_equity_guard_enabled ? "ON" : "OFF");
      ObjectSetString(0, Name("EQ_MODE"), OBJPROP_TEXT, EquityThresholdModeToString(m_equity_guard_mode));
      ObjectSetString(0, Name("SESSION_LABEL"), OBJPROP_TEXT,
```

- [ ] **Step 7: Handle clicks on the new buttons**

In `HandleChartEvent()`, find:

```mql5
      else if(object_name == Name("PASSED_BEHAVIOR"))
         m_passed_behavior = m_passed_behavior == PM_PASSED_CLOSE_DO_NOTHING ?
                             PM_PASSED_CLOSE_IMMEDIATELY : PM_PASSED_CLOSE_DO_NOTHING;
      else
        {
         const int page_start = m_page * m_max_rows;
```

Replace with:

```mql5
      else if(object_name == Name("PASSED_BEHAVIOR"))
         m_passed_behavior = m_passed_behavior == PM_PASSED_CLOSE_DO_NOTHING ?
                             PM_PASSED_CLOSE_IMMEDIATELY : PM_PASSED_CLOSE_DO_NOTHING;
      else if(object_name == Name("EQ_ENABLED"))
         m_equity_guard_enabled = !m_equity_guard_enabled;
      else if(object_name == Name("EQ_MODE"))
         m_equity_guard_mode = m_equity_guard_mode == PM_EQUITY_THRESHOLD_AMOUNT ?
                               PM_EQUITY_THRESHOLD_PERCENT : PM_EQUITY_THRESHOLD_AMOUNT;
      else
        {
         const int page_start = m_page * m_max_rows;
```

- [ ] **Step 8: Add the config getter and its private helpers**

Find:

```mql5
   void GetAutoCloseConfig(AutoCloseConfig &config)
     {
      config.enabled = m_auto_enabled;
      config.symbol = AutoSymbol();
      config.direction = m_auto_direction;
      config.minutes_before_close = AutoCloseMinutes();
      config.passed_behavior = m_passed_behavior;
     }
```

Replace with:

```mql5
   void GetAutoCloseConfig(AutoCloseConfig &config)
     {
      config.enabled = m_auto_enabled;
      config.symbol = AutoSymbol();
      config.direction = m_auto_direction;
      config.minutes_before_close = AutoCloseMinutes();
      config.passed_behavior = m_passed_behavior;
     }

   void GetEquityGuardConfig(EquityGuardConfig &config)
     {
      config.enabled = m_equity_guard_enabled;
      config.mode = m_equity_guard_mode;
      config.loss_threshold = EquityGuardLossThreshold();
      config.profit_threshold = EquityGuardProfitThreshold();
     }
```

Then find:

```mql5
   string PriceModeToString(const PMPriceMode mode)
     {
      return mode == PM_PRICE_ABSOLUTE ? "Price" : "Points";
     }
```

Replace with:

```mql5
   string PriceModeToString(const PMPriceMode mode)
     {
      return mode == PM_PRICE_ABSOLUTE ? "Price" : "Points";
     }

   string EquityThresholdModeToString(const PMEquityThresholdMode mode)
     {
      return mode == PM_EQUITY_THRESHOLD_AMOUNT ? "Amount" : "Percent";
     }
```

Then find:

```mql5
   int AutoCloseMinutes()
     {
      long minutes = StringToInteger(
         ObjectGetString(0, Name("AUTO_MINUTES"), OBJPROP_TEXT));
      if(minutes < 0)
         minutes = 0;
      if(minutes > PM_MAX_AUTO_CLOSE_MINUTES)
         minutes = PM_MAX_AUTO_CLOSE_MINUTES;
      return (int)minutes;
     }
```

Replace with:

```mql5
   int AutoCloseMinutes()
     {
      long minutes = StringToInteger(
         ObjectGetString(0, Name("AUTO_MINUTES"), OBJPROP_TEXT));
      if(minutes < 0)
         minutes = 0;
      if(minutes > PM_MAX_AUTO_CLOSE_MINUTES)
         minutes = PM_MAX_AUTO_CLOSE_MINUTES;
      return (int)minutes;
     }

   double EquityGuardLossThreshold()
     {
      const double value = StringToDouble(ObjectGetString(0, Name("EQ_LOSS_VALUE"), OBJPROP_TEXT));
      return value > 0.0 ? value : 0.0;
     }

   double EquityGuardProfitThreshold()
     {
      const double value = StringToDouble(ObjectGetString(0, Name("EQ_PROFIT_VALUE"), OBJPROP_TEXT));
      return value > 0.0 ? value : 0.0;
     }
```

- [ ] **Step 9: Ask the user to compile and manually verify the panel**

There is no MetaEditor in this sandbox. Ask the user to:
1. Compile `src/PositionManager.mq5` in MetaEditor (it still compiles at this point even though nothing calls `GetEquityGuardConfig()` yet).
2. Attach the EA to a chart.
3. Confirm a new "Equity Guard" row appears below "Auto Close", with an "OFF" button, an "Amount" button, and two empty edit fields labeled "Max Loss" / "Max Profit".
4. Click the "OFF" button and confirm it toggles to "ON" and back. Click the "Amount" button and confirm it toggles to "Percent" and back.
5. Confirm the panel still resizes correctly (drag the bottom-right grip) and the new row moves with the rest of the Auto Close section.

Expected: the row appears, both toggle buttons work, and resizing still repositions everything below the position list correctly.

---

### Task 3: Wire Equity Guard into the timer loop

**Files:**
- Modify: `src/PositionManager.mq5`

**Interfaces:**
- Consumes: `CEquityGuardService` and `EquityGuardConfig` (Task 1), `CUiPanel::GetEquityGuardConfig()` (Task 2).
- Produces: nothing further downstream — this is the last piece that makes the feature live.

- [ ] **Step 1: Include the new service and declare the global instance**

Find:

```mql5
#include "SessionService.mqh"
#include "AutoCloseService.mqh"
#include "UiPanel.mqh"
```

Replace with:

```mql5
#include "SessionService.mqh"
#include "AutoCloseService.mqh"
#include "EquityGuardService.mqh"
#include "UiPanel.mqh"
```

Then find:

```mql5
CSessionService g_sessions;
CAutoCloseService g_auto_close;
CUiPanel g_ui;
```

Replace with:

```mql5
CSessionService g_sessions;
CAutoCloseService g_auto_close;
CEquityGuardService g_equity_guard;
CUiPanel g_ui;
```

- [ ] **Step 2: Evaluate the guard every timer tick, with top status priority**

Find:

```mql5
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
```

Replace with:

```mql5
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
   EquityGuardConfig equity_guard_config = {};
   g_ui.GetEquityGuardConfig(equity_guard_config);
   string equity_guard_status = "";
   g_equity_guard.Evaluate(equity_guard_config, g_positions, g_trades, equity_guard_status);
   if(equity_guard_status != "")
      g_ui.SetStatus(equity_guard_status);
   else if(auto_status != "")
      g_ui.SetStatus(auto_status);
   else if(retry_status != "")
      g_ui.SetStatus(retry_status);
   g_ui.Render();
  }
```

- [ ] **Step 3: Ask the user to compile and manually verify end-to-end behavior**

There is no MetaEditor in this sandbox. Ask the user to compile `src/PositionManager.mq5`, attach it to a demo account chart with at least one open position, and check:
1. With Equity Guard OFF, opening/closing positions never shows an "Equity Guard:" status.
2. Set Max Loss to a very small amount (e.g. `0.01`) in Amount mode, turn Equity Guard ON. Within one timer tick (up to 1 second), confirm the status bar shows `Equity Guard: loss threshold reached (...)`. and all open positions get a close request submitted (check the Experts log for the usual `[INFO] Closing position ticket=...` lines from `CTradeManager`).
3. Confirm it does **not** re-submit a close request every second while the position is still closing/retrying (only one `[WARN] Equity Guard triggered by loss threshold...` log line per crossing).
4. Once flat (no open positions), confirm the status stops showing "Equity Guard:" until a new position is opened and crosses the threshold again.
5. Repeat with Max Profit in Percent mode against a small open profit, confirming the "profit threshold reached" wording appears instead.

Expected: all five checks match the described behavior.

---

### Task 4: Documentation

**Files:**
- Modify: `README.md`

**Interfaces:** None — documentation only.

- [ ] **Step 1: Add Equity Guard to the feature list**

In `README.md`, find:

```markdown
- 取引セッション終了時刻を使ったAuto Close
```

Replace with:

```markdown
- 取引セッション終了時刻を使ったAuto Close
- 口座全体の含み損益に基づくEquity Guard（緊急全決済）
```

- [ ] **Step 2: Add a usage section**

Find:

```markdown
## 安全上の注意
```

Replace with:

```markdown
## Equity Guard

口座全体の含み損益合計を監視し、指定した閾値を超えたら口座内の全ポジションを自動決済します。Max LossとMax Profitは独立に設定でき、0または未入力の側は無効です。Amount（金額）とPercent（`ACCOUNT_BALANCE`基準の割合）を切り替えられます。

一度発動すると、合計がセーフゾーン（両閾値の内側）に戻るか保有ポジションが0件になるまで再発動しません。Auto Closeと同様に確認ダイアログは表示されません。

## 安全上の注意
```

- [ ] **Step 3: Ask the user to review the rendered README**

Ask the user to open `README.md` and confirm the two new sections read correctly and match the actual panel labels ("Equity Guard", "Max Loss", "Max Profit", "Amount"/"Percent").
