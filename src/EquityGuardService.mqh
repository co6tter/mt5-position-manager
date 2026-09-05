#ifndef __MT5_POSITION_MANAGER_EQUITY_GUARD_SERVICE_MQH__
#define __MT5_POSITION_MANAGER_EQUITY_GUARD_SERVICE_MQH__

#include "Models.mqh"
#include "Constants.mqh"
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
      if(config.mode == PM_EQUITY_THRESHOLD_PERCENT && balance <= 0.0)
        {
         // A percentage of a zero/negative balance can't express a meaningful loss
         // limit. Fail safe rather than silently disabling the guard exactly when
         // the account is in its worst state: any floating loss triggers.
         if(total_profit < 0.0)
            loss_triggered = true;
        }
      else
        {
         const double loss_amount = config.mode == PM_EQUITY_THRESHOLD_PERCENT ?
                                    balance * config.loss_threshold / 100.0 :
                                    config.loss_threshold;
         if(loss_amount > 0.0 && total_profit <= -loss_amount)
            loss_triggered = true;
        }
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
                 const PMPosition &all_positions[],
                 CTradeManager &trades,
                 string &status)
     {
      status = "";
      const string key = PMEquityGuardConfigKey(config);
      if(key != m_config_key)
        {
         m_config_key = key;
         m_triggered = false;
        }
      if(!config.enabled)
         return false;

      double total_profit = 0.0;
      for(int i = 0; i < ArraySize(all_positions); i++)
         total_profit += all_positions[i].profit;

      const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      bool loss_triggered = false;
      bool profit_triggered = false;
      const bool should_trigger = PMEvaluateEquityGuard(total_profit, config, balance,
                                                        loss_triggered, profit_triggered);

      // Keep the latch clear while there are no positions so a later crossing
      // can trigger a fresh close request.
      if(ArraySize(all_positions) == 0)
        {
         m_triggered = false;
         if(!should_trigger)
            return false;
         const string empty_side = loss_triggered ? "loss" : "profit";
         status = StringFormat("Equity Guard: %s threshold reached (%.2f) but no positions to close.",
                               empty_side, total_profit);
         PrintFormat("[WARN] Equity Guard %s threshold reached (%.2f) with no open positions.",
                     empty_side, total_profit);
         return true;
        }

      // A previous close attempt may have failed permanently and left a
      // terminal close marker. Re-arm the edge trigger so the guard can retry
      // while the threshold remains breached.
      if(should_trigger && m_triggered && trades.HasFailedClose())
         m_triggered = false;
      if(!PMShouldFireEquityGuard(should_trigger, m_triggered))
         return false;

      const string side = loss_triggered ? "loss" : "profit";
      ulong tickets[];
      ArrayResize(tickets, ArraySize(all_positions));
      for(int i = 0; i < ArraySize(all_positions); i++)
         tickets[i] = all_positions[i].ticket;

      PMBatchResult result;
      trades.CloseTickets(tickets, result);
      status = StringFormat("Equity Guard: %s threshold reached (%.2f). Closing all positions: %d closed, %d queued, %d failed / %d",
                            side, total_profit, result.successful, result.queued,
                            ArraySize(result.failures), result.requested);
      PrintFormat("[WARN] Equity Guard triggered by %s threshold. total_profit=%.2f closed=%d queued=%d failed=%d requested=%d",
                  side, total_profit, result.successful, result.queued,
                  ArraySize(result.failures), result.requested);
      if(ArraySize(result.failures) > 0)
         m_triggered = false;
      return true;
     }

  };

#endif
