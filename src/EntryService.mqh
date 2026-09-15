#ifndef __MT5_POSITION_MANAGER_ENTRY_SERVICE_MQH__
#define __MT5_POSITION_MANAGER_ENTRY_SERVICE_MQH__
#include "EntryDraft.mqh"
#include "ValidationService.mqh"

class CEntryService
  {
public:
   bool Evaluate(const string symbol, CEntryDraft &draft,
                  const int drag_index, const double drag_price,
                  PMEntrySnapshot &snapshot, PMEntryComputation &result,
                  string &reason)
     {
      PMEntrySnapshot empty = {};
      snapshot = empty;
      MqlTick tick = {};
      SymbolInfoTick(symbol, tick);
      snapshot.bid = tick.bid; snapshot.ask = tick.ask;
      snapshot.point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      snapshot.tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      snapshot.digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      snapshot.stops_level = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
      snapshot.freeze_level = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
      snapshot.volume_min = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      snapshot.volume_max = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      snapshot.volume_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      snapshot.balance = AccountInfoDouble(ACCOUNT_BALANCE);
      const bool inputs_ok = draft.Resolve(snapshot, drag_index, drag_price, reason);
      double entry = 0.0;
      string entry_reason = "";
      PMCalculateAssumedEntryPrice(snapshot.order_type, snapshot.side, tick.bid, tick.ask,
                                   snapshot.order_price, entry, entry_reason);
      snapshot.reference_volume = snapshot.volume_min;
      double profit = 0.0;
      if(PMIsStopLossOnLossSide(snapshot.side, entry, snapshot.sl_price) &&
         OrderCalcProfit(snapshot.side == PM_ENTRY_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                          symbol, snapshot.reference_volume, entry, snapshot.sl_price, profit) &&
         MathIsValidNumber(profit) && profit < 0.0)
         snapshot.reference_loss = -profit;
      PMRecomputeEntry(snapshot, result);
      if(drag_index < 0 && snapshot.tp_state == PM_TP_STATE_AUTO && result.tp_auto_ok)
         draft.last_auto_tp = result.effective_tp;
      if(!inputs_ok) { result.lot_ok = false; result.lot = 0.0; return false; }
      if(!result.entry_ok) { reason = result.entry_reason; return false; }
      if(snapshot.tp_state == PM_TP_STATE_AUTO && snapshot.sl_price != 0.0 && !result.tp_auto_ok)
        { reason = result.tp_reason; return false; }
      if(!result.lot_ok) { reason = result.lot_reason; return false; }
      // Verify at the actual rounded volume, not only by scaling the probe loss.
      if(snapshot.quantity_mode != PM_QUANTITY_MANUAL_LOT)
        {
         double budget = 0.0;
         if(!PMCalculateRiskBudget(snapshot.quantity_mode, snapshot.risk_amount, snapshot.balance,
                                   snapshot.risk_percent, budget, reason) ||
            !OrderCalcProfit(snapshot.side == PM_ENTRY_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                             symbol, result.lot, entry, snapshot.sl_price, profit) ||
            !MathIsValidNumber(profit) || profit >= 0.0 || -profit > budget)
           {
            result.lot_ok = false; result.lot = 0.0;
            reason = "Rounded lot loss could not be verified within the risk budget.";
            return false;
           }
         result.estimated_loss = -profit;
        }
      CValidationService validator;
      return validator.ValidateEntryPrices(symbol, snapshot.order_type, snapshot.side,
                                            result.entry, tick.bid, tick.ask, snapshot.sl_price,
                                            result.effective_tp, reason);
     }
   string Estimate(const string symbol, const PMEntrySnapshot &snapshot,
                   const PMEntryComputation &result, const bool is_sl)
     {
      const double price = is_sl ? snapshot.sl_price : result.effective_tp;
      if(!result.lot_ok || (is_sl ? !PMIsStopLossOnLossSide(snapshot.side, result.entry, price) :
                                   !PMIsTakeProfitOnProfitSide(snapshot.side, result.entry, price))) return "N/A";
      string reason = "";
      CValidationService validator;
      if(!validator.ValidateEntryPrices(symbol, snapshot.order_type, snapshot.side,
                                        result.entry, snapshot.bid, snapshot.ask,
                                        is_sl ? price : 0.0, is_sl ? 0.0 : price, reason)) return "N/A";
      double profit = 0.0;
      if(!OrderCalcProfit(snapshot.side == PM_ENTRY_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                          symbol, result.lot, result.entry, price, profit) || !MathIsValidNumber(profit)) return "N/A";
      return DoubleToString(profit, (int)AccountInfoInteger(ACCOUNT_CURRENCY_DIGITS));
     }
  };
#endif
