//+------------------------------------------------------------------+
//|                                                    myFirstEA.mq4 |
//|                        Copyright 2021, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

input double lotsize = 0.01;
input int stoploss = 50;
input int takeprofit = 80;
input int slippage = 2;

input int ma_period = 14;
input int ma_shift = 0;
input int ma_method = MODE_SMA;
input int applied_price = 0;
input int shift = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
      //---
      Comment("\n\nHello World");
      int signal = 0;  // -1 = sell, 1 = buy, 0 = no action
      double close_price = iClose(NULL, 0, shift);
      double ma = iMA(NULL, 0, ma_period, ma_shift, ma_method, applied_price, shift);
      
      if (close_price > ma)
         signal = 1;  // buy
      else if (close_price < ma)
         signal = -1;  // sell
      
      // Only place an order if there is no open trade
      if (OrdersTotal() == 0)
      {  
         if (signal == 1)
            OrderSend(NULL, OP_BUY, lotsize, Ask, slippage, Ask-stoploss*Point, Ask+takeprofit*Point);
         else if (signal == -1)
            OrderSend(NULL, OP_SELL, lotsize, Bid, slippage, Bid+stoploss*Point, Bid-takeprofit*Point);
               
      }
  }
//+------------------------------------------------------------------+
