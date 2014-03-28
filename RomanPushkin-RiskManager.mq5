//+------------------------------------------------------------------+
//|                                     RomanPushkin-RiskManager.mq5 |
//|                                    Copyright 2013, Roman Pushkin |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2013, Roman Pushkin"
#property link      "http://www.mql5.com"
#property version   "1.00"

input int __SecondsWait = 3; //  оличество секунд, после которых устанавливать стоп от текущей цены, если он не установлен
input int __StopSize = 150; // —топ в пунктах от текущей цены
input int __Deviation = 700; // ѕроскальзывание (Deviation)

enum StrategyState { STATE_LOOK_FOR_POSITION, STATE_WAIT_FOR_STOP, STATE_SET_STOP };

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

int OnInit()
{
   EventSetTimer(1);
   Print("OK ѕровер€ем каждые " + __SecondsWait + ", при необходимости устанавливаем стоп в " + __StopSize + " пунктов");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+

void OnDeinit(const int reason)
{
   EventKillTimer();      
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+

void OnTick()
{   
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+

StrategyState state = STATE_LOOK_FOR_POSITION;

void OnTimer()
{
   if(state == STATE_LOOK_FOR_POSITION)
   {
      LookForPosition();
   }
   
   if(state == STATE_WAIT_FOR_STOP)
   {
      WaitForStop();
   }
   
   if(state == STATE_SET_STOP)
   {
      SetStop();
   }   
}
  
//+------------------------------------------------------------------+
//| Look for position                                                |
//+------------------------------------------------------------------+

void LookForPosition()
{
   if(PositionsTotal() > 0 && PositionSelect(_Symbol))
   {
      double stopLoss = PositionGetDouble(POSITION_SL);
      
      if(stopLoss == 0)
      {
         secondsLeft = __SecondsWait;
         state = STATE_WAIT_FOR_STOP;
      }
   }  
}

//+------------------------------------------------------------------+
//| Wait for stop                                                    |
//+------------------------------------------------------------------+

int secondsLeft = __SecondsWait;

void WaitForStop()
{

   if(secondsLeft <= 0)
   {
      state = STATE_SET_STOP;
      Print("WARN Ќайдена позици€ без стопа, устанавливаем стоп");
      return;
   }
   
   if(PositionsTotal() > 0 && PositionSelect(_Symbol))
   {
      double stopLoss = PositionGetDouble(POSITION_SL);
      
      if(stopLoss == 0)
      {
         secondsLeft--;   
      }
      else
      {
         state = STATE_LOOK_FOR_POSITION;
         return;
      }
   }
   else
   {
      state = STATE_LOOK_FOR_POSITION;
   }
}

//+------------------------------------------------------------------+
//| Set stop                                                         |
//+------------------------------------------------------------------+

void SetStop()
{
   if(PositionsTotal() > 0 && PositionSelect(_Symbol))
   {
      double stopLoss = PositionGetDouble(POSITION_SL);

      if(stopLoss == 0)
      {
         double takeProfit = PositionGetDouble(POSITION_TP);
         double newStopLoss = GetNewStopLoss();
         UpdatePositionStopTakeProfit(newStopLoss, takeProfit);
      }
   }
   
   state = STATE_LOOK_FOR_POSITION;
}

bool UpdatePositionStopTakeProfit(double stopPrice, double takeProfit)
{
   // подготовим структуры дл€ хранени€ данных
   
   MqlTradeRequest request;
   ZeroMemory(request);
   
   MqlTradeResult result;
   ZeroMemory(result);

   MqlTradeCheckResult checkResult;
   ZeroMemory(checkResult);   
   
   // инициализируем запрос
   
   request.action = TRADE_ACTION_SLTP;
   request.symbol = _Symbol;
   request.sl = stopPrice;
   request.deviation = __Deviation; // проскальзывание
   request.tp = takeProfit;
   
   Print("ќ  пробуем установить стоп ордер по цене " + stopPrice);
   
   if(OrderCheck(request, checkResult))
   {
      if(OrderSend(request, result))
      {
         Print("OK стоп ордер установлен по цене " + stopPrice);
         return true;
      }
      else
      {
         Print(
            "ERR ќшибка установки стоп-ордера, комментарий: " + result.comment +
            ", код ошибки: " + GetLastError() + 
            ", retcode: " + result.retcode
            );
      }
   }
   else
   {
      Print(
         "ERR ќшибка проверки на установку стоп-ордера, комментарий: " + checkResult.comment +
         ", код ошибки: " + GetLastError() +
         ", retcode: " + checkResult.retcode
         );
   }
   
   return false;
}


double GetNewStopLoss()
{
   double newStopLoss = 0;

   int positionType = PositionGetInteger(POSITION_TYPE);
     
   if(positionType == POSITION_TYPE_BUY)
   {
      newStopLoss = NormalizeByTickSize(SymbolInfoDouble(_Symbol, SYMBOL_BID) - __StopSize);
   }
   
   if(positionType == POSITION_TYPE_SELL)
   {
      newStopLoss = NormalizeByTickSize(SymbolInfoDouble(_Symbol, SYMBOL_ASK) + __StopSize);
   }
    
   return newStopLoss;
}

//+------------------------------------------------------------------+
//| Helper functions                                                 |
//+------------------------------------------------------------------+

double NormalizeByTickSize(double value)
{
   double result = 0;

   // убираем дробную часть   
   result = NormalizeDouble(value, _Digits);

   // получаем размер тика дл€ инструмента
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   // убираем остаток от делени€ на размер тика
   result = result - fmod(result, tickSize);
   
   return result;
}
