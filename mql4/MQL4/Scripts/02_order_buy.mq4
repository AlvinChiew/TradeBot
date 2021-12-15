#property copyright "Copyright 2016, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property show_inputs

input string symbol = NULL;
input double lotsize = 1.0;
input int max_slippage = 5;
input int stoploss = 500;
input int takeprofit = 500;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//---x`
   entry(symbol,OP_BUY,lotsize,0,max_slippage,stoploss,takeprofit);
  }
//+------------------------------------------------------------------+


int send_order(string ins,int cmd,double volume,int distance,int slippage,int sl, int tp, string comment=NULL,int magic=0,int expire=0,color a_clr=clrNONE)
{
 double price = 0;
 double price_sl = 0;
 double price_tp = 0;
 double point = MarketInfo(ins,MODE_POINT);
 datetime expiry = 0;
 int order_type = -1;
 
 RefreshRates();
 if (cmd==OP_BUY)
 {
   if (distance>0) order_type = OP_BUYSTOP;
   else if (distance<0) order_type = OP_BUYLIMIT;
   else order_type=OP_BUY;
   if (order_type==OP_BUY) distance=0;
   price = MarketInfo(ins,MODE_ASK)+distance*point;
   if (sl>0) price_sl = price-sl*point;
   if (tp>0) price_tp = price+tp*point;
 }
 else if (cmd==OP_SELL)
 {
   if (distance>0) order_type = OP_SELLLIMIT;
   else if (distance<0) order_type = OP_SELLSTOP;
   else order_type=OP_SELL;
   if (order_type==OP_SELL) distance=0;
   price = MarketInfo(ins,MODE_BID)+distance*point;
   if (sl>0) price_sl = price+sl*point;
   if (tp>0) price_tp = price-tp*point;
 }
 
 if (order_type<0) return 0;
 else  if (order_type==0 || order_type==1) expiry=0;
 else if (expire>0)
    expiry = MarketInfo(ins,MODE_TIME)+expire; 
 return OrderSend(NULL,order_type,volume,price,slippage,price_sl,price_tp,comment,magic,expiry,a_clr);
}


int entry(string ins,int cmd,double volume,int distance,int slippage,int sl,int tp,string comment=NULL,int magic=0,int expire=0,color a_clr=clrNONE,int retries=3,int sleep=500)
  {
   int ticket=0;
   for(int i=0;i<retries;i++)
     {
      if (IsStopped())                 Print("Expert was stopped");
      else if (!IsConnected())         Print("No internet connection");
      else if (!IsExpertEnabled())     Print("Experts not enabled in trading platform");
      else if (IsTradeContextBusy())  Print("Trade context is busy");
      else if (!IsTradeAllowed())      Print("Trade is not allowed in trading platform");
      else ticket=send_order(ins,cmd,volume,distance,slippage,sl,tp,comment,magic,expire,a_clr);
      if(ticket>0)
         break;
      else Print("Error in sending order ("+IntegerToString(GetLastError(),0)+"), retry: "+ IntegerToString(i,0)+"/"+IntegerToString(retries));
      Sleep(sleep);
     }
   return ticket;
  }