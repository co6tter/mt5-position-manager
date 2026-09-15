// Actual Entry state, service, UI actions and send method run above this file.
void TestEntryIntegration() {
    ResetBoundary();
    CEntryService service;
    PMEntrySnapshot snapshot = {};
    PMEntryComputation result = {};
    string reason;
    CEntryDraft draft;
    AssertTrue(service.Evaluate(_Symbol, draft, -1, 0, snapshot, result, reason) &&
               snapshot.sl_price == 0 && result.effective_tp == 0,
               "Initial Entry has no implicitly seeded protections");
    draft.SetPrice(0, 98, 2);
    AssertTrue(service.Evaluate(_Symbol, draft, -1, 0, snapshot, result, reason) && result.effective_tp == 102,
               "Setting SL generates default 1:1 TP");
    draft.CancelStop(0);
    AssertTrue(service.Evaluate(_Symbol, draft, -1, 0, snapshot, result, reason) &&
               snapshot.sl_price == 0 && result.effective_tp == 102 && draft.tp_state == PM_TP_STATE_MANUAL,
               "SL cancellation retains the generated TP in Manual state");
    draft.SetPrice(0, 97, 2);
    service.Evaluate(_Symbol, draft, -1, 0, snapshot, result, reason);
    AssertTrue(result.effective_tp == 102, "Restoring SL does not overwrite the frozen manual TP");
    draft.CancelStop(1); draft.rr_text = "2";
    service.Evaluate(_Symbol, draft, -1, 0, snapshot, result, reason);
    AssertTrue(result.effective_tp == 0 && draft.tp_state == PM_TP_STATE_OFF, "RR changes preserve TP Off");
    AssertTrue(draft.AutoTP(result.entry, snapshot.sl_price, reason), "Explicit Auto restore with SL succeeds");
    service.Evaluate(_Symbol, draft, -1, 0, snapshot, result, reason);
    AssertTrue(result.effective_tp == 106, "Restored Auto uses current SL and multiplier");
    service.Evaluate(_Symbol, draft, 1, 104, snapshot, result, reason);
    AssertTrue(result.effective_tp == 104 && std::abs(result.rr - 4.0/3) < 1e-9 && draft.tp_state == PM_TP_STATE_AUTO,
               "TP drag previews manual candidate without committing state");
    service.Evaluate(_Symbol, draft, 0, 99, snapshot, result, reason);
    AssertTrue(result.effective_tp == 102 && snapshot.sl_price == 99 && draft.stop_text[0] == "97.00",
               "SL drag previews matching Auto TP and preserves committed input");
    draft.CancelStop(0);
    draft.CancelStop(1);
    AssertTrue(!draft.AutoTP(100, 0, reason) && draft.tp_state == PM_TP_STATE_OFF,
               "Auto restore without SL rejects and preserves Off");

    // Every order side/type and every independent protection combination.
    for(int kind = 0; kind < 3; ++kind) for(int direction = 0; direction < 2; ++direction)
    for(int mask = 0; mask < 4; ++mask) {
        ResetBoundary();
        CEntryDraft d;
        d.order_type = (PMEntryOrderType)kind; d.side = (PMEntrySide)direction;
        double entry = direction == 0 ? 100 : 99.9;
        if(kind == 1) entry = direction == 0 ? 95 : 105;
        if(kind == 2) entry = direction == 0 ? 105 : 95;
        d.order_text = DoubleToString(entry, 2);
        d.lot_text = "0.037";
        double sl = mask & 1 ? entry + (direction == 0 ? -2 : 2) : 0;
        double tp = mask & 2 ? entry + (direction == 0 ? 2 : -2) : 0;
        d.SetPrice(0, sl, 2); d.SetPrice(1, tp, 2);
        bool valid = service.Evaluate(_Symbol, d, -1, 0, snapshot, result, reason);
        AssertTrue(valid && snapshot.sl_price == sl && result.effective_tp == tp && result.lot == .04,
                   "Six order combinations preserve each independent protection and normalize manual volume");
        CTradeManager trades; PMMarketEntryResult sent = {};
        AssertTrue(valid && trades.SubmitEntry(_Symbol, snapshot, result, sent) && checks == 1 && sends == 1,
                   "An explicit order passes exactly one check and send");
        const int type = kind == 0 ? direction : kind == 1 ? 2 + direction : 4 + direction;
        AssertTrue(sent_request.type == type && sent_request.price == entry && sent_request.sl == sl && sent_request.tp == tp &&
                   sent_request.volume == result.lot && checked_request.price == sent_request.price &&
                   checked_request.type_filling == sent_request.type_filling,
                   "Checked and sent requests use the displayed snapshot values");
        AssertTrue(kind == 0 ? sent_request.type_filling == ORDER_FILLING_FOK :
                   sent_request.type_filling == ORDER_FILLING_RETURN && sent_request.type_time == ORDER_TIME_GTC,
                   "Market and pending orders use their supported filling policy");
    }
    ResetBoundary();
    draft = CEntryDraft();
    draft.order_type = PM_ENTRY_ORDER_LIMIT; draft.order_text = "95";
    draft.SetStop(0, "200"); draft.quantity_mode = PM_QUANTITY_RISK_AMOUNT; draft.risk_text = "100";
    AssertTrue(service.Evaluate(_Symbol, draft, -1, 0, snapshot, result, reason) &&
               snapshot.sl_price == 93 && result.effective_tp == 97 && result.lot == .4,
               "Pending Points sizing and Auto TP use order price, not Bid/Ask");
    draft.quantity_mode = PM_QUANTITY_RISK_PERCENT; draft.risk_text = "1";
    AssertTrue(service.Evaluate(_Symbol, draft, -1, 0, snapshot, result, reason) && result.lot == .4,
               "One percent of balance equals the same amount budget");
    draft.CancelStop(0);
    AssertTrue(!service.Evaluate(_Symbol, draft, -1, 0, snapshot, result, reason) && !result.lot_ok && result.effective_tp == 97,
               "Cancel SL in risk mode invalidates lot and retains TP");
    draft.quantity_mode = PM_QUANTITY_MANUAL_LOT;
    AssertTrue(service.Evaluate(_Symbol, draft, -1, 0, snapshot, result, reason) && result.effective_tp == 97,
               "Explicit manual lot resumes TP-only order");
    draft.quantity_mode = PM_QUANTITY_RISK_AMOUNT; draft.risk_text = "100"; draft.SetPrice(0, 93, 2);
    profit_ok = false;
    AssertTrue(!service.Evaluate(_Symbol, draft, -1, 0, snapshot, result, reason) && !result.lot_ok,
               "Profit API failure cannot use a stale lot");
    profit_ok = true; final_loss_factor = 1.1;
    AssertTrue(!service.Evaluate(_Symbol, draft, -1, 0, snapshot, result, reason) && !result.lot_ok,
               "Final-volume API loss exceeding budget blocks sending");
    final_loss_factor = 1;
    symbol_values[SYMBOL_VOLUME_MAX] = .5;
    AssertTrue(service.Evaluate(_Symbol, draft, -1, 0, snapshot, result, reason),
               "Reference volume respects broker max below one lot");
    symbol_values[SYMBOL_VOLUME_MIN] = 2; symbol_values[SYMBOL_VOLUME_MAX] = 100; symbol_values[SYMBOL_VOLUME_STEP] = 1;
    draft.risk_text = "1000";
    AssertTrue(service.Evaluate(_Symbol, draft, -1, 0, snapshot, result, reason) && result.lot == 4,
               "Reference volume respects broker min above one lot");

    ResetBoundary();
    draft = CEntryDraft(); draft.SetPrice(0, 98, 2);
    for(const auto &invalid : {"1oops", "", "nan", "-1", "0"}) {
        draft.rr_text = invalid;
        AssertTrue(!service.Evaluate(_Symbol, draft, -1, 0, snapshot, result, reason), "Invalid RR cannot fall back to previous multiplier");
    }
    draft.rr_text = "1"; draft.quantity_mode = PM_QUANTITY_RISK_AMOUNT;
    for(const auto &invalid : {"100oops", "", "-1", "0"}) {
        draft.risk_text = invalid;
        AssertTrue(!service.Evaluate(_Symbol, draft, -1, 0, snapshot, result, reason), "Invalid risk text blocks send");
    }
    draft.quantity_mode = PM_QUANTITY_MANUAL_LOT;
    draft.SetPrice(0, 99.95, 2);
    AssertTrue(!service.Evaluate(_Symbol, draft, -1, 0, snapshot, result, reason),
               "Buy market SL inside spread is rejected using Bid distance");
    draft.side = PM_ENTRY_SELL; draft.SetPrice(0, 99.95, 2);
    AssertTrue(!service.Evaluate(_Symbol, draft, -1, 0, snapshot, result, reason),
               "Sell market SL inside spread is rejected using Ask distance");
    draft.side = PM_ENTRY_BUY; draft.order_type = PM_ENTRY_ORDER_LIMIT; draft.order_text = "99.99";
    draft.CancelStop(0); draft.CancelStop(1); symbol_values[SYMBOL_TRADE_STOPS_LEVEL] = 10;
    AssertTrue(!service.Evaluate(_Symbol, draft, -1, 0, snapshot, result, reason), "Pending entry inside minimum distance is rejected");
    draft.order_text = "95.005"; symbol_values[SYMBOL_TRADE_STOPS_LEVEL] = 0;
    AssertTrue(!service.Evaluate(_Symbol, draft, -1, 0, snapshot, result, reason), "Off-tick order price is rejected without hidden correction");
    draft.order_text = "95"; symbol_values[SYMBOL_EXPIRATION_MODE] = 0;
    AssertTrue(!service.Evaluate(_Symbol, draft, -1, 0, snapshot, result, reason), "Unsupported GTC is rejected");
    symbol_values[SYMBOL_EXPIRATION_MODE] = 1; symbol_values[SYMBOL_ORDER_MODE] = SYMBOL_ORDER_MARKET;
    AssertTrue(!service.Evaluate(_Symbol, draft, -1, 0, snapshot, result, reason), "Unsupported pending order mode is rejected");
    ResetBoundary();
    draft = CEntryDraft(); service.Evaluate(_Symbol, draft, -1, 0, snapshot, result, reason);
    CTradeManager trades; PMMarketEntryResult sent = {};
    check_ok = false;
    AssertTrue(!trades.SubmitEntry(_Symbol, snapshot, result, sent) && sends == 0, "OrderCheck false prevents send");
    check_ok = true; check_code = 10019;
    AssertTrue(!trades.SubmitEntry(_Symbol, snapshot, result, sent) && sends == 0, "OrderCheck failure retcode prevents send even when bool is true");
    check_code = 0; send_ok = false; send_code = 10012;
    AssertTrue(!trades.SubmitEntry(_Symbol, snapshot, result, sent) && sends == 1, "Unknown send result is never automatically retried");
    send_ok = true; send_code = TRADE_RETCODE_DONE_PARTIAL;
    AssertTrue(trades.SubmitEntry(_Symbol, snapshot, result, sent) && sends == 2, "Partial fill is accepted without resubmitting remainder");

    // UI actions use committed text. Timer evaluation never reads edited objects.
    ResetBoundary();
    EntryUiHarness ui;
    objects["SL_VALUE"] = "old position SL"; objects["TP_VALUE"] = "old position TP";
    ui.HandleEntryClick("ENTRY_SL_SET", trades);
    AssertTrue(ui.m_entry_draft.unit[0] == PM_ENTRY_UNIT_PRICE && StringToDouble(ui.m_entry_draft.stop_text[0]) > 0 && sends == 0,
               "Set SL creates a committed price and does not send");
    ui.RefreshEntryComputation(false);
    const double auto_tp = ui.m_entry_result.effective_tp;
    ui.HandleEntryClick("ENTRY_SL_CLEAR", trades); ui.RefreshEntryComputation(false);
    AssertTrue(ui.m_entry_snapshot.sl_price == 0 && ui.m_entry_result.effective_tp == auto_tp,
               "UI Clear SL retains automatic TP");
    AssertTrue(objects["SL_VALUE"] == "old position SL" && objects["TP_VALUE"] == "old position TP",
               "Entry clear/set operations leave existing-position edit objects untouched");
    ui.HandleEntryClick("ENTRY_TP_CLEAR", trades); ui.HandleEntryClick("ENTRY_TP_SET", trades); ui.RefreshEntryComputation(false);
    AssertTrue(ui.m_entry_snapshot.sl_price == 0 && ui.m_entry_result.effective_tp > 0 &&
               ui.m_entry_draft.tp_state == PM_TP_STATE_MANUAL, "Set TP alone creates only TP and enables manual sizing");
    objects["ENTRY_RR"] = "2junk";
    ui.RefreshEntryComputation(false);
    AssertTrue(ui.m_entry_valid && ui.m_entry_draft.rr_text == "1.0", "Timer evaluation does not commit half-edited RR");
    ui.HandleEntryClick("ENTRY_BUY", trades);
    AssertTrue(sends == 0 && !ui.m_entry_valid, "Send commits latest malformed RR then rejects it");
    objects["ENTRY_RR"] = "1";
    ui.HandleEntryClick("ENTRY_BUY", trades);
    AssertTrue(sends == 1 && sent_request.sl == 0 && sent_request.tp > 0, "TP-only send uses visible direction and resolved protections");
    ui.HandleEntryClick("ENTRY_SL_SET", trades);
    ui.SwitchEntryUnit(0); ui.RefreshEntryComputation(false);
    AssertTrue(ui.m_entry_draft.unit[0] == PM_ENTRY_UNIT_POINTS && PMIsUnsignedIntegerText(objects["ENTRY_SL_POINTS"]),
               "Price to Points conversion displays its rounded distance");
    ui.SwitchEntryUnit(0);
    AssertTrue(ui.m_entry_draft.unit[0] == PM_ENTRY_UNIT_PRICE, "Points to Price conversion restores explicit price mode");
    objects["ENTRY_SL_POINTS"] = "0"; ui.CommitEntryEditor("ENTRY_SL_POINTS"); ui.RefreshEntryComputation(false);
    AssertTrue(ui.m_entry_snapshot.sl_price == 0 && ui.m_entry_result.effective_tp > 0, "Typing zero cancels SL without canceling TP");
    ui.HandleEntryClick("ENTRY_AUTO_TP", trades);
    AssertTrue(ui.m_entry_draft.tp_state == PM_TP_STATE_MANUAL, "UI auto restore without SL preserves manual TP");
    const int previous_sends = sends;
    ui.m_price_drag.Begin(0, "Entry", 98);
    ui.OpenEntry(trades);
    AssertTrue(sends == previous_sends, "Direct Entry send rejects an active line drag");
    ui.m_price_drag.Cancel();
    ui.HandleEntryClick("ENTRY_TYPE", trades);
    objects["ENTRY_ORDER_PRICE"] = "95"; ui.CommitEntryEditor("ENTRY_ORDER_PRICE");
    ui.HandleEntryClick("ENTRY_TYPE", trades); ui.HandleEntryClick("ENTRY_TYPE", trades);
    objects["ENTRY_ORDER_PRICE"] = "100"; // read-only Market reference is not committed
    ui.HandleEntryClick("ENTRY_TYPE", trades);
    AssertTrue(objects["ENTRY_ORDER_PRICE"] == "95" && ui.m_entry_draft.order_text == "95",
               "Switching through Market retains the pending draft price");
    ResetBoundary();
    EntryUiHarness drag_ui;
    objects["SL_VALUE"] = "old SL"; objects["TP_VALUE"] = "old TP";
    drag_ui.m_entry_draft.SetPrice(0, 98, 2); drag_ui.WriteEntryStops();
    AssertTrue(drag_ui.HandlePriceMouse(820, 210, true, true) && !mouse_scroll,
               "Grabbing Entry SL label captures the mouse and suspends scroll");
    drag_ui.HandlePriceMouse(820, 230, true, false);
    AssertTrue(drag_ui.m_entry_snapshot.sl_price == 97.8 && drag_ui.m_entry_result.effective_tp == 102.2 &&
               drag_ui.m_entry_draft.stop_text[0] == "98.00", "Real drag event updates RR/Auto TP preview without committing input");
    drag_ui.HandlePriceMouse(820, 230, false, false);
    AssertTrue(drag_ui.m_entry_draft.stop_text[0] == "97.80" && objects["ENTRY_SL_POINTS"] == "97.80" && mouse_scroll,
               "Drag release commits Entry Price and restores chart scrolling");
    AssertTrue(objects["SL_VALUE"] == "old SL" && objects["TP_VALUE"] == "old TP" && sends == 0,
               "Entry drag cannot overwrite position editors or submit an order");
    drag_ui.m_active_tab = PM_PANEL_TAB_STOPS;
    drag_ui.HandlePriceMouse(820, 260, true, true);
    drag_ui.HandlePriceMouse(820, 280, false, false);
    AssertTrue(objects["TP_VALUE"] == "101.80" && drag_ui.m_entry_draft.stop_text[0] == "97.80" && mouse_scroll,
               "Existing SL/TP drag retains its own commit target");

    ResetBoundary();
    draft = CEntryDraft(); draft.SetStop(1, "200");
    service.Evaluate(_Symbol, draft, -1, 0, snapshot, result, reason);
    const double manual_tp = result.effective_tp;
    current_tick.bid += .5; current_tick.ask += .5;
    service.Evaluate(_Symbol, draft, -1, 0, snapshot, result, reason);
    AssertTrue(result.effective_tp == manual_tp, "Manual TP entered as Points stays at its committed price after ticks");

    ResetBoundary();
    EntryUiHarness render_ui;
    render_ui.HandleEntryClick("ENTRY_SL_SET", trades);
    render_ui.HandleEntryClick("ENTRY_QTY_MODE", trades);
    objects["ENTRY_RISK"] = "100"; render_ui.CommitEntryEditor("ENTRY_RISK");
    render_ui.Render();
    AssertTrue(objects["ENTRY_LOT"] != "N/A" && object_properties[{"ENTRY_LOT", OBJPROP_READONLY}] == 1,
               "Render displays the calculated risk lot as read-only");
    const string calculated_lot = objects["ENTRY_LOT"];
    objects["ENTRY_RISK"] = "200 unfinished";
    render_ui.Render();
    AssertTrue(objects["ENTRY_RISK"] == "200 unfinished" && objects["ENTRY_LOT"] == calculated_lot,
               "Timer leaves in-progress risk text alone and uses only committed risk");
    render_ui.HandleEntryClick("ENTRY_SL_CLEAR", trades); render_ui.Render();
    AssertTrue(objects["ENTRY_LOT"] == "N/A" && objects["ENTRY_CURRENT_RR"].find("N/A") != string::npos,
               "Invalid risk sizing and missing RR never display stale numeric values");
    render_ui.HandleEntryClick("ENTRY_QTY_MODE", trades); render_ui.HandleEntryClick("ENTRY_QTY_MODE", trades); render_ui.Render();
    AssertTrue(objects["ENTRY_LOT"] == "0.01" && object_properties[{"ENTRY_LOT", OBJPROP_READONLY}] == 0,
               "Returning to Manual restores its original lot instead of a cached risk lot");

    ResetBoundary();
    draft = CEntryDraft(); draft.SetPrice(0, 99.95, 2); draft.SetPrice(1, 102, 2);
    service.Evaluate(_Symbol, draft, -1, 0, snapshot, result, reason);
    AssertTrue(service.Estimate(_Symbol, snapshot, result, true) == "N/A" &&
               service.Estimate(_Symbol, snapshot, result, false) != "N/A",
               "Market SL inside spread has no estimate while valid TP retains its estimate");
    draft.SetPrice(0, 98, 2); draft.SetPrice(1, 100.05, 2);
    symbol_values[SYMBOL_TRADE_STOPS_LEVEL] = 20;
    service.Evaluate(_Symbol, draft, -1, 0, snapshot, result, reason);
    AssertTrue(service.Estimate(_Symbol, snapshot, result, true) != "N/A" &&
               service.Estimate(_Symbol, snapshot, result, false) == "N/A",
               "TP inside broker stop distance has no estimate while valid SL retains its estimate");

    ResetBoundary();
    EntryUiHarness simultaneous_ui;
    simultaneous_ui.HandleEntryClick("ENTRY_TYPE", trades);
    objects["ENTRY_ORDER_PRICE"] = "95"; simultaneous_ui.CommitEntryEditor("ENTRY_ORDER_PRICE");
    objects["ENTRY_ORDER_PRICE"] = "94";
    objects["ENTRY_TP_POINTS"] = "200"; objects["ENTRY_SL_POINTS"] = "200";
    simultaneous_ui.CommitEntryEditors(); simultaneous_ui.RefreshEntryComputation(false);
    AssertTrue(simultaneous_ui.m_entry_valid && simultaneous_ui.m_entry_result.entry == 94 &&
               simultaneous_ui.m_entry_snapshot.sl_price == 92 && simultaneous_ui.m_entry_result.effective_tp == 96,
               "Simultaneous price and stop edits resolve manual TP Points from the latest pending price");
}
