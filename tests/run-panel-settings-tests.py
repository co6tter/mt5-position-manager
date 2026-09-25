#!/usr/bin/env python3
"""Exercise the MQL panel settings store with a recording file boundary."""

from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

PRELUDE = r'''
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <map>
#include <sstream>
#include <string>
#include <vector>
using string = std::string;
using uint = unsigned int;
enum PMDirection { PM_DIRECTION_LONG, PM_DIRECTION_SHORT, PM_DIRECTION_BOTH };
enum PMPassedCloseBehavior { PM_PASSED_CLOSE_DO_NOTHING, PM_PASSED_CLOSE_IMMEDIATELY };
enum PMEquityThresholdMode { PM_EQUITY_THRESHOLD_AMOUNT, PM_EQUITY_THRESHOLD_PERCENT };
enum PMTrailBasis { PM_TRAIL_BASIS_PER_POSITION, PM_TRAIL_BASIS_AVERAGE };
#define PM_MAX_AUTO_CLOSE_MINUTES 1440
#define PM_MAX_TRAILING_POINTS 1000000
#define PM_MAX_EQUITY_THRESHOLD 1000000000.0
enum { FILE_READ = 1, FILE_WRITE = 2, FILE_CSV = 8, FILE_UNICODE = 64,
       FILE_REWRITE = 512, INVALID_HANDLE = -1 };
int StringLen(const string& s) { return int(s.size()); }
int StringGetCharacter(const string& s, int i) { return int((unsigned char)s.at(i)); }
long StringToInteger(const string& s) { return std::strtol(s.c_str(), nullptr, 10); }
double StringToDouble(const string& s) { return std::strtod(s.c_str(), nullptr); }
string IntegerToString(long n) { return std::to_string(n); }
bool MathIsValidNumber(double n) { return std::isfinite(n); }
string DoubleToString(double n, int digits) {
    std::ostringstream out; out << std::fixed << std::setprecision(digits) << n;
    return out.str();
}
string StringFormat(const string&, long chart, long account, long server) {
    return "settings_" + std::to_string(chart) + "_" + std::to_string(account) +
           "_" + std::to_string(server) + ".csv";
}
struct OpenFile { string path; bool write; std::vector<string> fields; size_t next = 0; };
std::map<string, string> disk;
std::map<int, OpenFile> opened;
int next_handle = 1;
string last_destination;
bool fail_move = false;
string Field(const string& s) { return s; }
string Field(const char* s) { return s; }
template<class T> string Field(T value) { return std::to_string(value); }
int FileOpen(const string& path, int flags, char) {
    bool write = flags & FILE_WRITE;
    if (!write && !disk.count(path)) return INVALID_HANDLE;
    OpenFile file{path, write, {}, 0};
    if (!write) {
        std::istringstream in(disk[path]); string field;
        while (std::getline(in, field, '\t')) {
            if (!field.empty() && field.back() == '\n') field.pop_back();
            file.fields.push_back(field);
        }
    }
    int handle = next_handle++; opened[handle] = file; return handle;
}
template<class... T> uint FileWrite(int handle, T... values) {
    opened[handle].fields = {Field(values)...};
    return uint(opened[handle].fields.size());
}
void FileFlush(int) {}
void FileClose(int handle) {
    OpenFile file = opened.at(handle);
    if (file.write) {
        std::ostringstream out;
        for (size_t i = 0; i < file.fields.size(); ++i) {
            if (i) out << '\t';
            out << file.fields[i];
        }
        out << '\n'; disk[file.path] = out.str();
    }
    opened.erase(handle);
}
bool FileMove(const string& from, int, const string& to, int) {
    if (fail_move || !disk.count(from)) return false;
    disk[to] = disk[from]; disk.erase(from); last_destination = to; return true;
}
bool FileIsEnding(int handle) { return opened.at(handle).next >= opened.at(handle).fields.size(); }
string FileReadString(int handle) {
    OpenFile& file = opened.at(handle); return file.fields.at(file.next++);
}
void Check(bool ok, const string& label) {
    if (!ok) { std::cerr << "[FAIL] " << label << '\n'; std::exit(1); }
}
'''

TESTS = r'''
PMPanelSettings Defaults() {
    PMPanelSettings s{};
    s.auto_minutes = 10;
    s.auto_direction = PM_DIRECTION_BOTH;
    s.passed_behavior = PM_PASSED_CLOSE_DO_NOTHING;
    s.equity_guard_mode = PM_EQUITY_THRESHOLD_AMOUNT;
    s.trailing_direction = PM_DIRECTION_BOTH;
    s.trail_basis = PM_TRAIL_BASIS_PER_POSITION;
    return s;
}
int main() {
    CPanelSettingsStore first;
    first.Configure(123, 456, "broker-A");
    PMPanelSettings empty = Defaults();
    Check(!first.Load(empty) && !empty.auto_enabled && empty.auto_minutes == 10,
          "missing file preserves defaults");
    PMPanelSettings saved = Defaults();
    saved.auto_enabled = true;
    saved.auto_symbol = "XAUUSD";
    saved.auto_direction = PM_DIRECTION_SHORT;
    saved.auto_minutes = 42;
    saved.passed_behavior = PM_PASSED_CLOSE_IMMEDIATELY;
    saved.equity_guard_enabled = true;
    saved.equity_guard_mode = PM_EQUITY_THRESHOLD_PERCENT;
    saved.equity_guard_loss_threshold = 7.25;
    saved.equity_guard_profit_threshold = 9.50;
    saved.trailing_symbol = "USDJPY";
    saved.trailing_direction = PM_DIRECTION_LONG;
    saved.trail_basis = PM_TRAIL_BASIS_AVERAGE;
    saved.break_even_enabled = true;
    saved.trailing_enabled = true;
    saved.be_trigger_pips = 10;
    saved.be_lock_pips = 2;
    saved.trail_trigger_pips = 15;
    saved.trail_pips = 5;
    Check(first.Save(saved), "save all automatic settings");
    string first_path = last_destination;
    CPanelSettingsStore restarted;
    restarted.Configure(123, 456, "broker-A");
    PMPanelSettings loaded = Defaults();
    Check(restarted.Load(loaded), "reload after EA recreation");
    Check(loaded.auto_enabled && loaded.auto_symbol == "XAUUSD" &&
          loaded.auto_direction == PM_DIRECTION_SHORT && loaded.auto_minutes == 42 &&
          loaded.passed_behavior == PM_PASSED_CLOSE_IMMEDIATELY,
          "Auto Close settings survive");
    Check(loaded.equity_guard_enabled && loaded.equity_guard_mode == PM_EQUITY_THRESHOLD_PERCENT &&
          loaded.equity_guard_loss_threshold == 7.25 && loaded.equity_guard_profit_threshold == 9.50,
          "Equity Guard settings survive");
    Check(loaded.trailing_symbol == "USDJPY" && loaded.trailing_direction == PM_DIRECTION_LONG &&
          loaded.trail_basis == PM_TRAIL_BASIS_AVERAGE && loaded.break_even_enabled &&
          loaded.trailing_enabled && loaded.be_trigger_pips == 10 && loaded.be_lock_pips == 2 &&
          loaded.trail_trigger_pips == 15 && loaded.trail_pips == 5,
          "Trail settings survive");
    CPanelSettingsStore other_account;
    other_account.Configure(123, 457, "broker-A");
    PMPanelSettings other = Defaults();
    Check(!other_account.Load(other) && !other.auto_enabled,
          "different account starts with defaults");
    CPanelSettingsStore other_server;
    other_server.Configure(123, 456, "broker-B");
    Check(!other_server.Load(other), "same login on another server is isolated");
    CPanelSettingsStore other_chart;
    other_chart.Configure(124, 456, "broker-A");
    Check(!other_chart.Load(other), "another chart is isolated");
    CPanelSettingsStore no_account;
    no_account.Configure(123, 0, "broker-A");
    Check(!no_account.Save(saved) && !no_account.Load(other),
          "disconnected account cannot share a settings file");
    saved.auto_enabled = false;
    fail_move = true;
    Check(!first.Save(saved), "failed replacement is reported");
    fail_move = false;
    Check(restarted.Load(loaded) && loaded.auto_enabled,
          "failed replacement keeps the previous settings");
    Check(first.Save(saved) && restarted.Load(loaded) && !loaded.auto_enabled,
          "OFF transition is persisted immediately");
    disk[first_path] = "1\t1\tXAUUSD\t1\t42\t1\t1\t1\t7.25\t9.50\tUSDJPY\t0\t1\t1\t1\t10\t2\t15\t9999999\tbroker-A\n";
    PMPanelSettings unchanged = Defaults();
    Check(!restarted.Load(unchanged) && unchanged.auto_minutes == 10 && !unchanged.auto_enabled,
          "invalid file does not partially restore settings");
    disk[first_path] = "1\t1\tXAUUSD\t1\t42\t1\t1\t1\t.\t9.50\tUSDJPY\t0\t1\t1\t1\t10\t2\t15\t5\tbroker-A\n";
    Check(!restarted.Load(unchanged), "malformed decimal is rejected");
    disk[first_path] = "1\t1\tXAUUSD\t1\t42\t1\t1\t1\t7.25\t9.50\tUSDJPY\t0\t1\t1\t1\t10\t2\t15\t5\tbroker-B\n";
    Check(!restarted.Load(unchanged), "mismatched server identity is rejected");
    disk[first_path] = "1\t1\tXAUUSD\t1\t42\t1\t1\t1\t7.25\t9.50\tUSDJPY\t0\t1\t1\t1\t10\t2\n";
    Check(!restarted.Load(unchanged), "truncated file is rejected");
    std::cout << "Panel settings round-trip, isolation and corruption checks passed\n";
}
'''


def main() -> None:
    ui = (ROOT / "src/UiPanel.mqh").read_text()
    ea = (ROOT / "src/PositionManager.mq5").read_text()
    for needle in ("LoadPanelSettings();", "WritePanelSettingsInputs();",
                   "if(IsAutomaticSettingControl(object_name)) SaveSettings();"):
        if needle not in ui:
            raise AssertionError(f"UI persistence path missing: {needle}")
    if "ResetPanelSettingsDefaults();\n      LoadPanelSettings();" not in ui:
        raise AssertionError("a new account must not inherit the previous account's live settings")
    if "g_ui.SaveSettings();" not in ea:
        raise AssertionError("EA deinitialization must save automatic settings")
    source = (ROOT / "src/PanelSettings.mqh").read_text()
    source = re.sub(r"^#.*$", "", source, flags=re.M)
    compiler = shutil.which("clang++") or shutil.which("g++")
    if not compiler:
        raise SystemExit("A C++17 compiler is required.")
    with tempfile.TemporaryDirectory(prefix="pm-panel-settings-") as directory:
        cpp = Path(directory) / "test.cpp"
        binary = Path(directory) / "test"
        cpp.write_text(PRELUDE + source + TESTS)
        subprocess.run([compiler, "-std=c++17", "-Wall", "-Wextra", "-Werror",
                        str(cpp), "-o", str(binary)], check=True)
        subprocess.run([str(binary)], check=True)


if __name__ == "__main__":
    main()
