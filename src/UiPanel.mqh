#ifndef __MT5_POSITION_MANAGER_UI_PANEL_MQH__
#define __MT5_POSITION_MANAGER_UI_PANEL_MQH__

#include "Models.mqh"
#include "Constants.mqh"
#include "PositionService.mqh"
#include "TradeManager.mqh"
#include "ValidationService.mqh"
#include "PositionActionService.mqh"
#include "PriceEditor.mqh"
#include "EntryService.mqh"

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
   CEntryDraft m_entry_draft;
   CEntryService m_entry_service;
   PMEntrySnapshot m_entry_snapshot;
   PMEntryComputation m_entry_result;
   bool m_entry_valid;
   string m_entry_reason;
   PMPassedCloseBehavior m_passed_behavior;
   int m_auto_minutes;
   bool m_auto_enabled;
   bool m_equity_guard_enabled;
   PMEquityThresholdMode m_equity_guard_mode;
   double m_equity_guard_loss_threshold;
   double m_equity_guard_profit_threshold;
   string m_trailing_symbol;
   PMDirection m_trailing_direction;
   PMTrailBasis m_trail_basis;
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
   int m_visible_rows;
   bool m_row_render_error_reported;
   bool m_controls_dirty;
   bool m_visibility_dirty;
   bool m_status_layout_dirty;
   bool m_schedule_dirty;
   bool m_positions_dirty;
   bool m_force_redraw;
   string m_object_names[];
   int m_object_x[];
   int m_object_y[];
   int m_origin_x;
   int m_origin_y;
   int m_panel_width;
   int m_panel_height;
   long m_chart_width;
   long m_chart_height;
   int m_expanded_height;
   int m_user_panel_height;
   bool m_dragging;
   bool m_resizing;
   CPriceEditDrag m_price_drag;
   string m_price_line_selection_key;
   string m_stop_committed[2];
   double m_price_seed[2];
   bool m_price_line_visible[2];
   int m_price_line_y[2];
   double m_price_line_price[2];
   int m_price_label_x[2];
   int m_price_label_y[2];
   int m_price_label_width[2];
   int m_price_label_height[2];
   bool m_price_scroll_before;
   bool m_mouse_left_pressed;
   bool m_price_drag_moved;
   int m_price_mouse_start_y;
   double m_price_mouse_start_price;
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
      m_entry_valid = false;
      m_entry_reason = "";
      m_passed_behavior = PM_PASSED_CLOSE_DO_NOTHING;
      m_auto_minutes = 10;
      m_auto_enabled = false;
      m_equity_guard_enabled = false;
      m_equity_guard_mode = PM_EQUITY_THRESHOLD_AMOUNT;
      m_equity_guard_loss_threshold = 0.0;
      m_equity_guard_profit_threshold = 0.0;
      m_trailing_symbol = "";
      m_trailing_direction = PM_DIRECTION_BOTH;
      m_trail_basis = PM_TRAIL_BASIS_PER_POSITION;
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
      m_visible_rows = 0;
      m_row_render_error_reported = false;
      m_controls_dirty = true;
      m_visibility_dirty = true;
      m_status_layout_dirty = true;
      m_schedule_dirty = true;
      m_positions_dirty = true;
      m_force_redraw = true;
      m_origin_x = 0;
      m_origin_y = 0;
      m_panel_width = PM_DEFAULT_PANEL_WIDTH;
      m_panel_height = 0;
      m_chart_width = 0;
      m_chart_height = 0;
      m_expanded_height = 0;
      m_user_panel_height = 0;
      m_dragging = false;
      m_resizing = false;
      m_price_line_selection_key = "";
      m_price_scroll_before = true;
      m_mouse_left_pressed = false;
      m_price_drag_moved = false;
      m_price_mouse_start_y = 0;
      m_price_mouse_start_price = 0.0;
      for(int i = 0; i < 2; i++)
        {
         m_stop_committed[i] = "";
         m_price_seed[i] = 0.0;
         m_price_line_visible[i] = false;
         m_price_line_y[i] = 0;
         m_price_line_price[i] = 0.0;
         m_price_label_x[i] = 0;
         m_price_label_y[i] = 0;
         m_price_label_width[i] = 0;
         m_price_label_height[i] = 0;
        }
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
      ArrayResize(m_object_names, 0, 128);
      ArrayResize(m_object_x, 0, 128);
      ArrayResize(m_object_y, 0, 128);
      m_rendered_rows = 0;
      m_visible_rows = 0;
      m_controls_dirty = true;
      m_visibility_dirty = true;
      m_status_layout_dirty = true;
      m_schedule_dirty = true;
      m_positions_dirty = true;
      m_force_redraw = true;
      m_max_rows = MathMax(PM_MIN_POSITION_ROWS, MathMin(max_rows, PM_MAX_POSITION_ROWS));
      m_panel_width = PM_DEFAULT_PANEL_WIDTH;
      m_user_panel_height = 0;
      m_origin_x = 0;
      m_origin_y = 0;
      RefreshChartSize();
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

      created = CreateButton("ENTRY_TYPE", "Market", 12, ContentTop(), 100, 24) && created;
      created = CreateButton("ENTRY_SIDE", "BUY", 124, ContentTop(), 85, 24, clrDarkGreen) && created;
      created = CreateLabel("ENTRY_PRICE", "Bid - / Ask -", 12, ContentTop() + 38, clrSilver, 8) && created;
      created = CreateLabel("ENTRY_ORDER_PRICE_LABEL", "Price", 278, ContentTop() + 38, clrSilver, 8) && created;
      created = CreateButton("ENTRY_ORDER_DEC", "-", 314, ContentTop() + 32, 24, 24) && created;
      created = CreateEdit("ENTRY_ORDER_PRICE", "", 342, ContentTop() + 32, 136, 24) && created;
      created = CreateButton("ENTRY_ORDER_INC", "+", 482, ContentTop() + 32, 24, 24) && created;
      created = CreateButton("ENTRY_QTY_MODE", "Manual Lot", 12, ContentTop() + 68, 130, 24) && created;
      created = CreateButton("ENTRY_RISK_DEC", "-", 150, ContentTop() + 68, 24, 24) && created;
      created = CreateEdit("ENTRY_RISK", "0", 178, ContentTop() + 68, 92, 24) && created;
      created = CreateButton("ENTRY_RISK_INC", "+", 274, ContentTop() + 68, 24, 24) && created;
      created = CreateLabel("ENTRY_LOT_LABEL", "Lot", 308, ContentTop() + 74, clrSilver, 8) && created;
      created = CreateButton("ENTRY_LOT_DEC", "-", 342, ContentTop() + 68, 24, 24) && created;
      created = CreateEdit("ENTRY_LOT", "0.01", 370, ContentTop() + 68, 108, 24) && created;
      created = CreateButton("ENTRY_LOT_INC", "+", 482, ContentTop() + 68, 24, 24) && created;
      created = CreateLabel("ENTRY_SL_LABEL", "SL", 12, ContentTop() + 110, clrSilver, 9) && created;
      created = CreateButton("ENTRY_SL_MODE", "Points", 42, ContentTop() + 104, 70, 24) && created;
      created = CreateButton("ENTRY_SL_DEC", "-", 120, ContentTop() + 104, 24, 24) && created;
      created = CreateEdit("ENTRY_SL_POINTS", "0", 148, ContentTop() + 104, 135, 24) && created;
      created = CreateButton("ENTRY_SL_INC", "+", 287, ContentTop() + 104, 24, 24) && created;
      created = CreateButton("ENTRY_SL_SET", "Set SL", 320, ContentTop() + 104, 85, 24) && created;
      created = CreateButton("ENTRY_SL_CLEAR", "Clear SL", 416, ContentTop() + 104, 90, 24) && created;
      created = CreateLabel("ENTRY_TP_LABEL", "TP", 12, ContentTop() + 146, clrSilver, 9) && created;
      created = CreateButton("ENTRY_TP_MODE", "Points", 42, ContentTop() + 140, 70, 24) && created;
      created = CreateButton("ENTRY_TP_DEC", "-", 120, ContentTop() + 140, 24, 24) && created;
      created = CreateEdit("ENTRY_TP_POINTS", "0", 148, ContentTop() + 140, 135, 24) && created;
      created = CreateButton("ENTRY_TP_INC", "+", 287, ContentTop() + 140, 24, 24) && created;
      created = CreateButton("ENTRY_TP_SET", "Set TP", 320, ContentTop() + 140, 85, 24) && created;
      created = CreateButton("ENTRY_TP_CLEAR", "Clear TP", 416, ContentTop() + 140, 90, 24) && created;
      created = CreateLabel("ENTRY_RR_LABEL", "RR 1:", 12, ContentTop() + 182, clrSilver, 9) && created;
      created = CreateButton("ENTRY_RR_DEC", "-", 70, ContentTop() + 176, 24, 24) && created;
      created = CreateEdit("ENTRY_RR", "1.0", 98, ContentTop() + 176, 70, 24) && created;
      created = CreateButton("ENTRY_RR_INC", "+", 172, ContentTop() + 176, 24, 24) && created;
      created = CreateButton("ENTRY_AUTO_TP", "Auto TP", 208, ContentTop() + 176, 110, 24) && created;
      created = CreateLabel("ENTRY_CURRENT_RR", "Current RR: N/A", 330, ContentTop() + 182, clrSilver, 8) && created;
      created = CreateLabel("ENTRY_PREVIEW", "SL: - / TP: -", 12, ContentTop() + 212, clrSilver, 8) && created;
      created = CreateLabel("ENTRY_ESTIMATE", "Est. SL: N/A / TP: N/A", 12, ContentTop() + 236, clrSilver, 8) && created;
      created = CreateButton("ENTRY_BUY", "BUY MARKET", 350, ContentTop() + 230, 156, 28, clrDarkGreen) && created;
      created = CreateButton("ENTRY_SELL", "SELL MARKET", 350, ContentTop() + 230, 156, 28, clrMaroon) && created;
      created = CreateButton("ENTRY_LIMIT", "BUY LIMIT", 350, ContentTop() + 230, 156, 28, clrDarkGreen) && created;
      created = CreateButton("ENTRY_STOP", "BUY STOP", 350, ContentTop() + 230, 156, 28, clrDarkGreen) && created;
      created = CreateLabel("ENTRY_HINT", "Set SL/TP, then drag the line or label.", 12, ContentTop() + 270, clrSilver, 8) && created;

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
      created = CreateButton("AUTO_ENABLED", "OFF", 160, ContentTop(), 60, 22) && created;
      created = CreateButton("AUTO_SYMBOL", "Symbol", 230, ContentTop(), 105, 22) && created;
      created = CreateButton("AUTO_DIRECTION", "Both", 345, ContentTop(), 85, 22) && created;
      created = CreateLabel("MINUTES_LABEL", "Minutes before close", 12, ContentTop() + 37, clrSilver, 9) && created;
      created = CreateNumericInput("AUTO_MINUTES", "AUTO_MINUTES", "10", 210, ContentTop() + 32, 90) && created;
      created = CreateButton("PASSED_BEHAVIOR", "Passed: Do Nothing", 12, ContentTop() + 64, 170, 22) && created;
      created = CreateLabel("AUTO_HINT", "Timer-driven schedule.", 195, ContentTop() + 69, clrSilver, 8) && created;

      created = CreateLabel("EQ_LABEL", "Equity Guard", 12, ContentTop() + 4, clrSilver, 9) && created;
      created = CreateButton("EQ_ENABLED", "OFF", 160, ContentTop(), 60, 22) && created;
      created = CreateButton("EQ_MODE", "Amount", 230, ContentTop(), 85, 22) && created;
      created = CreateLabel("EQ_LOSS_LABEL", "Max Loss", 12, ContentTop() + 37, clrSilver, 9) && created;
      created = CreateNumericInput("EQ_LOSS", "EQ_LOSS_VALUE", "", 120, ContentTop() + 32, 160) && created;
      created = CreateLabel("EQ_PROFIT_LABEL", "Max Profit", 12, ContentTop() + 69, clrSilver, 9) && created;
      created = CreateNumericInput("EQ_PROFIT", "EQ_PROFIT_VALUE", "", 120, ContentTop() + 64, 160) && created;
      created = CreateLabel("EQ_HINT", "Guard OFF | Loss: not set | Profit: not set", 12, ContentTop() + 101, clrOrange, 8) && created;

      created = CreateLabel("TS_LABEL", "Scope", 12, ContentTop() + 4, clrSilver, 9) && created;
      created = CreateButton("TS_SYMBOL", "Symbol", PM_TRAIL_TOGGLE_X, ContentTop(), 105, 22) && created;
      created = CreateButton("TS_DIRECTION", "Both", PM_TRAIL_TOGGLE_X + 110, ContentTop(), 85, 22) && created;
      created = CreateLabel("BASIS_LABEL", "Basis", 12, ContentTop() + PM_TRAIL_BASIS_ROW_Y + 5, clrSilver, 9) && created;
      created = CreateButton("BASIS_TOGGLE", "Per Position", PM_TRAIL_TOGGLE_X, ContentTop() + PM_TRAIL_BASIS_ROW_Y, PM_TRAIL_BASIS_TOGGLE_WIDTH, 22) && created;
      created = CreateLabel("BE_LABEL", "Break Even", 12, ContentTop() + PM_TRAIL_BE_ROW_Y + 5, clrSilver, 9) && created;
      created = CreateButton("BE_ENABLED", "OFF", PM_TRAIL_TOGGLE_X, ContentTop() + PM_TRAIL_BE_ROW_Y, 60, 22) && created;
      created = CreateLabel("BE_TRIGGER_LABEL", "Trigger", PM_TRAIL_LABEL1_X, ContentTop() + PM_TRAIL_BE_ROW_Y + 5, clrSilver, 9) && created;
      created = CreateNumericInput("BE_TRIGGER", "BE_TRIGGER_VALUE", "0", PM_TRAIL_INPUT1_X, ContentTop() + PM_TRAIL_BE_ROW_Y, PM_TRAIL_INPUT_WIDTH) && created;
      created = CreateLabel("BE_LOCK_LABEL", "Lock", PM_TRAIL_LABEL2_X, ContentTop() + PM_TRAIL_BE_ROW_Y + 5, clrSilver, 9) && created;
      created = CreateNumericInput("BE_LOCK", "BE_LOCK_VALUE", "0", PM_TRAIL_INPUT2_X, ContentTop() + PM_TRAIL_BE_ROW_Y, PM_TRAIL_INPUT_WIDTH) && created;
      created = CreateLabel("TRAIL_LABEL", "Trailing", 12, ContentTop() + PM_TRAIL_ROW_Y + 5, clrSilver, 9) && created;
      created = CreateButton("TRAIL_ENABLED", "OFF", PM_TRAIL_TOGGLE_X, ContentTop() + PM_TRAIL_ROW_Y, 60, 22) && created;
      created = CreateLabel("TRAIL_TRIGGER_LABEL", "Trigger", PM_TRAIL_LABEL1_X, ContentTop() + PM_TRAIL_ROW_Y + 5, clrSilver, 9) && created;
      created = CreateNumericInput("TRAIL_TRIGGER", "TRAIL_TRIGGER_VALUE", "0", PM_TRAIL_INPUT1_X, ContentTop() + PM_TRAIL_ROW_Y, PM_TRAIL_INPUT_WIDTH) && created;
      created = CreateLabel("TRAIL_DIST_LABEL", "Distance", PM_TRAIL_LABEL2_X, ContentTop() + PM_TRAIL_ROW_Y + 5, clrSilver, 9) && created;
      created = CreateNumericInput("TRAIL_DIST", "TRAIL_DIST_VALUE", "0", PM_TRAIL_INPUT2_X, ContentTop() + PM_TRAIL_ROW_Y, PM_TRAIL_INPUT_WIDTH) && created;
      created = CreateLabel("TRAIL_HINT", "Trailing Trigger 0 uses Distance. All distances are pips.", 12, ContentTop() + PM_TRAIL_HINT_ROW_Y, clrSilver, 8) && created;

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
      CancelPriceDrag();
      m_price_line_selection_key = "";
      ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, 0, m_chart_mouse_move_before_create);
      ObjectsDeleteAll(0, PM_OBJECT_PREFIX);
      DeletePriceLineObjects();
      ArrayResize(m_object_names, 0);
      ArrayResize(m_object_x, 0);
      ArrayResize(m_object_y, 0);
      m_rendered_rows = 0;
      m_visible_rows = 0;
      m_created = false;
     }

   void Refresh(const PMPosition &position_snapshot[],
                CPositionService &positions)
     {
      const int position_count = ArraySize(position_snapshot);
      ArrayResize(m_positions, position_count);
      for(int i = 0; i < position_count; i++)
         m_positions[i] = position_snapshot[i];
      positions.CollectSymbols(position_snapshot, m_symbols);
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
      SyncPriceContext();
      m_positions_dirty = true;
     }

   void Render()
     {
      bool redraw = m_force_redraw;
      if(m_controls_dirty)
        {
         RenderControlStates();
         m_controls_dirty = false;
         redraw = true;
        }
      if(m_schedule_dirty)
        {
         ObjectSetString(0, Name("SESSION_LABEL"), OBJPROP_TEXT,
                         "Session close: " + PMFormatDateTime(m_session_close) +
                         " | Auto close: " + PMFormatDateTime(m_auto_close_at));
         m_schedule_dirty = false;
         redraw = true;
        }
      if(!m_collapsed && m_active_tab == PM_PANEL_TAB_ENTRY)
        {
         RenderEntryState();
         redraw = true;
        }
      if(!m_collapsed && m_active_tab == PM_PANEL_TAB_POSITIONS &&
         m_positions_dirty)
        {
         RenderPositionSummary();
         m_positions_dirty = !RenderPositionRows();
         redraw = true;
        }
      if(m_visibility_dirty)
        {
         ApplyTabVisibility();
         m_visibility_dirty = false;
         redraw = true;
        }
      if(m_status_layout_dirty)
        {
         UpdateStatusLayout();
         MovePanelTo(m_origin_x, m_origin_y);
         m_status_layout_dirty = false;
         redraw = true;
        }
      if(!m_collapsed && (m_active_tab == PM_PANEL_TAB_STOPS || m_active_tab == PM_PANEL_TAB_ENTRY))
         UpdatePriceLines();
      else
         HidePriceLines();
      if(redraw || m_force_redraw)
         ChartRedraw();
      m_force_redraw = false;
     }

   void RequestRedraw()
     {
      m_force_redraw = true;
     }

   void SetStatus(const string status)
     {
      if(status == "" || status == m_status)
         return;
      m_status = status;
      m_status_layout_dirty = true;
     }

   void SetAutoSchedule(const datetime session_close, const datetime auto_close_at)
     {
      if(m_session_close == session_close && m_auto_close_at == auto_close_at)
         return;
      m_session_close = session_close;
      m_auto_close_at = auto_close_at;
      m_schedule_dirty = true;
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
      config.basis = m_trail_basis;
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
         const bool pressed = ((uint)StringToInteger(object_name) & 1) != 0;
         const bool started = pressed && !m_mouse_left_pressed;
         m_mouse_left_pressed = pressed;
         if(m_price_drag.Index() >= 0 && !pressed)
           {
            PMPosition snapshot[];
            positions.Collect(snapshot);
            Refresh(snapshot, positions);
           }
         if(HandlePriceMouse((int)lparam, (int)dparam, pressed, started))
            return true;
         if(started || m_dragging || m_resizing || !pressed)
            HandleMouseMove((int)lparam, (int)dparam, object_name);
         return true;
        }
      if(id == CHARTEVENT_CLICK)
        {
         if(m_price_drag.Index() >= 0)
           {
            PMPosition snapshot[];
            positions.Collect(snapshot);
            Refresh(snapshot, positions);
            HandlePriceMouse((int)lparam, (int)dparam, false, false);
           }
         m_mouse_left_pressed = false;
         EndInteraction();
         return true;
        }
      if(id == CHARTEVENT_CHART_CHANGE)
        {
         CancelPriceDrag();
         RefreshChartSize();
         ApplyPanelFrameLayout();
         m_positions_dirty = true;
         m_status_layout_dirty = true;
         Render();
         return true;
        }
      // These objects use mouse capture, never native object dragging.
      if(IsPriceLineObject(object_name)) return true;
      if(id != CHARTEVENT_OBJECT_CLICK && id != CHARTEVENT_OBJECT_ENDEDIT)
         return false;
      if(StringFind(object_name, PM_OBJECT_PREFIX) != 0 ||
         ObjectFind(0, object_name) < 0 ||
         ObjectGetInteger(0, object_name, OBJPROP_TIMEFRAMES) == OBJ_NO_PERIODS)
         return false;
      if(id == CHARTEVENT_OBJECT_ENDEDIT)
         return HandleEditEnd(object_name);
      if(IsEntrySendButton(object_name) && m_price_drag.Index() >= 0)
        { SetStatus("Finish the line drag before submitting an order."); return true; }
      CancelPriceDrag();
      EndInteraction();
      ObjectSetInteger(0, object_name, OBJPROP_STATE, false);
      if(object_name == Name("COLLAPSE"))
        {
         m_collapsed = !m_collapsed;
         if(m_collapsed)
            m_panel_height = PM_TITLEBAR_HEIGHT;
         else
            m_panel_height = m_expanded_height;
         m_visibility_dirty = true;
         m_status_layout_dirty = true;
        }
      else if(HandleTabClick(object_name))
         m_collapsed = false;
      else if(StringFind(object_name, Name("ENTRY_")) == 0)
         HandleEntryClick(object_name, trades);
      else if(object_name == Name("AUTO_MINUTES_DEC"))
         StepIntegerInput("AUTO_MINUTES", m_auto_minutes, -1, PM_MAX_AUTO_CLOSE_MINUTES, "Auto Close minutes");
      else if(object_name == Name("AUTO_MINUTES_INC"))
         StepIntegerInput("AUTO_MINUTES", m_auto_minutes, 1, PM_MAX_AUTO_CLOSE_MINUTES, "Auto Close minutes");
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
        {
         m_sl_mode = m_sl_mode == PM_PRICE_ABSOLUTE ? PM_PRICE_PIPS : PM_PRICE_ABSOLUTE;
         m_stop_committed[0] = ObjectGetString(0, Name("SL_VALUE"), OBJPROP_TEXT);
        }
      else if(object_name == Name("SL_DEC"))
         ShiftStopEditor(true, -1);
      else if(object_name == Name("SL_INC"))
         ShiftStopEditor(true, 1);
      else if(object_name == Name("SET_SL"))
         ApplyStopTarget(true, positions, trades, validator, actions);
      else if(object_name == Name("CLEAR_SL"))
         ClearStopTarget(true, positions, trades, actions);
      else if(object_name == Name("TP_MODE"))
        {
         m_tp_mode = m_tp_mode == PM_PRICE_ABSOLUTE ? PM_PRICE_PIPS : PM_PRICE_ABSOLUTE;
         m_stop_committed[1] = ObjectGetString(0, Name("TP_VALUE"), OBJPROP_TEXT);
        }
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
      else if(object_name == Name("EQ_LOSS_DEC"))
        {
         CommitDoubleValue("EQ_LOSS_VALUE", m_equity_guard_loss_threshold, PM_MAX_EQUITY_THRESHOLD, 2);
         m_equity_guard_loss_threshold = PMStepDecimal(m_equity_guard_loss_threshold,
                                                       -(m_equity_guard_mode == PM_EQUITY_THRESHOLD_PERCENT ? 0.1 : 1.0),
                                                       0.0, PM_MAX_EQUITY_THRESHOLD, 2);
         ObjectSetString(0, Name("EQ_LOSS_VALUE"), OBJPROP_TEXT,
                         DoubleToString(m_equity_guard_loss_threshold, 2));
         UpdateEquityGuardVisuals();
        }
      else if(object_name == Name("EQ_LOSS_INC"))
        {
         CommitDoubleValue("EQ_LOSS_VALUE", m_equity_guard_loss_threshold, PM_MAX_EQUITY_THRESHOLD, 2);
         m_equity_guard_loss_threshold = PMStepDecimal(m_equity_guard_loss_threshold,
                                                       m_equity_guard_mode == PM_EQUITY_THRESHOLD_PERCENT ? 0.1 : 1.0,
                                                       0.0, PM_MAX_EQUITY_THRESHOLD, 2);
         ObjectSetString(0, Name("EQ_LOSS_VALUE"), OBJPROP_TEXT,
                         DoubleToString(m_equity_guard_loss_threshold, 2));
         UpdateEquityGuardVisuals();
        }
      else if(object_name == Name("EQ_PROFIT_DEC"))
        {
         CommitDoubleValue("EQ_PROFIT_VALUE", m_equity_guard_profit_threshold, PM_MAX_EQUITY_THRESHOLD, 2);
         m_equity_guard_profit_threshold = PMStepDecimal(m_equity_guard_profit_threshold,
                                                          -(m_equity_guard_mode == PM_EQUITY_THRESHOLD_PERCENT ? 0.1 : 1.0),
                                                          0.0, PM_MAX_EQUITY_THRESHOLD, 2);
         ObjectSetString(0, Name("EQ_PROFIT_VALUE"), OBJPROP_TEXT,
                         DoubleToString(m_equity_guard_profit_threshold, 2));
         UpdateEquityGuardVisuals();
        }
      else if(object_name == Name("EQ_PROFIT_INC"))
        {
         CommitDoubleValue("EQ_PROFIT_VALUE", m_equity_guard_profit_threshold, PM_MAX_EQUITY_THRESHOLD, 2);
         m_equity_guard_profit_threshold = PMStepDecimal(m_equity_guard_profit_threshold,
                                                          m_equity_guard_mode == PM_EQUITY_THRESHOLD_PERCENT ? 0.1 : 1.0,
                                                          0.0, PM_MAX_EQUITY_THRESHOLD, 2);
         ObjectSetString(0, Name("EQ_PROFIT_VALUE"), OBJPROP_TEXT,
                         DoubleToString(m_equity_guard_profit_threshold, 2));
         UpdateEquityGuardVisuals();
        }
      else if(object_name == Name("TS_SYMBOL"))
         CycleSymbol(m_trailing_symbol);
      else if(object_name == Name("TS_DIRECTION"))
         m_trailing_direction = NextDirection(m_trailing_direction);
      else if(object_name == Name("BASIS_TOGGLE"))
         m_trail_basis = PMToggleTrailBasis(m_trail_basis);
      else if(object_name == Name("BE_ENABLED"))
         m_break_even_enabled = !m_break_even_enabled;
      else if(object_name == Name("BE_TRIGGER_DEC"))
         StepIntegerInput("BE_TRIGGER_VALUE", m_be_trigger_pips, -1, PM_MAX_TRAILING_POINTS, "Break Even Trigger");
      else if(object_name == Name("BE_TRIGGER_INC"))
         StepIntegerInput("BE_TRIGGER_VALUE", m_be_trigger_pips, 1, PM_MAX_TRAILING_POINTS, "Break Even Trigger");
      else if(object_name == Name("BE_LOCK_DEC"))
         StepIntegerInput("BE_LOCK_VALUE", m_be_lock_pips, -1, PM_MAX_TRAILING_POINTS, "Break Even Lock");
      else if(object_name == Name("BE_LOCK_INC"))
         StepIntegerInput("BE_LOCK_VALUE", m_be_lock_pips, 1, PM_MAX_TRAILING_POINTS, "Break Even Lock");
      else if(object_name == Name("TRAIL_ENABLED"))
         m_trailing_enabled = !m_trailing_enabled;
      else if(object_name == Name("TRAIL_TRIGGER_DEC"))
         StepIntegerInput("TRAIL_TRIGGER_VALUE", m_trail_trigger_pips, -1, PM_MAX_TRAILING_POINTS, "Trailing Trigger");
      else if(object_name == Name("TRAIL_TRIGGER_INC"))
         StepIntegerInput("TRAIL_TRIGGER_VALUE", m_trail_trigger_pips, 1, PM_MAX_TRAILING_POINTS, "Trailing Trigger");
      else if(object_name == Name("TRAIL_DIST_DEC"))
         StepIntegerInput("TRAIL_DIST_VALUE", m_trail_pips, -1, PM_MAX_TRAILING_POINTS, "Trailing Distance");
      else if(object_name == Name("TRAIL_DIST_INC"))
         StepIntegerInput("TRAIL_DIST_VALUE", m_trail_pips, 1, PM_MAX_TRAILING_POINTS, "Trailing Distance");
      else
         ToggleRowSelection(object_name);
      m_controls_dirty = true;
      m_positions_dirty = true;
      Render();
      return true;
     }

private:
   bool IsPriceLineObject(const string object_name)
     {
      return object_name == PM_SL_EDIT_LINE_NAME || object_name == PM_TP_EDIT_LINE_NAME ||
             StringFind(object_name, PM_SL_EDIT_LABEL_NAME) == 0 ||
             StringFind(object_name, PM_TP_EDIT_LABEL_NAME) == 0;
     }
   string PriceLineName(const int index)
     {
      return index == 0 ? PM_SL_EDIT_LINE_NAME : PM_TP_EDIT_LINE_NAME;
     }
   string PriceLabelName(const int index, const int row)
     {
      return (index == 0 ? PM_SL_EDIT_LABEL_NAME : PM_TP_EDIT_LABEL_NAME) +
             IntegerToString(row);
     }
   string StopSuffix(const int index) { return index == 0 ? "SL_VALUE" : "TP_VALUE"; }
   void CancelPriceDrag()
     {
      if(m_price_drag.Index() >= 0)
         ChartSetInteger(0, CHART_MOUSE_SCROLL, m_price_scroll_before);
      m_price_drag.Cancel();
      m_price_drag_moved = false;
     }
   void DeletePriceLineObjects()
     {
      CancelPriceDrag();
      for(int i = 0; i < 2; i++)
        {
         ObjectDelete(0, PriceLineName(i));
         for(int row = 0; row < 4; row++)
            ObjectDelete(0, PriceLabelName(i, row));
         m_price_line_visible[i] = false;
        }
     }
   bool PriceInteger(const string name, const ENUM_OBJECT_PROPERTY_INTEGER property,
                      const long value)
     {
      if(ObjectGetInteger(0, name, property) == value) return true;
      const bool ok = ObjectSetInteger(0, name, property, value);
      if(ok) m_force_redraw = true;
      return ok;
     }
   bool PriceText(const string name, const string text)
     {
      if(ObjectGetString(0, name, OBJPROP_TEXT) == text) return true;
      const bool ok = ObjectSetString(0, name, OBJPROP_TEXT, text);
      if(ok) m_force_redraw = true;
      return ok;
     }
   void HidePriceLine(const int index)
     {
      m_price_line_visible[index] = false;
      m_price_label_width[index] = 0;
      m_price_label_height[index] = 0;
      if(ObjectFind(0, PriceLineName(index)) >= 0)
         PriceInteger(PriceLineName(index), OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
      for(int row = 0; row < 4; row++)
         if(ObjectFind(0, PriceLabelName(index, row)) >= 0)
            PriceInteger(PriceLabelName(index, row), OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
     }
   void HidePriceLines()
     {
      CancelPriceDrag();
      HidePriceLine(0);
      HidePriceLine(1);
     }
   bool SelectedPriceSymbol()
     {
      if(ArraySize(m_selected) == 0) return false;
      for(int i = 0; i < ArraySize(m_selected); i++)
        {
         PMPosition position = {};
         if(!FindCachedPosition(m_selected[i], position) || position.symbol != _Symbol)
            return false;
        }
      return true;
     }
   bool EntryPriceContext() { return m_active_tab == PM_PANEL_TAB_ENTRY; }
   string PriceSelectionKey()
     {
      string key = StringFormat("%s:%d:%d:%d:%d", _Symbol, (int)m_active_tab,
                                 (int)m_collapsed, (int)m_sl_mode, (int)m_tp_mode);
      if(EntryPriceContext())
         return StringFormat("%s:entry:%d:%d:%d:%d:%d:%d", _Symbol, (int)m_collapsed,
                             (int)m_entry_draft.order_type, (int)m_entry_draft.side,
                             (int)m_entry_draft.quantity_mode, (int)m_entry_draft.unit[0],
                             (int)m_entry_draft.unit[1]) + ":" + m_entry_draft.order_text;
      for(int i = 0; i < ArraySize(m_selected); i++)
        {
         PMPosition position = {};
         if(!FindCachedPosition(m_selected[i], position)) return key + ":missing";
         // Netting trades can change the position without changing its ticket.
         key += StringFormat(":%I64u:%s:%d:%.8f:%.8f", position.ticket,
                              position.symbol, (int)position.type,
                              position.volume, position.open_price);
        }
      return key;
     }
   void SyncPriceContext()
     {
      const string context = PriceSelectionKey();
      if(context == m_price_line_selection_key) return;
      CancelPriceDrag();
      m_price_line_selection_key = context;
      for(int i = 0; i < 2; i++) m_price_seed[i] = 0.0;
      // Selection changes invalidate a drag, not the user's Price/Pips text.
     }
   bool ReadOrSeedStopPrice(const int index, const MqlTick &tick, double &price)
     {
      price = 0.0;
      if(EntryPriceContext())
        {
         price = index == 0 ? m_entry_snapshot.sl_price : m_entry_result.effective_tp;
         return MathIsValidNumber(price) && price > 0.0;
        }
      const string committed = m_stop_committed[index];
      if(committed != "")
        {
         if(!PMIsUnsignedDecimalText(committed)) return false;
         price = StringToDouble(committed);
         return MathIsValidNumber(price) && price > 0.0;
        }
      if(m_price_seed[index] > 0.0) { price = m_price_seed[index]; return true; }
      PMPosition first = {};
      if(!FirstSelectedPosition(first)) return false;
      const bool is_sl = index == 0;
      double existing = is_sl ? first.sl : first.tp;
      for(int i = 0; i < ArraySize(m_selected); i++)
        {
         PMPosition position = {};
         if(!FindCachedPosition(m_selected[i], position)) return false;
         if((is_sl ? position.sl : position.tp) != existing) existing = 0.0;
        }
      if(existing > 0.0 && MathIsValidNumber(existing))
         price = existing;
      else
        {
         const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
         const long level = MathMax(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL),
                                     SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL));
         const double distance = level * point + MathMax(point, tick_size) * 2.0;
         const double reference = first.type == POSITION_TYPE_BUY ? tick.bid : tick.ask;
         const bool upward = first.type == POSITION_TYPE_BUY ? !is_sl : is_sl;
         price = reference + (upward ? distance : -distance);
        }
      price = PMNormalizePrice(price, SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE),
                                (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
      m_price_seed[index] = price;
      return price > 0.0;
     }
   string SignedValue(const double value, const int digits)
     {
      const double rounded = NormalizeDouble(value, digits);
      return (rounded >= 0.0 ? "+" : "") + DoubleToString(rounded, digits);
     }
   void BuildPriceLineText(const int index, const double price, string &lines[])
     {
      ArrayResize(lines, 4);
      if(EntryPriceContext())
        {
         lines[0] = (index == 0 ? "SL " : "TP ") + PMFormatPrice(_Symbol, price);
         lines[1] = "Est. " + m_entry_service.Estimate(_Symbol, m_entry_snapshot, m_entry_result, index == 0) +
                    " " + AccountInfoString(ACCOUNT_CURRENCY);
         lines[2] = EntryRRText();
         lines[3] = m_entry_valid ? "Entry draft" : "Invalid: " + m_entry_reason;
         return;
        }
      CPriceEditEstimate estimate;
      bool money_ok = true, valid = true;
      CValidationService validator;
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      for(int i = 0; i < ArraySize(m_selected); i++)
        {
         PMPosition position = {};
         if(!FindCachedPosition(m_selected[i], position)) { valid = false; money_ok = false; continue; }
         double target = 0.0;
         string reason = "";
         if(!validator.CalculateTarget(position, index == 0, PM_PRICE_ABSOLUTE,
                                        price, target, reason)) valid = false;
         const double points = PMProfitPoints(position.open_price, position.type, price, point);
         ENUM_ORDER_TYPE side = ORDER_TYPE_BUY;
         if(position.type == POSITION_TYPE_SELL) side = ORDER_TYPE_SELL;
         double profit = 0.0;
         const bool calculated = OrderCalcProfit(side, _Symbol, position.volume,
                                                 position.open_price, price, profit);
         estimate.Add(position.type == POSITION_TYPE_BUY, position.volume, points,
                       calculated, profit);
        }
      const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      lines[0] = (index == 0 ? "SL" : "TP") + " draft " + DoubleToString(price, digits) +
                 (valid ? "" : " | Invalid");
      lines[1] = "Est. " + (money_ok && estimate.MoneyKnown() ?
                 SignedValue(estimate.Money(), (int)AccountInfoInteger(ACCOUNT_CURRENCY_DIGITS)) : "N/A") +
                 " " + AccountInfoString(ACCOUNT_CURRENCY) + StringFormat(" | %d pos", ArraySize(m_selected));
      const double points_per_pip = PMPointsPerPip(digits);
      lines[2] = estimate.HasBuy() ? "Buy avg " + SignedValue(estimate.BuyPoints() / points_per_pip, 1) + " pips" : "";
      lines[3] = estimate.HasSell() ? "Sell avg " + SignedValue(estimate.SellPoints() / points_per_pip, 1) + " pips" : "";
     }
   bool EnsurePriceObjects(const int index, const double price)
     {
      const string name = PriceLineName(index);
      const color line_color = index == 0 ? PM_SL_EDIT_LINE_COLOR : PM_TP_EDIT_LINE_COLOR;
      if(ObjectFind(0, name) < 0)
        {
         if(!ObjectCreate(0, name, OBJ_HLINE, 0, 0, price)) return false;
         m_force_redraw = true;
        }
      // Mouse capture is handled below. Native dragging would race timer rendering.
      bool ok = PriceInteger(name, OBJPROP_SELECTABLE, false);
      ok = PriceInteger(name, OBJPROP_SELECTED, false) && ok;
      ok = PriceInteger(name, OBJPROP_HIDDEN, true) && ok;
      ok = PriceInteger(name, OBJPROP_BACK, true) && ok;
      ok = PriceInteger(name, OBJPROP_COLOR, line_color) && ok;
      ok = PriceInteger(name, OBJPROP_STYLE, STYLE_DASH) && ok;
      ok = PriceInteger(name, OBJPROP_WIDTH, 1) && ok;
      if(ObjectGetDouble(0, name, OBJPROP_PRICE) != price)
        {
         ok = ObjectSetDouble(0, name, OBJPROP_PRICE, price) && ok;
         m_force_redraw = true;
        }
      for(int row = 0; row < 4; row++)
        {
         const string label = PriceLabelName(index, row);
         if(ObjectFind(0, label) < 0)
           {
            if(!ObjectCreate(0, label, OBJ_LABEL, 0, 0, 0)) return false;
            ObjectSetString(0, label, OBJPROP_FONT, "Arial");
            m_force_redraw = true;
           }
         ok = PriceInteger(label, OBJPROP_SELECTABLE, false) && ok;
         ok = PriceInteger(label, OBJPROP_HIDDEN, true) && ok;
         ok = PriceInteger(label, OBJPROP_CORNER, CORNER_LEFT_UPPER) && ok;
         ok = PriceInteger(label, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER) && ok;
         ok = PriceInteger(label, OBJPROP_FONTSIZE, 9) && ok;
         ok = PriceInteger(label, OBJPROP_COLOR, line_color) && ok;
        }
      return ok;
     }
   bool UpdatePriceLine(const int index, const MqlTick &tick, bool &outside)
     {
      outside = false;
      if(!EntryPriceContext() && (index == 0 ? m_sl_mode : m_tp_mode) != PM_PRICE_ABSOLUTE)
        { HidePriceLine(index); return true; }
      double price = 0.0;
      if(m_price_drag.Index() == index) price = m_price_drag.Price();
      else if(!ReadOrSeedStopPrice(index, tick, price))
        { HidePriceLine(index); return true; }
      price = PMNormalizePrice(price, SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE),
                                (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
      if(price <= 0.0) { HidePriceLine(index); return true; }
      int ignored_x = 0, price_y = 0;
      if(!ChartTimePriceToXY(0, 0, tick.time, price, ignored_x, price_y))
        { HidePriceLine(index); outside = true; return true; }
      if(price_y < 0 || price_y >= m_chart_height)
        { HidePriceLine(index); outside = true; return true; }
      string lines[];
      BuildPriceLineText(index, price, lines);
      int width = 0, row_height = 18;
      TextSetFont("Arial", -90, FW_NORMAL);
      for(int row = 0; row < 4; row++)
        {
         uint w = 0, h = 0;
         if(!TextGetSize(lines[row], w, h)) w = StringLen(lines[row]) * 8;
         width = MathMax(width, (int)w);
         row_height = MathMax(row_height, (int)h + 3);
        }
      const int height = 4 * row_height;
      const int other = 1 - index;
      int label_x = 0, label_y = 0;
      const bool placed = PMPlacePriceLabel((int)m_chart_width, (int)m_chart_height,
                                            price_y, width, height,
                                            m_origin_x - 4, m_origin_y - 4,
                                            m_panel_width + 8, PanelHeight() + 8,
                                            m_price_label_x[other], m_price_label_y[other],
                                            m_price_label_width[other], m_price_label_height[other] + 4,
                                            label_x, label_y);
      if(!EnsurePriceObjects(index, price)) { HidePriceLine(index); return false; }
      bool ok = PriceInteger(PriceLineName(index), OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      m_price_line_visible[index] = true;
      m_price_line_y[index] = price_y;
      m_price_line_price[index] = price;
      m_price_label_x[index] = label_x;
      m_price_label_y[index] = label_y;
      m_price_label_width[index] = placed ? width : 0;
      m_price_label_height[index] = placed ? height : 0;
      for(int row = 0; row < 4; row++)
        {
         const string label = PriceLabelName(index, row);
         ok = PriceInteger(label, OBJPROP_XDISTANCE, label_x) && ok;
         ok = PriceInteger(label, OBJPROP_YDISTANCE, label_y + row * row_height) && ok;
         ok = PriceText(label, lines[row]) && ok;
         ok = PriceInteger(label, OBJPROP_TIMEFRAMES,
                            placed && lines[row] != "" ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS) && ok;
        }
      if(!placed) outside = true;
      if(!ok) HidePriceLine(index);
      return ok;
     }
   void UpdatePriceLines()
     {
      SyncPriceContext();
      if(!EntryPriceContext() && m_sl_mode != PM_PRICE_ABSOLUTE && m_tp_mode != PM_PRICE_ABSOLUTE)
        {
         HidePriceLines();
         PriceText(Name("STOPS_HINT"), "Lines are available in Price mode.");
         return;
        }
      if(!EntryPriceContext() && !SelectedPriceSymbol())
        {
         HidePriceLines();
         PriceText(Name("STOPS_HINT"), "Lines: select positions of the chart symbol.");
         return;
        }
      MqlTick tick = {};
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(!SymbolInfoTick(_Symbol, tick) || tick.bid <= 0.0 || tick.ask <= 0.0 ||
         point <= 0.0 || tick_size <= 0.0)
        {
         HidePriceLines();
         PriceText(Name(EntryPriceContext() ? "ENTRY_HINT" : "STOPS_HINT"), "Lines unavailable: no price or symbol settings.");
         return;
        }
      // Place SL first, then TP around it, so equal-price labels remain accessible.
      m_price_label_width[0] = 0;
      m_price_label_width[1] = 0;
      bool sl_outside = false, tp_outside = false;
      const bool sl_ok = UpdatePriceLine(0, tick, sl_outside);
      const bool tp_ok = UpdatePriceLine(1, tick, tp_outside);
      if(EntryPriceContext())
        {
         if(!sl_ok || !tp_ok || sl_outside || tp_outside)
            PriceText(Name("ENTRY_HINT"), "Lines/labels outside view: adjust chart scale or size.");
         return;
        }
      bool invalid_input = false;
      for(int i = 0; i < 2; i++)
         if((i == 0 ? m_sl_mode : m_tp_mode) == PM_PRICE_ABSOLUTE && m_stop_committed[i] != "")
           {
            const double value = StringToDouble(m_stop_committed[i]);
            if(!PMIsUnsignedDecimalText(m_stop_committed[i]) || !MathIsValidNumber(value) ||
               PMNormalizePrice(value, tick_size, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)) <= 0.0)
               invalid_input = true;
           }
      const string hint = !sl_ok || !tp_ok ? "Lines unavailable: chart object update failed." :
                          invalid_input ? "Lines unavailable: enter a positive Price value." :
                          sl_outside || tp_outside ? "Lines/labels outside view: resize chart or price scale." :
                          "Drag a line or its label; Set / Change applies the draft.";
      PriceText(Name("STOPS_HINT"), hint);
     }
   void CommitStopEditor(const int index)
     {
      const string suffix = StopSuffix(index);
      string text = ObjectGetString(0, Name(suffix), OBJPROP_TEXT);
      if((index == 0 ? m_sl_mode : m_tp_mode) == PM_PRICE_ABSOLUTE &&
         PMIsUnsignedDecimalText(text) &&
         (ArraySize(m_selected) == 0 || SelectedPriceSymbol()))
        {
         // Mixed-symbol forms keep their input precision for per-ticket validation.
         const string symbol = _Symbol;
         const double price = PMNormalizePrice(StringToDouble(text),
                                                SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE),
                                                (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
         if(price > 0.0)
           {
            text = PMFormatPrice(symbol, price);
            ObjectSetString(0, Name(suffix), OBJPROP_TEXT, text);
           }
        }
      m_stop_committed[index] = text;
      CancelPriceDrag();
     }
   bool HandlePriceMouse(const int x, const int y, const bool pressed, const bool started)
     {
      SyncPriceContext();
      if(m_price_drag.Index() < 0)
        {
         if(!started || m_collapsed ||
            (!EntryPriceContext() && (m_active_tab != PM_PANEL_TAB_STOPS || !SelectedPriceSymbol())) ||
            PMRectOverlaps(x, y, 1, 1, m_origin_x, m_origin_y, m_panel_width, PanelHeight()))
            return false;
         int chosen = -1, distance = 6;
         // Labels disambiguate SL/TP at the same price.
         for(int i = 0; i < 2; i++)
            if(m_price_line_visible[i] &&
               PMRectOverlaps(x, y, 1, 1, m_price_label_x[i], m_price_label_y[i],
                               m_price_label_width[i], m_price_label_height[i])) chosen = i;
         if(chosen < 0)
            for(int i = 0; i < 2; i++)
               if(m_price_line_visible[i] && MathAbs(y - m_price_line_y[i]) < distance)
                 { distance = (int)MathAbs(y - m_price_line_y[i]); chosen = i; }
         if(chosen < 0) return false;
         long scroll = 1;
         ChartGetInteger(0, CHART_MOUSE_SCROLL, 0, scroll);
         m_price_scroll_before = scroll != 0;
         if(!ChartSetInteger(0, CHART_MOUSE_SCROLL, false)) return false;
         m_price_drag.Begin(chosen, m_price_line_selection_key, m_price_line_price[chosen]);
         m_price_mouse_start_y = y;
         m_price_mouse_start_price = m_price_line_price[chosen];
         m_price_drag_moved = false;
         return true;
        }
      // Use the price delta from mouse-down: grabbing a displaced label does not jump the line.
      int window = 0, start_window = 0;
      datetime time = 0, start_time = 0;
      double price = 0.0, start_price = 0.0;
      if(ChartXYToTimePrice(0, x, y, window, time, price) && window == 0 &&
         ChartXYToTimePrice(0, x, m_price_mouse_start_y, start_window, start_time, start_price) &&
         start_window == 0)
        {
         const double candidate = PMNormalizePrice(m_price_mouse_start_price + price - start_price,
                                                   SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE),
                                                   (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
         if(candidate > 0.0)
           {
            m_price_drag.Move(candidate);
            if(y != m_price_mouse_start_y) m_price_drag_moved = true;
           }
        }
      if(!pressed)
        {
         int index = -1;
         double final_price = 0.0;
         const bool moved = m_price_drag_moved;
         const bool accepted = m_price_drag.Finish(m_price_line_selection_key, index, final_price);
         ChartSetInteger(0, CHART_MOUSE_SCROLL, m_price_scroll_before);
         m_price_drag_moved = false;
         if(accepted && moved)
           {
            const string target_name = index == 0 ? "SL" : "TP";
            if(EntryPriceContext())
              {
               m_entry_draft.SetPrice(index, final_price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
               ObjectSetString(0, Name(EntryStopSuffix(index)), OBJPROP_TEXT, m_entry_draft.stop_text[index]);
               SetStatus(target_name + " Entry draft updated.");
              }
            else
              {
               m_stop_committed[index] = PMFormatPrice(_Symbol, final_price);
               ObjectSetString(0, Name(StopSuffix(index)), OBJPROP_TEXT, m_stop_committed[index]);
               SetStatus(target_name + " draft updated. Set / Change applies it.");
              }
           }
        }
      Render();
      return true;
     }
   void RenderControlStates()
     {
      ObjectSetString(0, Name("FILTER_SYMBOL"), OBJPROP_TEXT, FilterSymbol());
      ObjectSetString(0, Name("FILTER_DIRECTION"), OBJPROP_TEXT,
                      PMDirectionToString(m_filter_direction));
      ObjectSetString(0, Name("SL_MODE"), OBJPROP_TEXT,
                      PriceModeToString(m_sl_mode));
      ObjectSetString(0, Name("TP_MODE"), OBJPROP_TEXT,
                      PriceModeToString(m_tp_mode));
      UpdateToggleButtonVisual("AUTO_ENABLED", m_auto_enabled);
      ObjectSetString(0, Name("AUTO_SYMBOL"), OBJPROP_TEXT, AutoSymbol());
      ObjectSetString(0, Name("AUTO_DIRECTION"), OBJPROP_TEXT,
                      PMDirectionToString(m_auto_direction));
      ObjectSetString(0, Name("PASSED_BEHAVIOR"), OBJPROP_TEXT,
                      m_passed_behavior == PM_PASSED_CLOSE_IMMEDIATELY ?
                      "Passed: Close Now" : "Passed: Do Nothing");
      ObjectSetString(0, Name("EQ_MODE"), OBJPROP_TEXT,
                      EquityThresholdModeToString(m_equity_guard_mode));
      UpdateEquityGuardVisuals();
      ObjectSetString(0, Name("TS_SYMBOL"), OBJPROP_TEXT, TrailingSymbol());
      ObjectSetString(0, Name("TS_DIRECTION"), OBJPROP_TEXT,
                      PMDirectionToString(m_trailing_direction));
      ObjectSetString(0, Name("BASIS_TOGGLE"), OBJPROP_TEXT,
                      PMTrailBasisToString(m_trail_basis));
      UpdateToggleButtonVisual("BE_ENABLED", m_break_even_enabled);
      UpdateToggleButtonVisual("TRAIL_ENABLED", m_trailing_enabled);
     }
   string EntryRRText()
     {
      return m_entry_result.rr_status == PM_RR_VALID ? "Current RR 1:" + DoubleToString(m_entry_result.rr, 2) :
             m_entry_result.rr_status == PM_RR_INVALID ? "Current RR: Invalid" : "Current RR: N/A";
     }
   void RefreshEntryComputation(const bool preview)
     {
      m_entry_valid = m_entry_service.Evaluate(_Symbol, m_entry_draft,
                        preview ? m_price_drag.Index() : -1, preview ? m_price_drag.Price() : 0.0,
                        m_entry_snapshot, m_entry_result, m_entry_reason);
     }
   void FitEntryLabel(const string suffix, const int width)
     {
      const string name = Name(suffix);
      const string full_text = ObjectGetString(0, name, OBJPROP_TEXT);
      ObjectSetString(0, name, OBJPROP_TOOLTIP, full_text);
      uint measured = 0, height = 0;
      int font_size = 8;
      for(; font_size > 6; font_size--)
        {
         TextSetFont("Arial", -font_size * 10, FW_NORMAL);
         if(TextGetSize(full_text, measured, height) && (int)measured <= width) break;
        }
      PriceInteger(name, OBJPROP_FONTSIZE, font_size);
      TextSetFont("Arial", -font_size * 10, FW_NORMAL);
      if(!TextGetSize(full_text, measured, height) || (int)measured <= width) return;
      string shortened = full_text;
      while(StringLen(shortened) > 0 && (int)measured > width)
        {
         shortened = StringSubstr(shortened, 0, StringLen(shortened) - 1);
         if(!TextGetSize(shortened + "...", measured, height)) break;
        }
      PriceText(name, shortened + "...");
     }
   void RenderEntryState()
     {
      RefreshEntryComputation(true);
      const bool manual = m_entry_draft.quantity_mode == PM_QUANTITY_MANUAL_LOT;
      const bool market = m_entry_draft.order_type == PM_ENTRY_ORDER_MARKET;
      const bool buy = m_entry_draft.side == PM_ENTRY_BUY;
      PriceText(Name("ENTRY_TYPE"), market ? "Market" : m_entry_draft.order_type == PM_ENTRY_ORDER_LIMIT ? "Limit" : "Stop");
      PriceText(Name("ENTRY_SIDE"), buy ? "BUY" : "SELL");
      PriceInteger(Name("ENTRY_SIDE"), OBJPROP_BGCOLOR, buy ? clrDarkGreen : clrMaroon);
      PriceText(Name("ENTRY_QTY_MODE"), manual ? "Manual Lot" :
                m_entry_draft.quantity_mode == PM_QUANTITY_RISK_AMOUNT ? "Risk Amount" : "Risk Percent");
      PriceText(Name("ENTRY_PRICE"), _Symbol + " B " + PMFormatPrice(_Symbol, m_entry_snapshot.bid) +
                " / A " + PMFormatPrice(_Symbol, m_entry_snapshot.ask));
      PriceInteger(Name("ENTRY_ORDER_PRICE"), OBJPROP_READONLY, market);
      if(market) PriceText(Name("ENTRY_ORDER_PRICE"), PMFormatPrice(_Symbol, m_entry_result.entry));
      PriceInteger(Name("ENTRY_LOT"), OBJPROP_READONLY, !manual);
      if(!manual) PriceText(Name("ENTRY_LOT"), m_entry_result.lot_ok ?
                              DoubleToString(m_entry_result.lot, VolumeDigits(m_entry_snapshot.volume_step)) : "N/A");
      PriceText(Name("ENTRY_SL_MODE"), m_entry_draft.unit[0] == PM_ENTRY_UNIT_PRICE ? "Price" : "Points");
      PriceText(Name("ENTRY_TP_MODE"), m_entry_draft.unit[1] == PM_ENTRY_UNIT_PRICE ? "Price" : "Points");
      PriceText(Name("ENTRY_AUTO_TP"), m_entry_draft.tp_state == PM_TP_STATE_AUTO ? "Auto TP" : "Restore Auto");
      PriceText(Name("ENTRY_CURRENT_RR"), EntryRRText());
      PriceText(Name("ENTRY_PREVIEW"), "SL " + PMFormatPrice(_Symbol, m_entry_snapshot.sl_price) +
                " / TP " + PMFormatPrice(_Symbol, m_entry_result.effective_tp) +
                (m_entry_draft.tp_state == PM_TP_STATE_AUTO ? " (Auto)" : m_entry_draft.tp_state == PM_TP_STATE_OFF ? " (Off)" : " (Manual)"));
      PriceText(Name("ENTRY_ESTIMATE"), "Est. SL " + m_entry_service.Estimate(_Symbol, m_entry_snapshot, m_entry_result, true) +
                " / TP " + m_entry_service.Estimate(_Symbol, m_entry_snapshot, m_entry_result, false) +
                " " + AccountInfoString(ACCOUNT_CURRENCY));
      PriceText(Name("ENTRY_HINT"), !m_entry_valid ? m_entry_reason :
                m_entry_result.rr_status != PM_RR_VALID ? m_entry_result.rr_reason : "Drag SL/TP lines or labels to adjust prices.");
      PriceText(Name("ENTRY_LIMIT"), buy ? "BUY LIMIT" : "SELL LIMIT");
      PriceText(Name("ENTRY_STOP"), buy ? "BUY STOP" : "SELL STOP");
      PriceInteger(Name("ENTRY_LIMIT"), OBJPROP_BGCOLOR, buy ? clrDarkGreen : clrMaroon);
      PriceInteger(Name("ENTRY_STOP"), OBJPROP_BGCOLOR, buy ? clrDarkGreen : clrMaroon);
      string sends[] = {"ENTRY_BUY", "ENTRY_SELL", "ENTRY_LIMIT", "ENTRY_STOP"};
      for(int i = 0; i < 4; i++) PriceInteger(Name(sends[i]), OBJPROP_COLOR, m_entry_valid ? clrWhite : clrSilver);
      FitEntryLabel("ENTRY_PRICE", 256);
      FitEntryLabel("ENTRY_CURRENT_RR", 176);
      FitEntryLabel("ENTRY_PREVIEW", 494);
      FitEntryLabel("ENTRY_ESTIMATE", 326);
      FitEntryLabel("ENTRY_HINT", m_panel_width - 24);
     }
   void RenderPositionSummary()
     {
      ObjectSetString(0, Name("PAGE_LABEL"), OBJPROP_TEXT,
                      StringFormat("Page %d/%d", m_page + 1, PageCount()));
      ObjectSetString(0, Name("SELECTED_LABEL"), OBJPROP_TEXT,
                      StringFormat("Selected %d", ArraySize(m_selected)));
      ObjectSetString(0, Name("TOTAL_LABEL"), OBJPROP_TEXT,
                      StringFormat("Total %d", ArraySize(m_positions)));
     }
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
      return m_auto_minutes;
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
      ArrayResize(m_selected, ArraySize(m_positions));
      for(int i = 0; i < ArraySize(m_positions); i++)
         m_selected[i] = m_positions[i].ticket;
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
      string text = StringFormat("%s: %d succeeded, %d unchanged, %d queued, %d failed / %d",
                                 operation, result.successful, result.unchanged,
                                 result.queued, ArraySize(result.failures), result.requested);
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
      value = NormalizeDouble(value, digits);
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
   void StepIntegerInput(const string suffix,
                         int &target,
                         const int delta,
                         const int maximum,
                         const string description)
     {
      CommitIntegerValue(suffix, target, maximum);
      target = PMStepInteger(target, delta, 0, maximum);
      ObjectSetString(0, Name(suffix), OBJPROP_TEXT, IntegerToString(target));
      SetStatus(StringFormat("%s set to %d.", description, target));
     }
   bool HandleEditEnd(const string object_name)
     {
      if(object_name == Name("AUTO_MINUTES")) { CommitIntegerValue("AUTO_MINUTES", m_auto_minutes, PM_MAX_AUTO_CLOSE_MINUTES); SetStatus(StringFormat("Auto Close minutes set to %d.", m_auto_minutes)); }
      else if(object_name == Name("EQ_LOSS_VALUE")) { CommitDoubleValue("EQ_LOSS_VALUE", m_equity_guard_loss_threshold, PM_MAX_EQUITY_THRESHOLD, 2); UpdateEquityGuardVisuals(); SetStatus(StringFormat("Max Loss updated: %.2f (%s).", m_equity_guard_loss_threshold, m_equity_guard_enabled ? "Guard ON" : "Guard OFF")); }
      else if(object_name == Name("EQ_PROFIT_VALUE")) { CommitDoubleValue("EQ_PROFIT_VALUE", m_equity_guard_profit_threshold, PM_MAX_EQUITY_THRESHOLD, 2); UpdateEquityGuardVisuals(); SetStatus(StringFormat("Max Profit updated: %.2f (%s).", m_equity_guard_profit_threshold, m_equity_guard_enabled ? "Guard ON" : "Guard OFF")); }
      else if(object_name == Name("BE_TRIGGER_VALUE")) { CommitIntegerValue("BE_TRIGGER_VALUE", m_be_trigger_pips, PM_MAX_TRAILING_POINTS); SetStatus(StringFormat("Break Even Trigger updated: %d pips.", m_be_trigger_pips)); }
      else if(object_name == Name("BE_LOCK_VALUE")) { CommitIntegerValue("BE_LOCK_VALUE", m_be_lock_pips, PM_MAX_TRAILING_POINTS); SetStatus(StringFormat("Break Even Lock updated: %d pips.", m_be_lock_pips)); }
      else if(object_name == Name("TRAIL_TRIGGER_VALUE")) { CommitIntegerValue("TRAIL_TRIGGER_VALUE", m_trail_trigger_pips, PM_MAX_TRAILING_POINTS); SetStatus(StringFormat("Trailing Trigger updated: %d pips.", m_trail_trigger_pips)); }
      else if(object_name == Name("TRAIL_DIST_VALUE")) { CommitIntegerValue("TRAIL_DIST_VALUE", m_trail_pips, PM_MAX_TRAILING_POINTS); SetStatus(StringFormat("Trailing Distance updated: %d pips.", m_trail_pips)); }
      else if(StringFind(object_name, Name("ENTRY_")) == 0)
        {
         const bool tp_edit = object_name == Name(EntryStopSuffix(1));
         CommitEntryEditor(object_name);
         if(tp_edit && m_entry_draft.tp_state == PM_TP_STATE_AUTO)
            m_entry_draft.SetStop(1, ObjectGetString(0, object_name, OBJPROP_TEXT));
         CancelPriceDrag();
         RefreshEntryComputation(false);
         SetStatus(m_entry_valid ? "Entry draft updated." : m_entry_reason);
        }
      else if(object_name == Name("SL_VALUE")) { CommitStopEditor(0); SetStatus("SL draft updated."); }
      else if(object_name == Name("TP_VALUE")) { CommitStopEditor(1); SetStatus("TP draft updated."); }
      else return false;
      m_controls_dirty = true;
      m_positions_dirty = true;
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
      m_visibility_dirty = true;
      m_status_layout_dirty = true;
      m_positions_dirty = true;
      return true;
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
         CommitStopEditor(is_sl ? 0 : 1);
         return;
        }
      ObjectSetString(0, Name(suffix), OBJPROP_TEXT, DoubleToString(value, 0));
      CommitStopEditor(is_sl ? 0 : 1);
     }
   bool FirstSelectedPosition(PMPosition &position)
     {
      for(int index = 0; index < ArraySize(m_selected); index++)
         if(FindCachedPosition(m_selected[index], position))
            return true;
      return false;
     }
   string EntryStopSuffix(const int index) { return index == 0 ? "ENTRY_SL_POINTS" : "ENTRY_TP_POINTS"; }
   bool IsEntrySendButton(const string name)
     {
      return name == Name("ENTRY_BUY") || name == Name("ENTRY_SELL") ||
             name == Name("ENTRY_LIMIT") || name == Name("ENTRY_STOP");
     }
   void WriteEntryStops()
     {
      for(int i = 0; i < 2; i++)
         ObjectSetString(0, Name(EntryStopSuffix(i)), OBJPROP_TEXT, m_entry_draft.stop_text[i]);
     }
   void CommitEntryEditor(const string name)
     {
      const string text = ObjectGetString(0, name, OBJPROP_TEXT);
      if(name == Name("ENTRY_ORDER_PRICE") && m_entry_draft.order_type != PM_ENTRY_ORDER_MARKET)
         m_entry_draft.order_text = text;
      else if(name == Name("ENTRY_LOT") && m_entry_draft.quantity_mode == PM_QUANTITY_MANUAL_LOT)
        {
         m_entry_draft.lot_text = text;
         double volume = 0.0;
         if(m_entry_draft.Number(text, false, volume))
           {
            volume = PMNormalizeVolume(volume, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN),
                                        SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX), SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP));
            if(volume > 0.0)
              {
               m_entry_draft.lot_text = DoubleToString(volume, VolumeDigits(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP)));
               ObjectSetString(0, name, OBJPROP_TEXT, m_entry_draft.lot_text);
              }
           }
        }
      else if(name == Name("ENTRY_RISK")) m_entry_draft.risk_text = text;
      else if(name == Name("ENTRY_RR")) m_entry_draft.rr_text = text;
      else
         for(int i = 0; i < 2; i++)
            if(name == Name(EntryStopSuffix(i)) && text != m_entry_draft.stop_text[i])
              {
               RefreshEntryComputation(false);
               const bool was_auto = m_entry_draft.tp_state == PM_TP_STATE_AUTO;
               double price = 0.0;
               if(m_entry_draft.unit[i] == PM_ENTRY_UNIT_PRICE && m_entry_draft.Number(text, true, price) && price > 0.0)
                 {
                  price = PMNormalizePrice(price, SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE),
                                            (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
                  // A nonzero input that cannot be rounded must remain invalid, never cancel a stop.
                  if(price > 0.0) m_entry_draft.SetPrice(i, price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
                  else m_entry_draft.SetStop(i, text);
                 }
               else m_entry_draft.SetStop(i, text);
               ObjectSetString(0, name, OBJPROP_TEXT, m_entry_draft.stop_text[i]);
               if(i == 0 && was_auto && m_entry_draft.tp_state == PM_TP_STATE_MANUAL)
                  ObjectSetString(0, Name(EntryStopSuffix(1)), OBJPROP_TEXT, m_entry_draft.stop_text[1]);
              }
     }
   void CommitEntryEditors()
     {
      CommitEntryEditor(Name("ENTRY_ORDER_PRICE"));
      CommitEntryEditor(Name("ENTRY_LOT"));
      CommitEntryEditor(Name("ENTRY_RISK"));
      CommitEntryEditor(Name("ENTRY_RR"));
      // Resolve explicit TP Points from the latest entry before SL cancellation can freeze Auto TP.
      CommitEntryEditor(Name(EntryStopSuffix(1)));
      CommitEntryEditor(Name(EntryStopSuffix(0)));
     }
   void SetEntryStop(const int index)
     {
      RefreshEntryComputation(false);
      if(!m_entry_result.entry_ok) { SetStatus(m_entry_result.entry_reason); return; }
      const double point = m_entry_snapshot.point, tick = m_entry_snapshot.tick_size;
      if(point <= 0.0 || tick <= 0.0) { SetStatus("Symbol price settings are unavailable."); return; }
      double price = index == 0 ? m_entry_snapshot.sl_price : m_entry_result.effective_tp;
      if(price <= 0.0)
        {
         const double distance = MathMax(m_entry_snapshot.stops_level, m_entry_snapshot.freeze_level) * point + MathMax(point, tick) * 2.0;
         const bool upward = m_entry_draft.side == PM_ENTRY_BUY ? index == 1 : index == 0;
         double base = m_entry_result.entry;
         if(index == 0 && m_entry_draft.order_type == PM_ENTRY_ORDER_MARKET)
            base = m_entry_draft.PointsBase(m_entry_snapshot, m_entry_result.entry);
         price = PMNormalizePrice(base + (upward ? distance : -distance), tick, m_entry_snapshot.digits);
        }
      if(!MathIsValidNumber(price) || price <= 0.0) { SetStatus("Unable to seed a positive stop price."); return; }
      m_entry_draft.SetPrice(index, price, m_entry_snapshot.digits);
      WriteEntryStops();
     }
   void SwitchEntryUnit(const int index)
     {
      RefreshEntryComputation(false);
      double price = index == 0 ? m_entry_snapshot.sl_price : m_entry_result.effective_tp;
      if(!m_entry_result.entry_ok) { SetStatus(m_entry_result.entry_reason); return; }
      double value = 0.0;
      string reason = "";
      if(!(index == 1 && m_entry_draft.tp_state == PM_TP_STATE_AUTO) &&
         !(index == 1 && m_entry_draft.manual_tp_price > 0.0) &&
         !m_entry_draft.ResolveStop(index, m_entry_snapshot, m_entry_result.entry, price, reason))
        { SetStatus(reason); return; }
      if(m_entry_draft.unit[index] == PM_ENTRY_UNIT_POINTS)
        {
         m_entry_draft.unit[index] = PM_ENTRY_UNIT_PRICE;
         m_entry_draft.stop_text[index] = DoubleToString(price, m_entry_snapshot.digits);
        }
      else
        {
         const double point = m_entry_snapshot.point;
         if(point <= 0.0) { SetStatus("Point size is unavailable."); return; }
         if(price > 0.0)
           {
            const bool upward = m_entry_draft.side == PM_ENTRY_BUY ? index == 1 : index == 0;
            value = (price - m_entry_draft.PointsBase(m_entry_snapshot, m_entry_result.entry)) / point * (upward ? 1.0 : -1.0);
            if(value < 0.0 || value > PM_MAX_TRAILING_POINTS)
              { SetStatus("This price cannot be expressed as positive Points for this direction."); return; }
            value = MathRound(value);
           }
         if(index == 0 && price > 0.0 && value == 0.0) m_entry_draft.FreezeAutoTP();
         m_entry_draft.unit[index] = PM_ENTRY_UNIT_POINTS;
         m_entry_draft.stop_text[index] = DoubleToString(value, 0);
        }
      if(index == 1 && m_entry_draft.tp_state == PM_TP_STATE_MANUAL)
         m_entry_draft.manual_tp_price = 0.0; // Re-resolve the explicit mode conversion and its rounding.
      WriteEntryStops();
     }
   void StepEntryInput(const string suffix, const int direction)
     {
      const string name = Name(suffix);
      double value = 0.0;
      if(!m_entry_draft.Number(ObjectGetString(0, name, OBJPROP_TEXT), true, value))
        { SetStatus("Enter a valid number before using - / +."); return; }
      const bool price = suffix == "ENTRY_ORDER_PRICE" ||
                         (suffix == EntryStopSuffix(0) && m_entry_draft.unit[0] == PM_ENTRY_UNIT_PRICE) ||
                         (suffix == EntryStopSuffix(1) && m_entry_draft.unit[1] == PM_ENTRY_UNIT_PRICE);
      int digits = 0;
      if(price)
        {
         digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
         if(value == 0.0)
           {
            if(suffix != "ENTRY_ORDER_PRICE") { SetEntryStop(suffix == EntryStopSuffix(0) ? 0 : 1); return; }
            MqlTick tick = {}; SymbolInfoTick(_Symbol, tick);
            value = m_entry_draft.side == PM_ENTRY_BUY ? tick.ask : tick.bid;
           }
         value = PMShiftPriceEditorValue(value, SymbolInfoDouble(_Symbol, SYMBOL_POINT),
                                         SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE), direction, digits);
        }
      else if(suffix == "ENTRY_LOT")
        {
         const double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         value = PMNormalizeVolume(value + direction * step, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN),
                                    SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX), step);
         digits = VolumeDigits(step);
        }
      else if(suffix == "ENTRY_RISK" || suffix == "ENTRY_RR")
        {
         const bool percent = m_entry_draft.quantity_mode == PM_QUANTITY_RISK_PERCENT;
         const double step = suffix == "ENTRY_RR" || percent ? 0.1 : 1.0;
         const double minimum = suffix == "ENTRY_RR" ? 0.1 : 0.0;
         const double maximum = suffix == "ENTRY_RISK" && percent ? 100.0 : PM_MAX_EQUITY_THRESHOLD;
         digits = 2;
         value = PMStepDecimal(value, direction * step, minimum, maximum, digits);
        }
      else value = MathMax(0.0, MathMin(PM_MAX_TRAILING_POINTS, value + direction));
      ObjectSetString(0, name, OBJPROP_TEXT, DoubleToString(value, digits));
      CommitEntryEditor(name);
     }
   void HandleEntryClick(const string name, CTradeManager &trades)
     {
      CommitEntryEditors();
      RefreshEntryComputation(false);
      if(IsEntrySendButton(name)) { OpenEntry(trades); return; }
      if(name == Name("ENTRY_TYPE"))
        {
         m_entry_draft.order_type = m_entry_draft.order_type == PM_ENTRY_ORDER_MARKET ? PM_ENTRY_ORDER_LIMIT :
                                   m_entry_draft.order_type == PM_ENTRY_ORDER_LIMIT ? PM_ENTRY_ORDER_STOP : PM_ENTRY_ORDER_MARKET;
         ObjectSetString(0, Name("ENTRY_ORDER_PRICE"), OBJPROP_TEXT, m_entry_draft.order_text);
        }
      else if(name == Name("ENTRY_SIDE")) m_entry_draft.side = m_entry_draft.side == PM_ENTRY_BUY ? PM_ENTRY_SELL : PM_ENTRY_BUY;
      else if(name == Name("ENTRY_QTY_MODE"))
        {
         m_entry_draft.quantity_mode = m_entry_draft.quantity_mode == PM_QUANTITY_MANUAL_LOT ? PM_QUANTITY_RISK_AMOUNT :
                                      m_entry_draft.quantity_mode == PM_QUANTITY_RISK_AMOUNT ? PM_QUANTITY_RISK_PERCENT : PM_QUANTITY_MANUAL_LOT;
         ObjectSetString(0, Name("ENTRY_LOT"), OBJPROP_TEXT, m_entry_draft.lot_text);
        }
      else if(name == Name("ENTRY_SL_SET")) SetEntryStop(0);
      else if(name == Name("ENTRY_TP_SET")) SetEntryStop(1);
      else if(name == Name("ENTRY_SL_CLEAR")) { m_entry_draft.CancelStop(0); WriteEntryStops(); }
      else if(name == Name("ENTRY_TP_CLEAR")) { m_entry_draft.CancelStop(1); WriteEntryStops(); }
      else if(name == Name("ENTRY_AUTO_TP"))
        {
         string reason = "";
         if(!m_entry_draft.AutoTP(m_entry_result.entry, m_entry_snapshot.sl_price, reason)) SetStatus(reason);
        }
      else if(name == Name("ENTRY_SL_MODE")) SwitchEntryUnit(0);
      else if(name == Name("ENTRY_TP_MODE")) SwitchEntryUnit(1);
      else
        {
         string prefixes[] = {"ENTRY_ORDER", "ENTRY_LOT", "ENTRY_RISK", "ENTRY_RR", "ENTRY_SL", "ENTRY_TP"};
         string values[] = {"ENTRY_ORDER_PRICE", "ENTRY_LOT", "ENTRY_RISK", "ENTRY_RR", "ENTRY_SL_POINTS", "ENTRY_TP_POINTS"};
         for(int i = 0; i < ArraySize(prefixes); i++)
           {
            if(name == Name(prefixes[i] + "_DEC")) StepEntryInput(values[i], -1);
            if(name == Name(prefixes[i] + "_INC")) StepEntryInput(values[i], 1);
           }
        }
      m_visibility_dirty = true;
     }
   void OpenEntry(CTradeManager &trades)
     {
      if(m_price_drag.Index() >= 0) { SetStatus("Finish the line drag before submitting an order."); return; }
      RefreshEntryComputation(false);
      if(!m_entry_valid) { SetStatus(m_entry_reason); return; }
      PMMarketEntryResult result = {};
      if(!trades.SubmitEntry(_Symbol, m_entry_snapshot, m_entry_result, result))
        { SetStatus(StringFormat("Entry failed: %s (retcode=%u)", result.description, result.retcode)); return; }
      const string outcome = result.retcode == TRADE_RETCODE_DONE_PARTIAL ? "partially filled" :
                             result.retcode == TRADE_RETCODE_PLACED || m_entry_draft.order_type != PM_ENTRY_ORDER_MARKET ? "accepted" : "filled";
      SetStatus(StringFormat("Entry %s: requested=%s result=%s price=%s deal=%I64u order=%I64u retcode=%u",
                              outcome, DoubleToString(m_entry_result.lot, 8), DoubleToString(result.volume, 8),
                              PMFormatPrice(_Symbol, result.price), result.deal, result.order, result.retcode));
     }
   bool RenderPositionRows()
     {
      const int start = m_page * m_max_rows;
      const int visible_rows = VisiblePositionRows();
      const int previous_visible_rows = m_visible_rows;
      bool rows_created = true;
      int row_creation_error = 0;
      for(int row = 0; row < visible_rows; row++)
        {
         PMPosition position = m_positions[start + row];
         const int row_y = ContentTop() + PM_PANEL_POSITIONS_HEADER_HEIGHT + row * PM_PANEL_POSITION_ROW_HEIGHT;
         const bool is_selected = IsSelected(position.ticket);
         const string selected = is_selected ? "[x] " : "[ ] ";
         const string row_text = selected + position.symbol + "  Lot=" + DoubleToString(position.volume, 2) +
                                 "  Entry=" + PMFormatPrice(position.symbol, position.open_price) +
                                 "  SL=" + PMFormatPrice(position.symbol, position.sl) +
                                 "  TP=" + PMFormatPrice(position.symbol, position.tp) +
                                 "  P=" + DoubleToString(position.profit, 2) +
                                 "  #" + StringFormat("%I64u", position.ticket);
         if(row >= m_rendered_rows)
           {
            if(!CreatePositionRow(row, row_y, row_text, position.type,
                                  is_selected, row_creation_error))
              {
               rows_created = false;
               break;
              }
            m_rendered_rows++;
           }
         else
           {
            if(!UpdatePositionRow(row, row_text, position.type,
                                  is_selected) &&
               !CreatePositionRow(row, row_y, row_text, position.type,
                                  is_selected, row_creation_error))
              {
               rows_created = false;
               break;
              }
           }
        }
      m_visible_rows = MathMin(visible_rows, m_rendered_rows);
      if(previous_visible_rows != m_visible_rows)
        {
         m_visibility_dirty = true;
         m_status_layout_dirty = true;
        }
      if(!rows_created && !m_row_render_error_reported)
         PrintFormat("[ERROR] UI position row creation failed. last_error=%d",
                     row_creation_error);
      m_row_render_error_reported = !rows_created;
      return rows_created;
     }
   bool UpdatePositionRow(const int row,
                          const string row_text,
                          const ENUM_POSITION_TYPE type,
                          const bool selected)
     {
      bool updated = true;
      if(!ObjectSetInteger(0, RowName(row), OBJPROP_XSIZE,
                           m_panel_width - 24))
         updated = false;
      if(!ObjectSetInteger(0, RowName(row), OBJPROP_BGCOLOR,
                           selected ? clrDarkGreen : clrDarkSlateGray))
         updated = false;
      if(!ObjectSetString(0, RowDetailName(row), OBJPROP_TEXT, row_text))
         updated = false;
      if(!ObjectSetString(0, RowDirectionName(row), OBJPROP_TEXT,
                          PMPositionTypeToString(type)))
         updated = false;
      if(!ObjectSetInteger(0, RowDirectionName(row), OBJPROP_COLOR,
                           type == POSITION_TYPE_BUY ?
                           clrLimeGreen : clrTomato))
         updated = false;
      return updated;
     }
   bool CreatePositionRow(const int row,
                          const int row_y,
                          const string row_text,
                          const ENUM_POSITION_TYPE type,
                          const bool selected,
                          int &error_code)
     {
      error_code = 0;
      const string row_suffix = "ROW_" + IntegerToString(row);
      const string detail_suffix = "ROW_DETAIL_" + IntegerToString(row);
      const string direction_suffix = "ROW_DIRECTION_" + IntegerToString(row);
      ResetLastError();
      if(!DeleteRegisteredObject(Name(row_suffix)) ||
         !DeleteRegisteredObject(Name(detail_suffix)) ||
         !DeleteRegisteredObject(Name(direction_suffix)))
        {
         error_code = GetLastError();
         return false;
        }
      ResetLastError();
      if(!CreateButton(row_suffix, "", 12, row_y, m_panel_width - 24, 22,
                       selected ? clrDarkGreen : clrDarkSlateGray))
        {
         error_code = GetLastError();
         return false;
        }
      ResetLastError();
      if(!CreateLabel(detail_suffix, row_text, 75, row_y + 4, clrWhite, 8))
        {
         error_code = GetLastError();
         DeleteRegisteredObject(Name(row_suffix));
         return false;
        }
      ResetLastError();
      if(!CreateLabel(direction_suffix, PMPositionTypeToString(type),
                      40, row_y + 4,
                      type == POSITION_TYPE_BUY ? clrLimeGreen : clrTomato, 8))
        {
         error_code = GetLastError();
         DeleteRegisteredObject(Name(row_suffix));
         DeleteRegisteredObject(Name(detail_suffix));
         return false;
        }
      return true;
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
      string entry_controls[] = {"ENTRY_PRICE", "ENTRY_TYPE", "ENTRY_SIDE", "ENTRY_ORDER_PRICE_LABEL",
         "ENTRY_ORDER_PRICE", "ENTRY_QTY_MODE", "ENTRY_LOT_LABEL", "ENTRY_LOT", "ENTRY_SL_LABEL", "ENTRY_SL_MODE",
         "ENTRY_SL_DEC", "ENTRY_SL_POINTS", "ENTRY_SL_INC", "ENTRY_SL_SET", "ENTRY_SL_CLEAR",
         "ENTRY_TP_LABEL", "ENTRY_TP_MODE", "ENTRY_TP_DEC", "ENTRY_TP_POINTS", "ENTRY_TP_INC", "ENTRY_TP_SET", "ENTRY_TP_CLEAR",
         "ENTRY_RR_LABEL", "ENTRY_RR", "ENTRY_RR_DEC", "ENTRY_RR_INC", "ENTRY_AUTO_TP", "ENTRY_CURRENT_RR",
         "ENTRY_PREVIEW", "ENTRY_ESTIMATE", "ENTRY_HINT"};
      for(int i = 0; i < ArraySize(entry_controls); i++) SetVisible(entry_controls[i], entry);
      const bool manual = m_entry_draft.quantity_mode == PM_QUANTITY_MANUAL_LOT;
      const bool market = m_entry_draft.order_type == PM_ENTRY_ORDER_MARKET;
      SetVisible("ENTRY_ORDER_DEC", entry && !market); SetVisible("ENTRY_ORDER_INC", entry && !market);
      SetVisible("ENTRY_LOT_DEC", entry && manual); SetVisible("ENTRY_LOT_INC", entry && manual);
      SetVisible("ENTRY_RISK", entry && !manual);
      SetVisible("ENTRY_RISK_DEC", entry && !manual); SetVisible("ENTRY_RISK_INC", entry && !manual);
      SetVisible("ENTRY_BUY", entry && market && m_entry_draft.side == PM_ENTRY_BUY);
      SetVisible("ENTRY_SELL", entry && market && m_entry_draft.side == PM_ENTRY_SELL);
      SetVisible("ENTRY_LIMIT", entry && m_entry_draft.order_type == PM_ENTRY_ORDER_LIMIT);
      SetVisible("ENTRY_STOP", entry && m_entry_draft.order_type == PM_ENTRY_ORDER_STOP);
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
      SetVisible("AUTO_MINUTES_DEC", auto_tab);
      SetVisible("AUTO_MINUTES", auto_tab);
      SetVisible("AUTO_MINUTES_INC", auto_tab);
      SetVisible("PASSED_BEHAVIOR", auto_tab);
      SetVisible("AUTO_HINT", auto_tab);
      const bool guard = expanded && m_active_tab == PM_PANEL_TAB_GUARD;
      SetVisible("EQ_LABEL", guard);
      SetVisible("EQ_ENABLED", guard);
      SetVisible("EQ_MODE", guard);
      SetVisible("EQ_LOSS_LABEL", guard);
      SetVisible("EQ_LOSS_DEC", guard);
      SetVisible("EQ_LOSS_VALUE", guard);
      SetVisible("EQ_LOSS_INC", guard);
      SetVisible("EQ_PROFIT_LABEL", guard);
      SetVisible("EQ_PROFIT_DEC", guard);
      SetVisible("EQ_PROFIT_VALUE", guard);
      SetVisible("EQ_PROFIT_INC", guard);
      SetVisible("EQ_HINT", guard);
      const bool trail = expanded && m_active_tab == PM_PANEL_TAB_TRAIL;
      SetVisible("TS_LABEL", trail);
      SetVisible("TS_SYMBOL", trail);
      SetVisible("TS_DIRECTION", trail);
      SetVisible("BASIS_LABEL", trail);
      SetVisible("BASIS_TOGGLE", trail);
      SetVisible("BE_LABEL", trail);
      SetVisible("BE_ENABLED", trail);
      SetVisible("BE_TRIGGER_LABEL", trail);
      SetVisible("BE_TRIGGER_DEC", trail);
      SetVisible("BE_TRIGGER_VALUE", trail);
      SetVisible("BE_TRIGGER_INC", trail);
      SetVisible("BE_LOCK_LABEL", trail);
      SetVisible("BE_LOCK_DEC", trail);
      SetVisible("BE_LOCK_VALUE", trail);
      SetVisible("BE_LOCK_INC", trail);
      SetVisible("TRAIL_LABEL", trail);
      SetVisible("TRAIL_ENABLED", trail);
      SetVisible("TRAIL_TRIGGER_LABEL", trail);
      SetVisible("TRAIL_TRIGGER_DEC", trail);
      SetVisible("TRAIL_TRIGGER_VALUE", trail);
      SetVisible("TRAIL_TRIGGER_INC", trail);
      SetVisible("TRAIL_DIST_LABEL", trail);
      SetVisible("TRAIL_DIST_DEC", trail);
      SetVisible("TRAIL_DIST_VALUE", trail);
      SetVisible("TRAIL_DIST_INC", trail);
      SetVisible("TRAIL_HINT", trail);
      SetVisible("SESSION_LABEL", expanded);
      for(int row = 0; row < m_rendered_rows; row++)
        {
         const bool row_visible = positions && row < m_visible_rows;
         SetVisible("ROW_" + IntegerToString(row), row_visible);
         SetVisible("ROW_DETAIL_" + IntegerToString(row), row_visible);
         SetVisible("ROW_DIRECTION_" + IntegerToString(row), row_visible);
        }
      for(int line = 0; line < PM_MAX_STATUS_LINES; line++)
         SetVisible("STATUS_LINE_" + IntegerToString(line), expanded);
      SetVisible("RESIZE_GRIP", expanded);
      ObjectSetString(0, Name("COLLAPSE"), OBJPROP_TEXT, m_collapsed ? "+" : "-");
      ObjectSetInteger(0, Name("BACKGROUND"), OBJPROP_YSIZE, PanelHeight());
      SetObjectPosition(Name("RESIZE_GRIP"),
                        m_origin_x + m_panel_width - 24,
                        m_origin_y + PanelHeight() - 18);
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
      // Amounts remain in the full-width editors; keep this status readable at high DPI.
      return value > 0.0 ? "set" : "not set";
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
      SetObjectY(Name("SESSION_LABEL"), m_origin_y + base_y);
      const color status_color = StatusTextColor();
      for(int line = 0; line < PM_MAX_STATUS_LINES; line++)
        {
         const bool visible = line < ArraySize(lines);
         ObjectSetString(0, Name("STATUS_LINE_" + IntegerToString(line)), OBJPROP_TEXT, visible ? lines[line] : "");
         ObjectSetInteger(0, Name("STATUS_LINE_" + IntegerToString(line)), OBJPROP_COLOR, status_color);
         SetObjectY(Name("STATUS_LINE_" + IntegerToString(line)),
                    m_origin_y + base_y + PM_PANEL_STATUS_LINE_HEIGHT +
                    line * PM_PANEL_STATUS_LINE_HEIGHT);
         SetVisible("STATUS_LINE_" + IntegerToString(line), visible);
        }
      ObjectSetInteger(0, Name("BACKGROUND"), OBJPROP_YSIZE, PanelHeight());
      SetObjectY(Name("RESIZE_GRIP"), m_origin_y + PanelHeight() - 18);
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
   int FindRegisteredObject(const string object_name)
     {
      for(int index = 0; index < ArraySize(m_object_names); index++)
         if(m_object_names[index] == object_name)
            return index;
      return -1;
     }
   void RegisterObject(const string object_name, const int x, const int y)
     {
      int index = FindRegisteredObject(object_name);
      if(index < 0)
        {
         index = ArraySize(m_object_names);
         ArrayResize(m_object_names, index + 1, 128);
         ArrayResize(m_object_x, index + 1, 128);
         ArrayResize(m_object_y, index + 1, 128);
         m_object_names[index] = object_name;
        }
      m_object_x[index] = x;
      m_object_y[index] = y;
     }
   bool DeleteRegisteredObject(const string object_name)
     {
      const int index = FindRegisteredObject(object_name);
      if(index < 0)
         return true;
      if(!ObjectDelete(0, object_name) && ObjectFind(0, object_name) >= 0)
         return false;
      ArrayRemove(m_object_names, index, 1);
      ArrayRemove(m_object_x, index, 1);
      ArrayRemove(m_object_y, index, 1);
      return true;
     }
   void SetObjectPosition(const string object_name, const int x, const int y)
     {
      const int index = FindRegisteredObject(object_name);
      if(index >= 0)
        {
         if(m_object_x[index] != x)
            ObjectSetInteger(0, object_name, OBJPROP_XDISTANCE, x);
         if(m_object_y[index] != y)
            ObjectSetInteger(0, object_name, OBJPROP_YDISTANCE, y);
         m_object_x[index] = x;
         m_object_y[index] = y;
         return;
        }
      ObjectSetInteger(0, object_name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, object_name, OBJPROP_YDISTANCE, y);
     }
   void SetObjectX(const string object_name, const int x)
     {
      const int index = FindRegisteredObject(object_name);
      if(index >= 0 && m_object_x[index] == x)
         return;
      ObjectSetInteger(0, object_name, OBJPROP_XDISTANCE, x);
      if(index >= 0)
         m_object_x[index] = x;
     }
   void SetObjectY(const string object_name, const int y)
     {
      const int index = FindRegisteredObject(object_name);
      if(index >= 0 && m_object_y[index] == y)
         return;
      ObjectSetInteger(0, object_name, OBJPROP_YDISTANCE, y);
      if(index >= 0)
         m_object_y[index] = y;
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
      RegisterObject(object_name, m_origin_x, m_origin_y);
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
      RegisterObject(object_name, m_origin_x + x, m_origin_y + y);
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
   bool CreateNumericInput(const string buttons, const string suffix, const string text,
                            const int x, const int y, const int width)
     {
      bool ok = CreateButton(buttons + "_DEC", "-", x, y, 26, 22);
      ok = CreateEdit(suffix, text, x + 30, y, width, 22) && ok;
      return CreateButton(buttons + "_INC", "+", x + width + 34, y, 26, 22) && ok;
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
      RefreshChartSize();
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
        {
         MovePanelTo(m_interaction_origin_x + x - m_interaction_start_x,
                     m_interaction_origin_y + y - m_interaction_start_y);
         m_force_redraw = true;
         Render();
        }
      else if(m_resizing)
         ResizePanelTo(m_interaction_width + x - m_interaction_start_x,
                       m_interaction_height + y - m_interaction_start_y);
     }
   void MovePanelTo(const int requested_x, const int requested_y)
     {
      if(m_chart_width <= 0 || m_chart_height <= 0)
         RefreshChartSize();
      int max_x = (int)m_chart_width - m_panel_width;
      int max_y = (int)m_chart_height - PanelHeight();
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
      if(m_chart_width <= 0 || m_chart_height <= 0)
         RefreshChartSize();
      const int available_width = MathMax(PM_MIN_PANEL_WIDTH,
                                          (int)m_chart_width - m_origin_x);
      const int maximum = MathMin(PM_MAX_PANEL_WIDTH, available_width);
      m_panel_width = MathMax(PM_MIN_PANEL_WIDTH,
                              MathMin(requested_width, maximum));
      const int available_height = MathMax(PM_TITLEBAR_HEIGHT,
                                           (int)m_chart_height - m_origin_y);
      m_user_panel_height = MathMax(PM_TITLEBAR_HEIGHT,
                                    MathMin(requested_height,
                                            available_height));
      ApplyPanelFrameLayout();
      m_positions_dirty = true;
      m_status_layout_dirty = true;
      m_force_redraw = true;
      Render();
     }
   void RefreshChartSize()
     {
      long chart_width = 0;
      long chart_height = 0;
      if(ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0, chart_width) &&
         chart_width > 0)
         m_chart_width = chart_width;
      if(ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0, chart_height) &&
         chart_height > 0)
         m_chart_height = chart_height;
     }
   void ShiftPanelObjects(const int delta_x, const int delta_y, const string exclude_name)
     {
      if(delta_x == 0 && delta_y == 0)
         return;
      for(int index = 0; index < ArraySize(m_object_names); index++)
        {
         const string object_name = m_object_names[index];
         if(object_name == exclude_name)
            continue;
         m_object_x[index] += delta_x;
         m_object_y[index] += delta_y;
         ObjectSetInteger(0, object_name, OBJPROP_XDISTANCE,
                          m_object_x[index]);
         ObjectSetInteger(0, object_name, OBJPROP_YDISTANCE,
                          m_object_y[index]);
        }
     }
   void ApplyPanelFrameLayout()
     {
      ObjectSetInteger(0, Name("BACKGROUND"), OBJPROP_XSIZE, m_panel_width);
      ObjectSetInteger(0, Name("BACKGROUND"), OBJPROP_YSIZE, PanelHeight());
      SetObjectX(Name("COLLAPSE"), m_origin_x + m_panel_width - 30);
      SetObjectPosition(Name("RESIZE_GRIP"),
                        m_origin_x + m_panel_width - 24,
                        m_origin_y + PanelHeight() - 18);
      ApplyStopsLayout();
     }
   int StopsClearX()
     {
      return PM_STOPS_SET_BUTTON_X + PM_STOPS_SET_BUTTON_WIDTH + PM_STOPS_BUTTON_GAP;
     }
   void SetStopsObjectPosition(const string suffix, const int x, const int y)
     {
      SetObjectPosition(Name(suffix), m_origin_x + x, m_origin_y + y);
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
