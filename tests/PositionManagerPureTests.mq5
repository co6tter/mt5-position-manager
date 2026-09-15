#property strict
#property script_show_inputs

#include "..\src\Models.mqh"
#include "..\src\Constants.mqh"
#include "..\src\PriceEditor.mqh"
#include "..\src\SessionService.mqh"
#include "..\src\EquityGuardService.mqh"
#include "..\src\EquityLineService.mqh"
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
              result.queued == 0 && result.unchanged == 0,
              "Batch result reset");
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
   AssertTrue(PMEvaluateEquityGuard(-999999.0, config, 0.0, loss_triggered, profit_triggered) &&
              loss_triggered,
              "Percent mode with non-positive balance fails safe: any floating loss triggers");
   AssertTrue(!PMEvaluateEquityGuard(0.0, config, 0.0, loss_triggered, profit_triggered),
              "Percent mode with non-positive balance and zero profit does not trigger");
   AssertTrue(PMEvaluateEquityGuard(-999999.0, config, -5000.0, loss_triggered, profit_triggered) &&
              loss_triggered,
              "Percent mode with a negative balance also fails safe on any floating loss");

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

   AssertTrue(PMBreakEvenCandidate(1.1000, POSITION_TYPE_BUY, 1.1020, 0.0001, 20, 0, candidate) &&
              MathAbs(candidate - 1.1000) < 0.00001,
              "Buy break even with zero lock points locks in exactly the entry price");
  }

void TestTrailingCandidate()
  {
   double candidate = 0.0;

   AssertTrue(!PMTrailingCandidate(1.1000, POSITION_TYPE_BUY, 1.1015, 0.0001, 20, 10, candidate),
              "Trailing does not start before the trigger distance");

   AssertTrue(PMTrailingCandidate(1.1000, POSITION_TYPE_BUY, 1.1020, 0.0001, 20, 10, candidate) &&
              MathAbs(candidate - 1.1010) < 0.00001,
              "Buy trailing starts at the trigger and uses the separate distance");

   AssertTrue(PMTrailingCandidate(1.1000, POSITION_TYPE_SELL, 1.0980, 0.0001, 20, 10, candidate) &&
              MathAbs(candidate - 1.0990) < 0.00001,
              "Sell trailing starts at the trigger and uses the separate distance");
   AssertTrue(!PMTrailingCandidate(1.1000, POSITION_TYPE_BUY, 1.1010, 0.0001, 10, 20, candidate),
              "Trailing does not place the first stop below the entry price");

   AssertTrue(!PMTrailingCandidate(1.1000, POSITION_TYPE_BUY, 1.1050, 0.0001, 0, 10, candidate),
              "Trailing is disabled when the trigger is zero");
   AssertTrue(!PMTrailingCandidate(1.1000, POSITION_TYPE_BUY, 1.1050, 0.0001, 20, 0, candidate),
              "Trailing is disabled when the distance is zero");
  }

void TestPositionBasket()
  {
   PMPosition positions[];
   ArrayResize(positions, 3);
   positions[0].ticket = 101;
   positions[0].symbol = "USDJPY";
   positions[0].type = POSITION_TYPE_BUY;
   positions[0].volume = 1.0;
   positions[0].open_price = 100.0;
   positions[0].current_price = 108.0;
   positions[1].ticket = 102;
   positions[1].symbol = "USDJPY";
   positions[1].type = POSITION_TYPE_BUY;
   positions[1].volume = 2.0;
   positions[1].open_price = 110.0;
   positions[1].current_price = 108.0;
   positions[2].ticket = 103;
   positions[2].symbol = "USDJPY";
   positions[2].type = POSITION_TYPE_SELL;
   positions[2].volume = 1.0;
   positions[2].open_price = 109.0;
   positions[2].current_price = 108.0;

   double open_price = 0.0;
   double current_price = 0.0;
   ulong tickets[];
   AssertTrue(PMBuildPositionBasket(positions, "USDJPY", POSITION_TYPE_BUY,
                                    open_price, current_price, tickets) &&
              MathAbs(open_price - 106.66666667) < 0.00001 &&
              MathAbs(current_price - 108.0) < 0.00001 &&
              ArraySize(tickets) == 2 && tickets[0] == 101 && tickets[1] == 102,
              "Basket uses the volume-weighted entry and keeps same-direction tickets");

   double candidate = 0.0;
   AssertTrue(!PMTrailingCandidate(open_price, POSITION_TYPE_BUY, 107.5,
                                   0.1, 10, 2, candidate),
              "Basket trailing waits until the weighted entry reaches the trigger");
   AssertTrue(PMTrailingCandidate(open_price, POSITION_TYPE_BUY, current_price,
                                  0.1, 10, 2, candidate) &&
              MathAbs(candidate - 107.8) < 0.00001,
              "Basket trailing triggers from the weighted entry even when one layer is losing");

   AssertTrue(PMBuildPositionBasket(positions, "USDJPY", POSITION_TYPE_SELL,
                                    open_price, current_price, tickets) &&
              ArraySize(tickets) == 1 && tickets[0] == 103,
              "Buy and Sell positions are kept in separate baskets");

   AssertTrue(!PMBuildPositionBasket(positions, "", POSITION_TYPE_BUY,
                                     open_price, current_price, tickets) &&
              ArraySize(tickets) == 0,
              "An empty basket symbol clears stale output tickets");
  }

void TestTrailBasisToggle()
  {
   AssertTrue(PM_TRAIL_BASIS_PER_POSITION == 0,
              "Per-position is the zero-value default basis");
   AssertTrue(PMToggleTrailBasis(PM_TRAIL_BASIS_AVERAGE) == PM_TRAIL_BASIS_PER_POSITION,
              "Toggling the average basis selects per-position");
   AssertTrue(PMToggleTrailBasis(PM_TRAIL_BASIS_PER_POSITION) == PM_TRAIL_BASIS_AVERAGE,
              "Toggling the per-position basis selects average");
   AssertTrue(PMTrailBasisToString(PM_TRAIL_BASIS_AVERAGE) == "Average" &&
              PMTrailBasisToString(PM_TRAIL_BASIS_PER_POSITION) == "Per Position",
              "Each basis has a distinct display label");
  }

void TestResolveTrailingCandidatesBasisSelection()
  {
   // Four-digit point size: A: 1 lot @1.10000, B: 3 lots @1.10200, Bid 1.10300.
   // Average entry is 1.10150; only A has individually reached the trigger.
   PMPosition positions[];
   ArrayResize(positions, 2);
   positions[0].ticket = 201;
   positions[0].symbol = "EURUSD";
   positions[0].type = POSITION_TYPE_BUY;
   positions[0].volume = 1.0;
   positions[0].open_price = 1.10000;
   positions[0].current_price = 1.10300;
   positions[1].ticket = 202;
   positions[1].symbol = "EURUSD";
   positions[1].type = POSITION_TYPE_BUY;
   positions[1].volume = 3.0;
   positions[1].open_price = 1.10200;
   positions[1].current_price = 1.10300;

   double points[2] = {0.0001, 0.0001};
   int digits[2] = {5, 5};
   bool pending[2] = {false, false};
   ulong result_tickets[];
   int result_basis_index[];
   double result_candidates[];
   double result_fallback_candidates[];

   AssertTrue(PMResolveTrailingCandidates(positions, PM_TRAIL_BASIS_AVERAGE, "EURUSD", PM_DIRECTION_BOTH,
                                          points, digits, pending, true, false, 20, 2, 0, 0,
                                          result_tickets, result_basis_index,
                                          result_candidates, result_fallback_candidates) == 0,
              "Average basis Break Even does not fire when the weighted entry has not reached the trigger");

   AssertTrue(PMResolveTrailingCandidates(positions, PM_TRAIL_BASIS_PER_POSITION, "EURUSD", PM_DIRECTION_BOTH,
                                          points, digits, pending, true, false, 20, 2, 0, 0,
                                          result_tickets, result_basis_index,
                                          result_candidates, result_fallback_candidates) == 1 &&
              result_tickets[0] == 201 && MathAbs(result_candidates[0] - 1.10020) < 0.00001,
              "Per-position basis Break Even fires only for the ticket whose own entry reached the trigger");
  }

void TestResolveTrailingCandidatesSharedCandidate()
  {
   // Same A/B pair with current Bid 1.10400: both tickets individually reach
   // the trailing trigger, and the trailing candidate is price-derived rather
   // than entry-derived, so per-position basis can still agree with average
   // basis on one shared target.
   PMPosition positions[];
   ArrayResize(positions, 2);
   positions[0].ticket = 201;
   positions[0].symbol = "EURUSD";
   positions[0].type = POSITION_TYPE_BUY;
   positions[0].volume = 1.0;
   positions[0].open_price = 1.10000;
   positions[0].current_price = 1.10400;
   positions[1].ticket = 202;
   positions[1].symbol = "EURUSD";
   positions[1].type = POSITION_TYPE_BUY;
   positions[1].volume = 3.0;
   positions[1].open_price = 1.10200;
   positions[1].current_price = 1.10400;

   double points[2] = {0.0001, 0.0001};
   int digits[2] = {5, 5};
   bool pending[2] = {false, false};
   ulong result_tickets[];
   int result_basis_index[];
   double result_candidates[];
   double result_fallback_candidates[];

   AssertTrue(PMResolveTrailingCandidates(positions, PM_TRAIL_BASIS_AVERAGE, "EURUSD", PM_DIRECTION_BOTH,
                                          points, digits, pending, false, true, 0, 0, 20, 10,
                                          result_tickets, result_basis_index,
                                          result_candidates, result_fallback_candidates) == 2 &&
              MathAbs(result_candidates[0] - 1.10300) < 0.00001 &&
              MathAbs(result_candidates[1] - 1.10300) < 0.00001,
              "Average basis trailing applies one shared candidate to every ticket in the basket");

   AssertTrue(PMResolveTrailingCandidates(positions, PM_TRAIL_BASIS_PER_POSITION, "EURUSD", PM_DIRECTION_BOTH,
                                          points, digits, pending, false, true, 0, 0, 20, 10,
                                          result_tickets, result_basis_index,
                                          result_candidates, result_fallback_candidates) == 2 &&
              result_tickets[0] == 201 && result_tickets[1] == 202 &&
              MathAbs(result_candidates[0] - 1.10300) < 0.00001 &&
              MathAbs(result_candidates[1] - 1.10300) < 0.00001,
              "Per-position basis can independently agree with every ticket on the same price-derived candidate");
  }

void TestResolveTrailingCandidatesPendingExclusion()
  {
   PMPosition positions[];
   ArrayResize(positions, 2);
   positions[0].ticket = 201;
   positions[0].symbol = "EURUSD";
   positions[0].type = POSITION_TYPE_BUY;
   positions[0].volume = 1.0;
   positions[0].open_price = 1.10000;
   positions[0].current_price = 1.10300;
   positions[1].ticket = 202;
   positions[1].symbol = "EURUSD";
   positions[1].type = POSITION_TYPE_BUY;
   positions[1].volume = 1.0;
   positions[1].open_price = 1.10000;
   positions[1].current_price = 1.10300;

   double points[2] = {0.0001, 0.0001};
   int digits[2] = {5, 5};
   bool pending[2] = {true, false};
   ulong result_tickets[];
   int result_basis_index[];
   double result_candidates[];
   double result_fallback_candidates[];

   AssertTrue(PMResolveTrailingCandidates(positions, PM_TRAIL_BASIS_AVERAGE, "EURUSD", PM_DIRECTION_BOTH,
                                          points, digits, pending, true, false, 20, 2, 0, 0,
                                          result_tickets, result_basis_index,
                                          result_candidates, result_fallback_candidates) == 0,
              "Average basis skips the whole basket when any member ticket has a pending request");

   AssertTrue(PMResolveTrailingCandidates(positions, PM_TRAIL_BASIS_PER_POSITION, "EURUSD", PM_DIRECTION_BOTH,
                                          points, digits, pending, true, false, 20, 2, 0, 0,
                                          result_tickets, result_basis_index,
                                          result_candidates, result_fallback_candidates) == 1 &&
              result_tickets[0] == 202,
              "Per-position basis excludes only the pending ticket and still evaluates the rest");
  }

void TestResolveTrailingCandidatesSellAndScope()
  {
   PMPosition positions[];
   ArrayResize(positions, 4);
   for(int i = 0; i < 4; i++)
     {
      positions[i].ticket = 301 + i;
      positions[i].symbol = i == 3 ? "OTHER" : "EURUSD";
      positions[i].type = i == 2 ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      positions[i].volume = i == 1 ? 3.0 : 1.0;
      positions[i].open_price = i == 1 ? 1.1020 : 1.1040;
      positions[i].current_price = 1.1010;
     }
   double points[4] = {0.0001, 0.0001, 0.0001, 0.0001};
   int digits[4] = {5, 5, 5, 5};
   bool pending[4] = {false, false, false, false};
   ulong tickets[];
   int indices[];
   double candidates[];
   double fallbacks[];
   AssertTrue(PMResolveTrailingCandidates(positions, PM_TRAIL_BASIS_AVERAGE,
                                          "EURUSD", PM_DIRECTION_SHORT, points, digits, pending,
                                          true, true, 20, 2, 20, 10,
                                          tickets, indices, candidates, fallbacks) == 0,
              "Sell average below trigger ignores other symbols and Buy positions");
   AssertTrue(PMResolveTrailingCandidates(positions, PM_TRAIL_BASIS_PER_POSITION,
                                          "EURUSD", PM_DIRECTION_SHORT, points, digits, pending,
                                          true, true, 20, 2, 20, 10,
                                          tickets, indices, candidates, fallbacks) == 1 &&
              tickets[0] == 301 && indices[0] == 0 &&
              MathAbs(candidates[0] - 1.1020) < 0.000001 &&
              MathAbs(fallbacks[0] - 1.1038) < 0.000001,
              "Only triggered Sell gets its favorable trailing and entry-based fallback");
   AssertTrue(PMResolveTrailingCandidates(positions, PM_TRAIL_BASIS_PER_POSITION,
                                          "EURUSD", PM_DIRECTION_SHORT, points, digits, pending,
                                          false, true, 20, 2, 20, 40,
                                          tickets, indices, candidates, fallbacks) == 0 &&
              ArraySize(indices) == 0 && ArraySize(candidates) == 0 && ArraySize(fallbacks) == 0,
              "Trailing beyond own Sell entry is rejected and stale results are cleared");
   ArrayResize(positions, 1);
   PMResolveTrailingCandidates(positions, PM_TRAIL_BASIS_AVERAGE,
                               "EURUSD", PM_DIRECTION_SHORT, points, digits, pending,
                               true, false, 20, 0, 0, 0,
                               tickets, indices, candidates, fallbacks);
   AssertTrue(ArraySize(tickets) == 1 && MathAbs(candidates[0] - 1.1040) < 0.000001,
              "Single Sell average with zero lock sets entry SL");
   PMResolveTrailingCandidates(positions, PM_TRAIL_BASIS_PER_POSITION,
                               "EURUSD", PM_DIRECTION_SHORT, points, digits, pending,
                               true, false, 20, 0, 0, 0,
                               tickets, indices, candidates, fallbacks);
   AssertTrue(ArraySize(tickets) == 1 && MathAbs(candidates[0] - 1.1040) < 0.000001,
              "Single Sell per-position with zero lock agrees with average");
   ArrayResize(positions, 0);
   AssertTrue(PMResolveTrailingCandidates(positions, PM_TRAIL_BASIS_PER_POSITION,
                                          "EURUSD", PM_DIRECTION_SHORT, points, digits, pending,
                                          true, true, 20, 2, 20, 10,
                                          tickets, indices, candidates, fallbacks) == 0,
              "Empty position snapshot clears previous results");
  }

void TestResolveTrailingCandidatesSnapToDigitGrid()
  {
   // Gold-style 2-digit quote: raw candidate 4282.33 snaps to the nearest 0.1.
   PMPosition gold_position[];
   ArrayResize(gold_position, 1);
   gold_position[0].ticket = 501;
   gold_position[0].symbol = "XAUUSD";
   gold_position[0].type = POSITION_TYPE_BUY;
   gold_position[0].volume = 1.0;
   gold_position[0].open_price = 4280.00;
   gold_position[0].current_price = 4282.50;

   double gold_points[1] = {0.01};
   int gold_digits[1] = {2};
   bool gold_pending[1] = {false};
   ulong result_tickets[];
   int result_basis_index[];
   double result_candidates[];
   double result_fallback_candidates[];

   AssertTrue(PMResolveTrailingCandidates(gold_position, PM_TRAIL_BASIS_PER_POSITION, "XAUUSD", PM_DIRECTION_BOTH,
                                          gold_points, gold_digits, gold_pending, false, true, 0, 0, 200, 17,
                                          result_tickets, result_basis_index,
                                          result_candidates, result_fallback_candidates) == 1 &&
              MathAbs(result_candidates[0] - 4282.30) < 0.00001,
              "Two-digit XAUUSD-style trailing candidate snaps to the nearest 0.1");

   // Five-digit FX quote: raw candidate 1.10133 snaps to the nearest pip.
   PMPosition fx_position[];
   ArrayResize(fx_position, 1);
   fx_position[0].ticket = 502;
   fx_position[0].symbol = "EURUSD";
   fx_position[0].type = POSITION_TYPE_BUY;
   fx_position[0].volume = 1.0;
   fx_position[0].open_price = 1.10000;
   fx_position[0].current_price = 1.10233;

   double fx_points[1] = {0.0001};
   int fx_digits[1] = {5};
   bool fx_pending[1] = {false};

   AssertTrue(PMResolveTrailingCandidates(fx_position, PM_TRAIL_BASIS_PER_POSITION, "EURUSD", PM_DIRECTION_BOTH,
                                          fx_points, fx_digits, fx_pending, false, true, 0, 0, 10, 10,
                                          result_tickets, result_basis_index,
                                          result_candidates, result_fallback_candidates) == 1 &&
              MathAbs(result_candidates[0] - 1.1010) < 0.00001,
              "Five-digit FX-style trailing candidate snaps to the nearest pip");

   // Four-digit quote: unrecognized digit count keeps point-level precision.
   PMPosition plain_position[];
   ArrayResize(plain_position, 1);
   plain_position[0].ticket = 503;
   plain_position[0].symbol = "OTHERFX";
   plain_position[0].type = POSITION_TYPE_BUY;
   plain_position[0].volume = 1.0;
   plain_position[0].open_price = 1.1200;
   plain_position[0].current_price = 1.1234;

   double plain_points[1] = {0.0001};
   int plain_digits[1] = {4};
   bool plain_pending[1] = {false};

   AssertTrue(PMResolveTrailingCandidates(plain_position, PM_TRAIL_BASIS_PER_POSITION, "OTHERFX", PM_DIRECTION_BOTH,
                                          plain_points, plain_digits, plain_pending, false, true, 0, 0, 10, 5,
                                          result_tickets, result_basis_index,
                                          result_candidates, result_fallback_candidates) == 1 &&
              MathAbs(result_candidates[0] - 1.1229) < 0.00001,
              "Unrecognized digit counts keep the raw point-level trailing candidate");
  }

void TestProfitPoints()
  {
   AssertTrue(MathAbs(PMProfitPoints(1.1000, POSITION_TYPE_BUY, 1.1020, 0.0001) - 20.0) < 0.00001,
              "Buy profit points are calculated consistently");
   AssertTrue(MathAbs(PMProfitPoints(1.1000, POSITION_TYPE_SELL, 1.0980, 0.0001) - 20.0) < 0.00001,
              "Sell profit points are calculated consistently");
   AssertTrue(PMProfitPoints(1.1000, POSITION_TYPE_BUY, 1.1020, 0.0) == 0.0,
              "Profit points are zero when point size is unavailable");
  }

void TestPipConversion()
  {
   AssertTrue(PMPointsPerPip(5) == 10 && PMPointsPerPip(3) == 10,
              "Five-digit and three-digit symbols use ten points per pip");
   AssertTrue(PMPointsPerPip(4) == 1 && PMPointsPerPip(2) == 1,
              "Four-digit and two-digit symbols use one point per pip");
   AssertTrue(PMPipsToPoints(20, 5) == 200 && PMPipsToPoints(20, 3) == 200,
              "Pips convert to points for fractional-pip symbols");
   AssertTrue(PMPipsToPoints(20, 4) == 20 && PMPipsToPoints(20, 2) == 20,
              "Pips remain points for standard-digit symbols");
   AssertTrue(MathAbs(PMPipsToPointDistance(1.5, 5) - 15.0) < 0.00001 &&
              MathAbs(PMPipsToPointDistance(1.5, 4) - 1.5) < 0.00001,
              "Fractional pips convert to point distance");
   AssertTrue(PMPipsToPoints(0, 5) == 0 && PMPipsToPoints(-1, 5) == 0,
              "Non-positive pips remain disabled");
  }

void TestTrailingSnapGranularity()
  {
   AssertTrue(PMTrailingSnapPoints(5) == 10 && PMTrailingSnapPoints(3) == 10,
              "Five-digit and three-digit symbols snap trailing updates to one pip");
   AssertTrue(PMTrailingSnapPoints(2) == 10,
              "Two-digit symbols (e.g. XAUUSD) snap trailing updates to 0.1 price units");
   AssertTrue(PMTrailingSnapPoints(4) == 1 && PMTrailingSnapPoints(1) == 1,
              "Unrecognized digit counts fall back to point-level snapping");

   AssertTrue(MathAbs(PMSnapTrailingCandidate(1.10233, 0.0001, 5) - 1.1020) < 0.00001,
              "Five-digit candidates snap down to the nearest pip");
   AssertTrue(MathAbs(PMSnapTrailingCandidate(4282.33, 0.01, 2) - 4282.30) < 0.00001,
              "Two-digit candidates snap down to the nearest 0.1 price unit");
   AssertTrue(MathAbs(PMSnapTrailingCandidate(1.1234, 0.0001, 4) - 1.1234) < 0.00001,
              "Unrecognized digit counts leave the candidate unchanged");
   AssertTrue(PMSnapTrailingCandidate(1.1030, 0.0, 5) == 1.1030,
              "A non-positive point size leaves the candidate unchanged");
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
   AssertTrue(!PMIsMoreFavorableStop(POSITION_TYPE_BUY, 1.1005, 1.1005),
              "An equal candidate is not more favorable for a Buy (prevents resubmitting every tick)");
   AssertTrue(!PMIsMoreFavorableStop(POSITION_TYPE_SELL, 1.0995, 1.0995),
              "An equal candidate is not more favorable for a Sell (prevents resubmitting every tick)");
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

   AssertTrue(PMBestStopCandidate(POSITION_TYPE_SELL, true, 1.0998, true, 1.1005, best) &&
              MathAbs(best - 1.0998) < 0.00001,
              "Sell: break even wins when it is more favorable (lower) than trailing");
  }

void TestEntryHelpers()
  {
   AssertTrue(MathAbs(PMNormalizeVolume(0.001, 0.01, 1.0, 0.01) - 0.01) < 0.0000001,
              "Entry volume clamps to the symbol minimum");
   AssertTrue(MathAbs(PMNormalizeVolume(0.037, 0.01, 1.0, 0.01) - 0.04) < 0.0000001,
              "Entry volume rounds to the nearest volume step");
   AssertTrue(MathAbs(PMNormalizeVolume(2.0, 0.01, 1.0, 0.01) - 1.0) < 0.0000001,
              "Entry volume clamps to the symbol maximum");
   AssertTrue(MathAbs(PMNormalizeVolume(2.0, 0.01, 1.0, 0.03) - 1.0) < 0.0000001,
              "Entry volume stays aligned when the maximum is on the step grid");
   AssertTrue(MathAbs(PMNormalizeVolume(2.0, 0.01, 0.99, 0.03) - 0.97) < 0.0000001,
              "Entry volume does not return an off-step maximum");
   AssertTrue(MathAbs(PMNormalizePrice(159.520, 0.001, 3) - 159.520) < 0.000001,
              "Price normalization preserves the configured digits");
   AssertTrue(PMIsUnsignedDecimalText("0.01") && PMIsUnsignedDecimalText(".5") &&
              !PMIsUnsignedDecimalText("") && !PMIsUnsignedDecimalText(".") &&
              !PMIsUnsignedDecimalText("1x"),
              "Entry volume text accepts decimals and rejects invalid text");
   AssertTrue(PMIsUnsignedIntegerText("0") && PMIsUnsignedIntegerText("250") &&
              !PMIsUnsignedIntegerText("-1") && !PMIsUnsignedIntegerText("1.5"),
              "Entry point text accepts only non-negative integers");
   AssertTrue(PMIsMarketEntrySuccessRetcode(TRADE_RETCODE_DONE) &&
              PMIsMarketEntrySuccessRetcode(TRADE_RETCODE_DONE_PARTIAL) &&
              PMIsMarketEntrySuccessRetcode(TRADE_RETCODE_PLACED) &&
              !PMIsMarketEntrySuccessRetcode(TRADE_RETCODE_INVALID_VOLUME),
              "Market entry success includes partial fills but excludes failures");

   double sl = 0.0;
   double tp = 0.0;
   string reason = "";
   AssertTrue(PMCalculateEntryStops(PM_ENTRY_BUY, 159.500, 159.503,
                                    0.001, 0.001, 3, 0, 0,
                                    10, 20, sl, tp, reason) &&
              MathAbs(sl - 159.490) < 0.000001 &&
              MathAbs(tp - 159.520) < 0.000001,
              "Buy entry stops use Bid and preserve three price digits");
   AssertTrue(PMCalculateEntryStops(PM_ENTRY_SELL, 159.500, 159.503,
                                    0.001, 0.001, 3, 0, 0,
                                    10, 20, sl, tp, reason) &&
              MathAbs(sl - 159.513) < 0.000001 &&
              MathAbs(tp - 159.483) < 0.000001,
              "Sell entry stops use Ask and preserve three price digits");
   AssertTrue(PMCalculateEntryStops(PM_ENTRY_BUY, 159.500, 159.503,
                                    0.001, 0.001, 3, 0, 0,
                                    0, 0, sl, tp, reason) && sl == 0.0 && tp == 0.0,
              "Zero entry distances disable both protective prices");
   AssertTrue(!PMCalculateEntryStops(PM_ENTRY_BUY, 159.500, 159.503,
                                     0.001, 0.001, 3, 5, 0,
                                     5, 5, sl, tp, reason),
              "Entry stops inside the broker distance are rejected");
   AssertTrue(!PMCalculateEntryStops(PM_ENTRY_BUY, 159.500, 159.503,
                                     0.001, 0.0, 3, 0, 0,
                                     10, 20, sl, tp, reason),
              "Entry stops are rejected when tick size is unavailable");

   string lines[];
   const int line_count = PMWrapStatus("Status: SL clear stopped: trading unavailable (auto trading disabled by client)", 24, lines);
   AssertTrue(line_count > 1 && StringFind(lines[0], "Status:") == 0 &&
              StringLen(lines[line_count - 1]) > 0 &&
              StringLen(lines[0]) <= 24,
              "Long status messages are split into non-empty lines");

   AssertTrue(PMResolveStatusSeverity("Close: 7 succeeded, 0 queued, 0 failed / 7") == PM_STATUS_SUCCESS,
              "Zero failed results are successful");
   AssertTrue(PMResolveStatusSeverity("Close: 7 closed, 1 queued, 0 failed / 8") == PM_STATUS_WARNING,
              "Queued results are waiting status even with zero failures");
   AssertTrue(PMResolveStatusSeverity("Close: 6 succeeded, 0 queued, 1 failed / 7") == PM_STATUS_ERROR,
              "Non-zero failed results are errors");
   AssertTrue(PMResolveStatusSeverity("Close: 0 succeeded, 0 queued, 10 failed / 10") == PM_STATUS_ERROR,
              "Double-digit failed results are not mistaken for zero");
   AssertTrue(PMResolveStatusSeverity("SL update: 1 succeeded, 3 unchanged, 0 queued, 0 failed / 4") == PM_STATUS_SUCCESS,
              "Unchanged stop updates are not errors");
   AssertTrue(PMResolveStatusSeverity("SL clear stopped: trading unavailable") == PM_STATUS_ERROR,
              "Stopped unavailable results are errors");
  }

void TestEntryPricingAndRiskHelpers()
  {
   double entry = 0.0;
   string reason = "";

   // PMCalculateAssumedEntryPrice
   AssertTrue(PMCalculateAssumedEntryPrice(PM_ENTRY_ORDER_MARKET, PM_ENTRY_BUY,
                                           100.0, 100.05, 0.0, entry, reason) &&
              entry == 100.05,
              "Market Buy assumed entry uses Ask");
   AssertTrue(PMCalculateAssumedEntryPrice(PM_ENTRY_ORDER_MARKET, PM_ENTRY_SELL,
                                           100.0, 100.05, 0.0, entry, reason) &&
              entry == 100.0,
              "Market Sell assumed entry uses Bid");
   AssertTrue(PMCalculateAssumedEntryPrice(PM_ENTRY_ORDER_LIMIT, PM_ENTRY_BUY,
                                           100.0, 100.05, 99.5, entry, reason) &&
              entry == 99.5,
              "Buy Limit assumed entry uses the order price");
   AssertTrue(PMCalculateAssumedEntryPrice(PM_ENTRY_ORDER_LIMIT, PM_ENTRY_SELL,
                                           100.0, 100.05, 100.5, entry, reason) &&
              entry == 100.5,
              "Sell Limit assumed entry uses the order price");
   AssertTrue(PMCalculateAssumedEntryPrice(PM_ENTRY_ORDER_STOP, PM_ENTRY_BUY,
                                           100.0, 100.05, 100.5, entry, reason) &&
              entry == 100.5,
              "Buy Stop assumed entry uses the order price");
   AssertTrue(PMCalculateAssumedEntryPrice(PM_ENTRY_ORDER_STOP, PM_ENTRY_SELL,
                                           100.0, 100.05, 99.0, entry, reason) &&
              entry == 99.0,
              "Sell Stop assumed entry uses the order price");
   AssertTrue(!PMCalculateAssumedEntryPrice(PM_ENTRY_ORDER_MARKET, (PMEntrySide)99,
                                            100.0, 100.05, 0.0, entry, reason) &&
              entry == 0.0 && reason == "Direction is invalid.",
              "Invalid direction is rejected before anything else");
   AssertTrue(!PMCalculateAssumedEntryPrice(PM_ENTRY_ORDER_MARKET, PM_ENTRY_BUY,
                                            0.0, 0.0, 0.0, entry, reason) &&
              entry == 0.0 && reason == "Current price is unavailable.",
              "Market order with no tick fails");
   AssertTrue(!PMCalculateAssumedEntryPrice(PM_ENTRY_ORDER_LIMIT, PM_ENTRY_BUY,
                                            100.0, 100.05, 0.0, entry, reason) &&
              entry == 0.0 && reason == "Order price must be greater than zero.",
              "Limit order with a non-positive order price fails");
   AssertTrue(!PMCalculateAssumedEntryPrice(PM_ENTRY_ORDER_STOP, PM_ENTRY_SELL,
                                            100.0, 100.05, -1.0, entry, reason) &&
              entry == 0.0 && reason == "Order price must be greater than zero.",
              "Stop order with a negative order price fails");
   AssertTrue(!PMCalculateAssumedEntryPrice((PMEntryOrderType)99, PM_ENTRY_BUY,
                                            100.0, 100.05, 99.0, entry, reason) &&
              entry == 0.0 && reason == "Order type is invalid.",
              "Unknown order type is rejected");

   // PMIsStopLossOnLossSide
   AssertTrue(PMIsStopLossOnLossSide(PM_ENTRY_BUY, 100.0, 98.0),
              "Buy SL below entry is on the loss side");
   AssertTrue(!PMIsStopLossOnLossSide(PM_ENTRY_BUY, 100.0, 100.0),
              "Buy SL equal to entry is not on the loss side");
   AssertTrue(!PMIsStopLossOnLossSide(PM_ENTRY_BUY, 100.0, 102.0),
              "Buy SL above entry is not on the loss side");
   AssertTrue(PMIsStopLossOnLossSide(PM_ENTRY_SELL, 100.0, 102.0),
              "Sell SL above entry is on the loss side");
   AssertTrue(!PMIsStopLossOnLossSide(PM_ENTRY_SELL, 100.0, 100.0),
              "Sell SL equal to entry is not on the loss side");
   AssertTrue(!PMIsStopLossOnLossSide(PM_ENTRY_SELL, 100.0, 98.0),
              "Sell SL below entry is not on the loss side");
   AssertTrue(!PMIsStopLossOnLossSide((PMEntrySide)99, 100.0, 98.0),
              "An invalid direction is never on the loss side");
   AssertTrue(!PMIsStopLossOnLossSide(PM_ENTRY_BUY, 0.0, 98.0),
              "A non-positive entry price is never on the loss side");

   // PMIsTakeProfitOnProfitSide
   AssertTrue(PMIsTakeProfitOnProfitSide(PM_ENTRY_BUY, 100.0, 102.0),
              "Buy TP above entry is on the profit side");
   AssertTrue(!PMIsTakeProfitOnProfitSide(PM_ENTRY_BUY, 100.0, 100.0),
              "Buy TP equal to entry is not on the profit side");
   AssertTrue(!PMIsTakeProfitOnProfitSide(PM_ENTRY_BUY, 100.0, 98.0),
              "Buy TP below entry is not on the profit side");
   AssertTrue(PMIsTakeProfitOnProfitSide(PM_ENTRY_SELL, 100.0, 98.0),
              "Sell TP below entry is on the profit side");
   AssertTrue(!PMIsTakeProfitOnProfitSide(PM_ENTRY_SELL, 100.0, 100.0),
              "Sell TP equal to entry is not on the profit side");
   AssertTrue(!PMIsTakeProfitOnProfitSide(PM_ENTRY_SELL, 100.0, 102.0),
              "Sell TP above entry is not on the profit side");
   AssertTrue(!PMIsTakeProfitOnProfitSide((PMEntrySide)99, 100.0, 102.0),
              "An invalid direction is never on the profit side");

   // PMCalculateCurrentRR
   double rr = 0.0;
   AssertTrue(PMCalculateCurrentRR(PM_ENTRY_BUY, 100.0, 98.0, 102.0, rr, reason) == PM_RR_VALID &&
              MathAbs(rr - 1.0) < 0.0000001,
              "Buy RR of 1:1 matches acceptance criteria #4");
   AssertTrue(PMCalculateCurrentRR(PM_ENTRY_BUY, 100.0, 98.0, 104.0, rr, reason) == PM_RR_VALID &&
              MathAbs(rr - 2.0) < 0.0000001,
              "Buy RR of 1:2 matches acceptance criteria #4");
   AssertTrue(PMCalculateCurrentRR(PM_ENTRY_SELL, 100.0, 102.0, 98.0, rr, reason) == PM_RR_VALID &&
              MathAbs(rr - 1.0) < 0.0000001,
              "Sell RR of 1:1 matches acceptance criteria #4");
   AssertTrue(PMCalculateCurrentRR(PM_ENTRY_SELL, 100.0, 102.0, 96.0, rr, reason) == PM_RR_VALID &&
              MathAbs(rr - 2.0) < 0.0000001,
              "Sell RR of 1:2 matches acceptance criteria #4");
   AssertTrue(PMCalculateCurrentRR(PM_ENTRY_BUY, 100.0, 0.0, 102.0, rr, reason) == PM_RR_NOT_AVAILABLE &&
              rr == 0.0,
              "RR is not available without an SL");
   AssertTrue(PMCalculateCurrentRR(PM_ENTRY_BUY, 100.0, 98.0, 0.0, rr, reason) == PM_RR_NOT_AVAILABLE &&
              rr == 0.0,
              "RR is not available without a TP");
   AssertTrue(PMCalculateCurrentRR(PM_ENTRY_BUY, 100.0, 102.0, 104.0, rr, reason) == PM_RR_INVALID &&
              rr == 0.0,
              "RR is invalid when the SL is on the wrong side");
   AssertTrue(PMCalculateCurrentRR(PM_ENTRY_BUY, 100.0, 98.0, 96.0, rr, reason) == PM_RR_INVALID &&
              rr == 0.0,
              "RR is invalid when the TP is on the wrong side");
   AssertTrue(PMCalculateCurrentRR(PM_ENTRY_BUY, 100.0, 100.0, 102.0, rr, reason) == PM_RR_INVALID &&
              rr == 0.0,
              "RR is invalid, not a div-by-zero crash, when SL equals entry");
   AssertTrue(PMCalculateCurrentRR((PMEntrySide)99, 100.0, 98.0, 102.0, rr, reason) == PM_RR_INVALID,
              "RR is invalid when the direction is invalid");

   // PMCalculateAutoTakeProfit
   double tp = 0.0;
   AssertTrue(PMCalculateAutoTakeProfit(PM_ENTRY_BUY, 100.0, 98.0, 1.0,
                                        0.01, 0.01, 2, 0, 0, tp, reason) &&
              MathAbs(tp - 102.0) < 0.0000001,
              "Buy auto TP at RR 1:1 matches acceptance criteria #4 (entry 100, SL 98 -> TP 102)");
   AssertTrue(PMCalculateAutoTakeProfit(PM_ENTRY_BUY, 100.0, 98.0, 2.0,
                                        0.01, 0.01, 2, 0, 0, tp, reason) &&
              MathAbs(tp - 104.0) < 0.0000001,
              "Buy auto TP at RR 1:2 matches acceptance criteria #4 (entry 100, SL 98 -> TP 104)");
   AssertTrue(PMCalculateAutoTakeProfit(PM_ENTRY_SELL, 100.0, 102.0, 1.0,
                                        0.01, 0.01, 2, 0, 0, tp, reason) &&
              MathAbs(tp - 98.0) < 0.0000001,
              "Sell auto TP at RR 1:1 matches acceptance criteria #4 (entry 100, SL 102 -> TP 98)");
   AssertTrue(PMCalculateAutoTakeProfit(PM_ENTRY_SELL, 100.0, 102.0, 2.0,
                                        0.01, 0.01, 2, 0, 0, tp, reason) &&
              MathAbs(tp - 96.0) < 0.0000001,
              "Sell auto TP at RR 1:2 matches acceptance criteria #4 (entry 100, SL 102 -> TP 96)");
   AssertTrue(!PMCalculateAutoTakeProfit(PM_ENTRY_BUY, 100.0, 0.0, 1.0,
                                         0.01, 0.01, 2, 0, 0, tp, reason) &&
              tp == 0.0,
              "Auto TP fails without a valid SL");
   AssertTrue(!PMCalculateAutoTakeProfit(PM_ENTRY_BUY, 100.0, 102.0, 1.0,
                                         0.01, 0.01, 2, 0, 0, tp, reason) &&
              tp == 0.0,
              "Auto TP fails when the SL is on the wrong side");
   AssertTrue(!PMCalculateAutoTakeProfit(PM_ENTRY_BUY, 100.0, 98.0, 0.0,
                                         0.01, 0.01, 2, 0, 0, tp, reason) &&
              tp == 0.0,
              "Auto TP fails for a non-positive RR multiplier");
   AssertTrue(!PMCalculateAutoTakeProfit(PM_ENTRY_BUY, 100.0, 98.0, -1.0,
                                         0.01, 0.01, 2, 0, 0, tp, reason) &&
              tp == 0.0,
              "Auto TP fails for a negative RR multiplier");
   AssertTrue(!PMCalculateAutoTakeProfit(PM_ENTRY_BUY, 100.0, 98.0, 1.0,
                                         0.01, 0.01, 2, 1000, 0, tp, reason) &&
              tp == 0.0 && reason == "Buy TP is inside the broker's Stops/Freeze Level.",
              "Buy auto TP fails when the Stops/Freeze Level swallows the candidate");
   AssertTrue(!PMCalculateAutoTakeProfit(PM_ENTRY_SELL, 100.0, 102.0, 1.0,
                                         0.01, 0.01, 2, 1000, 0, tp, reason) &&
              tp == 0.0 && reason == "Sell TP is inside the broker's Stops/Freeze Level.",
              "Sell auto TP fails when the Stops/Freeze Level swallows the candidate");

   // PMNextTakeProfitState -- one assertion per transition-table row
   PMTpState next_state = PM_TP_STATE_AUTO;
   AssertTrue(PMNextTakeProfitState(PM_TP_STATE_AUTO, PM_TP_EVENT_SL_CHANGED, true, next_state, reason) &&
              next_state == PM_TP_STATE_AUTO,
              "SL changed leaves Auto state unchanged");
   AssertTrue(PMNextTakeProfitState(PM_TP_STATE_MANUAL, PM_TP_EVENT_SL_CHANGED, true, next_state, reason) &&
              next_state == PM_TP_STATE_MANUAL,
              "SL changed leaves Manual state unchanged");
   AssertTrue(PMNextTakeProfitState(PM_TP_STATE_AUTO, PM_TP_EVENT_SL_CANCELED, false, next_state, reason) &&
              next_state == PM_TP_STATE_MANUAL,
              "SL canceled moves Auto to Manual so the caller freezes the TP price");
   AssertTrue(PMNextTakeProfitState(PM_TP_STATE_MANUAL, PM_TP_EVENT_SL_CANCELED, false, next_state, reason) &&
              next_state == PM_TP_STATE_MANUAL,
              "SL canceled leaves Manual state unchanged");
   AssertTrue(PMNextTakeProfitState(PM_TP_STATE_OFF, PM_TP_EVENT_SL_CANCELED, false, next_state, reason) &&
              next_state == PM_TP_STATE_OFF,
              "SL canceled leaves Off state unchanged");
   AssertTrue(PMNextTakeProfitState(PM_TP_STATE_OFF, PM_TP_EVENT_TP_SET_MANUAL, true, next_state, reason) &&
              next_state == PM_TP_STATE_MANUAL,
              "Setting TP manually always moves to Manual regardless of prior state");
   AssertTrue(PMNextTakeProfitState(PM_TP_STATE_AUTO, PM_TP_EVENT_TP_CANCELED, true, next_state, reason) &&
              next_state == PM_TP_STATE_OFF,
              "Canceling TP always moves to Off");
   AssertTrue(PMNextTakeProfitState(PM_TP_STATE_MANUAL, PM_TP_EVENT_RR_CHANGED, true, next_state, reason) &&
              next_state == PM_TP_STATE_MANUAL,
              "RR changed leaves Manual state unchanged");
   AssertTrue(PMNextTakeProfitState(PM_TP_STATE_AUTO, PM_TP_EVENT_RR_CHANGED, true, next_state, reason) &&
              next_state == PM_TP_STATE_AUTO,
              "RR changed leaves Auto state unchanged");
   AssertTrue(PMNextTakeProfitState(PM_TP_STATE_MANUAL, PM_TP_EVENT_REVERT_TO_AUTO, true, next_state, reason) &&
              next_state == PM_TP_STATE_AUTO,
              "Revert to auto succeeds with a valid SL");
   AssertTrue(!PMNextTakeProfitState(PM_TP_STATE_MANUAL, PM_TP_EVENT_REVERT_TO_AUTO, false, next_state, reason) &&
              next_state == PM_TP_STATE_MANUAL &&
              reason == "Set a valid SL before reverting to automatic Take Profit.",
              "Revert to auto fails without a valid SL and leaves state unchanged");
   AssertTrue(!PMNextTakeProfitState(PM_TP_STATE_AUTO, (PMTpEvent)99, true, next_state, reason) &&
              next_state == PM_TP_STATE_AUTO && reason == "Unknown Take Profit event.",
              "An unknown event is rejected and leaves state unchanged");

   // PMCalculateRiskBudget
   double budget = 0.0;
   AssertTrue(PMCalculateRiskBudget(PM_QUANTITY_RISK_AMOUNT, 100.0, 0.0, 0.0, budget, reason) &&
              MathAbs(budget - 100.0) < 0.0000001,
              "Risk amount mode uses the manual amount directly");
   AssertTrue(PMCalculateRiskBudget(PM_QUANTITY_RISK_PERCENT, 0.0, 10000.0, 1.0, budget, reason) &&
              MathAbs(budget - 100.0) < 0.0000001,
              "Risk percent mode (balance 10000, 1%) equals risk amount 100 (acceptance criteria #8)");
   AssertTrue(!PMCalculateRiskBudget(PM_QUANTITY_RISK_AMOUNT, 0.0, 0.0, 0.0, budget, reason) &&
              budget == 0.0,
              "A risk amount of zero fails");
   AssertTrue(!PMCalculateRiskBudget(PM_QUANTITY_RISK_AMOUNT, -1.0, 0.0, 0.0, budget, reason) &&
              budget == 0.0,
              "A negative risk amount fails");
   AssertTrue(!PMCalculateRiskBudget(PM_QUANTITY_RISK_PERCENT, 0.0, 0.0, 1.0, budget, reason) &&
              budget == 0.0,
              "A non-positive balance fails");
   AssertTrue(!PMCalculateRiskBudget(PM_QUANTITY_RISK_PERCENT, 0.0, 10000.0, 0.0, budget, reason) &&
              budget == 0.0,
              "A non-positive percent fails");
   AssertTrue(!PMCalculateRiskBudget(PM_QUANTITY_RISK_PERCENT, 0.0, 10000.0, 100.1, budget, reason) &&
              budget == 0.0,
              "A percent above 100 fails");
   AssertTrue(!PMCalculateRiskBudget(PM_QUANTITY_MANUAL_LOT, 100.0, 10000.0, 1.0, budget, reason) &&
              budget == 0.0,
              "Manual Lot mode never produces a risk budget");

   // PMCalculateRiskLot
   double lot = 0.0;
   double estimated_loss = 0.0;
   AssertTrue(PMCalculateRiskLot(100.0, 1.0, 250.0, 0.01, 100.0, 0.01, lot, estimated_loss, reason) &&
              MathAbs(lot - 0.40) < 0.0000001,
              "Risk lot for budget 100 / reference loss 250 is 0.40 (acceptance criteria #8)");
   AssertTrue(PMCalculateRiskLot(3.7, 1.0, 100.0, 0.01, 100.0, 0.01, lot, estimated_loss, reason) &&
              MathAbs(lot - 0.03) < 0.0000001,
              "Raw lot 0.037 floors down to 0.03, not up to 0.04 (acceptance criteria #9)");
   AssertTrue(!PMCalculateRiskLot(0.05, 1.0, 100.0, 0.01, 100.0, 0.01, lot, estimated_loss, reason) &&
              lot == 0.0 && estimated_loss == 0.0,
              "A raw lot below the symbol minimum fails and does not round up");
   AssertTrue(PMCalculateRiskLot(50.0, 1.0, 100.0, 0.01, 0.30, 0.01, lot, estimated_loss, reason) &&
              MathAbs(lot - 0.30) < 0.0000001 && MathAbs(estimated_loss - 30.0) < 0.0000001,
              "A raw lot above the symbol maximum clips to the step-aligned maximum and recomputes the loss");
   AssertTrue(!PMCalculateRiskLot(0.0, 1.0, 250.0, 0.01, 100.0, 0.01, lot, estimated_loss, reason),
              "A non-positive budget fails");
   AssertTrue(!PMCalculateRiskLot(-1.0, 1.0, 250.0, 0.01, 100.0, 0.01, lot, estimated_loss, reason),
              "A negative budget fails");
   AssertTrue(!PMCalculateRiskLot(100.0, 0.0, 250.0, 0.01, 100.0, 0.01, lot, estimated_loss, reason),
              "A non-positive reference volume fails");
   AssertTrue(!PMCalculateRiskLot(100.0, 1.0, 0.0, 0.01, 100.0, 0.01, lot, estimated_loss, reason),
              "A non-positive reference loss fails");
   AssertTrue(!PMCalculateRiskLot(100.0, 1.0, 250.0, 0.0, 100.0, 0.01, lot, estimated_loss, reason),
              "A non-positive volume minimum fails");
   AssertTrue(!PMCalculateRiskLot(100.0, 1.0, 250.0, 0.5, 0.1, 0.01, lot, estimated_loss, reason),
              "A volume maximum below the minimum fails");
   AssertTrue(!PMCalculateRiskLot(100.0, 1.0, 250.0, 0.01, 100.0, 0.0, lot, estimated_loss, reason),
              "A non-positive volume step fails");

   // Non-finite inputs (NaN / Infinity) must fail the same as non-positive
   // ones. A literal "1.0 / 0.0" is a compile-time constant division in
   // MQL5, so route the zero through a variable to force a runtime IEEE-754
   // division instead (MathIsValidNumber() exists precisely because this is
   // a real, reachable value -- not a crash -- for both double division and
   // MQL5's own float arithmetic).
   double zero_divisor = 0.0;
   double not_a_number = 0.0 / zero_divisor;
   double positive_infinity = 1.0 / zero_divisor;
   AssertTrue(!PMCalculateRiskLot(not_a_number, 1.0, 250.0, 0.01, 100.0, 0.01, lot, estimated_loss, reason) &&
              lot == 0.0 && estimated_loss == 0.0,
              "A non-finite budget (NaN) fails");
   AssertTrue(!PMCalculateRiskLot(positive_infinity, 1.0, 250.0, 0.01, 100.0, 0.01, lot, estimated_loss, reason) &&
              lot == 0.0 && estimated_loss == 0.0,
              "A non-finite budget (Infinity) fails");
   AssertTrue(!PMCalculateRiskLot(100.0, not_a_number, 250.0, 0.01, 100.0, 0.01, lot, estimated_loss, reason) &&
              lot == 0.0 && estimated_loss == 0.0,
              "A non-finite reference volume (NaN) fails");
   AssertTrue(!PMCalculateRiskLot(100.0, 1.0, not_a_number, 0.01, 100.0, 0.01, lot, estimated_loss, reason) &&
              lot == 0.0 && estimated_loss == 0.0,
              "A non-finite reference loss (NaN) fails");
   AssertTrue(!PMCalculateRiskLot(100.0, 1.0, 250.0, not_a_number, 100.0, 0.01, lot, estimated_loss, reason) &&
              lot == 0.0 && estimated_loss == 0.0,
              "A non-finite volume minimum (NaN) fails");
   AssertTrue(!PMCalculateRiskLot(100.0, 1.0, 250.0, 0.01, not_a_number, 0.01, lot, estimated_loss, reason) &&
              lot == 0.0 && estimated_loss == 0.0,
              "A non-finite volume maximum (NaN) fails");
   AssertTrue(!PMCalculateRiskLot(100.0, 1.0, 250.0, 0.01, 100.0, not_a_number, lot, estimated_loss, reason) &&
              lot == 0.0 && estimated_loss == 0.0,
              "A non-finite volume step (NaN) fails");
  }

void TestPanelLayoutHelpers()
  {
   AssertTrue(PM_PANEL_POSITIONS_HEADER_HEIGHT >= 52,
              "Position rows start below both header button rows");
   AssertTrue(PM_MIN_PANEL_WIDTH >= PM_STOPS_SET_BUTTON_X +
              PM_STOPS_SET_BUTTON_WIDTH + PM_STOPS_BUTTON_GAP +
              PM_STOPS_CLEAR_BUTTON_WIDTH,
              "Minimum panel width keeps Set and Clear on one line");
   AssertTrue(PM_MIN_PANEL_WIDTH >= PM_TRAIL_TOGGLE_X + PM_TRAIL_BASIS_TOGGLE_WIDTH,
              "Minimum panel width fits the Basis toggle on its own row");
   AssertTrue(PM_MIN_PANEL_WIDTH - 12 >= PM_TRAIL_INPUT2_X + PM_TRAIL_INPUT_WIDTH + 34 + 26 &&
              PM_TRAIL_INPUT1_X + PM_TRAIL_INPUT_WIDTH + 34 + 26 + 10 <= PM_TRAIL_LABEL2_X,
              "Trail numeric groups preserve inner padding and leave room for the next label");
   AssertTrue(PM_TRAIL_BE_ROW_Y >= PM_TRAIL_BASIS_ROW_Y + 22 + 6 &&
              PM_TRAIL_ROW_Y >= PM_TRAIL_BE_ROW_Y + 22 + 6 &&
              PM_TRAIL_HINT_ROW_Y >= PM_TRAIL_ROW_Y + 22 + 10 &&
              PM_PANEL_TRAIL_HEIGHT >= PM_TRAIL_HINT_ROW_Y + 20,
              "Compact Trail rows and hint fit before the status block without overlap");
   AssertTrue(PMResolvePanelHeight(320, 500) == 500,
              "A taller user-requested panel height is preserved");
   AssertTrue(PMResolvePanelHeight(500, 320) == 500,
              "Panel height never shrinks below required content");
  }

void TestInputStepperHelpers()
  {
   AssertTrue(PMStepInteger(0, -1, 0, 1440) == 0,
              "Integer stepper clamps at its minimum");
   AssertTrue(PMStepInteger(1439, 1, 0, 1440) == 1440,
              "Integer stepper reaches its maximum");
   AssertTrue(PMStepInteger(2147483647, 1, 0, 2147483647) == 2147483647,
              "Integer stepper does not overflow before clamping");
   AssertTrue(MathAbs(PMStepDecimal(0.0, 0.1, 0.0, 100.0, 2) - 0.1) < 0.000001,
              "Decimal stepper supports percent-sized increments");
   AssertTrue(MathAbs(PMStepDecimal(100.0, 1.0, 0.0, 100.0, 2) - 100.0) < 0.000001,
              "Decimal stepper clamps at its maximum");
   double value = 0.0;
   for(int i = 0; i < 1000; i++) value = PMStepDecimal(value, 0.1, 0.0, 100.0, 2);
   AssertTrue(value == 100.0, "Repeated decimal steps reach the exact limit");
   AssertTrue(PMStepDecimal(0.05, -0.1, 0.0, 100.0, 2) == 0.0,
              "Decimal subtraction cannot make a threshold negative");
  }

void TestPriceEditorHelpers()
  {
   AssertTrue(MathAbs(PMPriceEditorStep(0.001, 0.01, 3) - 0.01) < 0.0000001,
              "Price editor uses one pip for three-digit symbols");
   AssertTrue(MathAbs(PMPriceEditorStep(0.00001, 0.00001, 5) - 0.0001) < 0.0000001,
              "Price editor uses one pip for five-digit symbols");
   AssertTrue(MathAbs(PMShiftPriceEditorValue(159.900, 0.001, 0.01, 1, 3) - 159.910) < 0.0000001,
              "Price editor increases USDJPY by one pip");
   AssertTrue(MathAbs(PMShiftPriceEditorValue(159.900, 0.001, 0.01, -1, 3) - 159.890) < 0.0000001,
              "Price editor decreases USDJPY by one pip");
   AssertTrue(PMShiftPriceEditorValue(10.0, 0.01, 0.25, 1, 2) == 10.25,
              "Increase advances one tick when a tick exceeds a pip");
   AssertTrue(PMShiftPriceEditorValue(10.0, 0.01, 0.25, -1, 2) == 9.75,
              "Decrease advances one tick when a tick exceeds a pip");
   AssertTrue(PMShiftPriceEditorValue(10.12, 0.01, 0.25, 1, 2) == 10.25,
              "Off-grid increase rounds in the requested direction");
   AssertTrue(PMShiftPriceEditorValue(10.12, 0.01, 0.25, -1, 2) == 10.0,
              "Off-grid decrease rounds in the requested direction");
   AssertTrue(PMShiftPriceEditorValue(0.25, 0.01, 0.25, -1, 2) == 0.25,
              "Price cannot step below the smallest positive tick");
  }

void TestPriceDragLifecycle()
  {
   CPriceEditDrag drag;
   int index = 7;
   double price = 7.0;
   AssertTrue(!drag.Finish("ticket:1", index, price) && index == -1 && price == 0.0,
              "An unsolicited drag completion cannot write an editor");
   drag.Begin(0, "ticket:1", 100.0);
   drag.Move(101.25);
   drag.Move(-1.0);
   AssertTrue(drag.Matches("ticket:1") && drag.Price() == 101.25,
              "An invalid mouse price preserves the last valid draft");
   AssertTrue(drag.Finish("ticket:1", index, price) && index == 0 && price == 101.25,
              "Matching completion returns the exact SL draft");
   AssertTrue(!drag.Finish("ticket:1", index, price),
              "Duplicate completion cannot apply a draft twice");
   drag.Begin(1, "ticket:1:volume:1", 100.0);
   drag.Move(102.0);
   AssertTrue(!drag.Finish("ticket:1:volume:2", index, price) && index == -1 && price == 0.0,
              "Netting volume changes invalidate the old drag even on the same ticket");
   drag.Begin(1, "ticket:1", 100.0);
   drag.Cancel();
   AssertTrue(!drag.Finish("ticket:1", index, price),
              "A cancelled drag cannot update a hidden or changed form");
   drag.Begin(2, "ticket:1", 100.0);
   AssertTrue(drag.Index() == -1, "Unknown price editors cannot acquire a drag");
   drag.Begin(0, "ticket:1", 0.0);
   AssertTrue(drag.Index() == -1, "A nonpositive price cannot acquire a drag");
  }

void TestPriceEstimateAggregation()
  {
   CPriceEditEstimate estimate;
   AssertTrue(!estimate.HasBuy() && !estimate.HasSell(),
              "Empty selections do not display a direction average");
   estimate.Add(true, 1.0, 100.0, true, 10.0);
   estimate.Add(true, 3.0, 200.0, true, 60.0);
   estimate.Add(false, 2.0, -300.0, true, -60.0);
   AssertTrue(estimate.BuyPoints() == 175.0 && estimate.SellPoints() == -300.0,
              "Mixed-side points use separate volume-weighted averages");
   AssertTrue(estimate.MoneyKnown() && estimate.Money() == 10.0,
              "Monetary estimates sum all selected tickets including losses");
   estimate.Add(false, 2.0, -100.0, false, 0.0);
   AssertTrue(!estimate.MoneyKnown() && estimate.SellPoints() == -200.0,
              "One failed monetary calculation keeps points but invalidates the total");
   estimate.Add(true, 1.0, 175.0, true, 20.0);
   AssertTrue(!estimate.MoneyKnown(),
              "A later successful calculation cannot restore an incomplete monetary total");
  }

void TestPriceLabelPlacement()
  {
   int sl_x = 0, sl_y = 0, tp_x = 0, tp_y = 0;
   AssertTrue(PMPlacePriceLabel(1000, 700, 300, 240, 72, 0, 0, 560, 500,
                              0, 0, 0, 0, sl_x, sl_y) &&
              !PMRectOverlaps(sl_x, sl_y, 240, 72, 0, 0, 560, 500),
              "Price labels leave the minimum-width panel unobscured");
   AssertTrue(PMPlacePriceLabel(1000, 700, 300, 240, 72, 0, 0, 560, 500,
                              sl_x, sl_y, 240, 76, tp_x, tp_y) &&
              !PMRectOverlaps(sl_x, sl_y, 240, 72, tp_x, tp_y, 240, 72),
              "SL and TP labels at the same price remain individually accessible");
   AssertTrue(tp_x >= 8 && tp_y >= 8 && tp_x + 240 <= 992 && tp_y + 72 <= 692,
              "Repositioned labels stay within chart margins");
   AssertTrue(PMPlacePriceLabel(1000, 700, 0, 240, 72, 0, 0, 0, 0,
                              0, 0, 0, 0, sl_x, sl_y) && sl_y == 8,
              "Top-edge prices retain readable labels");
   AssertTrue(PMPlacePriceLabel(1000, 700, 700, 240, 72, 0, 0, 0, 0,
                              0, 0, 0, 0, sl_x, sl_y) && sl_y + 72 <= 692,
              "Bottom-edge prices retain readable labels");
   AssertTrue(!PMPlacePriceLabel(200, 700, 300, 240, 72, 0, 0, 0, 0,
                               0, 0, 0, 0, sl_x, sl_y),
              "Oversized labels are reported unavailable instead of clipped");
   AssertTrue(!PMPlacePriceLabel(600, 400, 300, 240, 72, 0, 0, 600, 400,
                               0, 0, 0, 0, sl_x, sl_y),
              "A panel covering the chart cannot be covered by a label");
  }

void TestEquityLineCalculation()
  {
   PMPosition positions[];
   ArrayResize(positions, 3);
   positions[0].symbol = "USDJPY";
   positions[0].type = POSITION_TYPE_BUY;
   positions[0].volume = 1.0;
   positions[0].open_price = 100.0;
   positions[1].symbol = "USDJPY";
   positions[1].type = POSITION_TYPE_BUY;
   positions[1].volume = 2.0;
   positions[1].open_price = 110.0;
   positions[2].symbol = "EURUSD";
   positions[2].type = POSITION_TYPE_BUY;
   positions[2].volume = 10.0;
   positions[2].open_price = 1.1;

   double price = 0.0;
   AssertTrue(PMCalculateEquityLinePrice(positions, "USDJPY", price) &&
              MathAbs(price - 106.66666667) < 0.00000001,
              "Equity line uses the volume-weighted break-even price for the chart symbol");

   ArrayResize(positions, 2);
   positions[0].type = POSITION_TYPE_BUY;
   positions[0].volume = 2.0;
   positions[0].open_price = 100.0;
   positions[1].type = POSITION_TYPE_SELL;
   positions[1].volume = 1.0;
   positions[1].open_price = 110.0;
   AssertTrue(PMCalculateEquityLinePrice(positions, "USDJPY", price) &&
              MathAbs(price - 90.0) < 0.00000001,
              "Equity line accounts for mixed Buy and Sell positions");

   positions[1].volume = 2.0;
   AssertTrue(!PMCalculateEquityLinePrice(positions, "USDJPY", price) &&
              price == 0.0,
              "Equity line is unavailable when net volume is zero");
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
   TestPositionBasket();
   TestTrailBasisToggle();
   TestResolveTrailingCandidatesBasisSelection();
   TestResolveTrailingCandidatesSharedCandidate();
   TestResolveTrailingCandidatesPendingExclusion();
   TestResolveTrailingCandidatesSellAndScope();
   TestProfitPoints();
   TestPipConversion();
   TestIsMoreFavorableStop();
   TestBestStopCandidate();
   TestEntryHelpers();
   TestEntryPricingAndRiskHelpers();
   TestPanelLayoutHelpers();
   TestInputStepperHelpers();
   TestPriceEditorHelpers();
   TestPriceDragLifecycle();
   TestPriceEstimateAggregation();
   TestPriceLabelPlacement();
   TestEquityLineCalculation();
   if(g_failures == 0)
      Print("[PASS] All Position Manager pure tests passed.");
   else
      PrintFormat("[FAIL] %d Position Manager pure tests failed.", g_failures);
  }
