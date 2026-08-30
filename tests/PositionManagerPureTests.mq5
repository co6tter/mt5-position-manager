#property strict
#property script_show_inputs

#include "..\src\Models.mqh"
#include "..\src\Constants.mqh"
#include "..\src\SessionService.mqh"
#include "..\src\EquityGuardService.mqh"
#include "..\src\TrailingStopService.mqh"

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

   config.loss_threshold = 500.0;
   config.profit_threshold = 0.0;
   AssertTrue(!PMEvaluateEquityGuard(999999.0, config, 10000.0, loss_triggered, profit_triggered) &&
              !profit_triggered,
              "Zero profit threshold leaves the profit side disabled even on a huge gain");

   config.loss_threshold = 0.0;
   config.profit_threshold = 1000.0;
   AssertTrue(!PMEvaluateEquityGuard(-999999.0, config, 10000.0, loss_triggered, profit_triggered) &&
              !loss_triggered,
              "Zero loss threshold leaves the loss side disabled even on a huge loss");

   config.mode = PM_EQUITY_THRESHOLD_PERCENT;
   config.loss_threshold = 5.0;
   config.profit_threshold = 0.0;
   AssertTrue(!PMEvaluateEquityGuard(-999999.0, config, 0.0, loss_triggered, profit_triggered),
              "Percent mode with zero balance does not trigger (guards against a divide-by-zero-shaped threshold)");

   config.enabled = false;
   config.mode = PM_EQUITY_THRESHOLD_AMOUNT;
   config.loss_threshold = 500.0;
   AssertTrue(!PMEvaluateEquityGuard(-999999.0, config, 10000.0, loss_triggered, profit_triggered),
              "Disabled guard never triggers");
  }

void TestEquityGuardLatch()
  {
   bool triggered = false;

   AssertTrue(PMShouldFireEquityGuard(true, triggered) && triggered,
              "Latch fires on first crossing");
   AssertTrue(!PMShouldFireEquityGuard(true, triggered) && triggered,
              "Latch stays quiet while still triggered");
   AssertTrue(!PMShouldFireEquityGuard(false, triggered) && !triggered,
              "Latch resets once the crossing clears");
   AssertTrue(PMShouldFireEquityGuard(true, triggered) && triggered,
              "Latch fires again after resetting");
  }

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
