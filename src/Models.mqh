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
   PM_PRICE_POINTS = 1
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

enum PMTradeOperationType
  {
   PM_TRADE_OPERATION_CLOSE = 0,
   PM_TRADE_OPERATION_MODIFY = 1
  };

enum PMTradeAttemptStatus
  {
   PM_TRADE_ATTEMPT_SUCCESS = 0,
   PM_TRADE_ATTEMPT_QUEUED = 1,
   PM_TRADE_ATTEMPT_FAILED = 2
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
   int queued;
   PMTradeFailure failures[];
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
   int be_trigger_points;
   int be_lock_points;
   int trail_points;
  };

#endif
