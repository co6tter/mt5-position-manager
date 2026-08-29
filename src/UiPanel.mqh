#ifndef __MT5_POSITION_MANAGER_UI_PANEL_MQH__
#define __MT5_POSITION_MANAGER_UI_PANEL_MQH__

#include <WinUser32.mqh>
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
   int m_max_rows;
   string m_status;
   datetime m_session_close;
   datetime m_auto_close_at;
   int m_page;
   bool m_row_render_error_reported;

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
      m_max_rows = PM_DEFAULT_MAX_ROWS;
      m_status = "Ready";
      m_session_close = 0;
      m_auto_close_at = 0;
      m_page = 0;
      m_row_render_error_reported = false;
     }

   bool Create(const int max_rows)
     {
      m_max_rows = MathMax(1, MathMin(max_rows, PM_MAX_POSITION_ROWS));
      ObjectsDeleteAll(0, PM_OBJECT_PREFIX);
      const int section_y = 95 + m_max_rows * 21;
      bool created = true;
      created = CreateBackground(section_y + 165) && created;
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

      created = CreateLabel("SL_LABEL", "Stop Loss", 12, section_y + 3, clrSilver, 9) && created;
      created = CreateButton("SL_MODE", "Price", 95, section_y, 85, 22) && created;
      created = CreateEdit("SL_VALUE", "", 185, section_y, 110, 22) && created;
      created = CreateButton("SET_SL", "Set / Change SL", 300, section_y, 135, 22) && created;
      created = CreateButton("CLEAR_SL", "Clear SL", 440, section_y, 90, 22) && created;

      created = CreateLabel("TP_LABEL", "Take Profit", 12, section_y + 36, clrSilver, 9) && created;
      created = CreateButton("TP_MODE", "Price", 95, section_y + 33, 85, 22) && created;
      created = CreateEdit("TP_VALUE", "", 185, section_y + 33, 110, 22) && created;
      created = CreateButton("SET_TP", "Set / Change TP", 300, section_y + 33, 135, 22) && created;
      created = CreateButton("CLEAR_TP", "Clear TP", 440, section_y + 33, 90, 22) && created;

      created = CreateLabel("AUTO_LABEL", "Auto Close", 12, section_y + 70, clrSilver, 9) && created;
      created = CreateButton("AUTO_ENABLED", "OFF", 95, section_y + 67, 65, 22) && created;
      created = CreateLabel("AUTO_SYMBOL_LABEL", "Symbol", 170, section_y + 70, clrSilver, 9) && created;
      created = CreateButton("AUTO_SYMBOL", "Symbol", 220, section_y + 67, 105, 22) && created;
      created = CreateButton("AUTO_DIRECTION", "Both", 330, section_y + 67, 85, 22) && created;
      created = CreateLabel("MINUTES_LABEL", "Minutes before", 425, section_y + 70, clrSilver, 9) && created;
      created = CreateEdit("AUTO_MINUTES", "10", 525, section_y + 67, 55, 22) && created;
      created = CreateButton("PASSED_BEHAVIOR", "Passed: Do Nothing", 590, section_y + 67, 155, 22) && created;
      created = CreateLabel("SESSION_LABEL", "Today's Close: -    Auto Close At: -", 12, section_y + 100, clrSilver, 9) && created;
      created = CreateLabel("STATUS_LABEL", "Status: Ready", 12, section_y + 126, clrWhite, 9) && created;
      ChartRedraw();
      if(!created)
         PrintFormat("[ERROR] UI panel creation failed. last_error=%d", GetLastError());
      return created;
     }

   void Destroy()
     {
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
      EnsureSymbolCandidate(m_filter_symbol);
      EnsureSymbolCandidate(m_auto_symbol);
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
      ObjectSetString(0, Name("SESSION_LABEL"), OBJPROP_TEXT,
                      "Today's Close: " + PMFormatDateTime(m_session_close) +
                      "    Auto Close At: " + PMFormatDateTime(m_auto_close_at));
      ObjectSetString(0, Name("STATUS_LABEL"), OBJPROP_TEXT, "Status: " + m_status);
      ObjectSetString(0, Name("PAGE_LABEL"), OBJPROP_TEXT,
                      StringFormat("Page %d/%d  Selected %d  Total %d",
                                   m_page + 1, PageCount(),
                                   ArraySize(m_selected), ArraySize(m_positions)));

      for(int row = 0; row < m_max_rows; row++)
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
            RowSuffix(row), text, 12, 90 + row * 21, 755, 19,
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

   bool HandleChartEvent(const long id,
                         const string object_name,
                         CPositionService &positions,
                         CTradeManager &trades,
                         CValidationService &validator,
                         CPositionActionService &actions)
     {
      if(id != CHARTEVENT_OBJECT_CLICK && id != CHARTEVENT_OBJECT_ENDEDIT)
         return false;
      if(id == CHARTEVENT_OBJECT_ENDEDIT && object_name == Name("AUTO_MINUTES"))
        {
         const int minutes = AutoCloseMinutes();
         ObjectSetString(0, Name("AUTO_MINUTES"), OBJPROP_TEXT,
                         IntegerToString(minutes));
         SetStatus(StringFormat("Auto Close minutes set to %d.", minutes));
         return true;
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
      PMBatchResult result = {};
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
      PMBatchResult result = {};
      trades.CloseTickets(m_selected, result);
      SetStatus(BatchResultText("Close", result));
     }

   string BatchResultText(const string operation, PMBatchResult &result)
     {
      string text = StringFormat("%s: %d succeeded, %d queued, %d failed / %d",
                                 operation, result.successful, result.queued,
                                 ArraySize(result.failures), result.requested);
      if(ArraySize(result.failures) > 0)
         text += StringFormat("; ticket=%I64u (%s)",
                              result.failures[0].ticket,
                              result.failures[0].description);
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
      PMBatchResult result = {};
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
      PMBatchResult result = {};
      actions.ClearStopTarget(m_selected, is_sl, positions, trades, result);
      SetStatus(BatchResultText(is_sl ? "SL clear" : "TP clear", result));
     }

   bool CreateBackground(const int height)
     {
      const string object_name = Name("BACKGROUND");
      if(!ObjectCreate(0, object_name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
         return false;
      ObjectSetInteger(0, object_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, object_name, OBJPROP_XDISTANCE, 0);
      ObjectSetInteger(0, object_name, OBJPROP_YDISTANCE, 0);
      ObjectSetInteger(0, object_name, OBJPROP_XSIZE, 780);
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
      ObjectSetInteger(0, object_name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, object_name, OBJPROP_YDISTANCE, y);
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
