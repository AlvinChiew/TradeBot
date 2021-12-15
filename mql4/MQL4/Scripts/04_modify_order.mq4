#property copyright "Copyright 2021, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property show_inputs

input int ticketid;
input double stoploss = -1;
input double takeprofit = -1;
input double newprice = -1;
input datetime newexpire = 0;
input color newcolor = clrNONE;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//---
   modify(ticketid, stoploss, takeprofit, newprice, newexpire, newcolor, 3, 500);
  }
//+------------------------------------------------------------------+


int compare_doubles(double var1,double var2,int precision)
{
   double point = MathPow(10,-precision);
   int var1_int = var1/point;
   int var2_int = var2/point;
   if(var1_int>var2_int)
      return 1;
   else if(var1_int<var2_int)
      return -1;
   return 0;
}
  
  
bool modify_order(int ticket, double sl = -1, double tp = -1, double price = -1, datetime expire = 0, color a_color=clrNONE)
{
   bool result = false;
   if (OrderSelect(ticket, SELECT_BY_TICKET))
   {
      string ins = OrderSymbol();
      int digits = (int)MarketInfo(ins, MODE_DIGITS);
      if (sl == -1) sl = OrderStopLoss();
      else sl = NormalizeDouble(sl, digits);
      if (tp == -1) tp = OrderTakeProfit();
      else tp = NormalizeDouble(tp, digits);
      
      if (OrderType() <= 1)
      {
         if (compare_doubles(sl, OrderStopLoss(), digits) == 0 &&
             compare_doubles(tp, OrderTakeProfit(), digits) == 0)
            return true;
         price = OrderOpenPrice();       
      }
      else
      {
         if (price == -1)
            price = OrderOpenPrice();
         else 
            price = NormalizeDouble(price, digits);
         
         if (compare_doubles(price, OrderOpenPrice(), digits) == 0 &&   
             compare_doubles(sl, OrderStopLoss(), digits) == 0 &&
             compare_doubles(tp, OrderTakeProfit(), digits) == 0 &&
             expire == OrderExpiration())
            return true;    
      }
      
      result = OrderModify(ticket, price, sl, tp, expire, a_color);
   }
   return result;
}


bool modify(int ticket, double sl = -1, double tp = -1, double price = -1, datetime expire = 0, color a_color=clrNONE, int retries = 3, int sleep = 500)
{
   bool result = false;
   if (ticket > 0)
   {
      for (int i = 0; i < retries; i ++)
      {
         if (!IsConnected())              Print("No internet connection");
         else if (!IsExpertEnabled())     Print("Experts not enabled in trading platform");
         else if (IsTradeContextBusy())   Print("Trade context is busy");
         else if (!IsTradeAllowed())      Print("Trade is not allowed in trading platform");
         else result = modify_order(ticket, sl, tp, price, expire, a_color);
         if (result)
            break;
         Sleep(sleep);   
      }
   }
   else Print("Invalid ticket for modify function");
   return result;
}