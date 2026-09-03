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
   int m_be_trigger_pips;
   int m_be_lock_pips;
   int m_trail_trigger_pips;
   int m_trail_pips;
   int m_max_rows;
   PMPanelTab m_active_tab;
   bool m_collapsed;
   string m_status;
   datetime m_session_close;
   datetime m_auto_close_at;
   int m_page;
   int m_rendered_rows;
   bool m_row_render_error_reported;
   int m_origin_x;
   int m_origin_y;
   int m_panel_width;
   int m_panel_height;
   int m_expanded_height;
   int m_user_panel_height;
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
   bool m_created;

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
      m_be_trigger_pips = 0;
      m_be_lock_pips = 0;
      m_trail_trigger_pips = 0;
      m_trail_pips = 0;
      m_max_rows = PM_DEFAULT_MAX_ROWS;
      m_active_tab = PM_PANEL_TAB_ENTRY;
      m_collapsed = false;
      m_status = "Ready";
      m_session_close = 0;
      m_auto_close_at = 0;
      m_page = 0;
      m_rendered_rows = 0;
      m_row_render_error_reported = false;
      m_origin_x = 0;
      m_origin_y = 0;
      m_panel_width = PM_DEFAULT_PANEL_WIDTH;
      m_panel_height = 0;
      m_expanded_height = 0;
      m_user_panel_height = 0;
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
      m_created = false;
     }

   bool Create(const int max_rows)
     {
      m_max_rows = MathMax(PM_MIN_POSITION_ROWS, MathMin(max_rows, PM_MAX_POSITION_ROWS));
      m_panel_width = PM_DEFAULT_PANEL_WIDTH;
      m_user_panel_height = 0;
      m_origin_x = 0;
      m_origin_y = 0;
      LoadPanelPosition();
      m_panel_height = ExpandedPanelHeight();
      m_expanded_height = m_panel_height;
      long mouse_move_enabled = 0;
      if(ChartGetInteger(0, CHART_EVENT_MOUSE_MOVE, 0, mouse_move_enabled))
         m_chart_mouse_move_before_create = mouse_move_enabled != 0;
      ResetLastError();
      if(!ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, 0, true))
        {
         PrintFormat("[ERROR] Unable to enable chart mouse move events. error=%d", GetLastError());
         return false;
        }
      ObjectsDeleteAll(0, PM_OBJECT_PREFIX);
      bool created = true;
      created = CreateBackground(PanelHeight()) && created;
      created = CreateLabel("TITLE", "MT5 Position Manager", 16, 7, clrWhite, 12) && created;
      created = CreateButton("COLLAPSE", "-", m_panel_width - 30, 4, 24, 20) && created;
      created = CreateButton("TAB_ENTRY", "Entry", 14, PM_TITLEBAR_HEIGHT + 3, 64, PM_TAB_BAR_HEIGHT - 4) && created;
      created = CreateButton("TAB_POSITIONS", "Positions", 82, PM_TITLEBAR_HEIGHT + 3, 74, PM_TAB_BAR_HEIGHT - 4) && created;
      created = CreateButton("TAB_STOPS", "SL/TP", 160, PM_TITLEBAR_HEIGHT + 3, 68, PM_TAB_BAR_HEIGHT - 4) && created;
      created = CreateButton("TAB_AUTO", "Auto Close", 232, PM_TITLEBAR_HEIGHT + 3, 82, PM_TAB_BAR_HEIGHT - 4) && created;
      created = CreateButton("TAB_GUARD", "Equity Guard", 318, PM_TITLEBAR_HEIGHT + 3, 94, PM_TAB_BAR_HEIGHT - 4) && created;
      created = CreateButton("TAB_TRAIL", "Trail", 416, PM_TITLEBAR_HEIGHT + 3, 60, PM_TAB_BAR_HEIGHT - 4) && created;

      created = CreateLabel("ENTRY_PRICE", "Bid - / Ask -", 12, ContentTop() + 5, clrSilver, 9) && created;
      created = CreateLabel("ENTRY_LOT_LABEL", "Lot", 12, ContentTop() + 35, clrSilver, 9) && created;
      created = CreateButton("ENTRY_LOT_DEC", "-", 58, ContentTop() + 30, 26, 22) && created;
      created = CreateEdit("ENTRY_LOT", "0.01", 88, ContentTop() + 30, 90, 22) && created;
      created = CreateButton("ENTRY_LOT_INC", "+", 182, ContentTop() + 30, 26, 22) && created;
      created = CreateLabel("ENTRY_SL_LABEL", "SL pts", 12, ContentTop() + 67, clrSilver, 9) && created;
      created = CreateButton("ENTRY_SL_DEC", "-", 58, ContentTop() + 62, 26, 22) && created;
      created = CreateEdit("ENTRY_SL_POINTS", "0", 88, ContentTop() + 62, 90, 22) && created;
      created = CreateButton("ENTRY_SL_INC", "+", 182, ContentTop() + 62, 26, 22) && created;
      created = CreateLabel("ENTRY_TP_LABEL", "TP pts", 12, ContentTop() + 99, clrSilver, 9) && created;
      created = CreateButton("ENTRY_TP_DEC", "-", 58, ContentTop() + 94, 26, 22) && created;
      created = CreateEdit("ENTRY_TP_POINTS", "0", 88, ContentTop() + 94, 90, 22) && created;
      created = CreateButton("ENTRY_TP_INC", "+", 182, ContentTop() + 94, 26, 22) && created;
      created = CreateLabel("ENTRY_BUY_PREVIEW", "Buy SL/TP: - / -", 230, ContentTop() + 34, clrSilver, 9) && created;
      created = CreateLabel("ENTRY_SELL_PREVIEW", "Sell SL/TP: - / -", 230, ContentTop() + 51, clrSilver, 9) && created;
      created = CreateButton("ENTRY_SELL", "SELL", 230, ContentTop() + 72, 105, 28, clrMaroon) && created;
      created = CreateButton("ENTRY_BUY", "BUY", 343, ContentTop() + 72, 105, 28, clrDarkGreen) && created;
      created = CreateLabel("ENTRY_HINT", "Prices follow current Bid/Ask; 0 pts disables SL/TP.", 12, ContentTop() + 130, clrSilver, 8) && created;

      created = CreateLabel("FILTER_LABEL", "Filter", 12, ContentTop() + 4, clrSilver, 9) && created;
      created = CreateButton("FILTER_SYMBOL", "Symbol", 62, ContentTop(), 120, 22) && created;
      created = CreateButton("FILTER_DIRECTION", "Both", 188, ContentTop(), 90, 22) && created;
      created = CreateButton("CLOSE_NOW", "Close Now", 284, ContentTop(), 100, 22, clrMaroon) && created;
      created = CreateButton("PAGE_PREV", "<", 12, ContentTop() + 26, 28, 22) && created;
      created = CreateButton("PAGE_NEXT", ">", 48, ContentTop() + 26, 28, 22) && created;
      created = CreateLabel("PAGE_LABEL", "Page 1/1", 100, ContentTop() + 31, clrSilver, 9) && created;
      created = CreateLabel("SELECTED_LABEL", "Selected 0", 190, ContentTop() + 31, clrSilver, 9) && created;
      created = CreateLabel("TOTAL_LABEL", "Total 0", 280, ContentTop() + 31, clrSilver, 9) && created;
      created = CreateButton("SELECT_ALL", "Select All", 12, ContentTop() + 52, 90, 22) && created;
      created = CreateButton("CLEAR_SELECTION", "Clear", 108, ContentTop() + 52, 65, 22) && created;
      created = CreateButton("CLOSE_SELECTED", "Close Selected", 179, ContentTop() + 52, 115, 22, clrMaroon) && created;

      created = CreateLabel("SL_LABEL", "SL", 12, ContentTop() + 5, clrSilver, 9) && created;
      created = CreateButton("SL_MODE", "Price", PM_STOPS_MODE_X, ContentTop(), 75, 22) && created;
      created = CreateButton("SL_DEC", "-", PM_STOPS_DEC_X, ContentTop(), 26, 22) && created;
      created = CreateEdit("SL_VALUE", "", PM_STOPS_VALUE_X, ContentTop(), 110, 22) && created;
      created = CreateButton("SL_INC", "+", PM_STOPS_INC_X, ContentTop(), 26, 22) && created;
      created = CreateButton("SET_SL", "Set / Change", PM_STOPS_SET_BUTTON_X, ContentTop(), PM_STOPS_SET_BUTTON_WIDTH, 22) && created;
      created = CreateButton("CLEAR_SL", "Clear SL", 12, ContentTop() + 32, 90, 22) && created;
      created = CreateLabel("TP_LABEL", "TP", 12, ContentTop() + 37, clrSilver, 9) && created;
      created = CreateButton("TP_MODE", "Price", PM_STOPS_MODE_X, ContentTop() + 32, 75, 22) && created;
      created = CreateButton("TP_DEC", "-", PM_STOPS_DEC_X, ContentTop() + 32, 26, 22) && created;
      created = CreateEdit("TP_VALUE", "", PM_STOPS_VALUE_X, ContentTop() + 32, 110, 22) && created;
      created = CreateButton("TP_INC", "+", PM_STOPS_INC_X, ContentTop() + 32, 26, 22) && created;
      created = CreateButton("SET_TP", "Set / Change", PM_STOPS_SET_BUTTON_X, ContentTop() + 62, PM_STOPS_SET_BUTTON_WIDTH, 22) && created;
      created = CreateButton("CLEAR_TP", "Clear TP", 123, ContentTop() + 62, 90, 22) && created;
      created = CreateLabel("STOPS_HINT", "Select positions; +/- uses the selected mode.", 220, ContentTop() + 66, clrSilver, 8) && created;
      ApplyStopsLayout();

      created = CreateLabel("AUTO_LABEL", "Auto Close", 12, ContentTop() + 4, clrSilver, 9) && created;
      created = CreateButton("AUTO_ENABLED", "OFF", 95, ContentTop(), 60, 22) && created;
      created = CreateButton("AUTO_SYMBOL", "Symbol", 165, ContentTop(), 105, 22) && created;
      created = CreateButton("AUTO_DIRECTION", "Both", 280, ContentTop(), 85, 22) && created;
      created = CreateLabel("MINUTES_LABEL", "Mins", 370, ContentTop() + 5, clrSilver, 9) && created;
      created = CreateEdit("AUTO_MINUTES", "10", 405, ContentTop(), 50, 22) && created;
      created = CreateButton("PASSED_BEHAVIOR", "Passed: Do Nothing", 12, ContentTop() + 32, 170, 22) && created;
      created = CreateLabel("AUTO_HINT", "Timer-driven schedule.", 195, ContentTop() + 37, clrSilver, 8) && created;

      created = CreateLabel("EQ_LABEL", "Equity Guard", 12, ContentTop() + 4, clrSilver, 9) && created;
      created = CreateButton("EQ_ENABLED", "OFF", 95, ContentTop(), 60, 22) && created;
      created = CreateButton("EQ_MODE", "Amount", 165, ContentTop(), 85, 22) && created;
      created = CreateLabel("EQ_LOSS_LABEL", "Loss", 12, ContentTop() + 37, clrSilver, 9) && created;
      created = CreateEdit("EQ_LOSS_VALUE", "", 52, ContentTop() + 32, 120, 22) && created;
      created = CreateLabel("EQ_PROFIT_LABEL", "Profit", 184, ContentTop() + 37, clrSilver, 9) && created;
      created = CreateEdit("EQ_PROFIT_VALUE", "", 229, ContentTop() + 32, 120, 22) && created;
      created = CreateLabel("EQ_HINT", "Guard OFF | Loss: not set | Profit: not set", 12, ContentTop() + 69, clrOrange, 8) && created;

      created = CreateLabel("TS_LABEL", "Trailing Scope", 12, ContentTop() + 4, clrSilver, 9) && created;
      created = CreateButton("TS_SYMBOL", "Symbol", 105, ContentTop(), 105, 22) && created;
      created = CreateButton("TS_DIRECTION", "Both", 220, ContentTop(), 85, 22) && created;
      created = CreateLabel("BE_LABEL", "Break Even", 12, ContentTop() + 37, clrSilver, 9) && created;
      created = CreateButton("BE_ENABLED", "OFF", 95, ContentTop() + 32, 60, 22) && created;
      created = CreateLabel("BE_TRIGGER_LABEL", "Trigger(pips)", 165, ContentTop() + 37, clrSilver, 9) && created;
      created = CreateEdit("BE_TRIGGER_VALUE", "", 250, ContentTop() + 32, 60, 22) && created;
      created = CreateLabel("BE_LOCK_LABEL", "Lock(pips)", 305, ContentTop() + 37, clrSilver, 9) && created;
      created = CreateEdit("BE_LOCK_VALUE", "", 390, ContentTop() + 32, 60, 22) && created;
      created = CreateLabel("TRAIL_LABEL", "Trailing", 12, ContentTop() + 70, clrSilver, 9) && created;
      created = CreateButton("TRAIL_ENABLED", "OFF", 95, ContentTop() + 65, 60, 22) && created;
      created = CreateLabel("TRAIL_TRIGGER_LABEL", "Trigger(pips)", 165, ContentTop() + 70, clrSilver, 9) && created;
      created = CreateEdit("TRAIL_TRIGGER_VALUE", "", 250, ContentTop() + 65, 60, 22) && created;
      created = CreateLabel("TRAIL_DIST_LABEL", "Distance(pips)", 310, ContentTop() + 70, clrSilver, 9) && created;
      created = CreateEdit("TRAIL_DIST_VALUE", "", 390, ContentTop() + 65, 60, 22) && created;
      AlignLabelToInput("BE_TRIGGER_LABEL", 238, ContentTop() + 37);
      AlignLabelToInput("BE_LOCK_LABEL", 378, ContentTop() + 37);
      AlignLabelToInput("TRAIL_TRIGGER_LABEL", 238, ContentTop() + 70);
      AlignLabelToInput("TRAIL_DIST_LABEL", 378, ContentTop() + 70);
      created = CreateLabel("TRAIL_HINT", "Break-even and trailing rules use pips. Trigger 0 uses Distance.", 12, ContentTop() + 103, clrSilver, 8) && created;

      created = CreateLabel("SESSION_LABEL", "Session close: - | Auto close: -", 14, 0, clrSilver, 9) && created;
      for(int line = 0; line < PM_MAX_STATUS_LINES; line++)
         created = CreateLabel("STATUS_LINE_" + IntegerToString(line), "", 14, 0, PM_STATUS_COLOR, PM_STATUS_FONT_SIZE) && created;
      created = CreateLabel("RESIZE_GRIP", "///", m_panel_width - 24, PanelHeight() - 18, clrSilver, 8) && created;
      UpdateToggleButtonVisual("AUTO_ENABLED", m_auto_enabled);
      UpdateToggleButtonVisual("BE_ENABLED", m_break_even_enabled);
      UpdateToggleButtonVisual("TRAIL_ENABLED", m_trailing_enabled);
      UpdateEquityGuardVisuals();
      ApplyTabVisibility();
      UpdateStatusLayout();
      ChartRedraw();
      if(!created)
        {
         PrintFormat("[ERROR] UI panel creation failed. last_error=%d", GetLastError());
         Destroy();
        }
      else
         m_created = true;
      return created;
     }

   void SavePosition()
     {
      if(!m_created)
         return;
      GlobalVariableSet(PanelPositionKey("X"), (double)m_origin_x);
      GlobalVariableSet(PanelPositionKey("Y"), (double)m_origin_y);
     }

   void Destroy()
     {
      EndInteraction();
      ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, 0, m_chart_mouse_move_before_create);
      ObjectsDeleteAll(0, PM_OBJECT_PREFIX);
      m_created = false;
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
         if(!ContainsPosition(m_selected[i]))
            ArrayRemove(m_selected, i, 1);
     }

   void Render()
     {
      ObjectSetString(0, Name("FILTER_SYMBOL"), OBJPROP_TEXT, FilterSymbol());
      ObjectSetString(0, Name("FILTER_DIRECTION"), OBJPROP_TEXT, PMDirectionToString(m_filter_direction));
      ObjectSetString(0, Name("SL_MODE"), OBJPROP_TEXT, PriceModeToString(m_sl_mode));
      ObjectSetString(0, Name("TP_MODE"), OBJPROP_TEXT, PriceModeToString(m_tp_mode));
      UpdateToggleButtonVisual("AUTO_ENABLED", m_auto_enabled);
      ObjectSetString(0, Name("AUTO_SYMBOL"), OBJPROP_TEXT, AutoSymbol());
      ObjectSetString(0, Name("AUTO_DIRECTION"), OBJPROP_TEXT, PMDirectionToString(m_auto_direction));
      ObjectSetString(0, Name("PASSED_BEHAVIOR"), OBJPROP_TEXT,
                      m_passed_behavior == PM_PASSED_CLOSE_IMMEDIATELY ? "Passed: Close Now" : "Passed: Do Nothing");
      ObjectSetString(0, Name("EQ_MODE"), OBJPROP_TEXT, EquityThresholdModeToString(m_equity_guard_mode));
      UpdateEquityGuardVisuals();
      ObjectSetString(0, Name("TS_SYMBOL"), OBJPROP_TEXT, TrailingSymbol());
      ObjectSetString(0, Name("TS_DIRECTION"), OBJPROP_TEXT, PMDirectionToString(m_trailing_direction));
      UpdateToggleButtonVisual("BE_ENABLED", m_break_even_enabled);
      UpdateToggleButtonVisual("TRAIL_ENABLED", m_trailing_enabled);
      ObjectSetString(0, Name("SESSION_LABEL"), OBJPROP_TEXT,
                      "Session close: " + PMFormatDateTime(m_session_close) +
                      " | Auto close: " + PMFormatDateTime(m_auto_close_at));
      MqlTick tick = {};
      SymbolInfoTick(_Symbol, tick);
      ObjectSetString(0, Name("ENTRY_PRICE"), OBJPROP_TEXT,
                      _Symbol + "  Bid " + PMFormatPrice(_Symbol, tick.bid) +
                      " / Ask " + PMFormatPrice(_Symbol, tick.ask));
      UpdateEntryPreview(tick);
      ObjectSetString(0, Name("PAGE_LABEL"), OBJPROP_TEXT,
                      StringFormat("Page %d/%d", m_page + 1, PageCount()));
      ObjectSetString(0, Name("SELECTED_LABEL"), OBJPROP_TEXT,
                      StringFormat("Selected %d", ArraySize(m_selected)));
      ObjectSetString(0, Name("TOTAL_LABEL"), OBJPROP_TEXT,
                      StringFormat("Total %d", ArraySize(m_positions)));
      if(!m_collapsed && m_active_tab == PM_PANEL_TAB_POSITIONS)
         RenderPositionRows();
      else
         ClearPositionRows();
      ApplyTabVisibility();
      UpdateStatusLayout();
      MovePanelTo(m_origin_x, m_origin_y);
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
      const int digits = (int)SymbolInfoInteger(config.symbol, SYMBOL_DIGITS);
      config.be_trigger_points = PMPipsToPoints(m_be_trigger_pips, digits);
      config.be_lock_points = PMPipsToPoints(m_be_lock_pips, digits);
      const int trail_trigger_pips = m_trail_trigger_pips > 0 ?
                                     m_trail_trigger_pips : m_trail_pips;
      config.trail_trigger_points = PMPipsToPoints(trail_trigger_pips, digits);
      config.trail_points = PMPipsToPoints(m_trail_pips, digits);
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
      if(id == CHARTEVENT_OBJECT_ENDEDIT)
         return HandleEditEnd(object_name);
      EndInteraction();
      if(StringFind(object_name, PM_OBJECT_PREFIX) != 0)
         return false;
      ObjectSetInteger(0, object_name, OBJPROP_STATE, false);
      if(object_name == Name("COLLAPSE"))
        {
         m_collapsed = !m_collapsed;
         if(m_collapsed)
            m_panel_height = PM_TITLEBAR_HEIGHT;
         else
            m_panel_height = m_expanded_height;
        }
      else if(HandleTabClick(object_name))
         m_collapsed = false;
      else if(object_name == Name("ENTRY_LOT_DEC"))
         ShiftEntryVolume(-1.0);
      else if(object_name == Name("ENTRY_LOT_INC"))
         ShiftEntryVolume(1.0);
      else if(object_name == Name("ENTRY_SL_DEC"))
         ShiftEntryPoints("ENTRY_SL_POINTS", -1);
      else if(object_name == Name("ENTRY_SL_INC"))
         ShiftEntryPoints("ENTRY_SL_POINTS", 1);
      else if(object_name == Name("ENTRY_TP_DEC"))
         ShiftEntryPoints("ENTRY_TP_POINTS", -1);
      else if(object_name == Name("ENTRY_TP_INC"))
         ShiftEntryPoints("ENTRY_TP_POINTS", 1);
      else if(object_name == Name("ENTRY_BUY"))
         OpenMarket(PM_ENTRY_BUY, trades, validator);
      else if(object_name == Name("ENTRY_SELL"))
         OpenMarket(PM_ENTRY_SELL, trades, validator);
      else if(object_name == Name("FILTER_SYMBOL"))
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
         m_sl_mode = m_sl_mode == PM_PRICE_ABSOLUTE ? PM_PRICE_PIPS : PM_PRICE_ABSOLUTE;
      else if(object_name == Name("SL_DEC"))
         ShiftStopEditor(true, -1);
      else if(object_name == Name("SL_INC"))
         ShiftStopEditor(true, 1);
      else if(object_name == Name("SET_SL"))
         ApplyStopTarget(true, positions, trades, validator, actions);
      else if(object_name == Name("CLEAR_SL"))
         ClearStopTarget(true, positions, trades, actions);
      else if(object_name == Name("TP_MODE"))
         m_tp_mode = m_tp_mode == PM_PRICE_ABSOLUTE ? PM_PRICE_PIPS : PM_PRICE_ABSOLUTE;
      else if(object_name == Name("TP_DEC"))
         ShiftStopEditor(false, -1);
      else if(object_name == Name("TP_INC"))
         ShiftStopEditor(false, 1);
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
         m_passed_behavior = m_passed_behavior == PM_PASSED_CLOSE_DO_NOTHING ? PM_PASSED_CLOSE_IMMEDIATELY : PM_PASSED_CLOSE_DO_NOTHING;
      else if(object_name == Name("EQ_ENABLED"))
        {
         m_equity_guard_enabled = !m_equity_guard_enabled;
         SetStatus(StringFormat("Equity Guard %s.", m_equity_guard_enabled ? "ON" : "OFF"));
        }
      else if(object_name == Name("EQ_MODE"))
         m_equity_guard_mode = m_equity_guard_mode == PM_EQUITY_THRESHOLD_AMOUNT ? PM_EQUITY_THRESHOLD_PERCENT : PM_EQUITY_THRESHOLD_AMOUNT;
      else if(object_name == Name("TS_SYMBOL"))
         CycleSymbol(m_trailing_symbol);
      else if(object_name == Name("TS_DIRECTION"))
         m_trailing_direction = NextDirection(m_trailing_direction);
      else if(object_name == Name("BE_ENABLED"))
         m_break_even_enabled = !m_break_even_enabled;
      else if(object_name == Name("TRAIL_ENABLED"))
         m_trailing_enabled = !m_trailing_enabled;
      else
         ToggleRowSelection(object_name);
      Render();
      return true;
     }

private:
   string Name(const string suffix) { return PM_OBJECT_PREFIX + suffix; }
   string PanelPositionKey(const string axis)
     {
      return StringFormat("%s%I64d_%s", PM_PANEL_POSITION_KEY_PREFIX,
                          ChartID(), axis);
     }
   void LoadPanelPosition()
     {
      double saved_x = 0.0;
      double saved_y = 0.0;
      if(!GlobalVariableGet(PanelPositionKey("X"), saved_x) ||
         !GlobalVariableGet(PanelPositionKey("Y"), saved_y))
         return;
      if(!MathIsValidNumber(saved_x) || !MathIsValidNumber(saved_y))
         return;
      m_origin_x = (int)MathMax(0.0, MathRound(saved_x));
      m_origin_y = (int)MathMax(0.0, MathRound(saved_y));
     }
   string RowName(const int row) { return Name("ROW_" + IntegerToString(row)); }
   string RowDetailName(const int row) { return Name("ROW_DETAIL_" + IntegerToString(row)); }
   string RowDirectionName(const int row) { return Name("ROW_DIRECTION_" + IntegerToString(row)); }
   string FilterSymbol() { return m_filter_symbol == "" ? _Symbol : m_filter_symbol; }
   string AutoSymbol() { return m_auto_symbol == "" ? _Symbol : m_auto_symbol; }
   string TrailingSymbol() { return m_trailing_symbol == "" ? _Symbol : m_trailing_symbol; }
   int ContentTop() { return PM_TITLEBAR_HEIGHT + PM_TAB_BAR_HEIGHT + PM_PANEL_CONTENT_GAP; }
   int AutoCloseMinutes()
     {
      long minutes = StringToInteger(ObjectGetString(0, Name("AUTO_MINUTES"), OBJPROP_TEXT));
      if(minutes < 0) minutes = 0;
      if(minutes > PM_MAX_AUTO_CLOSE_MINUTES) minutes = PM_MAX_AUTO_CLOSE_MINUTES;
      return (int)minutes;
     }
   int PageCount()
     {
      if(ArraySize(m_positions) == 0) return 1;
      return (ArraySize(m_positions) + m_max_rows - 1) / m_max_rows;
     }
   void ClampPage()
     {
      const int pages = PageCount();
      if(m_page < 0) m_page = 0;
      if(m_page >= pages) m_page = pages - 1;
     }
   int VisiblePositionRows()
     {
      const int start = m_page * m_max_rows;
      return MathMax(0, MathMin(m_max_rows, ArraySize(m_positions) - start));
     }
   int ContentHeight()
     {
      if(m_active_tab == PM_PANEL_TAB_ENTRY) return PM_PANEL_ENTRY_HEIGHT;
      if(m_active_tab == PM_PANEL_TAB_POSITIONS) return PM_PANEL_POSITIONS_HEADER_HEIGHT + MathMax(1, VisiblePositionRows()) * PM_PANEL_POSITION_ROW_HEIGHT;
      if(m_active_tab == PM_PANEL_TAB_STOPS)
         return PM_PANEL_STOPS_HEIGHT;
      if(m_active_tab == PM_PANEL_TAB_AUTO) return PM_PANEL_AUTO_HEIGHT;
      if(m_active_tab == PM_PANEL_TAB_GUARD) return PM_PANEL_GUARD_HEIGHT;
      return PM_PANEL_TRAIL_HEIGHT;
     }
   int ExpandedPanelHeight()
     {
      return ContentTop() + ContentHeight() + PM_PANEL_CONTENT_GAP + PM_PANEL_STATUS_LINE_HEIGHT * 3 + 32;
     }
   int PanelHeight() { return m_panel_height > 0 ? m_panel_height : ExpandedPanelHeight(); }
   PMDirection NextDirection(const PMDirection direction)
     {
      return direction == PM_DIRECTION_LONG ? PM_DIRECTION_SHORT : direction == PM_DIRECTION_SHORT ? PM_DIRECTION_BOTH : PM_DIRECTION_LONG;
     }
   string PriceModeToString(const PMPriceMode mode) { return mode == PM_PRICE_ABSOLUTE ? "Price" : "Pips"; }
   string EquityThresholdModeToString(const PMEquityThresholdMode mode) { return mode == PM_EQUITY_THRESHOLD_AMOUNT ? "Amount" : "Percent"; }
   bool IsSelected(const ulong ticket)
     {
      for(int i = 0; i < ArraySize(m_selected); i++) if(m_selected[i] == ticket) return true;
      return false;
     }
   bool ContainsPosition(const ulong ticket)
     {
      for(int i = 0; i < ArraySize(m_positions); i++) if(m_positions[i].ticket == ticket) return true;
      return false;
     }
   void ToggleSelection(const ulong ticket)
     {
      for(int i = 0; i < ArraySize(m_selected); i++)
         if(m_selected[i] == ticket) { ArrayRemove(m_selected, i, 1); return; }
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
   void ToggleRowSelection(const string object_name)
     {
      const int start = m_page * m_max_rows;
      for(int row = 0; row < VisiblePositionRows(); row++)
         if(object_name == RowName(row) || object_name == RowDetailName(row) || object_name == RowDirectionName(row))
           {
            ToggleSelection(m_positions[start + row].ticket);
            return;
           }
     }
   string BuildTicketSummary(const string heading, const ulong &tickets[])
     {
      string text = heading + "\n\n";
      for(int i = 0; i < ArraySize(tickets); i++)
        {
         PMPosition position = {};
         if(FindCachedPosition(tickets[i], position))
            text += StringFormat("%s %s %.2f  #%I64u\n", position.symbol, PMPositionTypeToString(position.type), position.volume, position.ticket);
         else
            text += StringFormat("Unavailable  #%I64u\n", tickets[i]);
        }
      return text + "\nContinue?";
     }
   bool FindCachedPosition(const ulong ticket, PMPosition &position)
     {
      for(int i = 0; i < ArraySize(m_positions); i++) if(m_positions[i].ticket == ticket) { position = m_positions[i]; return true; }
      return false;
     }
   void CloseNow(CPositionService &positions, CTradeManager &trades)
     {
      ulong tickets[];
      positions.CollectTickets(FilterSymbol(), m_filter_direction, tickets);
      if(ArraySize(tickets) == 0) { SetStatus("No matching positions."); return; }
      if(MessageBox(BuildTicketSummary(StringFormat("Close %d %s %s positions?", ArraySize(tickets), FilterSymbol(), PMDirectionToString(m_filter_direction)), tickets), "MT5 Position Manager", MB_YESNO | MB_ICONWARNING | MB_DEFBUTTON2) != IDYES)
        { SetStatus("Close cancelled."); return; }
      PMBatchResult result;
      trades.CloseTickets(tickets, result);
      SetStatus(BatchResultText("Close", result));
     }
   void CloseSelected(CTradeManager &trades)
     {
      if(ArraySize(m_selected) == 0) { SetStatus("No positions selected."); return; }
      if(MessageBox(BuildTicketSummary(StringFormat("Close %d selected positions?", ArraySize(m_selected)), m_selected), "MT5 Position Manager", MB_YESNO | MB_ICONWARNING | MB_DEFBUTTON2) != IDYES)
        { SetStatus("Close cancelled."); return; }
      PMBatchResult result;
      trades.CloseTickets(m_selected, result);
      SetStatus(BatchResultText("Close", result));
     }
   string BatchResultText(const string operation, PMBatchResult &result)
     {
      if(ArraySize(result.failures) > 0 && PMIsTradingUnavailableRetcode(result.failures[0].retcode))
         return StringFormat("%s stopped: trading unavailable (%s)", operation, result.failures[0].description);
      string text = StringFormat("%s: %d succeeded, %d queued, %d failed / %d", operation, result.successful, result.queued, ArraySize(result.failures), result.requested);
      if(ArraySize(result.failures) > 0)
         text += StringFormat("; ticket=%I64u (%s, retcode=%u)", result.failures[0].ticket, result.failures[0].description, result.failures[0].retcode);
      return text;
     }
   void ApplyStopTarget(const bool is_sl, CPositionService &positions, CTradeManager &trades, CValidationService &validator, CPositionActionService &actions)
     {
      if(ArraySize(m_selected) == 0) { SetStatus("No positions selected."); return; }
      const string suffix = is_sl ? "SL_VALUE" : "TP_VALUE";
      const double value = StringToDouble(ObjectGetString(0, Name(suffix), OBJPROP_TEXT));
      PMBatchResult result;
      string validation_error = "";
      if(!actions.ApplyStopTarget(m_selected, is_sl, is_sl ? m_sl_mode : m_tp_mode, value, positions, trades, validator, result, validation_error))
        { SetStatus(validation_error); return; }
      SetStatus(BatchResultText(is_sl ? "SL update" : "TP update", result));
     }
   void ClearStopTarget(const bool is_sl, CPositionService &positions, CTradeManager &trades, CPositionActionService &actions)
     {
      if(ArraySize(m_selected) == 0) { SetStatus("No positions selected."); return; }
      PMBatchResult result;
      actions.ClearStopTarget(m_selected, is_sl, positions, trades, result);
      SetStatus(BatchResultText(is_sl ? "SL clear" : "TP clear", result));
     }
   void CommitDoubleValue(const string suffix, double &target, const double maximum, const int digits)
     {
      double value = StringToDouble(ObjectGetString(0, Name(suffix), OBJPROP_TEXT));
      if(!MathIsValidNumber(value) || value < 0.0) value = 0.0;
      if(value > maximum) value = maximum;
      target = value;
      ObjectSetString(0, Name(suffix), OBJPROP_TEXT, DoubleToString(value, digits));
     }
   void CommitIntegerValue(const string suffix, int &target, const int maximum)
     {
      long value = StringToInteger(ObjectGetString(0, Name(suffix), OBJPROP_TEXT));
      if(value < 0) value = 0;
      if(value > maximum) value = maximum;
      target = (int)value;
      ObjectSetString(0, Name(suffix), OBJPROP_TEXT, IntegerToString(target));
     }
   bool HandleEditEnd(const string object_name)
     {
      if(object_name == Name("AUTO_MINUTES")) { const int value = AutoCloseMinutes(); ObjectSetString(0, Name("AUTO_MINUTES"), OBJPROP_TEXT, IntegerToString(value)); SetStatus(StringFormat("Auto Close minutes set to %d.", value)); }
      else if(object_name == Name("EQ_LOSS_VALUE")) { CommitDoubleValue("EQ_LOSS_VALUE", m_equity_guard_loss_threshold, PM_MAX_EQUITY_THRESHOLD, 2); UpdateEquityGuardVisuals(); SetStatus(StringFormat("Max Loss updated: %.2f (%s).", m_equity_guard_loss_threshold, m_equity_guard_enabled ? "Guard ON" : "Guard OFF")); }
      else if(object_name == Name("EQ_PROFIT_VALUE")) { CommitDoubleValue("EQ_PROFIT_VALUE", m_equity_guard_profit_threshold, PM_MAX_EQUITY_THRESHOLD, 2); UpdateEquityGuardVisuals(); SetStatus(StringFormat("Max Profit updated: %.2f (%s).", m_equity_guard_profit_threshold, m_equity_guard_enabled ? "Guard ON" : "Guard OFF")); }
      else if(object_name == Name("BE_TRIGGER_VALUE")) { CommitIntegerValue("BE_TRIGGER_VALUE", m_be_trigger_pips, PM_MAX_TRAILING_POINTS); SetStatus(StringFormat("Break Even Trigger updated: %d pips.", m_be_trigger_pips)); }
      else if(object_name == Name("BE_LOCK_VALUE")) { CommitIntegerValue("BE_LOCK_VALUE", m_be_lock_pips, PM_MAX_TRAILING_POINTS); SetStatus(StringFormat("Break Even Lock updated: %d pips.", m_be_lock_pips)); }
      else if(object_name == Name("TRAIL_TRIGGER_VALUE")) { CommitIntegerValue("TRAIL_TRIGGER_VALUE", m_trail_trigger_pips, PM_MAX_TRAILING_POINTS); SetStatus(StringFormat("Trailing Trigger updated: %d pips.", m_trail_trigger_pips)); }
      else if(object_name == Name("TRAIL_DIST_VALUE")) { CommitIntegerValue("TRAIL_DIST_VALUE", m_trail_pips, PM_MAX_TRAILING_POINTS); SetStatus(StringFormat("Trailing Distance updated: %d pips.", m_trail_pips)); }
      else if(object_name == Name("ENTRY_LOT"))
        {
         double volume = 0.0;
         string reason = "";
         if(NormalizeEntryVolume(volume, reason))
            SetStatus("Entry lot updated.");
         else
            SetStatus(reason);
        }
      else if(object_name == Name("ENTRY_SL_POINTS"))
        {
         string reason = "";
         if(NormalizeEntryPoints("ENTRY_SL_POINTS", reason))
            SetStatus("Entry SL points updated.");
         else
            SetStatus(reason);
        }
      else if(object_name == Name("ENTRY_TP_POINTS"))
        {
         string reason = "";
         if(NormalizeEntryPoints("ENTRY_TP_POINTS", reason))
            SetStatus("Entry TP points updated.");
         else
            SetStatus(reason);
        }
      else if(object_name == Name("SL_VALUE")) { SetStatus("SL value updated."); }
      else if(object_name == Name("TP_VALUE")) { SetStatus("TP value updated."); }
      else return false;
      Render();
      return true;
     }
   int FindSymbol(const string symbol)
     {
      for(int i = 0; i < ArraySize(m_symbols); i++) if(m_symbols[i] == symbol) return i;
      return -1;
     }
   void EnsureSymbolCandidate(const string symbol)
     {
      if(symbol == "" || FindSymbol(symbol) >= 0) return;
      const int count = ArraySize(m_symbols);
      ArrayResize(m_symbols, count + 1);
      m_symbols[count] = symbol;
     }
   void CycleSymbol(string &selected)
     {
      EnsureSymbolCandidate(selected);
      if(ArraySize(m_symbols) == 0) { selected = _Symbol; return; }
      int index = FindSymbol(selected);
      if(index < 0) index = 0;
      selected = m_symbols[(index + 1) % ArraySize(m_symbols)];
     }
   bool HandleTabClick(const string object_name)
     {
      PMPanelTab tab = m_active_tab;
      if(object_name == Name("TAB_ENTRY")) tab = PM_PANEL_TAB_ENTRY;
      else if(object_name == Name("TAB_POSITIONS")) tab = PM_PANEL_TAB_POSITIONS;
      else if(object_name == Name("TAB_STOPS")) tab = PM_PANEL_TAB_STOPS;
      else if(object_name == Name("TAB_AUTO")) tab = PM_PANEL_TAB_AUTO;
      else if(object_name == Name("TAB_GUARD")) tab = PM_PANEL_TAB_GUARD;
      else if(object_name == Name("TAB_TRAIL")) tab = PM_PANEL_TAB_TRAIL;
      else return false;
      m_active_tab = tab;
      m_expanded_height = PMResolvePanelHeight(ExpandedPanelHeight(),
                                               m_user_panel_height);
      m_panel_height = m_expanded_height;
      return true;
     }
   void ShiftEntryVolume(const double direction)
     {
      const double minimum = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      const double maximum = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      const double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double value = StringToDouble(ObjectGetString(0, Name("ENTRY_LOT"), OBJPROP_TEXT));
      if(!MathIsValidNumber(value) || value <= 0.0) value = minimum;
      value = PMNormalizeVolume(value + direction * step, minimum, maximum, step);
      ObjectSetString(0, Name("ENTRY_LOT"), OBJPROP_TEXT, DoubleToString(value, VolumeDigits(step)));
     }
   int VolumeDigits(const double step)
     {
      if(step <= 0.0) return 2;
      double scaled = step;
      int digits = 0;
      while(digits < 8 && MathAbs(scaled - MathRound(scaled)) > 0.00000001)
        {
         scaled *= 10.0;
         digits++;
        }
      return digits;
     }
   bool NormalizeEntryVolume(double &volume, string &reason)
     {
      volume = 0.0;
      reason = "";
      const string text = ObjectGetString(0, Name("ENTRY_LOT"), OBJPROP_TEXT);
      if(!PMIsUnsignedDecimalText(text))
        {
         reason = "Entry lot must be a positive number.";
         return false;
        }
      const double minimum = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      const double maximum = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      const double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      const double requested = StringToDouble(text);
      if(!MathIsValidNumber(requested) || requested <= 0.0 ||
         minimum <= 0.0 || maximum < minimum || step <= 0.0)
        {
         reason = "Entry lot or symbol volume settings are invalid.";
         return false;
        }
      volume = PMNormalizeVolume(requested, minimum, maximum, step);
      if(volume <= 0.0)
        {
         reason = "Entry lot could not be normalized.";
         return false;
        }
      ObjectSetString(0, Name("ENTRY_LOT"), OBJPROP_TEXT,
                      DoubleToString(volume, VolumeDigits(step)));
      return true;
     }
   void ShiftEntryPoints(const string suffix, const int delta)
     {
      const string text = ObjectGetString(0, Name(suffix), OBJPROP_TEXT);
      long value = PMIsUnsignedIntegerText(text) ? StringToInteger(text) : 0;
      if(value < 0)
         value = 0;
      if(value > PM_MAX_TRAILING_POINTS)
         value = PM_MAX_TRAILING_POINTS;
      if(delta < 0 && value > 0)
         value--;
      else if(delta > 0 && value < PM_MAX_TRAILING_POINTS)
         value++;
      ObjectSetString(0, Name(suffix), OBJPROP_TEXT, IntegerToString((int)value));
     }
   bool NormalizeEntryPoints(const string suffix, string &reason)
     {
      reason = "";
      const string text = ObjectGetString(0, Name(suffix), OBJPROP_TEXT);
      if(!PMIsUnsignedIntegerText(text))
        {
         reason = "Entry SL/TP points must be a non-negative integer.";
         return false;
        }
      long value = StringToInteger(text);
      if(value < 0)
        {
         reason = "Entry SL/TP points are outside the supported range.";
         return false;
        }
      if(value > PM_MAX_TRAILING_POINTS) value = PM_MAX_TRAILING_POINTS;
      ObjectSetString(0, Name(suffix), OBJPROP_TEXT, IntegerToString((int)value));
      return true;
     }
   bool ReadEntryPoints(int &sl_points, int &tp_points, string &reason)
     {
      sl_points = 0;
      tp_points = 0;
      reason = "";
      const string sl_text = ObjectGetString(0, Name("ENTRY_SL_POINTS"), OBJPROP_TEXT);
      const string tp_text = ObjectGetString(0, Name("ENTRY_TP_POINTS"), OBJPROP_TEXT);
      if(!PMIsUnsignedIntegerText(sl_text) || !PMIsUnsignedIntegerText(tp_text))
        {
         reason = "Entry SL/TP points must be non-negative integers.";
         return false;
        }
      const long parsed_sl = StringToInteger(sl_text);
      const long parsed_tp = StringToInteger(tp_text);
      if(parsed_sl < 0 || parsed_tp < 0 ||
         parsed_sl > PM_MAX_TRAILING_POINTS || parsed_tp > PM_MAX_TRAILING_POINTS)
        {
         reason = StringFormat("Entry SL/TP points must not exceed %d.", PM_MAX_TRAILING_POINTS);
         return false;
        }
      sl_points = (int)parsed_sl;
      tp_points = (int)parsed_tp;
      return true;
     }
   void ShiftStopEditor(const bool is_sl, const int direction)
     {
      const string suffix = is_sl ? "SL_VALUE" : "TP_VALUE";
      double value = StringToDouble(ObjectGetString(0, Name(suffix), OBJPROP_TEXT));
      if(!MathIsValidNumber(value)) value = 0.0;
      if((is_sl ? m_sl_mode : m_tp_mode) == PM_PRICE_PIPS)
         value = MathMax(0.0, value + direction);
      else
        {
         PMPosition selected_position = {};
         const bool has_selected_position = FirstSelectedPosition(selected_position);
         const string symbol = has_selected_position ? selected_position.symbol : _Symbol;
         const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         const double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
         const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
         const double step = PMPriceEditorStep(point, tick_size, digits);
         if(value <= 0.0 && has_selected_position)
            value = is_sl ? selected_position.sl : selected_position.tp;
         if(value <= 0.0)
           {
            MqlTick tick = {};
            if(!SymbolInfoTick(symbol, tick) || tick.bid <= 0.0 || tick.ask <= 0.0 || step <= 0.0)
              {
               SetStatus("Current price is unavailable for " + symbol + ".");
               return;
              }
            value = has_selected_position && selected_position.type == POSITION_TYPE_SELL ? tick.ask : tick.bid;
           }
         value = PMShiftPriceEditorValue(value, point, tick_size, direction, digits);
         ObjectSetString(0, Name(suffix), OBJPROP_TEXT, DoubleToString(value, digits));
         return;
        }
      ObjectSetString(0, Name(suffix), OBJPROP_TEXT, DoubleToString(value, 0));
     }
   bool FirstSelectedPosition(PMPosition &position)
     {
      for(int index = 0; index < ArraySize(m_selected); index++)
         if(FindCachedPosition(m_selected[index], position))
            return true;
      return false;
     }
   void UpdateEntryPreview(const MqlTick &tick)
     {
      int sl_points = 0;
      int tp_points = 0;
      string reason = "";
      if(!ReadEntryPoints(sl_points, tp_points, reason))
        {
         ObjectSetString(0, Name("ENTRY_BUY_PREVIEW"), OBJPROP_TEXT, "Buy SL/TP: invalid input");
         ObjectSetString(0, Name("ENTRY_SELL_PREVIEW"), OBJPROP_TEXT, "Sell SL/TP: invalid input");
         return;
        }

      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      const long stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      const long freeze_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
      double buy_sl = 0.0;
      double buy_tp = 0.0;
      string buy_reason = "";
      const bool buy_valid = PMCalculateEntryStops(PM_ENTRY_BUY, tick.bid, tick.ask,
                                                    point, tick_size, digits,
                                                    stops_level, freeze_level,
                                                    sl_points, tp_points,
                                                    buy_sl, buy_tp, buy_reason);
      double sell_sl = 0.0;
      double sell_tp = 0.0;
      string sell_reason = "";
      const bool sell_valid = PMCalculateEntryStops(PM_ENTRY_SELL, tick.bid, tick.ask,
                                                     point, tick_size, digits,
                                                     stops_level, freeze_level,
                                                     sl_points, tp_points,
                                                     sell_sl, sell_tp, sell_reason);
      ObjectSetString(0, Name("ENTRY_BUY_PREVIEW"), OBJPROP_TEXT,
                      buy_valid ? "Buy SL/TP: " + PMFormatPrice(_Symbol, buy_sl) + " / " + PMFormatPrice(_Symbol, buy_tp) :
                                  "Buy SL/TP: invalid distance");
      ObjectSetString(0, Name("ENTRY_SELL_PREVIEW"), OBJPROP_TEXT,
                      sell_valid ? "Sell SL/TP: " + PMFormatPrice(_Symbol, sell_sl) + " / " + PMFormatPrice(_Symbol, sell_tp) :
                                   "Sell SL/TP: invalid distance");
     }
   void OpenMarket(const PMEntrySide side, CTradeManager &trades, CValidationService &validator)
     {
      double volume = 0.0;
      string reason = "";
      if(!NormalizeEntryVolume(volume, reason))
        {
         SetStatus(reason);
         return;
        }
      int sl_points = 0;
      int tp_points = 0;
      if(!ReadEntryPoints(sl_points, tp_points, reason))
        {
         SetStatus(reason);
         return;
        }
      double sl = 0.0;
      double tp = 0.0;
      if(!validator.CalculateEntryStops(_Symbol, side, sl_points, tp_points, sl, tp, reason))
        { SetStatus(reason); return; }
      PMMarketEntryResult result;
      if(!trades.OpenMarket(_Symbol, side, volume, sl, tp, result))
        { SetStatus(StringFormat("%s failed: %s (retcode=%u)", side == PM_ENTRY_BUY ? "Buy" : "Sell", result.description, result.retcode)); return; }
      SetStatus(StringFormat("%s accepted: %s requested=%s result=%s price=%s deal=%I64u order=%I64u retcode=%u",
                             side == PM_ENTRY_BUY ? "Buy" : "Sell", _Symbol,
                             DoubleToString(volume, VolumeDigits(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP))),
                             DoubleToString(result.volume, VolumeDigits(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP))),
                             PMFormatPrice(_Symbol, result.price), result.deal,
                             result.order, result.retcode));
     }
   void RenderPositionRows()
     {
      const int start = m_page * m_max_rows;
      const int visible_rows = VisiblePositionRows();
      const int previous_rows = m_rendered_rows;
      bool rows_created = true;
      for(int row = 0; row < visible_rows; row++)
        {
         PMPosition position = m_positions[start + row];
         const string selected = IsSelected(position.ticket) ? "[x] " : "[ ] ";
         const int row_y = ContentTop() + PM_PANEL_POSITIONS_HEADER_HEIGHT + row * PM_PANEL_POSITION_ROW_HEIGHT;
         const bool is_selected = IsSelected(position.ticket);
         const string row_text = selected + position.symbol + "  Lot=" + DoubleToString(position.volume, 2) +
                                 "  Entry=" + PMFormatPrice(position.symbol, position.open_price) +
                                 "  SL=" + PMFormatPrice(position.symbol, position.sl) +
                                 "  TP=" + PMFormatPrice(position.symbol, position.tp) +
                                 "  P=" + DoubleToString(position.profit, 2) +
                                 "  #" + StringFormat("%I64u", position.ticket);
         ObjectDelete(0, RowName(row));
         ObjectDelete(0, RowDetailName(row));
         ObjectDelete(0, RowDirectionName(row));
         rows_created = CreateButton("ROW_" + IntegerToString(row), "", 12, row_y, m_panel_width - 24, 22, is_selected ? clrDarkGreen : clrDarkSlateGray) && rows_created;
         rows_created = CreateLabel("ROW_DETAIL_" + IntegerToString(row), row_text, 75, row_y + 4, clrWhite, 8) && rows_created;
         rows_created = CreateLabel("ROW_DIRECTION_" + IntegerToString(row),
                                   PMPositionTypeToString(position.type), 40, row_y + 4,
                                   position.type == POSITION_TYPE_BUY ? clrLimeGreen : clrTomato, 8) && rows_created;
        }
      for(int row = visible_rows; row < previous_rows; row++)
        {
         ObjectDelete(0, RowName(row));
         ObjectDelete(0, RowDetailName(row));
         ObjectDelete(0, RowDirectionName(row));
        }
      m_rendered_rows = visible_rows;
      if(!rows_created && !m_row_render_error_reported)
         PrintFormat("[ERROR] UI position row creation failed. last_error=%d", GetLastError());
      m_row_render_error_reported = !rows_created;
     }
   void ClearPositionRows()
     {
      for(int row = 0; row < m_rendered_rows; row++)
        {
         ObjectDelete(0, RowName(row));
         ObjectDelete(0, RowDetailName(row));
         ObjectDelete(0, RowDirectionName(row));
        }
      m_rendered_rows = 0;
     }
   void ApplyTabVisibility()
     {
      const bool expanded = !m_collapsed;
      UpdateTabColors();
      SetVisible("TAB_ENTRY", expanded);
      SetVisible("TAB_POSITIONS", expanded);
      SetVisible("TAB_STOPS", expanded);
      SetVisible("TAB_AUTO", expanded);
      SetVisible("TAB_GUARD", expanded);
      SetVisible("TAB_TRAIL", expanded);
      const bool entry = expanded && m_active_tab == PM_PANEL_TAB_ENTRY;
      SetVisible("ENTRY_PRICE", entry);
      SetVisible("ENTRY_LOT_LABEL", entry);
      SetVisible("ENTRY_LOT_DEC", entry);
      SetVisible("ENTRY_LOT", entry);
      SetVisible("ENTRY_LOT_INC", entry);
      SetVisible("ENTRY_SL_LABEL", entry);
      SetVisible("ENTRY_SL_DEC", entry);
      SetVisible("ENTRY_SL_POINTS", entry);
      SetVisible("ENTRY_SL_INC", entry);
      SetVisible("ENTRY_TP_LABEL", entry);
      SetVisible("ENTRY_TP_DEC", entry);
      SetVisible("ENTRY_TP_POINTS", entry);
      SetVisible("ENTRY_TP_INC", entry);
      SetVisible("ENTRY_BUY_PREVIEW", entry);
      SetVisible("ENTRY_SELL_PREVIEW", entry);
      SetVisible("ENTRY_BUY", entry);
      SetVisible("ENTRY_SELL", entry);
      SetVisible("ENTRY_HINT", entry);
      const bool positions = expanded && m_active_tab == PM_PANEL_TAB_POSITIONS;
      SetVisible("FILTER_LABEL", positions);
      SetVisible("FILTER_SYMBOL", positions);
      SetVisible("FILTER_DIRECTION", positions);
      SetVisible("CLOSE_NOW", positions);
      SetVisible("PAGE_PREV", positions);
      SetVisible("PAGE_NEXT", positions);
      SetVisible("PAGE_LABEL", positions);
      SetVisible("SELECTED_LABEL", positions);
      SetVisible("TOTAL_LABEL", positions);
      SetVisible("SELECT_ALL", positions);
      SetVisible("CLEAR_SELECTION", positions);
      SetVisible("CLOSE_SELECTED", positions);
      const bool stops = expanded && m_active_tab == PM_PANEL_TAB_STOPS;
      SetVisible("SL_LABEL", stops);
      SetVisible("SL_MODE", stops);
      SetVisible("SL_DEC", stops);
      SetVisible("SL_VALUE", stops);
      SetVisible("SL_INC", stops);
      SetVisible("SET_SL", stops);
      SetVisible("CLEAR_SL", stops);
      SetVisible("TP_LABEL", stops);
      SetVisible("TP_MODE", stops);
      SetVisible("TP_DEC", stops);
      SetVisible("TP_VALUE", stops);
      SetVisible("TP_INC", stops);
      SetVisible("SET_TP", stops);
      SetVisible("CLEAR_TP", stops);
      SetVisible("STOPS_HINT", stops);
      const bool auto_tab = expanded && m_active_tab == PM_PANEL_TAB_AUTO;
      SetVisible("AUTO_LABEL", auto_tab);
      SetVisible("AUTO_ENABLED", auto_tab);
      SetVisible("AUTO_SYMBOL", auto_tab);
      SetVisible("AUTO_DIRECTION", auto_tab);
      SetVisible("MINUTES_LABEL", auto_tab);
      SetVisible("AUTO_MINUTES", auto_tab);
      SetVisible("PASSED_BEHAVIOR", auto_tab);
      SetVisible("AUTO_HINT", auto_tab);
      const bool guard = expanded && m_active_tab == PM_PANEL_TAB_GUARD;
      SetVisible("EQ_LABEL", guard);
      SetVisible("EQ_ENABLED", guard);
      SetVisible("EQ_MODE", guard);
      SetVisible("EQ_LOSS_LABEL", guard);
      SetVisible("EQ_LOSS_VALUE", guard);
      SetVisible("EQ_PROFIT_LABEL", guard);
      SetVisible("EQ_PROFIT_VALUE", guard);
      SetVisible("EQ_HINT", guard);
      const bool trail = expanded && m_active_tab == PM_PANEL_TAB_TRAIL;
      SetVisible("TS_LABEL", trail);
      SetVisible("TS_SYMBOL", trail);
      SetVisible("TS_DIRECTION", trail);
      SetVisible("BE_LABEL", trail);
      SetVisible("BE_ENABLED", trail);
      SetVisible("BE_TRIGGER_LABEL", trail);
      SetVisible("BE_TRIGGER_VALUE", trail);
      SetVisible("BE_LOCK_LABEL", trail);
      SetVisible("BE_LOCK_VALUE", trail);
      SetVisible("TRAIL_LABEL", trail);
      SetVisible("TRAIL_ENABLED", trail);
      SetVisible("TRAIL_TRIGGER_LABEL", trail);
      SetVisible("TRAIL_TRIGGER_VALUE", trail);
      SetVisible("TRAIL_DIST_LABEL", trail);
      SetVisible("TRAIL_DIST_VALUE", trail);
      SetVisible("TRAIL_HINT", trail);
      SetVisible("SESSION_LABEL", expanded);
      for(int row = 0; row < m_rendered_rows; row++)
        {
         SetVisible("ROW_" + IntegerToString(row), positions);
         SetVisible("ROW_DETAIL_" + IntegerToString(row), positions);
         SetVisible("ROW_DIRECTION_" + IntegerToString(row), positions);
        }
      for(int line = 0; line < PM_MAX_STATUS_LINES; line++)
         SetVisible("STATUS_LINE_" + IntegerToString(line), expanded);
      SetVisible("RESIZE_GRIP", expanded);
      ObjectSetString(0, Name("COLLAPSE"), OBJPROP_TEXT, m_collapsed ? "+" : "-");
      ObjectSetInteger(0, Name("BACKGROUND"), OBJPROP_YSIZE, PanelHeight());
      ObjectSetInteger(0, Name("RESIZE_GRIP"), OBJPROP_XDISTANCE, m_origin_x + m_panel_width - 24);
      ObjectSetInteger(0, Name("RESIZE_GRIP"), OBJPROP_YDISTANCE, m_origin_y + PanelHeight() - 18);
     }
   void UpdateTabColors()
     {
      SetTabColor("TAB_ENTRY", PM_PANEL_TAB_ENTRY);
      SetTabColor("TAB_POSITIONS", PM_PANEL_TAB_POSITIONS);
      SetTabColor("TAB_STOPS", PM_PANEL_TAB_STOPS);
      SetTabColor("TAB_AUTO", PM_PANEL_TAB_AUTO);
      SetTabColor("TAB_GUARD", PM_PANEL_TAB_GUARD);
      SetTabColor("TAB_TRAIL", PM_PANEL_TAB_TRAIL);
     }
   void SetTabColor(const string suffix, const PMPanelTab tab)
     {
      const bool active = m_active_tab == tab;
      ObjectSetInteger(0, Name(suffix), OBJPROP_BGCOLOR,
                       active ? PM_ACTIVE_TAB_COLOR : PM_INACTIVE_TAB_COLOR);
      ObjectSetInteger(0, Name(suffix), OBJPROP_BORDER_COLOR,
                       active ? PM_ACTIVE_TAB_BORDER_COLOR : PM_INACTIVE_TAB_BORDER_COLOR);
      ObjectSetInteger(0, Name(suffix), OBJPROP_COLOR,
                       active ? clrWhite : clrSilver);
      ObjectSetInteger(0, Name(suffix), OBJPROP_FONTSIZE, active ? 9 : 8);
     }
   string EquityGuardThresholdText(const double value)
     {
      return value > 0.0 ? DoubleToString(value, 2) : "not set";
     }
   void UpdateEquityThresholdVisual(const string suffix, const double value)
     {
      const bool configured = value > 0.0;
      ObjectSetInteger(0, Name(suffix), OBJPROP_BGCOLOR,
                       configured ? C'220,255,220' : clrWhite);
      ObjectSetInteger(0, Name(suffix), OBJPROP_BORDER_COLOR,
                       configured ? clrDarkGreen : clrGray);
     }
   void UpdateToggleButtonVisual(const string suffix, const bool enabled)
     {
      ObjectSetString(0, Name(suffix), OBJPROP_TEXT, enabled ? "ON" : "OFF");
      ObjectSetInteger(0, Name(suffix), OBJPROP_BGCOLOR,
                       enabled ? clrDarkGreen : clrMaroon);
     }
   color StatusTextColor()
     {
      const PMStatusSeverity severity = PMResolveStatusSeverity(m_status);
      if(severity == PM_STATUS_ERROR)
         return PM_STATUS_ERROR_COLOR;
      if(severity == PM_STATUS_WARNING)
         return PM_STATUS_WARNING_COLOR;
      if(severity == PM_STATUS_SUCCESS)
         return PM_STATUS_SUCCESS_COLOR;
      return PM_STATUS_COLOR;
     }
   void UpdateEquityGuardVisuals()
     {
      const bool enabled = m_equity_guard_enabled;
      UpdateToggleButtonVisual("EQ_ENABLED", enabled);
      ObjectSetString(0, Name("EQ_HINT"), OBJPROP_TEXT,
                      StringFormat("Guard %s | Loss: %s | Profit: %s",
                                   enabled ? "ON" : "OFF",
                                   EquityGuardThresholdText(m_equity_guard_loss_threshold),
                                   EquityGuardThresholdText(m_equity_guard_profit_threshold)));
      ObjectSetInteger(0, Name("EQ_HINT"), OBJPROP_COLOR,
                       enabled ? clrLimeGreen : clrOrange);
      UpdateEquityThresholdVisual("EQ_LOSS_VALUE", m_equity_guard_loss_threshold);
      UpdateEquityThresholdVisual("EQ_PROFIT_VALUE", m_equity_guard_profit_threshold);
     }
   void UpdateStatusLayout()
     {
      if(m_collapsed) return;
      string lines[];
      const int available_width = MathMax(1, m_panel_width - 28);
      WrapStatusToPixelWidth("Status: " + m_status, available_width, lines);
      if(ArraySize(lines) > PM_MAX_STATUS_LINES)
        {
         ArrayResize(lines, PM_MAX_STATUS_LINES);
         lines[PM_MAX_STATUS_LINES - 1] = lines[PM_MAX_STATUS_LINES - 1] + " ...";
        }
      const int content_bottom = ContentTop() + ContentHeight() +
                                 PM_PANEL_CONTENT_GAP;
      const int status_block_height = PM_PANEL_STATUS_LINE_HEIGHT *
                                      (ArraySize(lines) + 1) + 10;
      const int required_height = content_bottom + status_block_height;
      m_panel_height = PMResolvePanelHeight(required_height,
                                            m_user_panel_height);
      m_expanded_height = m_panel_height;
      const int base_y = content_bottom + m_panel_height - required_height;
      ObjectSetInteger(0, Name("SESSION_LABEL"), OBJPROP_YDISTANCE, m_origin_y + base_y);
      const color status_color = StatusTextColor();
      for(int line = 0; line < PM_MAX_STATUS_LINES; line++)
        {
         const bool visible = line < ArraySize(lines);
         ObjectSetString(0, Name("STATUS_LINE_" + IntegerToString(line)), OBJPROP_TEXT, visible ? lines[line] : "");
         ObjectSetInteger(0, Name("STATUS_LINE_" + IntegerToString(line)), OBJPROP_COLOR, status_color);
         ObjectSetInteger(0, Name("STATUS_LINE_" + IntegerToString(line)), OBJPROP_YDISTANCE, m_origin_y + base_y + PM_PANEL_STATUS_LINE_HEIGHT + line * PM_PANEL_STATUS_LINE_HEIGHT);
         SetVisible("STATUS_LINE_" + IntegerToString(line), visible);
        }
      ObjectSetInteger(0, Name("BACKGROUND"), OBJPROP_YSIZE, PanelHeight());
      ObjectSetInteger(0, Name("RESIZE_GRIP"), OBJPROP_YDISTANCE, m_origin_y + PanelHeight() - 18);
     }
   int StatusTextWidth(const string text)
     {
      TextSetFont("Arial", -PM_STATUS_FONT_SIZE * 10, FW_NORMAL);
      uint width = 0;
      uint height = 0;
      if(TextGetSize(text, width, height))
         return (int)width;
      return StringLen(text) * 7;
     }
   int StatusFittingCharacters(const string text, const int max_width)
     {
      const int length = StringLen(text);
      if(length == 0 || StatusTextWidth(text) <= max_width)
         return length;

      int low = 1;
      int high = length;
      while(low < high)
        {
         const int middle = (low + high + 1) / 2;
         if(StatusTextWidth(StringSubstr(text, 0, middle)) <= max_width)
            low = middle;
         else
            high = middle - 1;
        }
      return low;
     }
   void WrapStatusToPixelWidth(const string text,
                               const int max_width,
                               string &lines[])
     {
      ArrayResize(lines, 0);
      const int width = MathMax(1, max_width);
      string remaining = text;
      while(StringLen(remaining) > 0)
        {
         const int fitting = StatusFittingCharacters(remaining, width);
         if(fitting >= StringLen(remaining))
           {
            const int count = ArraySize(lines);
            ArrayResize(lines, count + 1);
            lines[count] = remaining;
            break;
           }

         int cut = fitting;
         while(cut > 1 && StringGetCharacter(remaining, cut - 1) != 32)
            cut--;
         if(cut <= 1)
            cut = fitting;
         const int count = ArraySize(lines);
         ArrayResize(lines, count + 1);
         lines[count] = StringSubstr(remaining, 0, cut);
         remaining = StringSubstr(remaining, cut);
         while(StringLen(remaining) > 0 && StringGetCharacter(remaining, 0) == 32)
            remaining = StringSubstr(remaining, 1);
        }
      if(ArraySize(lines) == 0)
        {
         ArrayResize(lines, 1);
         lines[0] = "";
        }
     }
   void SetVisible(const string suffix, const bool visible)
     {
      ObjectSetInteger(0, Name(suffix), OBJPROP_TIMEFRAMES,
                       visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
     }
   void AlignLabelToInput(const string suffix, const int right_x, const int y)
     {
      ObjectSetInteger(0, Name(suffix), OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
      ObjectSetInteger(0, Name(suffix), OBJPROP_XDISTANCE, m_origin_x + right_x);
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
   void PrepareObject(const string object_name, const int x, const int y)
     {
      ObjectSetInteger(0, object_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, object_name, OBJPROP_XDISTANCE, m_origin_x + x);
      ObjectSetInteger(0, object_name, OBJPROP_YDISTANCE, m_origin_y + y);
      ObjectSetInteger(0, object_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, object_name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, object_name, OBJPROP_ZORDER, 1);
     }
   bool CreateLabel(const string suffix, const string text, const int x, const int y, const color text_color, const int font_size)
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
   bool CreateButton(const string suffix, const string text, const int x, const int y, const int width, const int height = 22, const color background = clrDarkSlateGray)
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
   bool CreateEdit(const string suffix, const string text, const int x, const int y, const int width, const int height)
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
   bool IsInsideTitleBar(const int x, const int y)
     {
      return x >= m_origin_x && x < m_origin_x + m_panel_width &&
             y >= m_origin_y && y < m_origin_y + PM_TITLEBAR_HEIGHT;
     }
   bool IsInsideCollapseButton(const int x, const int y)
     {
      return x >= m_origin_x + m_panel_width - 30 &&
             x <= m_origin_x + m_panel_width - 6 &&
             y >= m_origin_y + 4 && y <= m_origin_y + 24;
     }
   bool IsInsideResizeCorner(const int x, const int y)
     {
      return !m_collapsed &&
             x >= m_origin_x + m_panel_width - PM_RESIZE_HANDLE_HIT_SIZE &&
             x <= m_origin_x + m_panel_width &&
             y >= m_origin_y + PanelHeight() - PM_RESIZE_HANDLE_HIT_SIZE &&
             y <= m_origin_y + PanelHeight();
     }
   void BeginInteraction(const bool resize, const int x, const int y)
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
   void HandleMouseMove(const int x, const int y, const string state_text)
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
         else if(IsInsideTitleBar(x, y) && !IsInsideCollapseButton(x, y))
            BeginInteraction(false, x, y);
        }
      if(m_dragging)
         MovePanelTo(m_interaction_origin_x + x - m_interaction_start_x,
                     m_interaction_origin_y + y - m_interaction_start_y);
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
      const int new_x = MathMax(0, MathMin(requested_x, max_x));
      const int new_y = MathMax(0, MathMin(requested_y, max_y));
      const int delta_x = new_x - m_origin_x;
      const int delta_y = new_y - m_origin_y;
      m_origin_x = new_x;
      m_origin_y = new_y;
      ShiftPanelObjects(delta_x, delta_y, "");
     }
   void ResizePanelTo(const int requested_width,
                      const int requested_height)
     {
      long chart_width = 0;
      long chart_height = 0;
      ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0, chart_width);
      ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0, chart_height);
      const int available_width = MathMax(PM_MIN_PANEL_WIDTH,
                                          (int)chart_width - m_origin_x);
      const int maximum = MathMin(PM_MAX_PANEL_WIDTH, available_width);
      m_panel_width = MathMax(PM_MIN_PANEL_WIDTH,
                              MathMin(requested_width, maximum));
      const int available_height = MathMax(PM_TITLEBAR_HEIGHT,
                                           (int)chart_height - m_origin_y);
      m_user_panel_height = MathMax(PM_TITLEBAR_HEIGHT,
                                    MathMin(requested_height,
                                            available_height));
      ApplyPanelFrameLayout();
      Render();
     }
   void ShiftPanelObjects(const int delta_x, const int delta_y, const string exclude_name)
     {
      if(delta_x == 0 && delta_y == 0)
         return;
      const int total = ObjectsTotal(0, -1, -1);
      for(int index = total - 1; index >= 0; index--)
        {
         const string object_name = ObjectName(0, index, -1, -1);
         if(StringFind(object_name, PM_OBJECT_PREFIX) != 0 ||
            object_name == exclude_name)
            continue;
         const int x = (int)ObjectGetInteger(0, object_name,
                                             OBJPROP_XDISTANCE);
         const int y = (int)ObjectGetInteger(0, object_name,
                                             OBJPROP_YDISTANCE);
         ObjectSetInteger(0, object_name, OBJPROP_XDISTANCE, x + delta_x);
         ObjectSetInteger(0, object_name, OBJPROP_YDISTANCE, y + delta_y);
        }
     }
   void ApplyPanelFrameLayout()
     {
      ObjectSetInteger(0, Name("BACKGROUND"), OBJPROP_XSIZE, m_panel_width);
      ObjectSetInteger(0, Name("BACKGROUND"), OBJPROP_YSIZE, PanelHeight());
      ObjectSetInteger(0, Name("COLLAPSE"), OBJPROP_XDISTANCE,
                       m_origin_x + m_panel_width - 30);
      ObjectSetInteger(0, Name("RESIZE_GRIP"), OBJPROP_XDISTANCE,
                       m_origin_x + m_panel_width - 24);
      ObjectSetInteger(0, Name("RESIZE_GRIP"), OBJPROP_YDISTANCE,
                       m_origin_y + PanelHeight() - 18);
      ApplyStopsLayout();
     }
   int StopsClearX()
     {
      return PM_STOPS_SET_BUTTON_X + PM_STOPS_SET_BUTTON_WIDTH + PM_STOPS_BUTTON_GAP;
     }
   void SetStopsObjectPosition(const string suffix, const int x, const int y)
     {
      ObjectSetInteger(0, Name(suffix), OBJPROP_XDISTANCE, m_origin_x + x);
      ObjectSetInteger(0, Name(suffix), OBJPROP_YDISTANCE, m_origin_y + y);
     }
   void ApplyStopsLayout()
     {
      const int top = ContentTop();
      SetStopsObjectPosition("CLEAR_SL", StopsClearX(), top);
      SetStopsObjectPosition("TP_LABEL", 12, top + 37);
      SetStopsObjectPosition("TP_MODE", PM_STOPS_MODE_X, top + 32);
      SetStopsObjectPosition("TP_DEC", PM_STOPS_DEC_X, top + 32);
      SetStopsObjectPosition("TP_VALUE", PM_STOPS_VALUE_X, top + 32);
      SetStopsObjectPosition("TP_INC", PM_STOPS_INC_X, top + 32);
      SetStopsObjectPosition("SET_TP", PM_STOPS_SET_BUTTON_X, top + 32);
      SetStopsObjectPosition("CLEAR_TP", StopsClearX(), top + 32);
      SetStopsObjectPosition("STOPS_HINT", 12, top + 66);
     }
  };

#endif
