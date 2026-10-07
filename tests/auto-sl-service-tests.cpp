// Included after the production Auto SL service by run-trailing-stop-tests.py.
// The service itself is not reimplemented here; only terminal boundaries
// are simulated by the runner.
std::vector<PMPosition> AutoSlPositions()
{
    // ticket, symbol, type, volume, open, current, sl, tp, profit, open_time
    return {{301, "USDJPY", POSITION_TYPE_BUY, 0.1, 150.000, 150.100, 0, 151.000, 0, 1000},
            {302, "USDJPY", POSITION_TYPE_SELL, 0.1, 150.000, 149.900, 0, 0, 0, 1500},
            {303, "USDJPY", POSITION_TYPE_BUY, 0.1, 150.000, 150.100, 0, 0, 0, 999},
            {304, "USDJPY", POSITION_TYPE_BUY, 0.1, 150.000, 150.100, 149.500, 0, 0, 2000},
            {305, "EURUSD", POSITION_TYPE_BUY, 0.1, 1.1000, 1.1010, 0, 0, 0, 2000}};
}

AutoSlConfig AutoSlServiceConfig()
{
    return {true, "USDJPY", 100.0, 1000};
}

void TestAutoSlServiceProtectsNewPositions()
{
    CAutoSlService service;
    CPositionService positions;
    positions.live = AutoSlPositions();
    CTradeManager trades;
    CValidationService validator;
    string status;
    AssertTrue(service.Evaluate(AutoSlServiceConfig(), 2000, positions.live, positions, trades, validator, status),
               "Auto SL reports the positions it protected");
    AssertTrue(trades.sent == std::vector<ulong>({301, 302}),
               "Only chart-symbol positions opened since ON without an SL receive Auto SL");
    AssertTrue(trades.stops.size() == 2 && MathAbs(trades.stops[0] - 149.000) < 1e-9 &&
               MathAbs(trades.stops[1] - 151.000) < 1e-9, "Each Auto SL is measured from its own entry price");
    AssertTrue(trades.take_profits == std::vector<double>({151.000, 0.0}), "Each ticket keeps its TP");

    AutoSlConfig off = AutoSlServiceConfig();
    off.enabled = false;
    AutoSlConfig zero = AutoSlServiceConfig();
    zero.pips = 0.0;
    AutoSlConfig unknown = AutoSlServiceConfig();
    unknown.enabled_at = 0;
    for (const AutoSlConfig& config : {off, zero, unknown}) {
        CAutoSlService idle;
        CTradeManager untouched;
        CValidationService unused;
        AssertTrue(!idle.Evaluate(config, 2000, positions.live, positions, untouched, unused, status) &&
                   untouched.sent.empty() && unused.calls == 0,
                   "OFF, 0 pips or an unknown ON time sends nothing");
    }
}

void TestAutoSlServiceUsesLatestState()
{
    CAutoSlService service;
    auto snapshot = AutoSlPositions();
    CPositionService positions;
    positions.live = snapshot;
    positions.live[0].sl = 149.800;
    positions.live[1].tp = 148.000;
    CTradeManager trades;
    CValidationService validator;
    string status;
    service.Evaluate(AutoSlServiceConfig(), 2000, snapshot, positions, trades, validator, status);
    AssertTrue(trades.sent == std::vector<ulong>({302}) && trades.take_profits[0] == 148.000,
               "An SL set after the snapshot is never overwritten and the latest TP is kept");

    CAutoSlService pending_service;
    CTradeManager pending;
    pending.pending = {301};
    positions.live = snapshot;
    pending_service.Evaluate(AutoSlServiceConfig(), 2000, snapshot, positions, pending, validator, status);
    AssertTrue(pending.sent == std::vector<ulong>({302}), "A ticket with a queued trade is left to its retry");

    CAutoSlService closed_service;
    CTradeManager closed;
    positions.live.clear();
    closed_service.Evaluate(AutoSlServiceConfig(), 2000, snapshot, positions, closed, validator, status);
    AssertTrue(closed.sent.empty(), "A position that disappeared receives no modification");
}

void TestAutoSlServiceWaitsAfterRejection()
{
    std::vector<PMPosition> one = {AutoSlPositions()[0]};
    CPositionService positions;
    positions.live = one;

    CAutoSlService rejected_service;
    CTradeManager trades;
    CValidationService validator;
    validator.responses = {false, true};
    string status;
    AssertTrue(rejected_service.Evaluate(AutoSlServiceConfig(), 2000, one, positions, trades, validator, status) &&
               trades.sent.empty() && validator.calls == 1,
               "A stop the broker would reject is reported and not sent");
    AssertTrue(!rejected_service.Evaluate(AutoSlServiceConfig(), 2001, one, positions, trades, validator, status) &&
               validator.calls == 1, "A rejected ticket is not retried every second");
    rejected_service.Evaluate(AutoSlServiceConfig(), 2000 + PM_AUTO_SL_RETRY_SECONDS, one, positions, trades,
                              validator, status);
    AssertTrue(validator.calls == 2 && trades.sent == std::vector<ulong>({301}),
               "A rejected ticket is retried once the wait has passed");

    CAutoSlService failed_service;
    CTradeManager failing;
    failing.result = PM_TRADE_ATTEMPT_FAILED;
    CValidationService accepting;
    failed_service.Evaluate(AutoSlServiceConfig(), 2000, one, positions, failing, accepting, status);
    failed_service.Evaluate(AutoSlServiceConfig(), 2001, one, positions, failing, accepting, status);
    AssertTrue(failing.sent == std::vector<ulong>({301}), "A failed modification is not resent every second");
    failed_service.Evaluate(AutoSlServiceConfig(), 2000 + PM_AUTO_SL_RETRY_SECONDS, one, positions, failing,
                            accepting, status);
    AssertTrue(failing.sent == std::vector<ulong>({301, 301}), "A failed modification is retried after the wait");
}
