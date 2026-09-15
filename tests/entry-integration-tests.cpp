// Actual Entry state, service, UI actions and send method run above this file.
void TestEntryIntegration() {
    ResetBoundary();
    CEntryService service;
    PMEntrySnapshot snapshot = {};
    PMEntryComputation result = {};
    string reason;
    CEntryDraft draft;
    AssertTrue(service.Evaluate(_Symbol, PM_ENTRY_BUY, draft, -1, 0, snapshot, result, reason) &&
               snapshot.sl_price == 0 && result.effective_tp == 0,
               "Initial Entry has no implicitly seeded protections");
    draft.SetPrice(0, 98, 2);
    AssertTrue(service.Evaluate(_Symbol, PM_ENTRY_BUY, draft, -1, 0, snapshot, result, reason) &&
               result.effective_tp == 0 && draft.tp_state == PM_TP_STATE_OFF,
               "Setting SL alone never creates a TP");
    draft.SetPrice(1, 102, 2);
    service.Evaluate(_Symbol, PM_ENTRY_BUY, draft, 1, 104, snapshot, result, reason);
    AssertTrue(result.effective_tp == 104 && std::abs(result.rr - 2.0) < 1e-9 && draft.stop_text[1] == "102.00",
               "TP drag previews a candidate without committing input");
    service.Evaluate(_Symbol, PM_ENTRY_BUY, draft, 0, 99, snapshot, result, reason);
    AssertTrue(snapshot.sl_price == 99 && result.effective_tp == 102 && draft.stop_text[0] == "98.00",
               "SL drag previews a candidate without moving TP or committing input");
    draft.CancelStop(0);
    AssertTrue(service.Evaluate(_Symbol, PM_ENTRY_BUY, draft, -1, 0, snapshot, result, reason) &&
               snapshot.sl_price == 0 && result.effective_tp == 102 && draft.tp_state == PM_TP_STATE_MANUAL,
               "Clearing SL keeps an explicitly set TP");
    draft.CancelStop(1);
    AssertTrue(service.Evaluate(_Symbol, PM_ENTRY_BUY, draft, -1, 0, snapshot, result, reason) &&
               result.effective_tp == 0 && draft.tp_state == PM_TP_STATE_OFF,
               "Clearing TP hides it independently of SL");

    // Every order side/type and every independent protection combination.
    for(int kind = 0; kind < 3; ++kind) for(int direction = 0; direction < 2; ++direction)
    for(int mask = 0; mask < 4; ++mask) {
        ResetBoundary();
        CEntryDraft d;
        d.order_type = (PMEntryOrderType)kind;
        const PMEntrySide side = (PMEntrySide)direction;
        double entry = direction == 0 ? 100 : 99.9;
        if(kind == 1) entry = direction == 0 ? 95 : 105;
        if(kind == 2) entry = direction == 0 ? 105 : 95;
        d.order_text = DoubleToString(entry, 2);
        d.lot_text = "0.037";
        double sl = mask & 1 ? entry + (direction == 0 ? -2 : 2) : 0;
        double tp = mask & 2 ? entry + (direction == 0 ? 2 : -2) : 0;
        d.SetPrice(0, sl, 2); d.SetPrice(1, tp, 2);
        bool valid = service.Evaluate(_Symbol, side, d, -1, 0, snapshot, result, reason);
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
    AssertTrue(service.Evaluate(_Symbol, PM_ENTRY_BUY, draft, -1, 0, snapshot, result, reason) &&
               snapshot.sl_price == 93 && result.effective_tp == 0 && result.lot == .4,
               "Pending Pips sizing uses order price, not Bid/Ask, and creates no TP");
    draft.quantity_mode = PM_QUANTITY_RISK_PERCENT; draft.risk_text = "1";
    AssertTrue(service.Evaluate(_Symbol, PM_ENTRY_BUY, draft, -1, 0, snapshot, result, reason) && result.lot == .4,
               "One percent of balance equals the same amount budget");
    draft.SetPrice(1, 97, 2); draft.CancelStop(0);
    AssertTrue(!service.Evaluate(_Symbol, PM_ENTRY_BUY, draft, -1, 0, snapshot, result, reason) && !result.lot_ok && result.effective_tp == 97,
               "Cancel SL in risk mode invalidates lot and retains TP");
    draft.quantity_mode = PM_QUANTITY_MANUAL_LOT;
    AssertTrue(service.Evaluate(_Symbol, PM_ENTRY_BUY, draft, -1, 0, snapshot, result, reason) && result.effective_tp == 97,
               "Explicit manual lot resumes TP-only order");
    draft.quantity_mode = PM_QUANTITY_RISK_AMOUNT; draft.risk_text = "100"; draft.SetPrice(0, 93, 2);
    profit_ok = false;
    AssertTrue(!service.Evaluate(_Symbol, PM_ENTRY_BUY, draft, -1, 0, snapshot, result, reason) && !result.lot_ok,
               "Profit API failure cannot use a stale lot");
    profit_ok = true; final_loss_factor = 1.1;
    AssertTrue(!service.Evaluate(_Symbol, PM_ENTRY_BUY, draft, -1, 0, snapshot, result, reason) && !result.lot_ok,
               "Final-volume API loss exceeding budget blocks sending");
    final_loss_factor = 1;
    symbol_values[SYMBOL_VOLUME_MAX] = .5;
    AssertTrue(service.Evaluate(_Symbol, PM_ENTRY_BUY, draft, -1, 0, snapshot, result, reason),
               "Reference volume respects broker max below one lot");
    symbol_values[SYMBOL_VOLUME_MIN] = 2; symbol_values[SYMBOL_VOLUME_MAX] = 100; symbol_values[SYMBOL_VOLUME_STEP] = 1;
    draft.risk_text = "1000";
    AssertTrue(service.Evaluate(_Symbol, PM_ENTRY_BUY, draft, -1, 0, snapshot, result, reason) && result.lot == 4,
               "Reference volume respects broker min above one lot");

    ResetBoundary();
    draft = CEntryDraft(); draft.SetPrice(0, 98, 2);
    draft.quantity_mode = PM_QUANTITY_RISK_AMOUNT;
    for(const auto &invalid : {"100oops", "", "-1", "0"}) {
        draft.risk_text = invalid;
        AssertTrue(!service.Evaluate(_Symbol, PM_ENTRY_BUY, draft, -1, 0, snapshot, result, reason), "Invalid risk text blocks send");
    }
    draft.quantity_mode = PM_QUANTITY_MANUAL_LOT;
    draft.SetPrice(0, 99.95, 2);
    AssertTrue(!service.Evaluate(_Symbol, PM_ENTRY_BUY, draft, -1, 0, snapshot, result, reason),
               "Buy market SL inside spread is rejected using Bid distance");
    AssertTrue(!service.Evaluate(_Symbol, PM_ENTRY_SELL, draft, -1, 0, snapshot, result, reason),
               "Sell market SL inside spread is rejected using Ask distance");
    draft.order_type = PM_ENTRY_ORDER_LIMIT; draft.order_text = "99.99";
    draft.CancelStop(0); draft.CancelStop(1); symbol_values[SYMBOL_TRADE_STOPS_LEVEL] = 10;
    AssertTrue(!service.Evaluate(_Symbol, PM_ENTRY_BUY, draft, -1, 0, snapshot, result, reason), "Pending entry inside minimum distance is rejected");
    draft.order_text = "95.005"; symbol_values[SYMBOL_TRADE_STOPS_LEVEL] = 0;
    AssertTrue(!service.Evaluate(_Symbol, PM_ENTRY_BUY, draft, -1, 0, snapshot, result, reason), "Off-tick order price is rejected without hidden correction");
    draft.order_text = "95"; symbol_values[SYMBOL_EXPIRATION_MODE] = 0;
    AssertTrue(!service.Evaluate(_Symbol, PM_ENTRY_BUY, draft, -1, 0, snapshot, result, reason), "Unsupported GTC is rejected");
    symbol_values[SYMBOL_EXPIRATION_MODE] = 1; symbol_values[SYMBOL_ORDER_MODE] = SYMBOL_ORDER_MARKET;
    AssertTrue(!service.Evaluate(_Symbol, PM_ENTRY_BUY, draft, -1, 0, snapshot, result, reason), "Unsupported pending order mode is rejected");
    ResetBoundary();
    draft = CEntryDraft(); service.Evaluate(_Symbol, PM_ENTRY_BUY, draft, -1, 0, snapshot, result, reason);
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
    AssertTrue(ui.m_entry_snapshot[PM_ENTRY_BUY].sl_price > 0 && ui.m_entry_result[PM_ENTRY_BUY].effective_tp == 0,
               "UI Set SL alone leaves TP unset");
    ui.HandleEntryClick("ENTRY_SL_CLEAR", trades); ui.RefreshEntryComputation(false);
    AssertTrue(ui.m_entry_snapshot[PM_ENTRY_BUY].sl_price == 0 && objects["ENTRY_SL_VALUE"] == "0",
               "UI Clear SL resets the SL field to 0");
    AssertTrue(objects["SL_VALUE"] == "old position SL" && objects["TP_VALUE"] == "old position TP",
               "Entry clear/set operations leave existing-position edit objects untouched");
    ui.HandleEntryClick("ENTRY_TP_CLEAR", trades); ui.HandleEntryClick("ENTRY_TP_SET", trades); ui.RefreshEntryComputation(false);
    AssertTrue(ui.m_entry_snapshot[PM_ENTRY_BUY].sl_price == 0 && ui.m_entry_result[PM_ENTRY_BUY].effective_tp > 0 &&
               ui.m_entry_draft.tp_state == PM_TP_STATE_MANUAL, "Set TP alone creates only TP and enables manual sizing");
    ui.HandleEntryClick("ENTRY_BUY", trades);
    AssertTrue(sends == 1 && sent_request.sl == 0 && sent_request.tp > 0, "TP-only send uses visible direction and resolved protections");
    ui.HandleEntryClick("ENTRY_SL_SET", trades);
    ui.SwitchEntryUnit(0); ui.RefreshEntryComputation(false);
    AssertTrue(ui.m_entry_draft.unit[0] == PM_ENTRY_UNIT_PIPS && objects["ENTRY_SL_VALUE"] == "2",
               "Price to Pips conversion displays its distance in pips");
    ui.SwitchEntryUnit(0);
    AssertTrue(ui.m_entry_draft.unit[0] == PM_ENTRY_UNIT_PRICE, "Pips to Price conversion restores explicit price mode");
    objects["ENTRY_SL_VALUE"] = "0"; ui.CommitEntryEditor("ENTRY_SL_VALUE"); ui.RefreshEntryComputation(false);
    AssertTrue(ui.m_entry_snapshot[PM_ENTRY_BUY].sl_price == 0 && ui.m_entry_result[PM_ENTRY_BUY].effective_tp > 0, "Typing zero cancels SL without canceling TP");
    const int previous_sends = sends;
    ui.m_price_drag.Begin(0, "Entry", 98);
    ui.OpenEntry(PM_ENTRY_BUY, trades);
    AssertTrue(sends == previous_sends, "Direct Entry send rejects an active line drag");
    ui.m_price_drag.Cancel();
    ui.HandleEntryClick("ENTRY_SUB_LIMIT", trades);
    objects["ENTRY_ORDER_PRICE"] = "95"; ui.CommitEntryEditor("ENTRY_ORDER_PRICE");
    ui.HandleEntryClick("ENTRY_SUB_STOP", trades); ui.HandleEntryClick("ENTRY_SUB_MARKET", trades);
    objects["ENTRY_ORDER_PRICE"] = "100"; // the hidden Market row is never committed
    ui.HandleEntryClick("ENTRY_SUB_LIMIT", trades);
    AssertTrue(objects["ENTRY_ORDER_PRICE"] == "95" && ui.m_entry_draft.order_text == "95" &&
               ui.m_entry_draft.order_type == PM_ENTRY_ORDER_LIMIT,
               "Switching through the Market sub-tab retains the pending draft price");
    ResetBoundary();
    EntryUiHarness drag_ui;
    objects["SL_VALUE"] = "old SL"; objects["TP_VALUE"] = "old TP";
    drag_ui.m_entry_draft.SetPrice(0, 98, 2); drag_ui.WriteEntryStops();
    AssertTrue(drag_ui.HandlePriceMouse(820, 210, true, true) && !mouse_scroll,
               "Grabbing Entry SL label captures the mouse and suspends scroll");
    drag_ui.HandlePriceMouse(820, 230, true, false);
    AssertTrue(drag_ui.m_entry_snapshot[PM_ENTRY_BUY].sl_price == 97.8 && drag_ui.m_entry_result[PM_ENTRY_BUY].effective_tp == 0 &&
               drag_ui.m_entry_draft.stop_text[0] == "98.00", "Real drag event previews SL without committing input or creating a TP");
    drag_ui.HandlePriceMouse(820, 230, false, false);
    AssertTrue(drag_ui.m_entry_draft.stop_text[0] == "97.80" && objects["ENTRY_SL_VALUE"] == "97.80" && mouse_scroll,
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
    service.Evaluate(_Symbol, PM_ENTRY_BUY, draft, -1, 0, snapshot, result, reason);
    const double manual_tp = result.effective_tp;
    current_tick.bid += .5; current_tick.ask += .5;
    service.Evaluate(_Symbol, PM_ENTRY_BUY, draft, -1, 0, snapshot, result, reason);
    AssertTrue(result.effective_tp == manual_tp, "Manual TP entered as Pips stays at its committed price after ticks");

    ResetBoundary();
    EntryUiHarness render_ui;
    render_ui.HandleEntryClick("ENTRY_SL_SET", trades);
    render_ui.HandleEntryClick("ENTRY_QTY_MODE", trades);
    objects["ENTRY_RISK"] = "100"; render_ui.CommitEntryEditor("ENTRY_RISK");
    render_ui.Render();
    // The risk lot differs per side, so it belongs on each side's preview row.
    AssertTrue(objects["ENTRY_BUY_PREVIEW"].rfind("BUY 6.66 | SL 99.88 -99.90 | TP - | -", 0) == 0 &&
               objects["ENTRY_QTY_MODE"] == "Risk USD",
               "Render shows the calculated risk lot on the side's own preview row");
    const string calculated_lot = objects["ENTRY_BUY_PREVIEW"];
    objects["ENTRY_RISK"] = "200 unfinished";
    render_ui.Render();
    AssertTrue(objects["ENTRY_RISK"] == "200 unfinished" && objects["ENTRY_BUY_PREVIEW"] == calculated_lot,
               "Timer leaves in-progress risk text alone and uses only committed risk");
    render_ui.HandleEntryClick("ENTRY_SL_CLEAR", trades); render_ui.Render();
    AssertTrue(objects["ENTRY_BUY_PREVIEW"] == "BUY - | SL - | TP - | -" &&
               objects["ENTRY_SELL_PREVIEW"] == "SELL - | SL - | TP - | -",
               "Invalid risk sizing and missing RR show only the shared unavailable token");
    render_ui.HandleEntryClick("ENTRY_QTY_MODE", trades); render_ui.HandleEntryClick("ENTRY_QTY_MODE", trades); render_ui.Render();
    AssertTrue(objects["ENTRY_LOT"] == "0.01" && objects["ENTRY_QTY_MODE"] == "Lot",
               "Returning to Manual restores its original lot instead of a cached risk lot");

    // The draft carries no side: Pips prices both sides, an absolute price fixes one.
    ResetBoundary();
    EntryUiHarness side_ui;
    objects["ENTRY_SL_VALUE"] = "20"; side_ui.CommitEntryEditor("ENTRY_SL_VALUE");
    side_ui.RefreshEntryComputation(false);
    AssertTrue(side_ui.m_entry_valid[PM_ENTRY_BUY] && side_ui.m_entry_valid[PM_ENTRY_SELL] &&
               side_ui.m_entry_snapshot[PM_ENTRY_BUY].sl_price == 99.7 &&
               side_ui.m_entry_snapshot[PM_ENTRY_SELL].sl_price == 100.2 &&
               side_ui.EntryReferenceSide() == PM_ENTRY_BUY,
               "A Pips SL keeps both sides orderable and prices each on its own loss side");
    side_ui.m_entry_draft.SetPrice(0, 99.88, 2); side_ui.WriteEntryStops();
    side_ui.RefreshEntryComputation(false);
    AssertTrue(side_ui.m_entry_valid[PM_ENTRY_BUY] && !side_ui.m_entry_valid[PM_ENTRY_SELL] &&
               side_ui.EntryReferenceSide() == PM_ENTRY_BUY,
               "An SL below the market fixes the orderable side to BUY");
    side_ui.m_entry_draft.SetPrice(0, 100.12, 2); side_ui.WriteEntryStops();
    side_ui.RefreshEntryComputation(false);
    AssertTrue(!side_ui.m_entry_valid[PM_ENTRY_BUY] && side_ui.m_entry_valid[PM_ENTRY_SELL] &&
               side_ui.EntryReferenceSide() == PM_ENTRY_SELL,
               "Moving the SL across the market flips the orderable side to SELL");
    const int blocked_sends = sends;
    side_ui.HandleEntryClick("ENTRY_BUY", trades);
    AssertTrue(sends == blocked_sends, "The side its own prices invalidated refuses to send");
    side_ui.HandleEntryClick("ENTRY_SELL", trades);
    AssertTrue(sends == blocked_sends + 1 && sent_request.type == ORDER_TYPE_SELL && sent_request.sl == 100.12,
               "The orderable side sends straight from its button with no side toggle");
    side_ui.Render();
    AssertTrue(objects["ENTRY_HINT"].rfind("BUY is not orderable: ", 0) == 0,
               "The hint names the blocked side so the greyed button is explained");

    ResetBoundary();
    draft = CEntryDraft(); draft.SetPrice(0, 99.95, 2); draft.SetPrice(1, 102, 2);
    service.Evaluate(_Symbol, PM_ENTRY_BUY, draft, -1, 0, snapshot, result, reason);
    AssertTrue(service.Estimate(_Symbol, snapshot, result, true) == "-" &&
               service.Estimate(_Symbol, snapshot, result, false) != "-",
               "Market SL inside spread has no estimate while valid TP retains its estimate");
    draft.SetPrice(0, 98, 2); draft.SetPrice(1, 100.05, 2);
    symbol_values[SYMBOL_TRADE_STOPS_LEVEL] = 20;
    service.Evaluate(_Symbol, PM_ENTRY_BUY, draft, -1, 0, snapshot, result, reason);
    AssertTrue(service.Estimate(_Symbol, snapshot, result, true) != "-" &&
               service.Estimate(_Symbol, snapshot, result, false) == "-",
               "TP inside broker stop distance has no estimate while valid SL retains its estimate");

    ResetBoundary();
    EntryUiHarness simultaneous_ui;
    simultaneous_ui.HandleEntryClick("ENTRY_SUB_LIMIT", trades);
    objects["ENTRY_ORDER_PRICE"] = "95"; simultaneous_ui.CommitEntryEditor("ENTRY_ORDER_PRICE");
    objects["ENTRY_ORDER_PRICE"] = "94";
    objects["ENTRY_TP_VALUE"] = "200"; objects["ENTRY_SL_VALUE"] = "200";
    simultaneous_ui.CommitEntryEditors(); simultaneous_ui.RefreshEntryComputation(false);
    AssertTrue(simultaneous_ui.m_entry_valid[PM_ENTRY_BUY] && simultaneous_ui.m_entry_result[PM_ENTRY_BUY].entry == 94 &&
               simultaneous_ui.m_entry_snapshot[PM_ENTRY_BUY].sl_price == 92 && simultaneous_ui.m_entry_result[PM_ENTRY_BUY].effective_tp == 96,
               "Simultaneous price and stop edits resolve manual TP Pips from the latest pending price");

    // OBJ_LABEL keeps only 63 characters, so long Entry hints continue on a second row.
    ResetBoundary();
    EntryUiHarness hint_ui;
    hint_ui.m_entry_draft.quantity_mode = PM_QUANTITY_RISK_AMOUNT;
    hint_ui.m_entry_draft.risk_text = "14";
    hint_ui.RenderEntryState();
    AssertTrue(!hint_ui.m_entry_valid[PM_ENTRY_BUY] && hint_ui.m_entry_reason[PM_ENTRY_BUY].size() > PM_MAX_LABEL_TEXT_LENGTH &&
               objects["ENTRY_HINT"].size() <= PM_MAX_LABEL_TEXT_LENGTH &&
               objects["ENTRY_HINT_2"].size() <= PM_MAX_LABEL_TEXT_LENGTH &&
               objects["ENTRY_HINT"] + objects["ENTRY_HINT_2"] == hint_ui.m_entry_reason[PM_ENTRY_BUY],
               "A hint longer than the OBJ_LABEL limit wraps onto the second hint row without losing text");
    const string invalid_line = hint_ui.EntryPriceLineText(1, 102);
    // A Pips draft prices both sides, so the line names the side it is drawn for.
    AssertTrue(invalid_line.size() <= PM_MAX_LABEL_TEXT_LENGTH && invalid_line.rfind("BUY TP ", 0) == 0 &&
               invalid_line.find("RR ") != string::npos && invalid_line.find('\n') == string::npos &&
               invalid_line.size() >= 10 && invalid_line.substr(invalid_line.size() - 10) == " | Invalid",
               "Entry line label is one short row naming its side and flagging an invalid draft");
    hint_ui.m_entry_draft.quantity_mode = PM_QUANTITY_MANUAL_LOT;
    hint_ui.RenderEntryState();
    AssertTrue(hint_ui.m_entry_valid[PM_ENTRY_BUY] && objects["ENTRY_HINT_2"] == " " &&
               hint_ui.EntryPriceLineText(0, 98).find("Invalid") == string::npos,
               "A short hint blanks the second row with a space instead of MT5's default Label text");
    AssertTrue(objects["ENTRY_SL_MODE"] == "Pips" && objects["ENTRY_TP_MODE"] == "Pips",
               "Entry SL/TP start in Pips mode");

    ResetBoundary();
    symbol_values[SYMBOL_DIGITS] = 3; symbol_values[SYMBOL_POINT] = .001; symbol_values[SYMBOL_TRADE_TICK_SIZE] = .001;
    draft = CEntryDraft(); draft.SetStop(0, "20"); draft.SetStop(1, "12.5");
    AssertTrue(service.Evaluate(_Symbol, PM_ENTRY_BUY, draft, -1, 0, snapshot, result, reason) &&
               std::abs(snapshot.sl_price - 99.7) < 1e-9 && std::abs(result.effective_tp - 100.025) < 1e-9,
               "Entry Pips use ten points per pip on a 3-digit symbol and accept decimals");

    // SL/TP tab: Clear resets only its own draft to 0, which hides its line.
    ResetBoundary();
    EntryUiHarness stops_ui;
    objects["SL_VALUE"] = "150.00"; objects["TP_VALUE"] = "155.00";
    stops_ui.m_stop_committed[0] = "150.00"; stops_ui.m_stop_committed[1] = "155.00";
    stops_ui.m_price_drag.Begin(0, "Stops", 150); mouse_scroll = false;
    stops_ui.ResetStopEditor(0);
    AssertTrue(objects["SL_VALUE"] == "0" && stops_ui.m_stop_committed[0] == "0" &&
               stops_ui.m_price_drag.Index() < 0 && mouse_scroll &&
               objects["TP_VALUE"] == "155.00" && stops_ui.m_stop_committed[1] == "155.00",
               "Clear SL resets only the SL draft to 0 and ends its drag");
}
