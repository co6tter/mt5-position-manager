#ifndef __MT5_POSITION_MANAGER_ENTRY_DRAFT_MQH__
#define __MT5_POSITION_MANAGER_ENTRY_DRAFT_MQH__

#include "Models.mqh"
#include "Constants.mqh"

// Committed Entry input only. Chart objects and position-edit drafts are not state.
class CEntryDraft
  {
public:
   PMEntryOrderType order_type;
   PMEntrySide side;
   PMQuantityMode quantity_mode;
   PMTpState tp_state;
   PMEntryInputUnit unit[2];
   string stop_text[2];
   string order_text, lot_text, risk_text, rr_text;
   double last_auto_tp;
   double manual_tp_price;

   CEntryDraft()
     {
      order_type = PM_ENTRY_ORDER_MARKET;
      side = PM_ENTRY_BUY;
      quantity_mode = PM_QUANTITY_MANUAL_LOT;
      tp_state = PM_TP_STATE_AUTO;
      unit[0] = PM_ENTRY_UNIT_POINTS; unit[1] = PM_ENTRY_UNIT_POINTS;
      stop_text[0] = "0"; stop_text[1] = "0";
      order_text = ""; lot_text = "0.01"; risk_text = "0"; rr_text = "1.0";
      last_auto_tp = 0.0; manual_tp_price = 0.0;
     }
   bool Number(const string text, const bool zero_allowed, double &value)
     {
      value = 0.0;
      if(!PMIsUnsignedDecimalText(text)) return false;
      value = StringToDouble(text);
      return MathIsValidNumber(value) && (zero_allowed ? value >= 0.0 : value > 0.0);
     }
   void FreezeAutoTP()
     {
      if(tp_state != PM_TP_STATE_AUTO) return;
      unit[1] = PM_ENTRY_UNIT_PRICE;
      stop_text[1] = DoubleToString(last_auto_tp, 8);
      tp_state = PM_TP_STATE_MANUAL;
      manual_tp_price = last_auto_tp;
     }
   void SetStop(const int index, const string text)
     {
      if(index == 0 && PMIsUnsignedDecimalText(text) && StringToDouble(text) == 0.0)
         FreezeAutoTP();
      stop_text[index] = text;
      if(index == 1)
        {
         manual_tp_price = 0.0;
         tp_state = PMIsUnsignedDecimalText(text) && StringToDouble(text) == 0.0 ?
                    PM_TP_STATE_OFF : PM_TP_STATE_MANUAL;
        }
     }
   void SetPrice(const int index, const double price, const int digits)
     {
      unit[index] = PM_ENTRY_UNIT_PRICE;
      SetStop(index, DoubleToString(price, digits));
     }
   void CancelStop(const int index) { SetStop(index, "0"); }
   bool AutoTP(const double entry, const double sl, string &reason)
     {
      PMTpState next = tp_state;
      if(!PMNextTakeProfitState(tp_state, PM_TP_EVENT_REVERT_TO_AUTO,
                                PMIsStopLossOnLossSide(side, entry, sl), next, reason)) return false;
      tp_state = next;
      return true;
     }
   double PointsBase(const PMEntrySnapshot &snapshot, const double entry)
     {
      return order_type == PM_ENTRY_ORDER_MARKET ?
             (side == PM_ENTRY_BUY ? snapshot.bid : snapshot.ask) : entry;
     }
   bool ResolveStop(const int index, const PMEntrySnapshot &snapshot,
                    const double entry, double &price, string &reason)
     {
      price = 0.0;
      double value = 0.0;
      if(!Number(stop_text[index], true, value) ||
         (unit[index] == PM_ENTRY_UNIT_POINTS &&
          (!PMIsUnsignedIntegerText(stop_text[index]) || value > PM_MAX_TRAILING_POINTS)))
        { reason = "SL/TP input is invalid for its Price/Points mode."; return false; }
      if(value == 0.0) return true;
      if(unit[index] == PM_ENTRY_UNIT_PRICE) price = value;
      else
        {
         const bool upward = side == PM_ENTRY_BUY ? index == 1 : index == 0;
         price = PointsBase(snapshot, entry) + (upward ? value : -value) * snapshot.point;
        }
      price = PMNormalizePrice(price, snapshot.tick_size, snapshot.digits);
      if(!MathIsValidNumber(price) || price <= 0.0)
        { reason = "The SL/TP price is invalid after tick rounding."; return false; }
      return true;
     }
   // Fill one snapshot used by lines, RR, sizing, estimates and order submission.
   bool Resolve(PMEntrySnapshot &snapshot, const int drag_index,
                const double drag_price, string &reason)
     {
      reason = "";
      snapshot.order_type = order_type; snapshot.side = side;
      snapshot.quantity_mode = quantity_mode; snapshot.tp_state = tp_state;
      snapshot.sl_price = 0.0; snapshot.tp_price = 0.0;
      snapshot.order_price = 0.0;
      if(order_type != PM_ENTRY_ORDER_MARKET && !Number(order_text, false, snapshot.order_price))
        { reason = "Order price must be a positive number."; return false; }
      double entry = 0.0;
      if(!PMCalculateAssumedEntryPrice(order_type, side, snapshot.bid, snapshot.ask,
                                       snapshot.order_price, entry, reason)) return false;
      if(!ResolveStop(0, snapshot, entry, snapshot.sl_price, reason)) return false;
      if(tp_state == PM_TP_STATE_MANUAL)
        {
         if(manual_tp_price > 0.0) snapshot.tp_price = manual_tp_price;
         else
           {
            if(!ResolveStop(1, snapshot, entry, snapshot.tp_price, reason)) return false;
            // A directly entered TP becomes an absolute draft once resolved.
            // Points remains the visible input unit, not a request to chase ticks.
            if(drag_index < 0) manual_tp_price = snapshot.tp_price;
           }
        }
      if(drag_index == 0) snapshot.sl_price = drag_price;
      if(drag_index == 1) { snapshot.tp_price = drag_price; snapshot.tp_state = PM_TP_STATE_MANUAL; }
      if(!Number(rr_text, false, snapshot.rr_multiplier))
        { reason = "RR must be a positive finite number."; return false; }
      if(quantity_mode == PM_QUANTITY_MANUAL_LOT)
        {
         if(!Number(lot_text, false, snapshot.manual_lot))
           { reason = "Entry lot must be a positive number."; return false; }
        }
      else
        {
         double risk = 0.0;
         if(!Number(risk_text, false, risk))
           { reason = "Risk must be a positive number."; return false; }
         snapshot.risk_amount = quantity_mode == PM_QUANTITY_RISK_AMOUNT ? risk : 0.0;
         snapshot.risk_percent = quantity_mode == PM_QUANTITY_RISK_PERCENT ? risk : 0.0;
        }
      return true;
     }
  };
#endif
