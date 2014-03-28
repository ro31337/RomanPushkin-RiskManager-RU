//+------------------------------------------------------------------+
//|                                     RomanPushkin-RiskManager.mq5 |
//|                                    Copyright 2013, Roman Pushkin |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2013, Roman Pushkin"
#property link      "http://www.mql5.com"
#property version   "1.00"

input int __SecondsWait = 3; // ���������� ������, ����� ������� ������������� ���� �� ������� ����, ���� �� �� ����������
input int __StopSize = 150; // ���� � ������� �� ������� ����
input int __Deviation = 700; // ��������������� (Deviation)

enum StrategyState { STATE_LOOK_FOR_POSITION, STATE_WAIT_FOR_STOP, STATE_SET_STOP };

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

int OnInit()
{
   EventSetTimer(1);
   Print("OK ��������� ������ " + __SecondsWait + ", ��� ������������� ������������� ���� � " + __StopSize + " �������");

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
      Print("WARN ������� ������� ��� �����, ������������� ����");
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
   // ���������� ��������� ��� �������� ������
   
   MqlTradeRequest request;
   ZeroMemory(request);
   
   MqlTradeResult result;
   ZeroMemory(result);

   MqlTradeCheckResult checkResult;
   ZeroMemory(checkResult);   
   
   // �������������� ������
   
   request.action = TRADE_ACTION_SLTP;
   request.symbol = _Symbol;
   request.sl = stopPrice;
   request.deviation = __Deviation; // ���������������
   request.tp = takeProfit;
   
   Print("�� ������� ���������� ���� ����� �� ���� " + stopPrice);
   
   if(OrderCheck(request, checkResult))
   {
      if(OrderSend(request, result))
      {
         Print("OK ���� ����� ���������� �� ���� " + stopPrice);
         return true;
      }
      else
      {
         Print(
            "ERR ������ ��������� ����-������, �����������: " + result.comment +
            ", ��� ������: " + GetLastError() + 
            ", retcode: " + result.retcode
            );
      }
   }
   else
   {
      Print(
         "ERR ������ �������� �� ��������� ����-������, �����������: " + checkResult.comment +
         ", ��� ������: " + GetLastError() +
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

   // ������� ������� �����   
   result = NormalizeDouble(value, _Digits);

   // �������� ������ ���� ��� �����������
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   // ������� ������� �� ������� �� ������ ����
   result = result - fmod(result, tickSize);
   
   return result;
}
