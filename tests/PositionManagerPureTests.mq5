#property strict
#property script_show_inputs

#include "..\src\Models.mqh"
#include "..\src\Constants.mqh"
#include "..\src\SessionService.mqh"
#include "..\src\EquityGuardService.mqh"

int g_failures = 0;

void AssertTrue(const bool condition, const string name)
  {
   if(condition)
      PrintFormat("[PASS] %s", name);
   else
     {
      PrintFormat("[FAIL] %s", name);
      g_failures++;
     }
  }

void TestDirectionMatching()
  {
   AssertTrue(PMDirectionMatches(PM_DIRECTION_LONG, POSITION_TYPE_BUY),
              "Long matches Buy");
   AssertTrue(!PMDirectionMatches(PM_DIRECTION_LONG, POSITION_TYPE_SELL),
              "Long rejects Sell");
   AssertTrue(PMDirectionMatches(PM_DIRECTION_SHORT, POSITION_TYPE_SELL),
              "Short matches Sell");
   AssertTrue(PMDirectionMatches(PM_DIRECTION_BOTH, POSITION_TYPE_BUY) &&
              PMDirectionMatches(PM_DIRECTION_BOTH, POSITION_TYPE_SELL),
              "Both matches both position types");
  }

void TestBatchResultHelpers()
  {
   PMBatchResult result;
   PMResetBatchResult(result, 3);
   PMAddFailure(result, 12345, 10016, "Invalid stops", 1);
   AssertTrue(result.requested == 3 && result.successful == 0 &&
              result.queued == 0, "Batch result reset");
   AssertTrue(ArraySize(result.failures) == 1 &&
              result.failures[0].ticket == 12345 &&
              result.failures[0].retcode == 10016,
              "Batch failure preserves ticket and retcode");
  }

void TestTransientRetcodes()
  {
   AssertTrue(PMIsTransientTradeRetcode(TRADE_RETCODE_REQUOTE) &&
              PMIsTransientTradeRetcode(TRADE_RETCODE_CONNECTION),
              "Transient retcodes are queued");
   AssertTrue(!PMIsTransientTradeRetcode(TRADE_RETCODE_INVALID_STOPS),
              "Permanent retcodes are not queued");
  }

void TestSessionCloseResolution()
  {
   const datetime midnight = D'2026.08.24 00:00';
   datetime today_closes[2];
   today_closes[0] = midnight + 12 * 3600;
   today_closes[1] = midnight + 23 * 3600;
   datetime no_previous_starts[];
   datetime no_previous_closes[];
   datetime close = 0;
   AssertTrue(PMResolveSessionClose(midnight + 10 * 3600, midnight,
                                    today_closes,
                                    no_previous_starts,
                                    no_previous_closes, close) &&
              close == today_closes[1],
              "Final intraday session close is selected");

   datetime previous_starts[1];
   datetime previous_closes[1];
   previous_starts[0] = midnight - 2 * 3600;
   previous_closes[0] = midnight + 5 * 3600;
   AssertTrue(PMResolveSessionClose(midnight + 1 * 3600, midnight,
                                    today_closes,
                                    previous_starts,
                                    previous_closes, close) &&
              close == previous_closes[0],
              "Active overnight session close is preserved");

   AssertTrue(PMResolveSessionClose(midnight + 6 * 3600, midnight,
                                    today_closes,
                                    previous_starts,
                                    previous_closes, close) &&
              close == today_closes[1],
              "Ended overnight session does not mask today's close");
  }

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
