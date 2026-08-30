# Trailing Stop / Break Even Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a per-position "Break Even" (move SL to a small profit once triggered) and "Trailing Stop" (continuously ratchet SL to follow price once triggered) feature, scoped to one Symbol + Direction selection shared by both.

**Architecture:** Follow the `CAutoCloseService`/`CEquityGuardService` pattern: pure, independently-testable functions decide the candidate SL; a thin `CTrailingStopService` class wraps them and calls the existing `CTradeManager::ModifyTicket()`. Unlike the other two services, this one needs **no persistent state at all** — every tick it recomputes the best candidate SL from the position's live open price, current price, and current SL, and only submits a modify request when the candidate is strictly more favorable than the position's actual current SL (a "ratchet" — SL only ever moves in the profitable direction, never back). Candidate validation (tick-size rounding, Stops Level/Freeze Level checks) reuses the existing `CValidationService.CalculateTarget()` in its `PM_PRICE_ABSOLUTE` mode — both Break Even (entry-based) and Trailing (current-price-based) compute their own absolute-price candidate first, keeping both pure and testable without a live-tick dependency, then validate through the same Absolute-mode call.

**Tech Stack:** MQL5 (MetaTrader 5), no new dependencies.

**Spec:** `docs/specification.md` — "Trailing Stop / Break Even" section.

## Global Constraints

- No MetaEditor/MT5 runtime is available in this sandbox (macOS, no CLI compiler for MQL5). Every task's verification step must be performed by the user in their own MetaTrader 5 installation. Do not claim a task "passes" without the user confirming the actual compile/run result.
- Never create a git commit unless the user explicitly asks for one in that moment.
- Follow existing code style exactly: 3-space indentation, opening brace of a block on its own line one level deeper than the statement that owns it (see any existing method in `src/EquityGuardService.mqh` or `src/PositionActionService.mqh` for the exact pattern), `PM_` prefix for free functions/enums/structs, `CXxxService` naming for service classes, `m_` prefix for class members, `g_` prefix for globals in `PositionManager.mq5`.
- SL never moves backward (toward loss) — a candidate is only ever applied if it is strictly more favorable than the position's current actual SL. A position with no SL (`sl == 0`) is treated as "any real candidate improves on it," for both Buy and Sell.
- Trailing only starts moving SL once price has moved at least the configured Trail distance past entry — it never places an SL below entry on its first application. Before that point, it does nothing (per the approved design: "含み益がTrail距離以上になってから開始").
- Break Even and Trailing share one Symbol + Direction selection, independent of the panel's other selections (Filter, Auto Close, Equity Guard) — same pattern as Auto Close's own Symbol/Direction pair.
- TP is never touched by this feature — only SL.
- No confirmation dialog (this runs from `OnTimer`, like Auto Close and Equity Guard).
- Status priority in `OnTimer` becomes: Equity Guard > Auto Close > Retry > Trailing/Break Even (lowest priority) — Trailing/Break Even can fire routinely (every tick while a strong trend is running), so it must never drown out the rarer, more important messages above it.

---

### Task 1: Trailing Stop core logic (pure functions + service class + unit tests)

**Files:**
- Modify: `src/Models.mqh`
- Create: `src/TrailingStopService.mqh`
- Modify: `tests/PositionManagerPureTests.mq5`

**Interfaces:**
- Consumes: `PMPosition`, `PMDirection`, `PMTradeFailure`, `PMTradeAttemptStatus` (all in `src/Models.mqh`, already defined); `CPositionService::CollectTickets(const string symbol, const PMDirection direction, ulong &tickets[])` and `CPositionService::Get(const ulong ticket, PMPosition &position)` (both already in `src/PositionService.mqh`); `CTradeManager::ModifyTicket(const ulong ticket, const double sl, const double tp, PMTradeFailure &failure)` returning `PMTradeAttemptStatus` (already in `src/TradeManager.mqh`); `CValidationService::CalculateTarget(const PMPosition &position, const bool is_sl, const PMPriceMode mode, const double value, double &target, string &reason)` returning `bool` (already in `src/ValidationService.mqh`).
- Produces: `struct TrailingStopConfig { bool enabled_break_even; bool enabled_trailing; string symbol; PMDirection direction; int be_trigger_points; int be_lock_points; int trail_points; }`; free functions `bool PMBreakEvenCandidate(...)`, `bool PMTrailingCandidate(...)`, `bool PMIsMoreFavorableStop(...)`, `bool PMBestStopCandidate(...)` (exact signatures below); class `CTrailingStopService` with `bool Evaluate(const TrailingStopConfig &config, CPositionService &positions, CTradeManager &trades, CValidationService &validator, string &status)`. Task 2 and Task 3 depend on these exact names and signatures.

- [ ] **Step 1: Add `TrailingStopConfig` to Models.mqh**

In `src/Models.mqh`, find:

```mql5
struct EquityGuardConfig
  {
   bool enabled;
   PMEquityThresholdMode mode;
   double loss_threshold;
   double profit_threshold;
  };

#endif
```

Replace with:

```mql5
struct EquityGuardConfig
  {
   bool enabled;
   PMEquityThresholdMode mode;
   double loss_threshold;
   double profit_threshold;
  };

struct TrailingStopConfig
  {
   bool enabled_break_even;
   bool enabled_trailing;
   string symbol;
   PMDirection direction;
   int be_trigger_points;
   int be_lock_points;
   int trail_points;
  };

#endif
```

- [ ] **Step 2: Create `src/TrailingStopService.mqh`**

Create the file with this exact content:

```mql5
#ifndef __MT5_POSITION_MANAGER_TRAILING_STOP_SERVICE_MQH__
#define __MT5_POSITION_MANAGER_TRAILING_STOP_SERVICE_MQH__

#include "Models.mqh"
#include "Constants.mqh"
#include "PositionService.mqh"
#include "TradeManager.mqh"
#include "ValidationService.mqh"

bool PMBreakEvenCandidate(const double open_price,
                          const ENUM_POSITION_TYPE type,
                          const double current_price,
                          const double point,
                          const int trigger_points,
                          const int lock_points,
                          double &candidate)
  {
   candidate = 0.0;
   if(trigger_points <= 0 || point <= 0.0)
      return false;
   const double profit_points = type == POSITION_TYPE_BUY ?
                                (current_price - open_price) / point :
                                (open_price - current_price) / point;
   if(profit_points < trigger_points)
      return false;
   candidate = type == POSITION_TYPE_BUY ?
              open_price + lock_points * point :
              open_price - lock_points * point;
   return true;
  }

bool PMTrailingCandidate(const double open_price,
                         const ENUM_POSITION_TYPE type,
                         const double current_price,
                         const double point,
                         const int trail_points,
                         double &candidate)
  {
   candidate = 0.0;
   if(trail_points <= 0 || point <= 0.0)
      return false;
   const double profit_points = type == POSITION_TYPE_BUY ?
                                (current_price - open_price) / point :
                                (open_price - current_price) / point;
   if(profit_points < trail_points)
      return false;
   candidate = type == POSITION_TYPE_BUY ?
              current_price - trail_points * point :
              current_price + trail_points * point;
   return true;
  }

bool PMIsMoreFavorableStop(const ENUM_POSITION_TYPE type,
                           const double candidate,
                           const double current)
  {
   if(current <= 0.0)
      return true;
   if(type == POSITION_TYPE_BUY)
      return candidate > current;
   return candidate < current;
  }

bool PMBestStopCandidate(const ENUM_POSITION_TYPE type,
                         const bool has_break_even,
                         const double break_even_candidate,
                         const bool has_trailing,
                         const double trailing_candidate,
                         double &best)
  {
   best = 0.0;
   if(!has_break_even && !has_trailing)
      return false;
   if(has_break_even && !has_trailing)
     {
      best = break_even_candidate;
      return true;
     }
   if(!has_break_even && has_trailing)
     {
      best = trailing_candidate;
      return true;
     }
   best = PMIsMoreFavorableStop(type, trailing_candidate, break_even_candidate) ?
         trailing_candidate : break_even_candidate;
   return true;
  }

class CTrailingStopService
  {
public:
   bool Evaluate(const TrailingStopConfig &config,
                 CPositionService &positions,
                 CTradeManager &trades,
                 CValidationService &validator,
                 string &status)
     {
      status = "";
      if(!config.enabled_break_even && !config.enabled_trailing)
         return false;

      ulong tickets[];
      positions.CollectTickets(config.symbol, config.direction, tickets);
      if(ArraySize(tickets) == 0)
         return false;

      int modified = 0;
      int queued = 0;
      int failed = 0;
      ulong first_failed_ticket = 0;
      string first_failure_description = "";

      for(int i = 0; i < ArraySize(tickets); i++)
        {
         PMPosition position = {};
         if(!positions.Get(tickets[i], position))
            continue;

         const double point = SymbolInfoDouble(position.symbol, SYMBOL_POINT);
         if(point <= 0.0)
            continue;

         double break_even_candidate = 0.0;
         const bool has_break_even = config.enabled_break_even &&
            PMBreakEvenCandidate(position.open_price, position.type, position.current_price,
                                 point, config.be_trigger_points, config.be_lock_points,
                                 break_even_candidate);

         double trailing_candidate = 0.0;
         const bool has_trailing = config.enabled_trailing &&
            PMTrailingCandidate(position.open_price, position.type, position.current_price,
                                point, config.trail_points, trailing_candidate);

         double best = 0.0;
         if(!PMBestStopCandidate(position.type, has_break_even, break_even_candidate,
                                 has_trailing, trailing_candidate, best))
            continue;

         double target = 0.0;
         string reason = "";
         if(!validator.CalculateTarget(position, true, PM_PRICE_ABSOLUTE, best, target, reason))
            continue;
         if(!PMIsMoreFavorableStop(position.type, target, position.sl))
            continue;

         PMTradeFailure failure = {};
         const PMTradeAttemptStatus attempt_status =
            trades.ModifyTicket(tickets[i], target, position.tp, failure);
         if(attempt_status == PM_TRADE_ATTEMPT_SUCCESS)
            modified++;
         else if(attempt_status == PM_TRADE_ATTEMPT_QUEUED)
            queued++;
         else
           {
            failed++;
            if(first_failed_ticket == 0)
              {
               first_failed_ticket = tickets[i];
               first_failure_description = failure.description;
              }
            PrintFormat("[ERROR] Trailing/Break Even modify failed ticket=%I64u description=%s",
                        tickets[i], failure.description);
           }
        }

      if(modified == 0 && queued == 0 && failed == 0)
         return false;

      status = StringFormat("Trailing/Break Even: %d updated, %d queued, %d failed",
                            modified, queued, failed);
      if(first_failed_ticket != 0)
         status += StringFormat("; ticket=%I64u (%s)",
                                first_failed_ticket, first_failure_description);
      return true;
     }
  };

#endif
```

- [ ] **Step 3: Add unit tests**

In `tests/PositionManagerPureTests.mq5`, find:

```mql5
#include "..\src\Models.mqh"
#include "..\src\Constants.mqh"
#include "..\src\SessionService.mqh"
#include "..\src\EquityGuardService.mqh"
```

Replace with:

```mql5
#include "..\src\Models.mqh"
#include "..\src\Constants.mqh"
#include "..\src\SessionService.mqh"
#include "..\src\EquityGuardService.mqh"
#include "..\src\TrailingStopService.mqh"
```

Then find:

```mql5
void OnStart()
  {
   TestDirectionMatching();
   TestBatchResultHelpers();
   TestTransientRetcodes();
   TestSessionCloseResolution();
   TestEquityGuardEvaluation();
   TestEquityGuardLatch();
   if(g_failures == 0)
      Print("[PASS] All Position Manager pure tests passed.");
   else
      PrintFormat("[FAIL] %d Position Manager pure tests failed.", g_failures);
  }
```

Replace with:

```mql5
void TestBreakEvenCandidate()
  {
   double candidate = 0.0;

   AssertTrue(!PMBreakEvenCandidate(1.1000, POSITION_TYPE_BUY, 1.1010, 0.0001, 20, 2, candidate),
              "Break even does not trigger before reaching the trigger distance");

   AssertTrue(PMBreakEvenCandidate(1.1000, POSITION_TYPE_BUY, 1.1020, 0.0001, 20, 2, candidate) &&
              MathAbs(candidate - 1.1002) < 0.00001,
              "Buy break even locks in entry plus the lock distance once triggered");

   AssertTrue(PMBreakEvenCandidate(1.1000, POSITION_TYPE_SELL, 1.0980, 0.0001, 20, 2, candidate) &&
              MathAbs(candidate - 1.0998) < 0.00001,
              "Sell break even locks in entry minus the lock distance once triggered");

   AssertTrue(!PMBreakEvenCandidate(1.1000, POSITION_TYPE_BUY, 1.1050, 0.0001, 0, 2, candidate),
              "Break even is disabled when trigger_points is zero");
  }

void TestTrailingCandidate()
  {
   double candidate = 0.0;

   AssertTrue(!PMTrailingCandidate(1.1000, POSITION_TYPE_BUY, 1.1015, 0.0001, 20, candidate),
              "Trailing does not start before price has moved the full trail distance");

   AssertTrue(PMTrailingCandidate(1.1000, POSITION_TYPE_BUY, 1.1030, 0.0001, 20, candidate) &&
              MathAbs(candidate - 1.1010) < 0.00001,
              "Buy trailing candidate sits trail distance behind current price, already above entry");

   AssertTrue(PMTrailingCandidate(1.1000, POSITION_TYPE_SELL, 1.0970, 0.0001, 20, candidate) &&
              MathAbs(candidate - 1.0990) < 0.00001,
              "Sell trailing candidate sits trail distance above current price, already below entry");

   AssertTrue(!PMTrailingCandidate(1.1000, POSITION_TYPE_BUY, 1.1050, 0.0001, 0, candidate),
              "Trailing is disabled when trail_points is zero");
  }

void TestIsMoreFavorableStop()
  {
   AssertTrue(PMIsMoreFavorableStop(POSITION_TYPE_BUY, 1.1005, 0.0),
              "Any real candidate improves on a Buy position with no SL");
   AssertTrue(PMIsMoreFavorableStop(POSITION_TYPE_SELL, 1.0995, 0.0),
              "Any real candidate improves on a Sell position with no SL");
   AssertTrue(PMIsMoreFavorableStop(POSITION_TYPE_BUY, 1.1010, 1.1005),
              "A higher candidate is more favorable for a Buy");
   AssertTrue(!PMIsMoreFavorableStop(POSITION_TYPE_BUY, 1.1000, 1.1005),
              "A lower candidate is not more favorable for a Buy");
   AssertTrue(PMIsMoreFavorableStop(POSITION_TYPE_SELL, 1.0990, 1.0995),
              "A lower candidate is more favorable for a Sell");
   AssertTrue(!PMIsMoreFavorableStop(POSITION_TYPE_SELL, 1.1000, 1.0995),
              "A higher candidate is not more favorable for a Sell");
  }

void TestBestStopCandidate()
  {
   double best = 0.0;

   AssertTrue(!PMBestStopCandidate(POSITION_TYPE_BUY, false, 0.0, false, 0.0, best),
              "No candidate when neither break even nor trailing is active");

   AssertTrue(PMBestStopCandidate(POSITION_TYPE_BUY, true, 1.1002, false, 0.0, best) &&
              MathAbs(best - 1.1002) < 0.00001,
              "Only the break even candidate is used when trailing is inactive");

   AssertTrue(PMBestStopCandidate(POSITION_TYPE_BUY, false, 0.0, true, 1.1010, best) &&
              MathAbs(best - 1.1010) < 0.00001,
              "Only the trailing candidate is used when break even is inactive");

   AssertTrue(PMBestStopCandidate(POSITION_TYPE_BUY, true, 1.1002, true, 1.1010, best) &&
              MathAbs(best - 1.1010) < 0.00001,
              "Buy: the more favorable (higher) of the two candidates wins");

   AssertTrue(PMBestStopCandidate(POSITION_TYPE_SELL, true, 1.0998, true, 1.0990, best) &&
              MathAbs(best - 1.0990) < 0.00001,
              "Sell: the more favorable (lower) of the two candidates wins");
  }

void OnStart()
  {
   TestDirectionMatching();
   TestBatchResultHelpers();
   TestTransientRetcodes();
   TestSessionCloseResolution();
   TestEquityGuardEvaluation();
   TestEquityGuardLatch();
   TestBreakEvenCandidate();
   TestTrailingCandidate();
   TestIsMoreFavorableStop();
   TestBestStopCandidate();
   if(g_failures == 0)
      Print("[PASS] All Position Manager pure tests passed.");
   else
      PrintFormat("[FAIL] %d Position Manager pure tests failed.", g_failures);
  }
```

- [ ] **Step 4: Hand-verify the arithmetic, then ask the user to compile and run**

Before moving on, manually re-derive each test's expected number from the formulas in Step 2 (e.g. for `TestBreakEvenCandidate`'s second case: `open_price=1.1000`, `type=BUY`, `current_price=1.1020`, `point=0.0001`, `trigger_points=20` → `profit_points=(1.1020-1.1000)/0.0001=20`, `20 >= 20` so it triggers; `candidate = 1.1000 + 2*0.0001 = 1.1002`). There is no MetaEditor in this sandbox, so this hand-check is the only verification available here.

Then ask the user to:
1. Open `tests/PositionManagerPureTests.mq5` in MetaEditor and compile it (or run `scripts\compile.ps1 -SourcePath tests\PositionManagerPureTests.mq5 -MetaEditorPath "<path to metaeditor64.exe>"` on Windows).
2. Run it as a script on any chart.
3. Confirm the Experts log shows `[PASS] All Position Manager pure tests passed.` with no `[FAIL]` lines, specifically the new lines from `TestBreakEvenCandidate`, `TestTrailingCandidate`, `TestIsMoreFavorableStop`, and `TestBestStopCandidate`.

---

### Task 2: Trailing Stop / Break Even panel section in UiPanel.mqh

**Files:**
- Modify: `src/UiPanel.mqh`

**Interfaces:**
- Consumes: `TrailingStopConfig`, `PMDirection` (from Task 1's `src/Models.mqh` change; `PMDirection` already existed).
- Produces: `CUiPanel::GetTrailingStopConfig(TrailingStopConfig &config)` — Task 3 calls this exact method from `PositionManager.mq5`.

This task adds three new rows below the existing Equity Guard row: a shared Symbol/Direction scope row, a Break Even row, and a Trailing row. Nothing consumes `GetTrailingStopConfig()` yet until Task 3 — toggling the new ON/OFF buttons will change their own label but have no other effect until Task 3 is done. That is expected, not a bug.

- [ ] **Step 1: Add member variables**

In `src/UiPanel.mqh`, find:

```mql5
   bool m_equity_guard_enabled;
   PMEquityThresholdMode m_equity_guard_mode;
   int m_max_rows;
```

Replace with:

```mql5
   bool m_equity_guard_enabled;
   PMEquityThresholdMode m_equity_guard_mode;
   string m_trailing_symbol;
   PMDirection m_trailing_direction;
   bool m_break_even_enabled;
   bool m_trailing_enabled;
   int m_max_rows;
```

- [ ] **Step 2: Initialize the new members in the constructor**

Find:

```mql5
      m_equity_guard_enabled = false;
      m_equity_guard_mode = PM_EQUITY_THRESHOLD_AMOUNT;
      m_max_rows = PM_DEFAULT_MAX_ROWS;
```

Replace with:

```mql5
      m_equity_guard_enabled = false;
      m_equity_guard_mode = PM_EQUITY_THRESHOLD_AMOUNT;
      m_trailing_symbol = "";
      m_trailing_direction = PM_DIRECTION_BOTH;
      m_break_even_enabled = false;
      m_trailing_enabled = false;
      m_max_rows = PM_DEFAULT_MAX_ROWS;
```

- [ ] **Step 3: Create the new controls and shift Session/Status down**

Find:

```mql5
      created = CreateLabel("EQ_SCOPE_LABEL", "All symbols", 625, section_y + 103, clrOrange, 9) && created;

      created = CreateLabel("SESSION_LABEL", "Today's Close: -    Auto Close At: -", 12, section_y + 134, clrSilver, 9) && created;
      created = CreateLabel("STATUS_LABEL", "Status: Ready", 12, section_y + 160, clrWhite, 9) && created;
```

Replace with:

```mql5
      created = CreateLabel("EQ_SCOPE_LABEL", "All symbols", 625, section_y + 103, clrOrange, 9) && created;

      created = CreateLabel("TS_LABEL", "Trailing Stop", 12, section_y + 137, clrSilver, 9) && created;
      created = CreateLabel("TS_SYMBOL_LABEL", "Symbol", 95, section_y + 137, clrSilver, 9) && created;
      created = CreateButton("TS_SYMBOL", "Symbol", 145, section_y + 134, 105, 22) && created;
      created = CreateButton("TS_DIRECTION", "Both", 255, section_y + 134, 85, 22) && created;

      created = CreateLabel("BE_LABEL", "Break Even", 12, section_y + 171, clrSilver, 9) && created;
      created = CreateButton("BE_ENABLED", "OFF", 95, section_y + 168, 65, 22) && created;
      created = CreateLabel("BE_TRIGGER_LABEL", "Trigger(pt)", 170, section_y + 171, clrSilver, 9) && created;
      created = CreateEdit("BE_TRIGGER_VALUE", "", 255, section_y + 168, 70, 22) && created;
      created = CreateLabel("BE_LOCK_LABEL", "Lock(pt)", 335, section_y + 171, clrSilver, 9) && created;
      created = CreateEdit("BE_LOCK_VALUE", "", 400, section_y + 168, 70, 22) && created;

      created = CreateLabel("TRAIL_LABEL", "Trailing", 12, section_y + 205, clrSilver, 9) && created;
      created = CreateButton("TRAIL_ENABLED", "OFF", 95, section_y + 202, 65, 22) && created;
      created = CreateLabel("TRAIL_DIST_LABEL", "Distance(pt)", 170, section_y + 205, clrSilver, 9) && created;
      created = CreateEdit("TRAIL_DIST_VALUE", "", 255, section_y + 202, 70, 22) && created;

      created = CreateLabel("SESSION_LABEL", "Today's Close: -    Auto Close At: -", 12, section_y + 236, clrSilver, 9) && created;
      created = CreateLabel("STATUS_LABEL", "Status: Ready", 12, section_y + 262, clrWhite, 9) && created;
```

- [ ] **Step 4: Grow the panel height by three rows (102px)**

Find:

```mql5
   int PanelHeight()
     {
      return SectionY() + 199;
     }
```

Replace with:

```mql5
   int PanelHeight()
     {
      return SectionY() + 301;
     }
```

- [ ] **Step 5: Reposition the new controls (and the shifted Session/Status labels) on resize**

In `ApplyLayout()`, find:

```mql5
      RepositionY("EQ_SCOPE_LABEL", section_y + 103);
      RepositionY("SESSION_LABEL", section_y + 134);
      RepositionY("STATUS_LABEL", section_y + 160);
     }
```

Replace with:

```mql5
      RepositionY("EQ_SCOPE_LABEL", section_y + 103);
      RepositionY("TS_LABEL", section_y + 137);
      RepositionY("TS_SYMBOL_LABEL", section_y + 137);
      RepositionY("TS_SYMBOL", section_y + 134);
      RepositionY("TS_DIRECTION", section_y + 134);
      RepositionY("BE_LABEL", section_y + 171);
      RepositionY("BE_ENABLED", section_y + 168);
      RepositionY("BE_TRIGGER_LABEL", section_y + 171);
      RepositionY("BE_TRIGGER_VALUE", section_y + 168);
      RepositionY("BE_LOCK_LABEL", section_y + 171);
      RepositionY("BE_LOCK_VALUE", section_y + 168);
      RepositionY("TRAIL_LABEL", section_y + 205);
      RepositionY("TRAIL_ENABLED", section_y + 202);
      RepositionY("TRAIL_DIST_LABEL", section_y + 205);
      RepositionY("TRAIL_DIST_VALUE", section_y + 202);
      RepositionY("SESSION_LABEL", section_y + 236);
      RepositionY("STATUS_LABEL", section_y + 262);
     }
```

- [ ] **Step 6: Refresh the new buttons' text in Render()**

Find:

```mql5
      ObjectSetString(0, Name("EQ_ENABLED"), OBJPROP_TEXT, m_equity_guard_enabled ? "ON" : "OFF");
      ObjectSetString(0, Name("EQ_MODE"), OBJPROP_TEXT, EquityThresholdModeToString(m_equity_guard_mode));
      ObjectSetString(0, Name("SESSION_LABEL"), OBJPROP_TEXT,
```

Replace with:

```mql5
      ObjectSetString(0, Name("EQ_ENABLED"), OBJPROP_TEXT, m_equity_guard_enabled ? "ON" : "OFF");
      ObjectSetString(0, Name("EQ_MODE"), OBJPROP_TEXT, EquityThresholdModeToString(m_equity_guard_mode));
      ObjectSetString(0, Name("TS_SYMBOL"), OBJPROP_TEXT, TrailingSymbol());
      ObjectSetString(0, Name("TS_DIRECTION"), OBJPROP_TEXT, PMDirectionToString(m_trailing_direction));
      ObjectSetString(0, Name("BE_ENABLED"), OBJPROP_TEXT, m_break_even_enabled ? "ON" : "OFF");
      ObjectSetString(0, Name("TRAIL_ENABLED"), OBJPROP_TEXT, m_trailing_enabled ? "ON" : "OFF");
      ObjectSetString(0, Name("SESSION_LABEL"), OBJPROP_TEXT,
```

- [ ] **Step 7: Keep the Symbol candidate list and default in sync in Refresh()**

Find:

```mql5
   void Refresh(CPositionService &positions)
     {
      positions.Collect(m_positions);
      positions.CollectSymbols(m_symbols);
      if(m_filter_symbol == "")
         m_filter_symbol = _Symbol;
      if(m_auto_symbol == "")
         m_auto_symbol = _Symbol;
      EnsureSymbolCandidate(m_filter_symbol);
      EnsureSymbolCandidate(m_auto_symbol);
      ClampPage();
```

Replace with:

```mql5
   void Refresh(CPositionService &positions)
     {
      positions.Collect(m_positions);
      positions.CollectSymbols(m_symbols);
      if(m_filter_symbol == "")
         m_filter_symbol = _Symbol;
      if(m_auto_symbol == "")
         m_auto_symbol = _Symbol;
      if(m_trailing_symbol == "")
         m_trailing_symbol = _Symbol;
      EnsureSymbolCandidate(m_filter_symbol);
      EnsureSymbolCandidate(m_auto_symbol);
      EnsureSymbolCandidate(m_trailing_symbol);
      ClampPage();
```

- [ ] **Step 8: Handle clicks on the new buttons**

In `HandleChartEvent()`, find:

```mql5
      else if(object_name == Name("EQ_ENABLED"))
         m_equity_guard_enabled = !m_equity_guard_enabled;
      else if(object_name == Name("EQ_MODE"))
         m_equity_guard_mode = m_equity_guard_mode == PM_EQUITY_THRESHOLD_AMOUNT ?
                               PM_EQUITY_THRESHOLD_PERCENT : PM_EQUITY_THRESHOLD_AMOUNT;
      else
        {
         const int page_start = m_page * m_max_rows;
```

Replace with:

```mql5
      else if(object_name == Name("EQ_ENABLED"))
         m_equity_guard_enabled = !m_equity_guard_enabled;
      else if(object_name == Name("EQ_MODE"))
         m_equity_guard_mode = m_equity_guard_mode == PM_EQUITY_THRESHOLD_AMOUNT ?
                               PM_EQUITY_THRESHOLD_PERCENT : PM_EQUITY_THRESHOLD_AMOUNT;
      else if(object_name == Name("TS_SYMBOL"))
         CycleSymbol(m_trailing_symbol);
      else if(object_name == Name("TS_DIRECTION"))
         m_trailing_direction = NextDirection(m_trailing_direction);
      else if(object_name == Name("BE_ENABLED"))
         m_break_even_enabled = !m_break_even_enabled;
      else if(object_name == Name("TRAIL_ENABLED"))
         m_trailing_enabled = !m_trailing_enabled;
      else
        {
         const int page_start = m_page * m_max_rows;
```

- [ ] **Step 9: Add the config getter and its private helpers**

Find:

```mql5
   void GetEquityGuardConfig(EquityGuardConfig &config)
     {
      config.enabled = m_equity_guard_enabled;
      config.mode = m_equity_guard_mode;
      config.loss_threshold = EquityGuardLossThreshold();
      config.profit_threshold = EquityGuardProfitThreshold();
     }
```

Replace with:

```mql5
   void GetEquityGuardConfig(EquityGuardConfig &config)
     {
      config.enabled = m_equity_guard_enabled;
      config.mode = m_equity_guard_mode;
      config.loss_threshold = EquityGuardLossThreshold();
      config.profit_threshold = EquityGuardProfitThreshold();
     }

   void GetTrailingStopConfig(TrailingStopConfig &config)
     {
      config.enabled_break_even = m_break_even_enabled;
      config.enabled_trailing = m_trailing_enabled;
      config.symbol = TrailingSymbol();
      config.direction = m_trailing_direction;
      config.be_trigger_points = BreakEvenTriggerPoints();
      config.be_lock_points = BreakEvenLockPoints();
      config.trail_points = TrailingDistancePoints();
     }
```

Then find:

```mql5
   string AutoSymbol()
     {
      return m_auto_symbol == "" ? _Symbol : m_auto_symbol;
     }
```

Replace with:

```mql5
   string AutoSymbol()
     {
      return m_auto_symbol == "" ? _Symbol : m_auto_symbol;
     }

   string TrailingSymbol()
     {
      return m_trailing_symbol == "" ? _Symbol : m_trailing_symbol;
     }
```

Then find:

```mql5
   double EquityGuardProfitThreshold()
     {
      const double value = StringToDouble(ObjectGetString(0, Name("EQ_PROFIT_VALUE"), OBJPROP_TEXT));
      return value > 0.0 ? value : 0.0;
     }
```

Replace with:

```mql5
   double EquityGuardProfitThreshold()
     {
      const double value = StringToDouble(ObjectGetString(0, Name("EQ_PROFIT_VALUE"), OBJPROP_TEXT));
      return value > 0.0 ? value : 0.0;
     }

   int BreakEvenTriggerPoints()
     {
      const long value = StringToInteger(ObjectGetString(0, Name("BE_TRIGGER_VALUE"), OBJPROP_TEXT));
      return value > 0 ? (int)value : 0;
     }

   int BreakEvenLockPoints()
     {
      const long value = StringToInteger(ObjectGetString(0, Name("BE_LOCK_VALUE"), OBJPROP_TEXT));
      return value > 0 ? (int)value : 0;
     }

   int TrailingDistancePoints()
     {
      const long value = StringToInteger(ObjectGetString(0, Name("TRAIL_DIST_VALUE"), OBJPROP_TEXT));
      return value > 0 ? (int)value : 0;
     }
```

- [ ] **Step 10: Ask the user to compile and manually verify the panel**

There is no MetaEditor in this sandbox. Ask the user to:
1. Compile `src/PositionManager.mq5` in MetaEditor (it still compiles at this point even though nothing calls `GetTrailingStopConfig()` yet).
2. Attach the EA to a chart.
3. Confirm three new rows appear below "Equity Guard": "Trailing Stop" (Symbol/Direction buttons), "Break Even" (OFF button, Trigger(pt)/Lock(pt) edit fields), "Trailing" (OFF button, Distance(pt) edit field).
4. Click the Symbol/Direction buttons on the Trailing Stop row and confirm they cycle independently of the Filter and Auto Close rows' own Symbol/Direction. Click BE_ENABLED and TRAIL_ENABLED and confirm they toggle ON/OFF.
5. Confirm the panel still resizes correctly (drag the bottom-right grip) and all three new rows move with the rest of the panel below the position list.

---

### Task 3: Wire Trailing Stop / Break Even into the timer loop

**Files:**
- Modify: `src/PositionManager.mq5`

**Interfaces:**
- Consumes: `CTrailingStopService` and `TrailingStopConfig` (Task 1), `CUiPanel::GetTrailingStopConfig()` (Task 2), the existing global `g_validation` (`CValidationService`, already declared).
- Produces: nothing further downstream — this is the last piece that makes the feature live.

- [ ] **Step 1: Include the new service and declare the global instance**

Find:

```mql5
#include "EquityGuardService.mqh"
#include "UiPanel.mqh"
```

Replace with:

```mql5
#include "EquityGuardService.mqh"
#include "TrailingStopService.mqh"
#include "UiPanel.mqh"
```

Then find:

```mql5
CEquityGuardService g_equity_guard;
CUiPanel g_ui;
```

Replace with:

```mql5
CEquityGuardService g_equity_guard;
CTrailingStopService g_trailing_stop;
CUiPanel g_ui;
```

- [ ] **Step 2: Evaluate the service every timer tick, at the lowest status priority**

Find:

```mql5
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

Replace with:

```mql5
   EquityGuardConfig equity_guard_config = {};
   g_ui.GetEquityGuardConfig(equity_guard_config);
   string equity_guard_status = "";
   g_equity_guard.Evaluate(equity_guard_config, g_positions, g_trades, equity_guard_status);
   TrailingStopConfig trailing_stop_config = {};
   g_ui.GetTrailingStopConfig(trailing_stop_config);
   string trailing_stop_status = "";
   g_trailing_stop.Evaluate(trailing_stop_config, g_positions, g_trades, g_validation, trailing_stop_status);
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
```

- [ ] **Step 3: Ask the user to compile and manually verify end-to-end behavior**

There is no MetaEditor in this sandbox. Ask the user to compile `src/PositionManager.mq5`, attach it to a demo account chart with at least one open position, and check:
1. With both Break Even and Trailing OFF, no position's SL ever changes on its own and no "Trailing/Break Even:" status appears.
2. Turn Break Even ON with a small Trigger (e.g. `20`) and Lock (e.g. `2`) on the position's Symbol/Direction. Once the position is at least 20 points in profit, confirm its SL moves to entry+2 points (Buy) or entry-2 points (Sell) within one timer tick, and does **not** keep resubmitting every second afterward (SL already at target — the ratchet check should make it a no-op every tick after the first move).
3. Turn Trailing ON with a Distance (e.g. `20`). Confirm SL does not move at all until the position is at least 20 points in profit, then starts following price at a fixed 20-point distance, only ever moving toward more profit, never backward, even as price pulls back.
4. With both enabled, confirm the SL always reflects whichever of Break Even's fixed lock level or Trailing's current level is more favorable (Trailing should eventually take over as profit grows past the Break Even lock level).
5. Confirm a manual SL/TP change (via the existing "Set / Change SL" button) on the same position is not fought by this feature unless the manual SL happens to be less favorable than what Break Even/Trailing would compute.

---

### Task 4: Documentation

**Files:**
- Modify: `README.md`
- Modify: `tests/manual-test-plan.md`

**Interfaces:** None — documentation only.

- [ ] **Step 1: Add the feature to the README's feature list**

In `README.md`, find:

```markdown
- 口座全体の含み損益に基づくEquity Guard（緊急全決済）
```

Replace with:

```markdown
- 口座全体の含み損益に基づくEquity Guard（緊急全決済）
- 選択したSymbol・DirectionへのBreak Even（建値保存）とTrailing Stop
```

- [ ] **Step 2: Add a usage section**

Find:

```markdown
## 安全上の注意
```

Replace with:

```markdown
## Trailing Stop / Break Even

Break EvenとTrailingは1つのSymbol・Direction選択を共有し、Filter・Auto Close・Equity Guardの選択とは独立です。

Break Evenは、現在価格が建値からTrigger（points）以上有利に動いたら、建値からLock（points）分有利な位置へSLを移動します。Trailingは、現在価格が建値からDistance（points）以上有利に動いたら、現在価格からDistance分のSLで追従を開始します。どちらも毎tick再計算され、現在の実際のSLより厳密に有利な場合のみ更新するため、SLが後退することはありません（一度設定したSLより不利な方向へは動きません）。TPは変更しません。

両方を同時に有効にした場合は、その時点でより有利な方を採用します。ブローカーのStops Level・Freeze Levelにより更新が拒否される場合は、そのTicketをそのtickだけスキップし、次のtickで再試行します。Auto Close・Equity Guardと同様に確認ダイアログは表示されません。

## 安全上の注意
```

- [ ] **Step 3: Add the new file to the `## 構成` list**

Find:

```markdown
- `src/EquityGuardService.mqh`: 口座全体の含み損益によるEquity Guard判定
- `src/UiPanel.mqh`: チャートオブジェクトによる操作パネル
```

Replace with:

```markdown
- `src/EquityGuardService.mqh`: 口座全体の含み損益によるEquity Guard判定
- `src/TrailingStopService.mqh`: Break Even・Trailing StopのSL候補計算とラチェット更新
- `src/UiPanel.mqh`: チャートオブジェクトによる操作パネル
```

- [ ] **Step 4: Add a manual test plan section**

In `tests/manual-test-plan.md`, this file has no MetaEditor CLI test runner backing it — it's the project's checklist for manual verification on a demo account, with one `##` section per feature. Append this new section at the end of the file (after the existing `## Equity Guard` section, which is currently the last one):

```markdown

## Trailing Stop / Break Even

1. Break Even・Trailingを両方OFFのまま複数ポジションを保有し、SLが一切変化しないことを確認する。
2. Break EvenをONにしTrigger/Lockを設定し、対象Symbol・Directionのポジションが含み益Trigger以上になった瞬間にSLが建値+Lock（Buy）または建値-Lock（Sell）へ1回だけ更新されることを確認する（Expertsログの`[INFO] Position modified...`が連続して出力されないこと）。
3. TrailingをONにしDistanceを設定し、含み益がDistance未満の間はSLが動かず、Distance以上になってから現在価格からDistance分の位置で追従を始めることを確認する。価格が反落してもSLが後退しないことを確認する。
4. Break Even・Trailing両方ONの状態で、含み益が小さい間はBreak Evenのロック位置、含み益が大きくなるとTrailingの位置に自然に切り替わることを確認する。
5. Trigger/Lock/Distance欄に非数値・負数・空欄を入力し、その機能が実質的に無効になる（SLを一切動かさない）ことを確認する。
6. 対象外のSymbol・Directionのポジションが影響を受けないことを確認する。

```

- [ ] **Step 5: Ask the user to review both documents**

Ask the user to open `README.md` and `tests/manual-test-plan.md` and confirm the new sections read correctly and match the actual panel labels ("Trailing Stop", "Break Even", "Trailing", "Trigger(pt)", "Lock(pt)", "Distance(pt)").
