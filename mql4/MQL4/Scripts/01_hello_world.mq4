//+------------------------------------------------------------------+
//|                                                  hello_world.mq4 |
//|                        Copyright 2021, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
//#property show_inputs


//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//---
   Print("----- print hello world");
   Print("----- " + TimeHour(TimeCurrent()));
   Print("----- " + TimeMinute(TimeCurrent()));
   //Comment("----- comment hello world");
   //Print(MarketInfo(NULL,MODE_TIME));
  }
//+------------------------------------------------------------------+
