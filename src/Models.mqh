#ifndef __MT5_POSITION_MANAGER_MODELS_MQH__
#define __MT5_POSITION_MANAGER_MODELS_MQH__

enum PMDirection
  {
   PM_DIRECTION_LONG = 0,
   PM_DIRECTION_SHORT = 1,
   PM_DIRECTION_BOTH = 2
  };

enum PMPriceMode
  {
   PM_PRICE_ABSOLUTE = 0,
   PM_PRICE_PIPS = 1
  };

enum PMPassedCloseBehavior
  {
   PM_PASSED_CLOSE_DO_NOTHING = 0,
   PM_PASSED_CLOSE_IMMEDIATELY = 1
  };

enum PMEquityThresholdMode
  {
   PM_EQUITY_THRESHOLD_AMOUNT = 0,
   PM_EQUITY_THRESHOLD_PERCENT = 1
  };

enum PMTrailBasis
  {
   // Keep the zero value aligned with the requested per-position default.
   PM_TRAIL_BASIS_PER_POSITION = 0,
   PM_TRAIL_BASIS_AVERAGE = 1
  };

enum PMPanelTab
  {
   PM_PANEL_TAB_ENTRY = 0,
   PM_PANEL_TAB_POSITIONS = 1,
   PM_PANEL_TAB_STOPS = 2,
   PM_PANEL_TAB_AUTO = 3,
   PM_PANEL_TAB_GUARD = 4,
   PM_PANEL_TAB_TRAIL = 5
  };

enum PMEntrySide
  {
   PM_ENTRY_BUY = 0,
   PM_ENTRY_SELL = 1
  };

enum PMEntryOrderType
  {
   PM_ENTRY_ORDER_MARKET = 0,
   PM_ENTRY_ORDER_LIMIT = 1,
   PM_ENTRY_ORDER_STOP = 2
  };

enum PMQuantityMode
  {
   PM_QUANTITY_MANUAL_LOT = 0,
   PM_QUANTITY_RISK_AMOUNT = 1,
   PM_QUANTITY_RISK_PERCENT = 2
  };

enum PMEntryInputUnit
  {
   PM_ENTRY_UNIT_POINTS = 0,
   PM_ENTRY_UNIT_PRICE = 1
  };

enum PMTpState
  {
   PM_TP_STATE_AUTO = 0,
   PM_TP_STATE_MANUAL = 1,
   PM_TP_STATE_OFF = 2
  };

enum PMTpEvent
  {
   PM_TP_EVENT_SL_CHANGED = 0,
   PM_TP_EVENT_SL_CANCELED = 1,
   PM_TP_EVENT_TP_SET_MANUAL = 2,
   PM_TP_EVENT_TP_CANCELED = 3,
   PM_TP_EVENT_REVERT_TO_AUTO = 4,
   PM_TP_EVENT_RR_CHANGED = 5
  };

enum PMRRStatus
  {
   PM_RR_VALID = 0,
   PM_RR_NOT_AVAILABLE = 1,
   PM_RR_INVALID = 2
  };

enum PMTradeOperationType
  {
   PM_TRADE_OPERATION_CLOSE = 0,
   PM_TRADE_OPERATION_MODIFY = 1
  };

enum PMTradeAttemptStatus
  {
   PM_TRADE_ATTEMPT_SUCCESS = 0,
   PM_TRADE_ATTEMPT_QUEUED = 1,
   PM_TRADE_ATTEMPT_FAILED = 2,
   PM_TRADE_ATTEMPT_UNCHANGED = 3
  };

enum PMStatusSeverity
  {
   PM_STATUS_NORMAL = 0,
   PM_STATUS_SUCCESS = 1,
   PM_STATUS_WARNING = 2,
   PM_STATUS_ERROR = 3
  };

struct PMPosition
  {
   ulong ticket;
   string symbol;
   ENUM_POSITION_TYPE type;
   double volume;
   double open_price;
   double current_price;
   double sl;
   double tp;
   double profit;
  };

struct PMTradeFailure
  {
   ulong ticket;
   uint retcode;
   string description;
   int attempts;
  };

struct PMPendingTrade
  {
   PMTradeOperationType operation;
   ulong ticket;
   double sl;
   double tp;
   int attempts;
   datetime next_attempt_at;
   bool wait_only;
   bool terminal_failure;
   uint last_retcode;
   string last_description;
  };

struct PMBatchResult
  {
   int requested;
   int successful;
   int unchanged;
   int queued;
   PMTradeFailure failures[];
  };

struct PMMarketEntryResult
  {
   bool request_ok;
   uint retcode;
   string description;
   ulong deal;
   ulong order;
   double volume;
   double price;
  };

struct PMEntrySnapshot
  {
   PMEntryOrderType order_type;
   PMEntrySide side;
   double bid;
   double ask;
   double order_price;      // Limit/Stop only; ignored for Market.
   double point;
   double tick_size;
   int digits;
   long stops_level;
   long freeze_level;
   double sl_price;         // 0.0 means SL is not set.
   double tp_price;         // The currently committed TP price; 0.0 when TP state is Off or not yet set.
   PMTpState tp_state;
   double rr_multiplier;
   PMQuantityMode quantity_mode;
   double manual_lot;
   double risk_amount;
   double risk_percent;
   double balance;
   double reference_volume; // e.g. 1.0, the probe volume the caller used for reference_loss.
   double reference_loss;   // Caller's own OrderCalcProfit(reference_volume, entry, sl) magnitude; 0.0 if not computed/unavailable.
   double volume_min;
   double volume_max;
   double volume_step;
  };

struct PMEntryComputation
  {
   bool entry_ok;
   double entry;
   string entry_reason;
   double effective_tp;     // tp_price for Manual, zero for Off, or the freshly computed Auto price.
   bool tp_auto_ok;         // Only meaningful when tp_state == PM_TP_STATE_AUTO.
   string tp_reason;
   PMRRStatus rr_status;
   double rr;
   string rr_reason;
   bool lot_ok;
   double lot;
   double estimated_loss;   // Only meaningful for Risk Amount / Risk Percent mode; see PMRecomputeEntry.
   string lot_reason;
  };

struct AutoCloseConfig
  {
   bool enabled;
   string symbol;
   PMDirection direction;
   int minutes_before_close;
   PMPassedCloseBehavior passed_behavior;
  };

struct EquityGuardConfig
  {
   bool enabled;
   PMEquityThresholdMode mode;
   double loss_threshold;
   double profit_threshold;
  };

struct TrailingStopConfig
  {
   bool enabled_break_even;
   bool enabled_trailing;
   string symbol;
   PMDirection direction;
   PMTrailBasis basis;
   int be_trigger_points;
   int be_lock_points;
   int trail_trigger_points;
   int trail_points;
  };

#endif
