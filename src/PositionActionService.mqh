#ifndef __MT5_POSITION_MANAGER_POSITION_ACTION_SERVICE_MQH__
#define __MT5_POSITION_MANAGER_POSITION_ACTION_SERVICE_MQH__

#include "Models.mqh"
#include "Constants.mqh"
#include "PositionService.mqh"
#include "TradeManager.mqh"
#include "ValidationService.mqh"

class CPositionActionService
  {
public:
   bool ApplyStopTarget(const ulong &tickets[],
                        const bool is_sl,
                        const PMPriceMode mode,
                        const double value,
                        CPositionService &positions,
                        CTradeManager &trades,
                        CValidationService &validator,
                        PMBatchResult &result,
                        string &validation_error)
     {
      PMResetBatchResult(result, ArraySize(tickets));
      validation_error = "";
      double targets[];
      ArrayResize(targets, ArraySize(tickets));

      for(int i = 0; i < ArraySize(tickets); i++)
        {
         PMPosition position = {};
         if(!positions.Get(tickets[i], position))
           {
            validation_error = StringFormat("Ticket %I64u no longer exists.", tickets[i]);
            PMAddFailure(result, tickets[i], 0, validation_error, 0);
            PrintFormat("[ERROR] Position validation failed ticket=%I64u description=%s",
                        tickets[i], validation_error);
            return false;
           }
         string reason = "";
         if(!validator.CalculateTarget(position, is_sl, mode, value,
                                       targets[i], reason))
           {
            validation_error = StringFormat("Ticket %I64u rejected: %s",
                                            tickets[i], reason);
            PMAddFailure(result, tickets[i], 0, reason, 0);
            PrintFormat("[ERROR] Position validation failed ticket=%I64u description=%s",
                        tickets[i], reason);
            return false;
           }
        }

      for(int i = 0; i < ArraySize(tickets); i++)
        {
         PMPosition position = {};
         if(!positions.Get(tickets[i], position))
           {
            PMAddFailure(result, tickets[i], 0,
                         "Position disappeared after validation.", 0);
            PrintFormat("[ERROR] Position modification failed ticket=%I64u retcode=0 description=%s",
                        tickets[i], "Position disappeared after validation.");
            continue;
           }
         const double sl = is_sl ? targets[i] : position.sl;
         const double tp = is_sl ? position.tp : targets[i];
         PMTradeFailure failure = {};
         RecordOutcome(trades.ModifyTicket(tickets[i], sl, tp, failure),
                       failure, result);
        }
      return true;
     }

   void ClearStopTarget(const ulong &tickets[],
                        const bool is_sl,
                        CPositionService &positions,
                        CTradeManager &trades,
                        PMBatchResult &result)
     {
      PMResetBatchResult(result, ArraySize(tickets));
      for(int i = 0; i < ArraySize(tickets); i++)
        {
         PMPosition position = {};
         if(!positions.Get(tickets[i], position))
           {
            PMAddFailure(result, tickets[i], 0,
                         "Position no longer exists.", 0);
            PrintFormat("[ERROR] Position modification failed ticket=%I64u retcode=0 description=%s",
                        tickets[i], "Position no longer exists.");
            continue;
           }
         const double sl = is_sl ? 0.0 : position.sl;
         const double tp = is_sl ? position.tp : 0.0;
         PMTradeFailure failure = {};
         RecordOutcome(trades.ModifyTicket(tickets[i], sl, tp, failure),
                       failure, result);
        }
     }

private:
   void RecordOutcome(const PMTradeAttemptStatus status,
                      PMTradeFailure &failure,
                      PMBatchResult &result)
     {
      if(status == PM_TRADE_ATTEMPT_SUCCESS)
         result.successful++;
      else if(status == PM_TRADE_ATTEMPT_UNCHANGED)
         result.unchanged++;
      else if(status == PM_TRADE_ATTEMPT_QUEUED)
         result.queued++;
      else
        {
         PMAddFailure(result, failure.ticket, failure.retcode,
                      failure.description, failure.attempts);
         PrintFormat("[ERROR] Position modification failed ticket=%I64u retcode=%u description=%s attempts=%d",
                     failure.ticket, failure.retcode,
                     failure.description, failure.attempts);
        }
     }
  };

#endif
