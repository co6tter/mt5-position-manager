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
   bool worst_first;
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

// Keep files local to this terminal. Hash only the server name so the filename
// stays valid even when a broker uses punctuation in its name.
long PMPanelSettingsServerHash(const string account_server)
  {
   long server_hash = 0;
   for(int i = 0; i < StringLen(account_server); i++)
      server_hash = (server_hash * 131 + StringGetCharacter(account_server, i)) % 2147483647;
   return server_hash;
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
      m_file_name = StringFormat("MT5PositionManager\\settings_%I64d_%I64d_%I64d.csv",
                                 chart_id, account_login, PMPanelSettingsServerHash(account_server));
     }

   bool Save(const PMPanelSettings &settings)
     {
      if(m_file_name == "") return false;
      const string temporary = m_file_name + ".tmp";
      const int file = FileOpen(temporary, FILE_WRITE | FILE_CSV | FILE_UNICODE, '\t');
      if(file == INVALID_HANDLE) return false;
      // Version 2 appends Worst First after the server; version 1 files still load.
      const uint written = FileWrite(file, "2",
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
                                     settings.trail_pips, m_account_server,
                                     (int)settings.worst_first);
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
      string worst_first_field = "0";
      if(fields[0] == "2")
        {
         if(FileIsEnding(file)) { FileClose(file); return false; }
         worst_first_field = FileReadString(file);
        }
      FileClose(file);
      if((fields[0] != "1" && fields[0] != "2") || fields[2] == "" || fields[10] == "" ||
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
      if(!PMPanelSettingInteger(worst_first_field, 0, 1, n)) return false;
      loaded.worst_first = n == 1;
      settings = loaded;
      return true;
     }
  };

// Auto SL is saved per account and symbol, not per chart: a pips distance only
// means something for one symbol, and every chart of that symbol shares it.
// enabled_at is the trade server time of the last OFF->ON switch: positions
// opened from then on are the ones Auto SL may protect.
struct PMAutoSlSetting
  {
   string symbol;
   bool enabled;
   string pips;
   datetime enabled_at;
  };

bool PMAutoSlPipsText(const string text, string &normalized)
  {
   double value = 0.0;
   if(!PMPanelSettingDecimal(text, value) || value > PM_MAX_TRAILING_POINTS) return false;
   // 0.1 pip is the finest step any field shows; "100.0" is stored as "100".
   normalized = DoubleToString(value, 1);
   if(StringSubstr(normalized, StringLen(normalized) - 2) == ".0")
      normalized = StringSubstr(normalized, 0, StringLen(normalized) - 2);
   return true;
  }

// Seconds since 1970 as plain digits; FileWrite would format a datetime as a date.
bool PMAutoSlEnabledAtText(const string text, datetime &value)
  {
   if(text == "" || StringLen(text) > 18) return false;
   for(int i = 0; i < StringLen(text); i++)
      if(StringGetCharacter(text, i) < '0' || StringGetCharacter(text, i) > '9') return false;
   const long parsed = StringToInteger(text);
   if(IntegerToString(parsed) != text) return false;
   value = (datetime)parsed;
   return true;
  }

class CAutoSlStore
  {
private:
   string m_file_name;
   string m_account_server;

   // A file that fails validation reads as empty: no symbol inherits a guessed value.
   // Version 1 records have no ON time; they load with enabled_at 0 ("unknown").
   bool ReadAll(PMAutoSlSetting &records[])
     {
      ArrayResize(records, 0);
      if(m_file_name == "") return false;
      const int file = FileOpen(m_file_name, FILE_READ | FILE_SHARE_READ | FILE_CSV | FILE_UNICODE, '\t');
      if(file == INVALID_HANDLE) return false;
      const string version = FileIsEnding(file) ? "" : FileReadString(file);
      const int field_count = version == "2" ? 4 : 3;
      bool ok = (version == "1" || version == "2") &&
                !FileIsEnding(file) && FileReadString(file) == m_account_server;
      while(ok && !FileIsEnding(file))
        {
         PMAutoSlSetting record = {};
         string fields[4];
         fields[3] = "0";
         for(int i = 0; i < field_count && ok; i++)
           {
            if(FileIsEnding(file)) ok = false;
            else fields[i] = FileReadString(file);
           }
         int enabled = 0;
         ok = ok && fields[0] != "" && PMPanelSettingInteger(fields[1], 0, 1, enabled) &&
              PMAutoSlPipsText(fields[2], record.pips) &&
              PMAutoSlEnabledAtText(fields[3], record.enabled_at);
         if(!ok) break;
         record.symbol = fields[0];
         record.enabled = enabled == 1;
         const int size = ArraySize(records);
         ArrayResize(records, size + 1);
         records[size] = record;
        }
      FileClose(file);
      if(!ok) ArrayResize(records, 0);
      return ok;
     }

public:
   void Configure(const long account_login, const string account_server)
     {
      m_file_name = "";
      m_account_server = "";
      if(account_login <= 0 || account_server == "") return;
      m_account_server = account_server;
      m_file_name = StringFormat("MT5PositionManager\\autosl_%I64d_%I64d.csv",
                                 account_login, PMPanelSettingsServerHash(account_server));
     }

   bool Load(const string symbol, bool &enabled, string &pips, datetime &enabled_at)
     {
      PMAutoSlSetting records[];
      if(!ReadAll(records)) return false;
      for(int i = 0; i < ArraySize(records); i++)
         if(records[i].symbol == symbol)
           {
            enabled = records[i].enabled;
            pips = records[i].pips;
            enabled_at = records[i].enabled_at;
            return true;
           }
      return false;
     }

   // Re-read before writing so another chart's symbol saved meanwhile survives.
   bool Save(const string symbol, const bool enabled, const string pips, const datetime enabled_at)
     {
      string normalized = "";
      if(m_file_name == "" || symbol == "" || enabled_at < 0 ||
         !PMAutoSlPipsText(pips, normalized)) return false;
      PMAutoSlSetting records[];
      ReadAll(records);
      const string temporary = m_file_name + ".tmp";
      const int file = FileOpen(temporary, FILE_WRITE | FILE_CSV | FILE_UNICODE, '\t');
      if(file == INVALID_HANDLE) return false;
      bool written = FileWrite(file, "2", m_account_server) > 0;
      for(int i = 0; i < ArraySize(records) && written; i++)
         if(records[i].symbol != symbol)
            written = FileWrite(file, records[i].symbol, (int)records[i].enabled, records[i].pips,
                                IntegerToString((long)records[i].enabled_at)) > 0;
      written = written && FileWrite(file, symbol, (int)enabled, normalized,
                                     IntegerToString((long)enabled_at)) > 0;
      FileFlush(file);
      FileClose(file);
      return written && FileMove(temporary, 0, m_file_name, FILE_REWRITE);
     }
  };

#endif
