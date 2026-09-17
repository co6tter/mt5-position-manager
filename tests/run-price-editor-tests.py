#!/usr/bin/env python3
"""Run the chart-independent price editor tests without MT5.

Checks the Trail control grouping/defaults, then compiles the actual MQL helper
bodies and shared test functions as C++. It does not validate MQL compilation,
native chart/font behavior or live trade APIs. Entry UI actions, drag handlers,
sizing and request submission are also exercised against a recording API boundary.
Requires Python 3 and a C++17 compiler (CXX, clang++, or g++).
"""

import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def verify_trail_layout(ui: str) -> None:
    """Protect the user-visible single-row Trail layout from regressions."""
    rows = {
        "PM_TRAIL_BE_ROW_Y": [
            'CreateLabel("BE_LABEL"', 'CreateButton("BE_ENABLED"',
            'CreateLabel("BE_TRIGGER_LABEL"', 'CreateNumericInput("BE_TRIGGER"',
            'CreateLabel("BE_LOCK_LABEL"', 'CreateNumericInput("BE_LOCK"',
        ],
        "PM_TRAIL_ROW_Y": [
            'CreateLabel("TRAIL_LABEL"', 'CreateButton("TRAIL_ENABLED"',
            'CreateLabel("TRAIL_TRIGGER_LABEL"', 'CreateNumericInput("TRAIL_TRIGGER"',
            'CreateLabel("TRAIL_DIST_LABEL"', 'CreateNumericInput("TRAIL_DIST"',
        ],
    }
    lines = ui.splitlines()
    for row, controls in rows.items():
        for control in controls:
            line = next((item for item in lines if control in item), None)
            if line is None or row not in line:
                raise AssertionError(f"{control} must remain on {row}")
    for control in ("BE_TRIGGER", "BE_LOCK", "TRAIL_TRIGGER", "TRAIL_DIST"):
        expected = f'CreateNumericInput("{control}", "{control}_VALUE", "0"'
        if expected not in ui:
            raise AssertionError(f"{control} must initially display 0")
    if 'CreateButton("BASIS_TOGGLE", "Per Position"' not in ui:
        raise AssertionError("Trail Basis must initially display Per Position")


def verify_entry_controls(ui: str) -> None:
    """Protect the Entry contract and prevent the old points-only labels returning."""
    if 'CreateLabel("ENTRY_SL_LABEL", "SL"' not in ui:
        raise AssertionError("Entry SL label must be SL")
    if 'CreateLabel("ENTRY_TP_LABEL", "TP"' not in ui:
        raise AssertionError("Entry TP label must be TP")
    if '"SL pts"' in ui or '"TP pts"' in ui:
        raise AssertionError("Entry labels must not contain pts")
    for control in ("ENTRY_SUB_MARKET", "ENTRY_SUB_LIMIT", "ENTRY_SUB_STOP", "ENTRY_ORDER_PRICE",
                    "ENTRY_QTY_LABEL", "ENTRY_QTY_MODE", "ENTRY_RISK", "ENTRY_RISK_DEC", "ENTRY_RISK_INC",
                    "ENTRY_SL_CLEAR", "ENTRY_TP_CLEAR", "ENTRY_SL_SET", "ENTRY_TP_SET",
                    "ENTRY_SL_MODE", "ENTRY_TP_MODE", "ENTRY_SELL_PREVIEW", "ENTRY_BUY_PREVIEW"):
        if f'"{control}"' not in ui:
            raise AssertionError(f"Missing Entry control: {control}")
    # The side is never a toggle, and the order type is never a cycling button.
    for removed in ("ENTRY_SIDE", "ENTRY_TYPE", "ENTRY_LIMIT", "ENTRY_STOP"):
        if f'"{removed}"' in ui:
            raise AssertionError(f"Entry must not bring back the {removed} control")
    # Both sides stay visible whenever the tab is, so neither may be gated separately.
    visibility = function(ui, "ApplyTabVisibility")
    if '"ENTRY_SELL", "ENTRY_BUY"' not in visibility:
        raise AssertionError("Both Entry send buttons must share the tab visibility list")
    for send in ('SetVisible("ENTRY_BUY"', 'SetVisible("ENTRY_SELL"'):
        if send in visibility:
            raise AssertionError(f"{send} must not gate a send button on anything but the tab")


def verify_entry_layout(ui: str) -> None:
    """Protect the user-visible Entry row grouping from regressions."""
    rows = {
        "PM_ENTRY_SUBTAB_ROW_Y": ['CreateButton("ENTRY_SUB_MARKET"', 'CreateButton("ENTRY_SUB_LIMIT"',
                                  'CreateButton("ENTRY_SUB_STOP"', 'CreateLabel("ENTRY_PRICE"'],
        "PM_ENTRY_QTY_ROW_Y": ['CreateLabel("ENTRY_QTY_LABEL"', 'CreateButton("ENTRY_QTY_MODE"',
                               'CreateNumericInput("ENTRY_LOT"', 'CreateNumericInput("ENTRY_RISK"',
                               'CreateLabel("ENTRY_ORDER_PRICE_LABEL"', 'CreateNumericInput("ENTRY_ORDER"'],
        "PM_ENTRY_SL_ROW_Y": ['CreateLabel("ENTRY_SL_LABEL"', 'CreateButton("ENTRY_SL_MODE"',
                              'CreateNumericInput("ENTRY_SL"', 'CreateButton("ENTRY_SL_SET"',
                              'CreateButton("ENTRY_SL_CLEAR"'],
        "PM_ENTRY_TP_ROW_Y": ['CreateLabel("ENTRY_TP_LABEL"', 'CreateButton("ENTRY_TP_MODE"',
                              'CreateNumericInput("ENTRY_TP"', 'CreateButton("ENTRY_TP_SET"',
                              'CreateButton("ENTRY_TP_CLEAR"'],
        "PM_ENTRY_SEND_ROW_Y": ['CreateButton("ENTRY_SELL"', 'CreateButton("ENTRY_BUY"'],
    }
    lines = ui.splitlines()
    for row, controls in rows.items():
        for control in controls:
            line = next((item for item in lines if control in item), None)
            if line is None or row not in line:
                raise AssertionError(f"{control} must remain on {row}")


def verify_stop_defaults(ui: str) -> None:
    """SL/TP editors start at 0 (unset), so no line appears until a value is entered."""
    for control in ("SL_VALUE", "TP_VALUE", "ENTRY_SL_VALUE", "ENTRY_TP_VALUE"):
        seeded = (f'CreateEdit("{control}", "0"' in ui or
                  f'"{control}", "0"' in ui)
        if not seeded:
            raise AssertionError(f"{control} must initially display 0")


def verify_status_line_visibility(ui: str) -> None:
    """Unused Status rows hold empty text, which MT5 draws as "Label"."""
    if "line < m_status_line_count" not in function(ui, "ApplyTabVisibility"):
        raise AssertionError("Tab visibility must show only the Status rows in use")


def function(source: str, name: str) -> str:
    match = re.search(r"^\s*\w+\s+" + re.escape(name) + r"\s*\(", source, re.M)
    if not match:
        raise ValueError(f"Missing function: {name}")
    start = source.index("{", match.end())
    depth = 1
    end = start + 1
    while depth:
        if source[end] == "{":
            depth += 1
        elif source[end] == "}":
            depth -= 1
        end += 1
    return source[match.start():end]


def enum_block(source: str, name: str) -> str:
    match = re.search(r"^enum\s+" + re.escape(name) + r"\b", source, re.M)
    if not match:
        raise ValueError(f"Missing enum: {name}")
    start = source.index("{", match.end())
    depth, end = 1, start + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    end = source.index(";", end) + 1
    return source[match.start():end]


def struct_block(source: str, name: str) -> str:
    match = re.search(r"^struct\s+" + re.escape(name) + r"\b", source, re.M)
    if not match:
        raise ValueError(f"Missing struct: {name}")
    start = source.index("{", match.end())
    depth, end = 1, start + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    end = source.index(";", end) + 1
    return source[match.start():end]


def main() -> None:
    compiler = os.environ.get("CXX") or shutil.which("clang++") or shutil.which("g++")
    if not compiler:
        raise SystemExit("A C++17 compiler is required (set CXX or install clang++/g++).")
    helpers = (ROOT / "src/Constants.mqh").read_text()
    models = (ROOT / "src/Models.mqh").read_text()
    tests = (ROOT / "tests/PositionManagerPureTests.mq5").read_text()
    ui_source = (ROOT / "src/UiPanel.mqh").read_text()
    verify_trail_layout(ui_source)
    verify_entry_controls(ui_source)
    verify_entry_layout(ui_source)
    verify_status_line_visibility(ui_source)
    verify_stop_defaults(ui_source)
    enum_names = ["PMEntrySide", "PMEntryOrderType", "PMQuantityMode", "PMEntryInputUnit",
                  "PMTpState", "PMTpEvent", "PMRRStatus"]
    struct_names = ["PMEntrySnapshot", "PMEntryComputation", "PMMarketEntryResult"]
    helper_names = ["PMPointsPerPip", "PMPipsToPointDistance", "PMPipDigits", "PMStepInteger", "PMStepDecimal", "PMPriceEditorStep", "PMShiftPriceEditorValue",
                    "PMNormalizePrice", "PMNormalizeVolume", "PMCalculateAssumedEntryPrice", "PMIsStopLossOnLossSide",
                    "PMIsTakeProfitOnProfitSide", "PMCalculateCurrentRR", "PMCalculateAutoTakeProfit",
                    "PMNextTakeProfitState", "PMCalculateRiskBudget", "PMCalculateRiskLot",
                    "PMRecomputeEntry", "PMIsUnsignedIntegerText", "PMIsUnsignedDecimalText",
                    "PMValidateEntryGeometry", "PMResetMarketEntryResult", "PMIsMarketEntrySuccessRetcode",
                    "PMLabelLineBreak", "PMTruncateLabelText", "PMStopDraftPrice"]
    test_names = ["TestLabelTextLimits", "TestStopDraftPrice", "TestInputStepperHelpers", "TestPriceEditorHelpers",
                  "TestPriceDragLifecycle", "TestPriceEstimateAggregation", "TestPriceLabelPlacement",
                  "TestEntryPricingAndRiskHelpers", "TestEntryRecomputeOrchestration",
                  "TestEntryReviewRegressions"]
    prelude = r"""
#include <algorithm>
#include <cmath>
#include <iostream>
#include <string>
#include <type_traits>
#include <sstream>
#include <iomanip>
#include <map>
using ushort = unsigned short;
using ulong = unsigned long;
const unsigned int TRADE_RETCODE_DONE = 10009, TRADE_RETCODE_DONE_PARTIAL = 10010, TRADE_RETCODE_PLACED = 10008;

using string = std::string;
int StringLen(const string &s) { return (int)s.size(); }
ushort StringGetCharacter(const string &s, int i) { return s.at(i); }
string StringSubstr(const string &s, int start, int length = -1) { return s.substr(start, length < 0 ? string::npos : (size_t)length); }
double StringToDouble(const string &s) { try { return std::stod(s); } catch (...) { return 0.0; } }
string DoubleToString(double v, int digits) { std::ostringstream s; s << std::fixed << std::setprecision(digits) << v; return s.str(); }
template<class T, size_t N> int ArraySize(const T (&)[N]) { return (int)N; }
template<class A, class B> auto MathMax(A a, B b) {
    using T = std::common_type_t<A, B>; return std::max(T(a), T(b));
}
template<class A, class B> auto MathMin(A a, B b) {
    using T = std::common_type_t<A, B>; return std::min(T(a), T(b));
}
double MathAbs(double v) { return std::abs(v); }
double MathCeil(double v) { return std::ceil(v); }
double MathFloor(double v) { return std::floor(v); }
double MathRound(double v) { return std::round(v); }
double MathArcsin(double v) { return std::asin(v); }
double MathExp(double v) { return std::exp(v); }
bool MathIsValidNumber(double v) { return std::isfinite(v); }
double NormalizeDouble(double v, int digits) {
    const double scale = std::pow(10.0, digits);
    return std::round(v * scale) / scale;
}
#include "PriceEditor.mqh"
int failures = 0, assertions = 0;
void AssertTrue(bool condition, const string &name) {
    ++assertions;
    if (!condition) { ++failures; std::cerr << "[FAIL] " << name << '\n'; }
}
"""
    for constant in ("PM_MAX_TRAILING_POINTS", "PM_MAX_EQUITY_THRESHOLD", "PM_MAX_LABEL_TEXT_LENGTH"):
        prelude += re.search(r"^#define " + constant + r" .*", helpers, re.M).group(0) + "\n"
    source = prelude + "\n".join(enum_block(models, name) for name in enum_names) + "\n"
    source += "\n".join(struct_block(models, name) for name in struct_names) + "\n"
    source += "\n".join(function(helpers, name) for name in helper_names)
    source += "\n" + "\n".join(function(tests, name) for name in test_names)
    # Compile actual Entry state/service and UI action bodies against a recording
    # MT5 boundary. No orders leave this process.
    boundary = (ROOT / "tests/entry-test-boundary.cpp").read_text()
    source += "\n" + boundary
    def without_includes(path: str) -> str:
        return "\n".join(line for line in (ROOT / path).read_text().splitlines()
                         if not line.startswith("#include"))
    source += "\n" + without_includes("src/EntryDraft.mqh")
    source += "\nclass CValidationService { public:\n" + function((ROOT / "src/ValidationService.mqh").read_text(), "ValidateEntryPrices") + "\n};\n"
    source += without_includes("src/EntryService.mqh")
    source += "\nclass CTradeManager { public: int m_deviation_points = 10;\n" + function((ROOT / "src/TradeManager.mqh").read_text(), "SubmitEntry") + "\n};\n"
    ui_methods = ["EntryReferenceSide", "EntrySideName", "EntryRRText", "EntryStopPreview", "EntryPreviewText",
                  "EntryQuantityModeLabel", "EntryHintText", "SetEntrySubTabColor", "SetEntryModeVisual", "SetEntrySendVisual",
                  "RefreshEntryComputation", "EntryStopSuffix", "IsEntrySendButton", "WriteEntryStops",
                  "CommitEntryEditor", "CommitEntryEditors", "SetEntryStop", "SwitchEntryUnit", "StepEntryInput",
                  "SelectEntryOrderType", "HandleEntryClick", "OpenEntry", "VolumeDigits", "HandlePriceMouse",
                  "RenderEntryState", "FitEntryLabel",
                  "LabelTextWidth", "LabelFittingCharacters", "SetEntryHint", "EntryPriceLineText",
                  "CancelPriceDrag", "ResetStopEditor"]
    source += "\nclass EntryUiHarness { public: CEntryDraft m_entry_draft; CEntryService m_entry_service; PMEntrySnapshot m_entry_snapshot[2]; PMEntryComputation m_entry_result[2]; bool m_entry_valid[2] = {false, false}; bool m_visibility_dirty = false; string m_entry_reason[2], status; CPriceEditDrag m_price_drag; string Name(const string s) { return s; } void SetStatus(const string s) { status = s; }\n"
    source += r"""
    bool m_collapsed = false, m_price_scroll_before = true, m_price_drag_moved = false;
    int m_active_tab = PM_PANEL_TAB_ENTRY, m_origin_x = 0, m_origin_y = 0, m_panel_width = 560;
    int m_price_mouse_start_y = 0;
    double m_price_mouse_start_price = 0;
    string m_price_line_selection_key = "Entry", m_stop_committed[2];
    bool m_price_line_visible[2] = {true, true};
    int m_price_label_x[2] = {800, 800}, m_price_label_y[2] = {200, 250};
    int m_price_label_width[2] = {100, 100}, m_price_label_height[2] = {40, 40};
    int m_price_line_y[2] = {200, 250};
    double m_price_line_price[2] = {98, 102};
    bool EntryPriceContext() { return m_active_tab == PM_PANEL_TAB_ENTRY; }
    bool SelectedPriceSymbol() { return true; }
    int PanelHeight() { return 350; }
    string StopSuffix(int i) { return i == 0 ? "SL_VALUE" : "TP_VALUE"; }
    void SyncPriceContext() {} // Tests below keep the interaction context fixed.
    bool PriceText(const string name, const string text) { return ObjectSetString(0, name, OBJPROP_TEXT, text); }
    bool PriceInteger(const string name, int property, long value) { object_properties[{name, property}] = value; return true; }
    void Render() { RenderEntryState(); }
"""
    source += "\n".join(function(ui_source, name) for name in ui_methods) + "\n};\n"
    source += (ROOT / "tests/entry-integration-tests.cpp").read_text()
    source += "\nint main() {\n" + "\n".join(name + "();" for name in test_names)
    source += "\nTestEntryIntegration();\n"
    source += r"""
std::cout << assertions << " portable assertions, " << failures << " failures\n";
return failures ? 1 : 0;
}
"""
    with tempfile.TemporaryDirectory(prefix="pm-price-editor-") as directory:
        cpp = Path(directory) / "tests.cpp"
        binary = Path(directory) / "tests"
        cpp.write_text(source)
        subprocess.run([compiler, "-std=c++17", "-Wall", "-Wextra", "-Werror",
                        "-I", str(ROOT / "src"), str(cpp), "-o", str(binary)], check=True)
        subprocess.run([str(binary)], check=True)


if __name__ == "__main__":
    main()
