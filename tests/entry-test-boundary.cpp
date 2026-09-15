// Recording boundary for Entry tests. These functions never access MT5.
const string _Symbol = "TEST";
enum { SYMBOL_POINT, SYMBOL_TRADE_TICK_SIZE, SYMBOL_VOLUME_MIN, SYMBOL_VOLUME_MAX, SYMBOL_VOLUME_STEP,
       SYMBOL_DIGITS, SYMBOL_TRADE_STOPS_LEVEL, SYMBOL_TRADE_FREEZE_LEVEL, SYMBOL_ORDER_MODE,
       SYMBOL_EXPIRATION_MODE, SYMBOL_FILLING_MODE, SYMBOL_TRADE_EXEMODE,
       ACCOUNT_BALANCE, ACCOUNT_CURRENCY_DIGITS, ACCOUNT_CURRENCY, OBJPROP_TEXT,
       OBJPROP_TOOLTIP, OBJPROP_FONTSIZE, OBJPROP_COLOR, OBJPROP_READONLY, OBJPROP_BGCOLOR };
enum { SYMBOL_ORDER_MARKET = 1, SYMBOL_ORDER_LIMIT = 2, SYMBOL_ORDER_STOP = 4, SYMBOL_ORDER_SL = 16,
       SYMBOL_ORDER_TP = 32, SYMBOL_EXPIRATION_GTC = 1, SYMBOL_FILLING_FOK = 1, SYMBOL_FILLING_IOC = 2,
       SYMBOL_TRADE_EXECUTION_MARKET = 2 };
enum ENUM_ORDER_TYPE { ORDER_TYPE_BUY, ORDER_TYPE_SELL, ORDER_TYPE_BUY_LIMIT, ORDER_TYPE_SELL_LIMIT,
                       ORDER_TYPE_BUY_STOP, ORDER_TYPE_SELL_STOP };
enum { TRADE_ACTION_DEAL, TRADE_ACTION_PENDING, ORDER_FILLING_RETURN, ORDER_FILLING_FOK, ORDER_FILLING_IOC, ORDER_TIME_GTC };
struct MqlTick { double bid = 99.9, ask = 100.0; };
struct MqlTradeRequest {
    int action = 0; string symbol; double volume = 0, price = 0, sl = 0, tp = 0;
    ENUM_ORDER_TYPE type = ORDER_TYPE_BUY;
    int type_time = 0, type_filling = 0, deviation = 0; string comment;
};
struct MqlTradeResult { unsigned int retcode = TRADE_RETCODE_DONE; string comment; unsigned long deal = 1, order = 2; double volume = 0, price = 0; };
struct MqlTradeCheckResult { unsigned int retcode = 0; string comment; };
std::map<int, double> symbol_values;
std::map<string, string> objects;
MqlTick current_tick;
MqlTradeRequest checked_request, sent_request;
int checks = 0, sends = 0;
bool check_ok = true, send_ok = true, profit_ok = true;
unsigned int check_code = 0, send_code = TRADE_RETCODE_DONE;
double balance = 10000.0, loss_multiplier = 125.0, final_loss_factor = 1.0;
void ResetBoundary() {
    symbol_values = {{SYMBOL_POINT, .01}, {SYMBOL_TRADE_TICK_SIZE, .01}, {SYMBOL_VOLUME_MIN, .01},
        {SYMBOL_VOLUME_MAX, 100.0}, {SYMBOL_VOLUME_STEP, .01}, {SYMBOL_DIGITS, 2},
        {SYMBOL_TRADE_STOPS_LEVEL, 0}, {SYMBOL_TRADE_FREEZE_LEVEL, 0},
        {SYMBOL_ORDER_MODE, 55}, {SYMBOL_EXPIRATION_MODE, 1}, {SYMBOL_FILLING_MODE, 1}, {SYMBOL_TRADE_EXEMODE, 2}};
    objects = {{"ENTRY_ORDER_PRICE", ""}, {"ENTRY_LOT", "0.01"}, {"ENTRY_RISK", "0"},
               {"ENTRY_SL_VALUE", "0"}, {"ENTRY_TP_VALUE", "0"}};
    current_tick = {}; checks = sends = 0; check_ok = send_ok = profit_ok = true;
    check_code = 0; send_code = TRADE_RETCODE_DONE; balance = 10000.0; final_loss_factor = 1.0;
}
double SymbolInfoDouble(const string &, int property) { return symbol_values[property]; }
long SymbolInfoInteger(const string &, int property) { return (long)symbol_values[property]; }
bool SymbolInfoTick(const string &, MqlTick &tick) { tick = current_tick; return tick.bid > 0 && tick.ask > 0; }
double AccountInfoDouble(int) { return balance; }
long AccountInfoInteger(int) { return 2; }
string AccountInfoString(int) { return "USD"; }
bool OrderCalcProfit(ENUM_ORDER_TYPE side, const string &, double volume, double entry, double exit, double &profit) {
    if(!profit_ok || volume < symbol_values[SYMBOL_VOLUME_MIN] || volume > symbol_values[SYMBOL_VOLUME_MAX]) return false;
    profit = (exit - entry) * volume * loss_multiplier * (side == ORDER_TYPE_BUY ? 1 : -1);
    if(volume > symbol_values[SYMBOL_VOLUME_MIN]) profit *= final_loss_factor;
    return true;
}
bool OrderCheck(MqlTradeRequest &request, MqlTradeCheckResult &result) {
    ++checks; checked_request = request; result.retcode = check_code; result.comment = check_ok ? "" : "Check rejected"; return check_ok;
}
bool OrderSend(MqlTradeRequest &request, MqlTradeResult &result) {
    ++sends; sent_request = request; result.retcode = send_code; result.volume = request.volume;
    result.price = request.price; return send_ok;
}
void ResetLastError() {}
int GetLastError() { return 0; }
template<class... Args> void PrintFormat(const string &, Args...) {}
template<class... Args> string StringFormat(const string &format, Args...) { return format; }
string PMFormatPrice(const string &, double price) { return DoubleToString(price, 2); }
string ObjectGetString(int, const string &name, int) { return objects[name]; }
bool ObjectSetString(int, const string &name, int property, const string &value) { if(property == OBJPROP_TEXT) objects[name] = value; return true; }

using datetime = long;
const int CHART_MOUSE_SCROLL = 900;
const int PM_PANEL_TAB_ENTRY = 0, PM_PANEL_TAB_STOPS = 2;
bool mouse_scroll = true;
bool ChartGetInteger(int, int, int, long &value) { value = mouse_scroll; return true; }
bool ChartSetInteger(int, int, bool value) { mouse_scroll = value; return true; }
bool ChartXYToTimePrice(int, int, int y, int &window, datetime &time, double &price) {
    window = 0; time = 1; price = 100.0 - y * .01; return true;
}

const int clrDarkGreen = 1, clrMaroon = 2, clrWhite = 3, clrSilver = 4, FW_NORMAL = 400;
std::map<std::pair<string, int>, long> object_properties;
bool TextSetFont(const string &, int, int) { return true; }
bool TextGetSize(const string &text, unsigned int &width, unsigned int &height) { width = text.size() * 6; height = 12; return true; }
