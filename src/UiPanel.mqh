#ifndef __MT5_POSITION_MANAGER_UI_PANEL_MQH__
#define __MT5_POSITION_MANAGER_UI_PANEL_MQH__

#include "Models.mqh"
#include "Constants.mqh"
#include "PositionService.mqh"
#include "TradeManager.mqh"
#include "ValidationService.mqh"
#include "PositionActionService.mqh"

class CUiPanel
  {
private:
   PMPosition m_positions[];
   string m_symbols[];
   ulong m_selected[];
   string m_filter_symbol;
   PMDirection m_filter_direction;
   string m_auto_symbol;
   PMDirection m_auto_direction;
   PMPriceMode m_sl_mode;
   PMPriceMode m_tp_mode;
   PMPassedCloseBehavior m_passed_behavior;
   bool m_auto_enabled;
   bool m_equity_guard_enabled;
   PMEquityThresholdMode m_equity_guard_mode;
   double m_equity_guard_loss_threshold;
   double m_equity_guard_profit_threshold;
   string m_trailing_symbol;
   PMDirection m_trailing_direction;
   bool m_break_even_enabled;
   bool m_trailing_enabled;
   int m_be_trigger_points;
   int m_be_lock_points;
   int m_trail_points;
   int m_max_rows;
   string m_status;
   datetime m_session_close;
   datetime m_auto_close_at;
   int m_page;
   bool m_row_render_error_reported;
   int m_origin_x;
   int m_origin_y;
   int m_panel_width;
   int m_panel_height;
   bool m_dragging;
   bool m_resizing;
   int m_interaction_start_x;
   int m_interaction_start_y;
   int m_interaction_origin_x;
   int m_interaction_origin_y;
   int m_interaction_width;
   int m_interaction_height;
   bool m_chart_mouse_scroll_before_interaction;
   bool m_chart_mouse_move_before_create;

public:
   CUiPanel()
     {
      m_filter_symbol = "";
      m_filter_direction = PM_DIRECTION_BOTH;
      m_auto_symbol = "";
      m_auto_direction = PM_DIRECTION_BOTH;
      m_sl_mode = PM_PRICE_ABSOLUTE;
      m_tp_mode = PM_PRICE_ABSOLUTE;
      m_passed_behavior = PM_PASSED_CLOSE_DO_NOTHING;
      m_auto_enabled = false;
      m_equity_guard_enabled = false;
      m_equity_guard_mode = PM_EQUITY_THRESHOLD_AMOUNT;
      m_equity_guard_loss_threshold = 0.0;
      m_equity_guard_profit_threshold = 0.0;
      m_trailing_symbol = "";
      m_trailing_direction = PM_DIRECTION_BOTH;
      m_break_even_enabled = false;
      m_trailing_enabled = false;
      m_be_trigger_points = 0;
      m_be_lock_points = 0;
      m_trail_points = 0;
      m_max_rows = PM_DEFAULT_MAX_ROWS;
      m_status = "Ready";
      m_session_close = 0;
      m_auto_close_at = 0;
      m_page = 0;
      m_row_render_error_reported = false;
      m_origin_x = 0;
      m_origin_y = 0;
      m_panel_width = PM_DEFAULT_PANEL_WIDTH;
      m_panel_height = 0;
      m_dragging = false;
      m_resizing = false;
      m_interaction_start_x = 0;
      m_interaction_start_y = 0;
      m_interaction_origin_x = 0;
      m_interaction_origin_y = 0;
      m_interaction_width = 0;
      m_interaction_height = 0;
      m_chart_mouse_scroll_before_interaction = true;
      m_chart_mouse_move_before_create = true;
     }

   bool Create(const int max_rows)
     {
      m_max_rows = MathMax(PM_MIN_POSITION_ROWS, MathMin(max_rows, PM_MAX_POSITION_ROWS));
      m_panel_width = PM_DEFAULT_PANEL_WIDTH;
      m_origin_x = 0;
      m_origin_y = 0;
      m_panel_height = MinimumPanelHeightForRows(m_max_rows);
      long mouse_move_enabled = 0;
      if(ChartGetInteger(0, CHART_EVENT_MOUSE_MOVE, 0, mouse_move_enabled))
         m_chart_mouse_move_before_create = mouse_move_enabled != 0;
      ResetLastError();
      if(!ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, 0, true))
        {
         PrintFormat("[ERROR] Unable to enable chart mouse move events. error=%d",
                     GetLastError());
         return false;
        }
      ObjectsDeleteAll(0, PM_OBJECT_PREFIX);
      const int section_y = SectionY();
      bool created = true;
      created = CreateBackground(PanelHeight()) && created;
      created = CreateLabel("TITLE", "MT5 Position Manager", 12, 8, clrWhite, 12) && created;
      created = CreateLabel("FILTER_LABEL", "Filter", 12, 38, clrSilver, 9) && created;
      created = CreateButton("FILTER_SYMBOL", "Symbol", 62, 34, 120, 22) && created;
      created = CreateButton("FILTER_DIRECTION", "Both", 188, 34, 95, 22) && created;
      created = CreateButton("CLOSE_NOW", "Close Now", 292, 34, 110, 22, clrMaroon) && created;
      created = CreateLabel("POSITIONS_LABEL", "Positions", 12, 67, clrSilver, 9) && created;
      created = CreateButton("PAGE_PREV", "<", 85, 64, 35, 22) && created;
      created = CreateButton("PAGE_NEXT", ">", 125, 64, 35, 22) && created;
      created = CreateLabel("PAGE_LABEL", "Page 1/1", 170, 67, clrSilver, 9) && created;
      created = CreateButton("SELECT_ALL", "Select All", 410, 64, 100, 22) && created;
      created = CreateButton("CLEAR_SELECTION", "Clear Selection", 516, 64, 125, 22) && created;
      created = CreateButton("CLOSE_SELECTED", "Close Selected", 647, 64, 120, 22, clrMaroon) && created;

      created = CreateLabel("SL_LABEL", "Stop Loss", 12, section_y + PM_PANEL_SL_LABEL_Y, clrSilver, 9) && created;
      created = CreateButton("SL_MODE", "Price", 95, section_y + PM_PANEL_SL_Y, 85, 22) && created;
      created = CreateEdit("SL_VALUE", "", 185, section_y + PM_PANEL_SL_Y, 110, 22) && created;
      created = CreateButton("SET_SL", "Set / Change SL", 300, section_y + PM_PANEL_SL_Y, 135, 22) && created;
      created = CreateButton("CLEAR_SL", "Clear SL", 440, section_y + PM_PANEL_SL_Y, 90, 22) && created;

      created = CreateLabel("TP_LABEL", "Take Profit", 12, section_y + PM_PANEL_TP_LABEL_Y, clrSilver, 9) && created;
      created = CreateButton("TP_MODE", "Price", 95, section_y + PM_PANEL_TP_Y, 85, 22) && created;
      created = CreateEdit("TP_VALUE", "", 185, section_y + PM_PANEL_TP_Y, 110, 22) && created;
      created = CreateButton("SET_TP", "Set / Change TP", 300, section_y + PM_PANEL_TP_Y, 135, 22) && created;
      created = CreateButton("CLEAR_TP", "Clear TP", 440, section_y + PM_PANEL_TP_Y, 90, 22) && created;

      created = CreateLabel("AUTO_LABEL", "Auto Close", 12, section_y + PM_PANEL_AUTO_LABEL_Y, clrSilver, 9) && created;
      created = CreateButton("AUTO_ENABLED", "OFF", 95, section_y + PM_PANEL_AUTO_Y, 65, 22) && created;
      created = CreateLabel("AUTO_SYMBOL_LABEL", "Symbol", 170, section_y + PM_PANEL_AUTO_LABEL_Y, clrSilver, 9) && created;
      created = CreateButton("AUTO_SYMBOL", "Symbol", 220, section_y + PM_PANEL_AUTO_Y, 105, 22) && created;
      created = CreateButton("AUTO_DIRECTION", "Both", 330, section_y + PM_PANEL_AUTO_Y, 85, 22) && created;
      created = CreateLabel("MINUTES_LABEL", "Mins before close", 425, section_y + PM_PANEL_AUTO_LABEL_Y, clrSilver, 9) && created;
      created = CreateEdit("AUTO_MINUTES", "10", 525, section_y + PM_PANEL_AUTO_Y, 55, 22) && created;
      created = CreateButton("PASSED_BEHAVIOR", "Passed: Do Nothing", 590, section_y + PM_PANEL_AUTO_Y, 155, 22) && created;

      created = CreateLabel("EQ_LABEL", "Equity Guard", 12, section_y + PM_PANEL_EQUITY_LABEL_Y, clrSilver, 9) && created;
      created = CreateButton("EQ_ENABLED", "OFF", 95, section_y + PM_PANEL_EQUITY_Y, 65, 22) && created;
      created = CreateButton("EQ_MODE", "Amount", 170, section_y + PM_PANEL_EQUITY_Y, 85, 22) && created;
      created = CreateLabel("EQ_LOSS_LABEL", "Loss limit", 265, section_y + PM_PANEL_EQUITY_LABEL_Y, clrSilver, 9) && created;
      created = CreateEdit("EQ_LOSS_VALUE", "", 330, section_y + PM_PANEL_EQUITY_Y, 100, 22) && created;
      created = CreateLabel("EQ_PROFIT_LABEL", "Profit limit", 440, section_y + PM_PANEL_EQUITY_LABEL_Y, clrSilver, 9) && created;
      created = CreateEdit("EQ_PROFIT_VALUE", "", 515, section_y + PM_PANEL_EQUITY_Y, 100, 22) && created;
      created = CreateLabel("EQ_SCOPE_LABEL", "All symbols", 625, section_y + PM_PANEL_EQUITY_LABEL_Y, clrOrange, 9) && created;

      created = CreateLabel("TS_LABEL", "Trailing Stop", 12, section_y + PM_PANEL_TRAILING_SCOPE_LABEL_Y, clrSilver, 9) && created;
      created = CreateLabel("TS_SYMBOL_LABEL", "Symbol", 95, section_y + PM_PANEL_TRAILING_SCOPE_LABEL_Y, clrSilver, 9) && created;
      created = CreateButton("TS_SYMBOL", "Symbol", 145, section_y + PM_PANEL_TRAILING_SCOPE_Y, 105, 22) && created;
      created = CreateButton("TS_DIRECTION", "Both", 255, section_y + PM_PANEL_TRAILING_SCOPE_Y, 85, 22) && created;

      created = CreateLabel("BE_LABEL", "Break Even", 12, section_y + PM_PANEL_BREAK_EVEN_LABEL_Y, clrSilver, 9) && created;
      created = CreateButton("BE_ENABLED", "OFF", 95, section_y + PM_PANEL_BREAK_EVEN_Y, 65, 22) && created;
      created = CreateLabel("BE_TRIGGER_LABEL", "Trigger pts", 170, section_y + PM_PANEL_BREAK_EVEN_LABEL_Y, clrSilver, 9) && created;
      created = CreateEdit("BE_TRIGGER_VALUE", "", 255, section_y + PM_PANEL_BREAK_EVEN_Y, 70, 22) && created;
      created = CreateLabel("BE_LOCK_LABEL", "Lock pts", 335, section_y + PM_PANEL_BREAK_EVEN_LABEL_Y, clrSilver, 9) && created;
      created = CreateEdit("BE_LOCK_VALUE", "", 400, section_y + PM_PANEL_BREAK_EVEN_Y, 70, 22) && created;

      created = CreateLabel("TRAIL_LABEL", "Trailing", 12, section_y + PM_PANEL_TRAIL_LABEL_Y, clrSilver, 9) && created;
      created = CreateButton("TRAIL_ENABLED", "OFF", 95, section_y + PM_PANEL_TRAIL_Y, 65, 22) && created;
      created = CreateLabel("TRAIL_DIST_LABEL", "Distance pts", 170, section_y + PM_PANEL_TRAIL_LABEL_Y, clrSilver, 9) && created;
      created = CreateEdit("TRAIL_DIST_VALUE", "", 255, section_y + PM_PANEL_TRAIL_Y, 70, 22) && created;

      created = CreateLabel("SESSION_LABEL", "Today's Close: -    Auto Close At: -", 12, section_y + PM_PANEL_SESSION_Y, clrSilver, 9) && created;
      created = CreateLabel("STATUS_LABEL", "Status: Ready", 12, section_y + PM_PANEL_STATUS_Y, clrWhite, 9) && created;
      created = CreateLabel("RESIZE_GRIP", "///", m_panel_width - 24,
                            PanelHeight() - 18, clrSilver, 8) && created;
      ChartRedraw();
      if(!created)
        {
         PrintFormat("[ERROR] UI panel creation failed. last_error=%d", GetLastError());
         Destroy();
        }
      return created;
     }

   void Destroy()
     {
      EndInteraction();
      ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, 0, m_chart_mouse_move_before_create);
      ObjectsDeleteAll(0, PM_OBJECT_PREFIX);
     }

   void Refresh(CPositionService &positions)
     {
      positions.Collect(m_positions);
      positions.CollectSymbols(m_symbols);
      if(m_filter_symbol == "")
         m_filter_symbol = _Symbol;
      if(m_auto_symbol == "")
         m_auto_symbol = _Symbol;
      if(m_trailing_symbol == "")
         m_trailing_symbol = _Symbol;
      EnsureSymbolCandidate(m_filter_symbol);
      EnsureSymbolCandidate(m_auto_symbol);
      EnsureSymbolCandidate(m_trailing_symbol);
      ClampPage();
      for(int i = ArraySize(m_selected) - 1; i >= 0; i--)
        {
         if(!ContainsPosition(m_selected[i]))
            ArrayRemove(m_selected, i, 1);
        }
     }

   void Render()
     {
      ObjectSetString(0, Name("FILTER_SYMBOL"), OBJPROP_TEXT, FilterSymbol());
      ObjectSetString(0, Name("FILTER_DIRECTION"), OBJPROP_TEXT, PMDirectionToString(m_filter_direction));
      ObjectSetString(0, Name("SL_MODE"), OBJPROP_TEXT, PriceModeToString(m_sl_mode));
      ObjectSetString(0, Name("TP_MODE"), OBJPROP_TEXT, PriceModeToString(m_tp_mode));
      ObjectSetString(0, Name("AUTO_ENABLED"), OBJPROP_TEXT, m_auto_enabled ? "ON" : "OFF");
      ObjectSetString(0, Name("AUTO_SYMBOL"), OBJPROP_TEXT, AutoSymbol());
      ObjectSetString(0, Name("AUTO_DIRECTION"), OBJPROP_TEXT, PMDirectionToString(m_auto_direction));
      ObjectSetString(0, Name("PASSED_BEHAVIOR"), OBJPROP_TEXT,
                      m_passed_behavior == PM_PASSED_CLOSE_IMMEDIATELY ? "Passed: Close Now" : "Passed: Do Nothing");
      ObjectSetString(0, Name("EQ_ENABLED"), OBJPROP_TEXT, m_equity_guard_enabled ? "ON" : "OFF");
      ObjectSetString(0, Name("EQ_MODE"), OBJPROP_TEXT, EquityThresholdModeToString(m_equity_guard_mode));
      ObjectSetString(0, Name("TS_SYMBOL"), OBJPROP_TEXT, TrailingSymbol());
      ObjectSetString(0, Name("TS_DIRECTION"), OBJPROP_TEXT, PMDirectionToString(m_trailing_direction));
      ObjectSetString(0, Name("BE_ENABLED"), OBJPROP_TEXT, m_break_even_enabled ? "ON" : "OFF");
      ObjectSetString(0, Name("TRAIL_ENABLED"), OBJPROP_TEXT, m_trailing_enabled ? "ON" : "OFF");
      ObjectSetString(0, Name("SESSION_LABEL"), OBJPROP_TEXT,
                      "Today's Close: " + PMFormatDateTime(m_session_close) +
                      "    Auto Close At: " + PMFormatDateTime(m_auto_close_at));
      ObjectSetString(0, Name("STATUS_LABEL"), OBJPROP_TEXT, "Status: " + m_status);
      ObjectSetString(0, Name("PAGE_LABEL"), OBJPROP_TEXT,
                      StringFormat("Page %d/%d  Selected %d  Total %d",
                                   m_page + 1, PageCount(),
                                   ArraySize(m_selected), ArraySize(m_positions)));

      for(int row = 0; row < PM_MAX_POSITION_ROWS; row++)
         ObjectDelete(0, RowName(row));
      const int page_start = m_page * m_max_rows;
      const int visible = MathMin(m_max_rows, ArraySize(m_positions) - page_start);
      bool rows_created = true;
      for(int row = 0; row < visible; row++)
        {
         PMPosition position = m_positions[page_start + row];
         const string selected = IsSelected(position.ticket) ? "[x] " : "[ ] ";
         const string text = selected + position.symbol + " " + PMPositionTypeToString(position.type) +
                             "  Lot=" + DoubleToString(position.volume, 2) +
                             "  Entry=" + PMFormatPrice(position.symbol, position.open_price) +
                             "  SL=" + PMFormatPrice(position.symbol, position.sl) +
                             "  TP=" + PMFormatPrice(position.symbol, position.tp) +
                             "  P=" + DoubleToString(position.profit, 2) +
                             "  #" + StringFormat("%I64u", position.ticket);
         rows_created = CreateButton(
            RowSuffix(row), text, 12, 90 + row * 21, m_panel_width - 25, 19,
            IsSelected(position.ticket) ? clrDarkGreen : clrDarkSlateGray) &&
            rows_created;
        }
      if(!rows_created)
        {
         m_status = "UI row rendering failed; check Experts log.";
         ObjectSetString(0, Name("STATUS_LABEL"), OBJPROP_TEXT,
                         "Status: " + m_status);
         if(!m_row_render_error_reported)
            PrintFormat("[ERROR] UI position row creation failed. last_error=%d",
                        GetLastError());
        }
      m_row_render_error_reported = !rows_created;
      ChartRedraw();
     }

   void SetStatus(const string status)
     {
      if(status != "")
         m_status = status;
     }

   void SetAutoSchedule(const datetime session_close, const datetime auto_close_at)
     {
      m_session_close = session_close;
      m_auto_close_at = auto_close_at;
     }

   void GetAutoCloseConfig(AutoCloseConfig &config)
     {
      config.enabled = m_auto_enabled;
      config.symbol = AutoSymbol();
      config.direction = m_auto_direction;
      config.minutes_before_close = AutoCloseMinutes();
      config.passed_behavior = m_passed_behavior;
     }

   void GetEquityGuardConfig(EquityGuardConfig &config)
     {
      config.enabled = m_equity_guard_enabled;
      config.mode = m_equity_guard_mode;
      config.loss_threshold = m_equity_guard_loss_threshold;
      config.profit_threshold = m_equity_guard_profit_threshold;
     }

   void GetTrailingStopConfig(TrailingStopConfig &config)
     {
      config.enabled_break_even = m_break_even_enabled;
      config.enabled_trailing = m_trailing_enabled;
      config.symbol = TrailingSymbol();
      config.direction = m_trailing_direction;
      config.be_trigger_points = m_be_trigger_points;
      config.be_lock_points = m_be_lock_points;
      config.trail_points = m_trail_points;
     }

   bool HandleChartEvent(const long id,
                         const long lparam,
                         const double dparam,
                         const string object_name,
                         CPositionService &positions,
                         CTradeManager &trades,
                         CValidationService &validator,
                         CPositionActionService &actions)
     {
      if(id == CHARTEVENT_MOUSE_MOVE)
        {
         HandleMouseMove((int)lparam, (int)dparam, object_name);
         return true;
        }
      if(id == CHARTEVENT_CLICK)
        {
         EndInteraction();
         return true;
        }
      if(id != CHARTEVENT_OBJECT_CLICK && id != CHARTEVENT_OBJECT_ENDEDIT)
         return false;
      if(id == CHARTEVENT_OBJECT_CLICK)
         EndInteraction();
      if(id == CHARTEVENT_OBJECT_ENDEDIT)
        {
         if(object_name == Name("AUTO_MINUTES"))
           {
            const int minutes = AutoCloseMinutes();
            ObjectSetString(0, Name("AUTO_MINUTES"), OBJPROP_TEXT,
                            IntegerToString(minutes));
            SetStatus(StringFormat("Auto Close minutes set to %d.", minutes));
            return true;
         }
         if(object_name == Name("EQ_LOSS_VALUE"))
           {
            CommitDoubleValue("EQ_LOSS_VALUE", m_equity_guard_loss_threshold,
                              PM_MAX_EQUITY_THRESHOLD, 2);
            SetStatus(StringFormat("Equity Guard Max Loss set to %.2f.", m_equity_guard_loss_threshold));
            return true;
           }
         if(object_name == Name("EQ_PROFIT_VALUE"))
           {
            CommitDoubleValue("EQ_PROFIT_VALUE", m_equity_guard_profit_threshold,
                              PM_MAX_EQUITY_THRESHOLD, 2);
            SetStatus(StringFormat("Equity Guard Max Profit set to %.2f.", m_equity_guard_profit_threshold));
            return true;
           }
         if(object_name == Name("BE_TRIGGER_VALUE"))
           {
            CommitIntegerValue("BE_TRIGGER_VALUE", m_be_trigger_points,
                               PM_MAX_TRAILING_POINTS);
            SetStatus(StringFormat("Break Even Trigger set to %d.", m_be_trigger_points));
            return true;
           }
         if(object_name == Name("BE_LOCK_VALUE"))
           {
            CommitIntegerValue("BE_LOCK_VALUE", m_be_lock_points,
                               PM_MAX_TRAILING_POINTS);
            SetStatus(StringFormat("Break Even Lock set to %d.", m_be_lock_points));
            return true;
           }
         if(object_name == Name("TRAIL_DIST_VALUE"))
           {
            CommitIntegerValue("TRAIL_DIST_VALUE", m_trail_points,
                               PM_MAX_TRAILING_POINTS);
            SetStatus(StringFormat("Trailing Distance set to %d.", m_trail_points));
            return true;
           }
         return false;
        }
      if(id != CHARTEVENT_OBJECT_CLICK)
         return false;
      if(StringFind(object_name, PM_OBJECT_PREFIX) != 0)
         return false;
      ObjectSetInteger(0, object_name, OBJPROP_STATE, false);

      if(object_name == Name("FILTER_SYMBOL"))
         CycleSymbol(m_filter_symbol);
      else if(object_name == Name("FILTER_DIRECTION"))
         m_filter_direction = NextDirection(m_filter_direction);
      else if(object_name == Name("CLOSE_NOW"))
         CloseNow(positions, trades);
      else if(object_name == Name("SELECT_ALL"))
         SelectAll();
      else if(object_name == Name("PAGE_PREV"))
        {
         if(m_page > 0)
            m_page--;
        }
      else if(object_name == Name("PAGE_NEXT"))
        {
         if(m_page + 1 < PageCount())
            m_page++;
        }
      else if(object_name == Name("CLEAR_SELECTION"))
        {
         ArrayResize(m_selected, 0);
         SetStatus("Selection cleared.");
        }
      else if(object_name == Name("CLOSE_SELECTED"))
         CloseSelected(trades);
      else if(object_name == Name("SL_MODE"))
         m_sl_mode = m_sl_mode == PM_PRICE_ABSOLUTE ? PM_PRICE_POINTS : PM_PRICE_ABSOLUTE;
      else if(object_name == Name("SET_SL"))
         ApplyStopTarget(true, positions, trades, validator, actions);
      else if(object_name == Name("CLEAR_SL"))
         ClearStopTarget(true, positions, trades, actions);
      else if(object_name == Name("TP_MODE"))
         m_tp_mode = m_tp_mode == PM_PRICE_ABSOLUTE ? PM_PRICE_POINTS : PM_PRICE_ABSOLUTE;
      else if(object_name == Name("SET_TP"))
         ApplyStopTarget(false, positions, trades, validator, actions);
      else if(object_name == Name("CLEAR_TP"))
         ClearStopTarget(false, positions, trades, actions);
      else if(object_name == Name("AUTO_ENABLED"))
         m_auto_enabled = !m_auto_enabled;
      else if(object_name == Name("AUTO_SYMBOL"))
         CycleSymbol(m_auto_symbol);
      else if(object_name == Name("AUTO_DIRECTION"))
         m_auto_direction = NextDirection(m_auto_direction);
      else if(object_name == Name("PASSED_BEHAVIOR"))
         m_passed_behavior = m_passed_behavior == PM_PASSED_CLOSE_DO_NOTHING ?
                             PM_PASSED_CLOSE_IMMEDIATELY : PM_PASSED_CLOSE_DO_NOTHING;
      else if(object_name == Name("EQ_ENABLED"))
         m_equity_guard_enabled = !m_equity_guard_enabled;
      else if(object_name == Name("EQ_MODE"))
         m_equity_guard_mode = m_equity_guard_mode == PM_EQUITY_THRESHOLD_AMOUNT ?
                               PM_EQUITY_THRESHOLD_PERCENT : PM_EQUITY_THRESHOLD_AMOUNT;
      else if(object_name == Name("TS_SYMBOL"))
         CycleSymbol(m_trailing_symbol);
      else if(object_name == Name("TS_DIRECTION"))
         m_trailing_direction = NextDirection(m_trailing_direction);
      else if(object_name == Name("BE_ENABLED"))
         m_break_even_enabled = !m_break_even_enabled;
      else if(object_name == Name("TRAIL_ENABLED"))
         m_trailing_enabled = !m_trailing_enabled;
      else
        {
         const int page_start = m_page * m_max_rows;
         const int visible = MathMin(m_max_rows, ArraySize(m_positions) - page_start);
         for(int row = 0; row < visible; row++)
            if(object_name == RowName(row))
              {
               ToggleSelection(m_positions[page_start + row].ticket);
               break;
              }
        }
      Render();
      return true;
     }

private:
   string Name(const string suffix)
     {
      return PM_OBJECT_PREFIX + suffix;
     }

   string RowName(const int row)
     {
      return Name(RowSuffix(row));
     }

   string RowSuffix(const int row)
     {
      return "ROW_" + IntegerToString(row);
     }

   string FilterSymbol()
     {
      return m_filter_symbol == "" ? _Symbol : m_filter_symbol;
     }

   string AutoSymbol()
     {
      return m_auto_symbol == "" ? _Symbol : m_auto_symbol;
     }

   string TrailingSymbol()
     {
      return m_trailing_symbol == "" ? _Symbol : m_trailing_symbol;
     }

   int AutoCloseMinutes()
     {
      long minutes = StringToInteger(
         ObjectGetString(0, Name("AUTO_MINUTES"), OBJPROP_TEXT));
      if(minutes < 0)
         minutes = 0;
      if(minutes > PM_MAX_AUTO_CLOSE_MINUTES)
         minutes = PM_MAX_AUTO_CLOSE_MINUTES;
      return (int)minutes;
     }

   // Values are only adopted on CHARTEVENT_OBJECT_ENDEDIT. Reading edit boxes
   // live on every timer tick would allow transient input to drive automation.
   void CommitDoubleValue(const string suffix,
                          double &target,
                          const double maximum,
                          const int digits)
     {
      double value = StringToDouble(ObjectGetString(0, Name(suffix), OBJPROP_TEXT));
      if(!MathIsValidNumber(value) || value < 0.0)
         value = 0.0;
      if(value > maximum)
         value = maximum;
      target = value;
      ObjectSetString(0, Name(suffix), OBJPROP_TEXT, DoubleToString(value, digits));
     }

   void CommitIntegerValue(const string suffix,
                           int &target,
                           const int maximum)
     {
      long value = StringToInteger(ObjectGetString(0, Name(suffix), OBJPROP_TEXT));
      if(value < 0)
         value = 0;
      if(value > maximum)
         value = maximum;
      target = (int)value;
      ObjectSetString(0, Name(suffix), OBJPROP_TEXT, IntegerToString(target));
     }

   int FindSymbol(const string symbol)
     {
      for(int i = 0; i < ArraySize(m_symbols); i++)
         if(m_symbols[i] == symbol)
            return i;
      return -1;
     }

   void EnsureSymbolCandidate(const string symbol)
     {
      if(symbol == "" || FindSymbol(symbol) >= 0)
         return;
      const int count = ArraySize(m_symbols);
      ArrayResize(m_symbols, count + 1);
      m_symbols[count] = symbol;
     }

   void CycleSymbol(string &selected)
     {
      EnsureSymbolCandidate(selected);
      if(ArraySize(m_symbols) == 0)
        {
         selected = _Symbol;
         return;
        }
      int index = FindSymbol(selected);
      if(index < 0)
         index = 0;
      selected = m_symbols[(index + 1) % ArraySize(m_symbols)];
     }

   int SectionY()
     {
      return 95 + m_max_rows * 21;
     }

   int MinimumPanelHeightForRows(const int rows)
     {
      return 95 + rows * 21 + PM_PANEL_CHROME_HEIGHT;
     }

   int MinimumPanelHeight()
     {
      return MinimumPanelHeightForRows(PM_MIN_POSITION_ROWS);
     }

   int MaximumPanelHeight()
     {
      return MinimumPanelHeightForRows(PM_MAX_POSITION_ROWS);
     }

   int PanelHeight()
     {
      return m_panel_height > 0 ? m_panel_height : MinimumPanelHeightForRows(m_max_rows);
     }

   int PageCount()
     {
      if(ArraySize(m_positions) == 0)
         return 1;
      return (ArraySize(m_positions) + m_max_rows - 1) / m_max_rows;
     }

   void ClampPage()
     {
      const int pages = PageCount();
      if(m_page < 0)
         m_page = 0;
      if(m_page >= pages)
         m_page = pages - 1;
     }

   PMDirection NextDirection(const PMDirection direction)
     {
      return direction == PM_DIRECTION_LONG ? PM_DIRECTION_SHORT :
             direction == PM_DIRECTION_SHORT ? PM_DIRECTION_BOTH : PM_DIRECTION_LONG;
     }

   string PriceModeToString(const PMPriceMode mode)
     {
      return mode == PM_PRICE_ABSOLUTE ? "Price" : "Points";
     }

   string EquityThresholdModeToString(const PMEquityThresholdMode mode)
     {
      return mode == PM_EQUITY_THRESHOLD_AMOUNT ? "Amount" : "Percent";
     }

   bool IsSelected(const ulong ticket)
     {
      for(int i = 0; i < ArraySize(m_selected); i++)
         if(m_selected[i] == ticket)
            return true;
      return false;
     }

   bool ContainsPosition(const ulong ticket)
     {
      for(int i = 0; i < ArraySize(m_positions); i++)
         if(m_positions[i].ticket == ticket)
            return true;
      return false;
     }

   void ToggleSelection(const ulong ticket)
     {
      for(int i = 0; i < ArraySize(m_selected); i++)
         if(m_selected[i] == ticket)
           {
            ArrayRemove(m_selected, i, 1);
            return;
           }
      const int count = ArraySize(m_selected);
      ArrayResize(m_selected, count + 1);
      m_selected[count] = ticket;
     }

   void SelectAll()
     {
      ArrayResize(m_selected, 0);
      for(int i = 0; i < ArraySize(m_positions); i++)
        {
         const int count = ArraySize(m_selected);
         ArrayResize(m_selected, count + 1);
         m_selected[count] = m_positions[i].ticket;
        }
      SetStatus(StringFormat("%d positions selected.", ArraySize(m_selected)));
     }

   void CloseNow(CPositionService &positions, CTradeManager &trades)
     {
      const string symbol = FilterSymbol();
      ulong tickets[];
      positions.CollectTickets(symbol, m_filter_direction, tickets);
      if(ArraySize(tickets) == 0)
        {
         SetStatus("No matching positions.");
         return;
        }
      const string question = BuildTicketSummary(
         StringFormat("Close %d %s %s positions?", ArraySize(tickets), symbol,
                      PMDirectionToString(m_filter_direction)), tickets);
      if(MessageBox(question, "MT5 Position Manager",
                    MB_YESNO | MB_ICONWARNING | MB_DEFBUTTON2) != IDYES)
        {
         SetStatus("Close cancelled.");
         return;
        }
      PMBatchResult result;
      trades.CloseTickets(tickets, result);
      SetStatus(BatchResultText("Close", result));
     }

   void CloseSelected(CTradeManager &trades)
     {
      if(ArraySize(m_selected) == 0)
        {
         SetStatus("No positions selected.");
         return;
        }
      const string question = BuildTicketSummary(
         StringFormat("Close %d selected positions?", ArraySize(m_selected)),
         m_selected);
      if(MessageBox(question, "MT5 Position Manager",
                    MB_YESNO | MB_ICONWARNING | MB_DEFBUTTON2) != IDYES)
        {
         SetStatus("Close cancelled.");
         return;
        }
      PMBatchResult result;
      trades.CloseTickets(m_selected, result);
      SetStatus(BatchResultText("Close", result));
     }

   string BatchResultText(const string operation, PMBatchResult &result)
     {
      if(ArraySize(result.failures) > 0 &&
         PMIsTradingUnavailableRetcode(result.failures[0].retcode))
         return StringFormat("%s stopped: trading unavailable (%s)",
                             operation, result.failures[0].description);
      string text = StringFormat("%s: %d succeeded, %d queued, %d failed / %d",
                                 operation, result.successful, result.queued,
                                 ArraySize(result.failures), result.requested);
      if(ArraySize(result.failures) > 0)
         text += StringFormat("; ticket=%I64u (%s, retcode=%u)",
                              result.failures[0].ticket,
                              result.failures[0].description,
                              result.failures[0].retcode);
      return text;
     }

   string BuildTicketSummary(const string heading, const ulong &tickets[])
     {
      string text = heading + "\n\n";
      for(int i = 0; i < ArraySize(tickets); i++)
        {
         PMPosition position = {};
         if(FindCachedPosition(tickets[i], position))
            text += StringFormat("%s %s %.2f  #%I64u\n", position.symbol,
                                 PMPositionTypeToString(position.type),
                                 position.volume, position.ticket);
         else
            text += StringFormat("Unavailable  #%I64u\n", tickets[i]);
        }
      text += "\nContinue?";
      return text;
     }

   bool FindCachedPosition(const ulong ticket, PMPosition &position)
     {
      for(int i = 0; i < ArraySize(m_positions); i++)
         if(m_positions[i].ticket == ticket)
           {
            position = m_positions[i];
            return true;
           }
      return false;
     }

   void ApplyStopTarget(const bool is_sl,
                        CPositionService &positions,
                        CTradeManager &trades,
                        CValidationService &validator,
                        CPositionActionService &actions)
     {
      if(ArraySize(m_selected) == 0)
        {
         SetStatus("No positions selected.");
         return;
        }
      const string value_text = ObjectGetString(0, Name(is_sl ? "SL_VALUE" : "TP_VALUE"), OBJPROP_TEXT);
      const double value = StringToDouble(value_text);
      const PMPriceMode mode = is_sl ? m_sl_mode : m_tp_mode;
      PMBatchResult result;
      string validation_error = "";
      if(!actions.ApplyStopTarget(m_selected, is_sl, mode, value,
                                  positions, trades, validator,
                                  result, validation_error))
        {
         SetStatus(validation_error);
         return;
        }
      SetStatus(BatchResultText(is_sl ? "SL update" : "TP update", result));
     }

   void ClearStopTarget(const bool is_sl,
                        CPositionService &positions,
                        CTradeManager &trades,
                        CPositionActionService &actions)
     {
      if(ArraySize(m_selected) == 0)
        {
         SetStatus("No positions selected.");
         return;
        }
      PMBatchResult result;
      actions.ClearStopTarget(m_selected, is_sl, positions, trades, result);
      SetStatus(BatchResultText(is_sl ? "SL clear" : "TP clear", result));
     }

   void ShiftPanelObjects(const int delta_x, const int delta_y, const string exclude_name)
     {
      if(delta_x == 0 && delta_y == 0)
         return;
      const int total = ObjectsTotal(0, -1, -1);
      for(int i = total - 1; i >= 0; i--)
        {
         const string name = ObjectName(0, i, -1, -1);
         if(StringFind(name, PM_OBJECT_PREFIX) != 0 || name == exclude_name)
            continue;
         const int x = (int)ObjectGetInteger(0, name, OBJPROP_XDISTANCE);
         const int y = (int)ObjectGetInteger(0, name, OBJPROP_YDISTANCE);
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x + delta_x);
         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y + delta_y);
        }
     }

   bool IsInsideTitleBar(const int x, const int y)
     {
      return x >= m_origin_x && x < m_origin_x + m_panel_width &&
             y >= m_origin_y && y < m_origin_y + PM_TITLEBAR_HEIGHT;
     }

   bool IsInsideResizeCorner(const int x, const int y)
     {
      return x >= m_origin_x + m_panel_width - PM_RESIZE_HANDLE_HIT_SIZE &&
             x <= m_origin_x + m_panel_width &&
             y >= m_origin_y + PanelHeight() - PM_RESIZE_HANDLE_HIT_SIZE &&
             y <= m_origin_y + PanelHeight();
     }

   void BeginInteraction(const bool resize,
                         const int x,
                         const int y)
     {
      m_dragging = !resize;
      m_resizing = resize;
      m_interaction_start_x = x;
      m_interaction_start_y = y;
      m_interaction_origin_x = m_origin_x;
      m_interaction_origin_y = m_origin_y;
      m_interaction_width = m_panel_width;
      m_interaction_height = PanelHeight();
      long mouse_scroll_enabled = 1;
      if(ChartGetInteger(0, CHART_MOUSE_SCROLL, 0, mouse_scroll_enabled))
         m_chart_mouse_scroll_before_interaction = mouse_scroll_enabled != 0;
      ChartSetInteger(0, CHART_MOUSE_SCROLL, 0, false);
     }

   void EndInteraction()
     {
      if(!m_dragging && !m_resizing)
         return;
      m_dragging = false;
      m_resizing = false;
      ChartSetInteger(0, CHART_MOUSE_SCROLL, 0,
                     m_chart_mouse_scroll_before_interaction);
      ChartRedraw();
     }

   void HandleMouseMove(const int x,
                        const int y,
                        const string state_text)
     {
      const uint state = (uint)StringToInteger(state_text);
      const bool left_pressed = (state & 1) != 0;
      if(!left_pressed)
        {
         EndInteraction();
         return;
        }
      if(!m_dragging && !m_resizing)
        {
         if(IsInsideResizeCorner(x, y))
            BeginInteraction(true, x, y);
         else if(IsInsideTitleBar(x, y))
            BeginInteraction(false, x, y);
        }
      if(m_dragging)
        {
         MovePanelTo(m_interaction_origin_x + x - m_interaction_start_x,
                     m_interaction_origin_y + y - m_interaction_start_y);
         ChartRedraw();
        }
      else if(m_resizing)
         ResizePanelTo(m_interaction_width + x - m_interaction_start_x,
                       m_interaction_height + y - m_interaction_start_y);
     }

   void MovePanelTo(const int requested_x, const int requested_y)
     {
      long chart_width = 0;
      long chart_height = 0;
      ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0, chart_width);
      ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0, chart_height);
      int max_x = (int)chart_width - m_panel_width;
      int max_y = (int)chart_height - PanelHeight();
      if(max_x < 0)
         max_x = 0;
      if(max_y < 0)
         max_y = 0;
      int new_x = requested_x;
      int new_y = requested_y;
      if(new_x < 0)
         new_x = 0;
      if(new_x > max_x)
         new_x = max_x;
      if(new_y < 0)
         new_y = 0;
      if(new_y > max_y)
         new_y = max_y;
      const int delta_x = new_x - m_origin_x;
      const int delta_y = new_y - m_origin_y;
      if(delta_x == 0 && delta_y == 0)
         return;
      m_origin_x = new_x;
      m_origin_y = new_y;
      ShiftPanelObjects(delta_x, delta_y, "");
     }

   void ResizePanelTo(const int requested_width,
                      const int requested_height)
     {
      const int previous_rows = m_max_rows;
      long chart_width = 0;
      long chart_height = 0;
      ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0, chart_width);
      ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0, chart_height);
      int maximum_width = PM_MAX_PANEL_WIDTH;
      int maximum_height = MaximumPanelHeight();
      if((int)chart_width - m_origin_x > PM_MIN_PANEL_WIDTH)
         maximum_width = MathMin(maximum_width, (int)chart_width - m_origin_x);
      if((int)chart_height - m_origin_y > MinimumPanelHeight())
         maximum_height = MathMin(maximum_height, (int)chart_height - m_origin_y);
      m_panel_width = MathMax(PM_MIN_PANEL_WIDTH,
                              MathMin(requested_width, maximum_width));
      m_panel_height = MathMax(MinimumPanelHeight(),
                               MathMin(requested_height, maximum_height));
      const int content_height = m_panel_height - (95 + PM_PANEL_CHROME_HEIGHT);
      const int requested_rows = content_height / 21;
      m_max_rows = MathMax(PM_MIN_POSITION_ROWS,
                           MathMin(requested_rows, PM_MAX_POSITION_ROWS));
      if(m_max_rows != previous_rows)
        {
         ApplyLayout();
         ClampPage();
         Render();
         return;
        }
      ApplyPanelFrameLayout();
      ResizeVisibleRows();
      ChartRedraw();
     }

   void ApplyPanelFrameLayout()
     {
      ObjectSetInteger(0, Name("BACKGROUND"), OBJPROP_XSIZE, m_panel_width);
      ObjectSetInteger(0, Name("BACKGROUND"), OBJPROP_YSIZE, PanelHeight());
      Reposition("RESIZE_GRIP", m_panel_width - 24, PanelHeight() - 18);
     }

   void ResizeVisibleRows()
     {
      const int page_start = m_page * m_max_rows;
      const int visible = MathMin(m_max_rows, ArraySize(m_positions) - page_start);
      for(int row = 0; row < visible; row++)
         ObjectSetInteger(0, RowName(row), OBJPROP_XSIZE, m_panel_width - 25);
     }

   void ApplyLayout()
     {
      const int section_y = SectionY();
      ApplyPanelFrameLayout();
      RepositionY("SL_LABEL", section_y + PM_PANEL_SL_LABEL_Y);
      RepositionY("SL_MODE", section_y + PM_PANEL_SL_Y);
      RepositionY("SL_VALUE", section_y + PM_PANEL_SL_Y);
      RepositionY("SET_SL", section_y + PM_PANEL_SL_Y);
      RepositionY("CLEAR_SL", section_y + PM_PANEL_SL_Y);
      RepositionY("TP_LABEL", section_y + PM_PANEL_TP_LABEL_Y);
      RepositionY("TP_MODE", section_y + PM_PANEL_TP_Y);
      RepositionY("TP_VALUE", section_y + PM_PANEL_TP_Y);
      RepositionY("SET_TP", section_y + PM_PANEL_TP_Y);
      RepositionY("CLEAR_TP", section_y + PM_PANEL_TP_Y);
      RepositionY("AUTO_LABEL", section_y + PM_PANEL_AUTO_LABEL_Y);
      RepositionY("AUTO_ENABLED", section_y + PM_PANEL_AUTO_Y);
      RepositionY("AUTO_SYMBOL_LABEL", section_y + PM_PANEL_AUTO_LABEL_Y);
      RepositionY("AUTO_SYMBOL", section_y + PM_PANEL_AUTO_Y);
      RepositionY("AUTO_DIRECTION", section_y + PM_PANEL_AUTO_Y);
      RepositionY("MINUTES_LABEL", section_y + PM_PANEL_AUTO_LABEL_Y);
      RepositionY("AUTO_MINUTES", section_y + PM_PANEL_AUTO_Y);
      RepositionY("PASSED_BEHAVIOR", section_y + PM_PANEL_AUTO_Y);
      RepositionY("EQ_LABEL", section_y + PM_PANEL_EQUITY_LABEL_Y);
      RepositionY("EQ_ENABLED", section_y + PM_PANEL_EQUITY_Y);
      RepositionY("EQ_MODE", section_y + PM_PANEL_EQUITY_Y);
      RepositionY("EQ_LOSS_LABEL", section_y + PM_PANEL_EQUITY_LABEL_Y);
      RepositionY("EQ_LOSS_VALUE", section_y + PM_PANEL_EQUITY_Y);
      RepositionY("EQ_PROFIT_LABEL", section_y + PM_PANEL_EQUITY_LABEL_Y);
      RepositionY("EQ_PROFIT_VALUE", section_y + PM_PANEL_EQUITY_Y);
      RepositionY("EQ_SCOPE_LABEL", section_y + PM_PANEL_EQUITY_LABEL_Y);
      RepositionY("TS_LABEL", section_y + PM_PANEL_TRAILING_SCOPE_LABEL_Y);
      RepositionY("TS_SYMBOL_LABEL", section_y + PM_PANEL_TRAILING_SCOPE_LABEL_Y);
      RepositionY("TS_SYMBOL", section_y + PM_PANEL_TRAILING_SCOPE_Y);
      RepositionY("TS_DIRECTION", section_y + PM_PANEL_TRAILING_SCOPE_Y);
      RepositionY("BE_LABEL", section_y + PM_PANEL_BREAK_EVEN_LABEL_Y);
      RepositionY("BE_ENABLED", section_y + PM_PANEL_BREAK_EVEN_Y);
      RepositionY("BE_TRIGGER_LABEL", section_y + PM_PANEL_BREAK_EVEN_LABEL_Y);
      RepositionY("BE_TRIGGER_VALUE", section_y + PM_PANEL_BREAK_EVEN_Y);
      RepositionY("BE_LOCK_LABEL", section_y + PM_PANEL_BREAK_EVEN_LABEL_Y);
      RepositionY("BE_LOCK_VALUE", section_y + PM_PANEL_BREAK_EVEN_Y);
      RepositionY("TRAIL_LABEL", section_y + PM_PANEL_TRAIL_LABEL_Y);
      RepositionY("TRAIL_ENABLED", section_y + PM_PANEL_TRAIL_Y);
      RepositionY("TRAIL_DIST_LABEL", section_y + PM_PANEL_TRAIL_LABEL_Y);
      RepositionY("TRAIL_DIST_VALUE", section_y + PM_PANEL_TRAIL_Y);
      RepositionY("SESSION_LABEL", section_y + PM_PANEL_SESSION_Y);
      RepositionY("STATUS_LABEL", section_y + PM_PANEL_STATUS_Y);
     }

   void RepositionY(const string suffix, const int y)
     {
      ObjectSetInteger(0, Name(suffix), OBJPROP_YDISTANCE, m_origin_y + y);
     }

   void Reposition(const string suffix, const int x, const int y)
     {
      ObjectSetInteger(0, Name(suffix), OBJPROP_XDISTANCE, m_origin_x + x);
      ObjectSetInteger(0, Name(suffix), OBJPROP_YDISTANCE, m_origin_y + y);
     }

   bool CreateBackground(const int height)
     {
      const string object_name = Name("BACKGROUND");
      if(!ObjectCreate(0, object_name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
         return false;
      ObjectSetInteger(0, object_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, object_name, OBJPROP_XDISTANCE, m_origin_x);
      ObjectSetInteger(0, object_name, OBJPROP_YDISTANCE, m_origin_y);
      ObjectSetInteger(0, object_name, OBJPROP_XSIZE, m_panel_width);
      ObjectSetInteger(0, object_name, OBJPROP_YSIZE, height);
      ObjectSetInteger(0, object_name, OBJPROP_BGCOLOR, C'25,25,30');
      ObjectSetInteger(0, object_name, OBJPROP_BORDER_COLOR, clrDimGray);
      ObjectSetInteger(0, object_name, OBJPROP_BACK, false);
      ObjectSetInteger(0, object_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, object_name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, object_name, OBJPROP_ZORDER, 0);
      return true;
     }

   void PrepareObject(const string object_name,
                      const int x,
                      const int y)
     {
      ObjectSetInteger(0, object_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, object_name, OBJPROP_XDISTANCE, m_origin_x + x);
      ObjectSetInteger(0, object_name, OBJPROP_YDISTANCE, m_origin_y + y);
      ObjectSetInteger(0, object_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, object_name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, object_name, OBJPROP_ZORDER, 1);
     }

   bool CreateLabel(const string suffix,
                    const string text,
                    const int x,
                    const int y,
                    const color text_color,
                    const int font_size)
     {
      const string object_name = Name(suffix);
      if(!ObjectCreate(0, object_name, OBJ_LABEL, 0, 0, 0))
         return false;
      PrepareObject(object_name, x, y);
      ObjectSetString(0, object_name, OBJPROP_TEXT, text);
      ObjectSetString(0, object_name, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, object_name, OBJPROP_FONTSIZE, font_size);
      ObjectSetInteger(0, object_name, OBJPROP_COLOR, text_color);
      return true;
     }

   bool CreateButton(const string suffix,
                     const string text,
                     const int x,
                     const int y,
                     const int width,
                     const int height = 22,
                     const color background = clrDarkSlateGray)
     {
      const string object_name = Name(suffix);
      if(!ObjectCreate(0, object_name, OBJ_BUTTON, 0, 0, 0))
         return false;
      PrepareObject(object_name, x, y);
      ObjectSetInteger(0, object_name, OBJPROP_XSIZE, width);
      ObjectSetInteger(0, object_name, OBJPROP_YSIZE, height);
      ObjectSetString(0, object_name, OBJPROP_TEXT, text);
      ObjectSetString(0, object_name, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, object_name, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, object_name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, object_name, OBJPROP_BGCOLOR, background);
      ObjectSetInteger(0, object_name, OBJPROP_BORDER_COLOR, clrGray);
      return true;
     }

   bool CreateEdit(const string suffix,
                   const string text,
                   const int x,
                   const int y,
                   const int width,
                   const int height)
     {
      const string object_name = Name(suffix);
      if(!ObjectCreate(0, object_name, OBJ_EDIT, 0, 0, 0))
         return false;
      PrepareObject(object_name, x, y);
      ObjectSetInteger(0, object_name, OBJPROP_XSIZE, width);
      ObjectSetInteger(0, object_name, OBJPROP_YSIZE, height);
      ObjectSetString(0, object_name, OBJPROP_TEXT, text);
      ObjectSetString(0, object_name, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, object_name, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, object_name, OBJPROP_COLOR, clrBlack);
      ObjectSetInteger(0, object_name, OBJPROP_BGCOLOR, clrWhite);
      return true;
     }
  };

#endif
