#ifndef __MT5_POSITION_MANAGER_EQUITY_GUARD_SERVICE_MQH__
#define __MT5_POSITION_MANAGER_EQUITY_GUARD_SERVICE_MQH__

#include "Models.mqh"
#include "Constants.mqh"
#include "PositionService.mqh"
#include "TradeManager.mqh"

bool PMEvaluateEquityGuard(const double total_profit,
                           const EquityGuardConfig &config,
                           const double balance,
                           bool &loss_triggered,
                           bool &profit_triggered)
  {
   loss_triggered = false;
   profit_triggered = false;
   if(!config.enabled)
      return false;

   if(config.loss_threshold > 0.0)
     {
      const double loss_amount = config.mode == PM_EQUITY_THRESHOLD_PERCENT ?
                                 balance * config.loss_threshold / 100.0 :
                                 config.loss_threshold;
      if(loss_amount > 0.0 && total_profit <= -loss_amount)
         loss_triggered = true;
     }

   if(config.profit_threshold > 0.0)
     {
      const double profit_amount = config.mode == PM_EQUITY_THRESHOLD_PERCENT ?
                                   balance * config.profit_threshold / 100.0 :
                                   config.profit_threshold;
      if(profit_amount > 0.0 && total_profit >= profit_amount)
         profit_triggered = true;
     }

   return loss_triggered || profit_triggered;
  }

bool PMShouldFireEquityGuard(const bool should_trigger, bool &triggered)
  {
   if(!should_trigger)
     {
      triggered = false;
      return false;
     }
   if(triggered)
      return false;
   triggered = true;
   return true;
  }

class CEquityGuardService
  {
private:
   bool m_triggered;
   string m_config_key;

public:
   CEquityGuardService()
     {
      m_triggered = false;
      m_config_key = "";
     }

   bool Evaluate(const EquityGuardConfig &config,
                 CPositionService &positions,
                 CTradeManager &trades,
                 string &status)
     {
      status = "";
      const string key = ConfigKey(config);
      if(key != m_config_key)
        {
         m_config_key = key;
         m_triggered = false;
        }
      if(!config.enabled)
         return false;

      PMPosition all_positions[];
      positions.Collect(all_positions);
      double total_profit = 0.0;
      for(int i = 0; i < ArraySize(all_positions); i++)
         total_profit += all_positions[i].profit;

      const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      bool loss_triggered = false;
      bool profit_triggered = false;
      const bool should_trigger = PMEvaluateEquityGuard(total_profit, config, balance,
                                                        loss_triggered, profit_triggered);

      if(!PMShouldFireEquityGuard(should_trigger, m_triggered))
         return false;

      const string side = loss_triggered ? "loss" : "profit";
      ulong tickets[];
      positions.CollectTickets("", PM_DIRECTION_BOTH, tickets);
      if(ArraySize(tickets) == 0)
        {
         status = StringFormat("Equity Guard: %s threshold reached (%.2f) but no positions to close.",
                               side, total_profit);
         PrintFormat("[WARN] Equity Guard %s threshold reached (%.2f) with no open positions.",
                     side, total_profit);
         return true;
        }

      PMBatchResult result;
      trades.CloseTickets(tickets, result);
      status = StringFormat("Equity Guard: %s threshold reached (%.2f). Closing all positions: %d closed, %d queued, %d failed / %d",
                            side, total_profit, result.successful, result.queued,
                            ArraySize(result.failures), result.requested);
      PrintFormat("[WARN] Equity Guard triggered by %s threshold. total_profit=%.2f closed=%d queued=%d failed=%d requested=%d",
                  side, total_profit, result.successful, result.queued,
                  ArraySize(result.failures), result.requested);
      return true;
     }

private:
   string ConfigKey(const EquityGuardConfig &config)
     {
      return StringFormat("%d|%d|%.2f|%.2f", config.enabled ? 1 : 0,
                          (int)config.mode, config.loss_threshold, config.profit_threshold);
     }
  };

#endif
