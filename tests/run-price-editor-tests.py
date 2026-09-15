#!/usr/bin/env python3
"""Run the chart-independent price editor tests without MT5.

Checks the Trail control grouping/defaults, then compiles the actual MQL helper
bodies and shared test functions as C++. It does not validate MQL compilation,
chart events, font metrics, trade APIs, or any other MT5 integration.
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


def function(source: str, name: str) -> str:
    match = re.search(r"^(?:int|double|void)\s+" + re.escape(name) + r"\s*\(", source, re.M)
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


def main() -> None:
    compiler = os.environ.get("CXX") or shutil.which("clang++") or shutil.which("g++")
    if not compiler:
        raise SystemExit("A C++17 compiler is required (set CXX or install clang++/g++).")
    helpers = (ROOT / "src/Constants.mqh").read_text()
    tests = (ROOT / "tests/PositionManagerPureTests.mq5").read_text()
    verify_trail_layout((ROOT / "src/UiPanel.mqh").read_text())
    helper_names = ["PMStepInteger", "PMStepDecimal", "PMPriceEditorStep", "PMShiftPriceEditorValue"]
    test_names = ["TestInputStepperHelpers", "TestPriceEditorHelpers",
                  "TestPriceDragLifecycle", "TestPriceEstimateAggregation", "TestPriceLabelPlacement"]
    prelude = r"""
#include <algorithm>
#include <cmath>
#include <iostream>
#include <string>
#include <type_traits>
using string = std::string;
template<class A, class B> auto MathMax(A a, B b) {
    using T = std::common_type_t<A, B>; return std::max(T(a), T(b));
}
template<class A, class B> auto MathMin(A a, B b) {
    using T = std::common_type_t<A, B>; return std::min(T(a), T(b));
}
double MathAbs(double v) { return std::abs(v); }
double MathCeil(double v) { return std::ceil(v); }
double MathFloor(double v) { return std::floor(v); }
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
    source = prelude + "\n".join(function(helpers, name) for name in helper_names)
    source += "\n" + "\n".join(function(tests, name) for name in test_names)
    source += "\nint main() {\n" + "\n".join(name + "();" for name in test_names)
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
