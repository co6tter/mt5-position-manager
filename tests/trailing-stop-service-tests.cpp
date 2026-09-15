// Included after the production service by run-trailing-stop-tests.py.
// The service itself is not reimplemented here; only terminal boundaries
// are simulated by the runner.
std::vector<PMPosition> ServicePositions()
{
    return {{201, "EURUSD", POSITION_TYPE_BUY, 1, 1.1000, 1.1040, 0, 1.1200, 0},
            {202, "EURUSD", POSITION_TYPE_BUY, 3, 1.1020, 1.1040, 0, 1.1300, 0}};
}

TrailingStopConfig ServiceConfig(PMTrailBasis basis)
{
    return {true, true, "EURUSD", PM_DIRECTION_BOTH, basis, 20, 2, 20, 10};
}

void TestServiceValidationUnit()
{
    for (auto basis : {PM_TRAIL_BASIS_AVERAGE, PM_TRAIL_BASIS_PER_POSITION}) {
        CTrailingStopService service;
        CPositionService positions;
        positions.live = ServicePositions();
        CTradeManager trades;
        CValidationService validator;
        validator.responses = {true, false, true};
        string status;
        service.Evaluate(ServiceConfig(basis), positions.live, positions, trades, validator, status);
        AssertTrue(trades.sent == std::vector<ulong>({201, 202}), "Both eligible tickets are updated");
        AssertTrue(trades.take_profits == std::vector<double>({1.1200, 1.1300}), "Each ticket retains its TP");
        if (basis == PM_TRAIL_BASIS_AVERAGE) {
            AssertTrue(validator.calls == 1 && trades.stops.size() == 2 &&
                       MathAbs(trades.stops[0] - 1.1030) < 1e-8 && trades.stops[0] == trades.stops[1],
                       "Quote movement between sends does not split the common basket target");
        } else {
            AssertTrue(validator.calls == 3 && trades.stops.size() == 2 &&
                       MathAbs(trades.stops[1] - 1.1022) < 1e-8,
                       "Per-position validation and fallback remain independent");
        }
    }
    for (bool fallback_accepted : {false, true}) {
        CTrailingStopService service;
        CPositionService positions;
        positions.live = ServicePositions();
        CTradeManager trades;
        CValidationService validator;
        validator.responses = {false, fallback_accepted, true};
        string status;
        service.Evaluate(ServiceConfig(PM_TRAIL_BASIS_AVERAGE), positions.live,
                         positions, trades, validator, status);
        AssertTrue(validator.calls == 2, "Basket primary and fallback are each validated only once");
        if (fallback_accepted) {
            AssertTrue(trades.stops.size() == 2 && MathAbs(trades.stops[0] - 1.1017) < 1e-8 &&
                       trades.stops[0] == trades.stops[1], "Accepted fallback is shared by the whole basket");
        } else {
            AssertTrue(trades.sent.empty(), "Rejected basket stays rejected even if a later quote would accept it");
        }
    }
}

void TestServicePendingAndRatchet()
{
    for (auto basis : {PM_TRAIL_BASIS_AVERAGE, PM_TRAIL_BASIS_PER_POSITION}) {
        CTrailingStopService service;
        CPositionService positions;
        positions.live = ServicePositions();
        CTradeManager trades;
        trades.pending = {201};
        CValidationService validator;
        string status;
        service.Evaluate(ServiceConfig(basis), positions.live, positions, trades, validator, status);
        AssertTrue(basis == PM_TRAIL_BASIS_AVERAGE ? trades.sent.empty() :
                   trades.sent == std::vector<ulong>({202}), "Pending protection follows the selected basis");
    }
    for (auto basis : {PM_TRAIL_BASIS_AVERAGE, PM_TRAIL_BASIS_PER_POSITION}) {
        CTrailingStopService service;
        auto snapshot = ServicePositions();
        CPositionService positions;
        positions.live = snapshot;
        positions.live[0].sl = 1.1035;
        positions.live[1].tp = 1.1400;
        CTradeManager trades;
        CValidationService validator;
        string status;
        service.Evaluate(ServiceConfig(basis), snapshot, positions, trades, validator, status);
        AssertTrue(trades.sent == std::vector<ulong>({202}) && trades.take_profits[0] == 1.1400,
                   "Latest SL prevents regression and latest TP is preserved after snapshot collection");
        trades = CTradeManager();
        positions.live.clear();
        service.Evaluate(ServiceConfig(basis), snapshot, positions, trades, validator, status);
        AssertTrue(trades.sent.empty(), "Disappeared tickets never receive a modification");
    }
}
