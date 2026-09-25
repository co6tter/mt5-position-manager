#ifndef __MT5_POSITION_MANAGER_PANEL_SETTINGS_MQH__
#define __MT5_POSITION_MANAGER_PANEL_SETTINGS_MQH__

#include "Models.mqh"
#include "Constants.mqh"

struct PMPanelSettings
  {
   bool auto_enabled;
   string auto_symbol;
   PMDirection auto_direction;
   int auto_minutes;
   PMPassedCloseBehavior passed_behavior;
   bool equity_guard_enabled;
   PMEquityThresholdMode equity_guard_mode;
   double equity_guard_loss_threshold;
   double equity_guard_profit_threshold;
   string trailing_symbol;
   PMDirection trailing_direction;
   PMTrailBasis trail_basis;
   bool break_even_enabled;
   bool trailing_enabled;
   int be_trigger_pips;
   int be_lock_pips;
   int trail_trigger_pips;
   int trail_pips;
  };

bool PMPanelSettingInteger(const string text, const int minimum, const int maximum, int &value)
  {
   if(text == "") return false;
   for(int i = 0; i < StringLen(text); i++)
      if(StringGetCharacter(text, i) < '0' || StringGetCharacter(text, i) > '9') return false;
   const long parsed = StringToInteger(text);
   if(parsed < minimum || parsed > maximum || IntegerToString(parsed) != text) return false;
   value = (int)parsed;
   return true;
  }

bool PMPanelSettingDecimal(const string text, double &value)
  {
   if(text == "") return false;
   bool point = false;
   bool digit = false;
   for(int i = 0; i < StringLen(text); i++)
     {
      const int c = StringGetCharacter(text, i);
      if(c == '.' && !point) { point = true; continue; }
      if(c < '0' || c > '9') return false;
      digit = true;
     }
   if(!digit) return false;
   const double parsed = StringToDouble(text);
   if(!MathIsValidNumber(parsed) || parsed < 0.0 || parsed > PM_MAX_EQUITY_THRESHOLD)
      return false;
   value = parsed;
   return true;
  }

class CPanelSettingsStore
  {
private:
   string m_file_name;
   string m_account_server;

public:
   void Configure(const long chart_id, const long account_login, const string account_server)
     {
      m_file_name = "";
      m_account_server = "";
      if(chart_id <= 0 || account_login <= 0 || account_server == "") return;
      m_account_server = account_server;
      // Keep the file local to this terminal. Hash only the server name so the
      // filename stays valid even when a broker uses punctuation in its name.
      long server_hash = 0;
      for(int i = 0; i < StringLen(account_server); i++)
         server_hash = (server_hash * 131 + StringGetCharacter(account_server, i)) % 2147483647;
      m_file_name = StringFormat("MT5PositionManager\\settings_%I64d_%I64d_%I64d.csv",
                                 chart_id, account_login, server_hash);
     }

   bool Save(const PMPanelSettings &settings)
     {
      if(m_file_name == "") return false;
      const string temporary = m_file_name + ".tmp";
      const int file = FileOpen(temporary, FILE_WRITE | FILE_CSV | FILE_UNICODE, '\t');
      if(file == INVALID_HANDLE) return false;
      const uint written = FileWrite(file, "1",
                                     (int)settings.auto_enabled, settings.auto_symbol,
                                     (int)settings.auto_direction, settings.auto_minutes,
                                     (int)settings.passed_behavior,
                                     (int)settings.equity_guard_enabled,
                                     (int)settings.equity_guard_mode,
                                     DoubleToString(settings.equity_guard_loss_threshold, 2),
                                     DoubleToString(settings.equity_guard_profit_threshold, 2),
                                     settings.trailing_symbol, (int)settings.trailing_direction,
                                     (int)settings.trail_basis, (int)settings.break_even_enabled,
                                     (int)settings.trailing_enabled, settings.be_trigger_pips,
                                     settings.be_lock_pips, settings.trail_trigger_pips,
                                     settings.trail_pips, m_account_server);
      FileFlush(file);
      FileClose(file);
      return written > 0 && FileMove(temporary, 0, m_file_name, FILE_REWRITE);
     }

   bool Load(PMPanelSettings &settings)
     {
      if(m_file_name == "") return false;
      const int file = FileOpen(m_file_name, FILE_READ | FILE_CSV | FILE_UNICODE, '\t');
      if(file == INVALID_HANDLE) return false;
      string fields[20];
      for(int i = 0; i < 20; i++)
        {
         if(FileIsEnding(file)) { FileClose(file); return false; }
         fields[i] = FileReadString(file);
        }
      FileClose(file);
      if(fields[0] != "1" || fields[2] == "" || fields[10] == "" ||
         fields[19] != m_account_server) return false;
      PMPanelSettings loaded = {};
      int n = 0;
      if(!PMPanelSettingInteger(fields[1], 0, 1, n)) return false;
      loaded.auto_enabled = n == 1;
      loaded.auto_symbol = fields[2];
      if(!PMPanelSettingInteger(fields[3], 0, 2, n)) return false;
      loaded.auto_direction = (PMDirection)n;
      if(!PMPanelSettingInteger(fields[4], 0, PM_MAX_AUTO_CLOSE_MINUTES, loaded.auto_minutes)) return false;
      if(!PMPanelSettingInteger(fields[5], 0, 1, n)) return false;
      loaded.passed_behavior = (PMPassedCloseBehavior)n;
      if(!PMPanelSettingInteger(fields[6], 0, 1, n)) return false;
      loaded.equity_guard_enabled = n == 1;
      if(!PMPanelSettingInteger(fields[7], 0, 1, n)) return false;
      loaded.equity_guard_mode = (PMEquityThresholdMode)n;
      if(!PMPanelSettingDecimal(fields[8], loaded.equity_guard_loss_threshold) ||
         !PMPanelSettingDecimal(fields[9], loaded.equity_guard_profit_threshold)) return false;
      loaded.trailing_symbol = fields[10];
      if(!PMPanelSettingInteger(fields[11], 0, 2, n)) return false;
      loaded.trailing_direction = (PMDirection)n;
      if(!PMPanelSettingInteger(fields[12], 0, 1, n)) return false;
      loaded.trail_basis = (PMTrailBasis)n;
      if(!PMPanelSettingInteger(fields[13], 0, 1, n)) return false;
      loaded.break_even_enabled = n == 1;
      if(!PMPanelSettingInteger(fields[14], 0, 1, n)) return false;
      loaded.trailing_enabled = n == 1;
      if(!PMPanelSettingInteger(fields[15], 0, PM_MAX_TRAILING_POINTS, loaded.be_trigger_pips) ||
         !PMPanelSettingInteger(fields[16], 0, PM_MAX_TRAILING_POINTS, loaded.be_lock_pips) ||
         !PMPanelSettingInteger(fields[17], 0, PM_MAX_TRAILING_POINTS, loaded.trail_trigger_pips) ||
         !PMPanelSettingInteger(fields[18], 0, PM_MAX_TRAILING_POINTS, loaded.trail_pips)) return false;
      settings = loaded;
      return true;
     }
  };

#endif
