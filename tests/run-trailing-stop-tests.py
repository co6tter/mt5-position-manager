#!/usr/bin/env python3
"""Exercise the actual Trail resolver/service and shared MQL tests as C++.

Only MQL array syntax is adapted. Terminal position, quote, validation and
trade boundaries are simulated; this does not verify MQL compilation, broker
rules, chart events, font metrics or actual trading. Requires Python 3 and C++17.
"""

import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def function(source: str, name: str) -> str:
    match = re.search(r"^\w+\s+" + re.escape(name) + r"\s*\(", source, re.M)
    if not match:
        raise ValueError(f"Missing function: {name}")
    start = source.index("{", match.end())
    depth, end = 1, start + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[match.start():end]


def arrays(source: str) -> str:
    source = re.sub(r"\b(const\s+)?(\w+)\s+&(\w+)\[\]",
                    lambda m: f"{m[1] or ''}std::vector<{m[2]}> &{m[3]}", source)
    source = re.sub(r"\b(\w+)\s+(\w+)\[\d*\](\s*[;=])",
                    r"std::vector<\1> \2\3", source)
    return source


PRELUDE = r"""
#include <algorithm>
#include <cmath>
#include <iostream>
#include <string>
#include <vector>
using string = std::string;
using ulong = unsigned long;
using uint = unsigned int;
using datetime = long;
enum ENUM_POSITION_TYPE { POSITION_TYPE_BUY, POSITION_TYPE_SELL };
enum { SYMBOL_POINT };
template<class T> int ArraySize(const std::vector<T>& a) { return int(a.size()); }
template<class T> int ArrayResize(std::vector<T>& a, int n) { a.resize(n); return n; }
template<class T> void ArrayInitialize(std::vector<T>& a, T v) { std::fill(a.begin(), a.end(), v); }
template<class T> T MathMax(T a, T b) { return std::max(a, b); }
bool MathIsValidNumber(double x) { return std::isfinite(x); }
double MathAbs(double x) { return std::abs(x); }
double SymbolInfoDouble(const string&, int) { return 0.0001; }
template<class... T> void PrintFormat(const string&, T...) {}
template<class... T> string StringFormat(const string&, T...) { return "status"; }
int failures = 0, assertions = 0;
void AssertTrue(bool condition, const string& name) {
    ++assertions;
    if (!condition) { ++failures; std::cerr << "[FAIL] " << name << '\n'; }
}
"""

BOUNDARIES = r"""
class CPositionService {
public:
    std::vector<PMPosition> live;
    bool Get(ulong ticket, PMPosition& out) {
        for (const auto& p : live) if (p.ticket == ticket) { out = p; return true; }
        return false;
    }
};
class CTradeManager {
public:
    std::vector<ulong> pending, sent;
    std::vector<double> stops, take_profits;
    bool HasPending(ulong ticket) {
        return std::find(pending.begin(), pending.end(), ticket) != pending.end();
    }
    PMTradeAttemptStatus ModifyTicket(ulong ticket, double sl, double tp, PMTradeFailure&) {
        sent.push_back(ticket); stops.push_back(sl); take_profits.push_back(tp);
        return PM_TRADE_ATTEMPT_SUCCESS;
    }
};
class CValidationService {
public:
    // Each validation reads a fresh quote in production. A scripted response
    // makes quote movement between ticket sends deterministic in this test.
    std::vector<bool> responses;
    int calls = 0;
    bool CalculateTarget(const PMPosition&, bool, PMPriceMode, double value,
                         double& target, string& reason) {
        target = value;
        reason = "simulated quote change";
        bool accepted = calls < int(responses.size()) ? responses[calls] : true;
        ++calls;
        return accepted;
    }
};
"""


def main() -> None:
    compiler = os.environ.get("CXX") or shutil.which("clang++") or shutil.which("g++")
    if not compiler:
        raise SystemExit("A C++17 compiler is required (set CXX or install clang++/g++).")
    constants = (ROOT / "src/Constants.mqh").read_text()
    tests = (ROOT / "tests/PositionManagerPureTests.mq5").read_text()
    service = (ROOT / "src/TrailingStopService.mqh").read_text()
    service = re.sub(r'^#include .*$', '', service, flags=re.M)
    names = ["TestBreakEvenCandidate", "TestTrailingCandidate", "TestPositionBasket",
             "TestTrailBasisToggle", "TestResolveTrailingCandidatesBasisSelection",
             "TestResolveTrailingCandidatesSharedCandidate",
             "TestResolveTrailingCandidatesPendingExclusion",
             "TestResolveTrailingCandidatesSellAndScope",
             "TestIsMoreFavorableStop", "TestBestStopCandidate", "TestPanelLayoutHelpers"]
    helpers = ["PMProfitPoints", "PMDirectionMatches", "PMPositionTypeToString",
               "PMToggleTrailBasis", "PMTrailBasisToString", "PMResolvePanelHeight"]
    defines = "\n".join(line for line in constants.splitlines()
                        if re.match(r"#define PM_(?:PANEL_|TRAIL_|STOPS_|MIN_PANEL_WIDTH)", line))
    source = PRELUDE + arrays((ROOT / "src/Models.mqh").read_text()) + defines + "\n"
    source += "\n".join(function(constants, name) for name in helpers)
    source += BOUNDARIES + arrays(service)
    source += "\n".join(arrays(function(tests, name)) for name in names)
    source += (ROOT / "tests/trailing-stop-service-tests.cpp").read_text()
    source += "\nint main() {\n" + "\n".join(name + "();" for name in names)
    source += r"""
TestServiceValidationUnit();
TestServicePendingAndRatchet();
std::cout << assertions << " Trail assertions, " << failures << " failures\n";
return failures ? 1 : 0;
}
"""
    with tempfile.TemporaryDirectory(prefix="pm-trailing-stop-") as directory:
        cpp = Path(directory) / "tests.cpp"
        binary = Path(directory) / "tests"
        cpp.write_text(source)
        print("Compiling Trail helper and service tests...", flush=True)
        subprocess.run([compiler, "-std=c++17", "-Wall", "-Wextra", "-Werror",
                        str(cpp), "-o", str(binary)], check=True, timeout=60)
        print("Running Trail tests...", flush=True)
        subprocess.run([str(binary)], check=True, timeout=30)


if __name__ == "__main__":
    main()
