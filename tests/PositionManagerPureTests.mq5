#property strict
#property script_show_inputs

#include "..\src\Models.mqh"
#include "..\src\Constants.mqh"
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

void TestPanelLayoutHelpers()
  {
   AssertTrue(PM_PANEL_POSITIONS_HEADER_HEIGHT >= 52,
              "Position rows start below both header button rows");
   AssertTrue(PM_MIN_PANEL_WIDTH >= PM_STOPS_SET_BUTTON_X +
              PM_STOPS_SET_BUTTON_WIDTH + PM_STOPS_BUTTON_GAP +
              PM_STOPS_CLEAR_BUTTON_WIDTH,
              "Minimum panel width keeps Set and Clear on one line");
   AssertTrue(PMResolvePanelHeight(320, 500) == 500,
              "A taller user-requested panel height is preserved");
   AssertTrue(PMResolvePanelHeight(500, 320) == 500,
              "Panel height never shrinks below required content");
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
   TestProfitPoints();
   TestPipConversion();
   TestIsMoreFavorableStop();
   TestBestStopCandidate();
   TestEntryHelpers();
   TestPanelLayoutHelpers();
   TestPriceEditorHelpers();
   TestEquityLineCalculation();
   if(g_failures == 0)
      Print("[PASS] All Position Manager pure tests passed.");
   else
      PrintFormat("[FAIL] %d Position Manager pure tests failed.", g_failures);
  }
