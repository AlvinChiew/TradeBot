#property copyright "Copyright 2021, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

input double trail_pt = 200;  // diff between new sl and current price
input double thresh_pt = 0;   // start trailing after x pt away from Open price
input double min_diff_pt = 50;  // min diff between old & new sl to lighten pc burden
input double magic_num = -1;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//---
   trailingstop_check(trail_pt, thresh_pt, min_diff_pt, magic_num);
  }
//+------------------------------------------------------------------+


void trailingstop_check(int trail, int threshold, int step, int magic = -1)
{
   for (int i = 0; i < OrdersTotal(); i ++)
   {
      if (magic == -1 || magic == OrderMagicNumber())
         trailingstop_check_order(OrderTicket(), trail, threshold, step);
   }
}


bool trailingstop_check_order(int ticket,int trail,int threshold,int step)
  {
   if(ticket<=0) return true;
   if(!OrderSelect(ticket,SELECT_BY_TICKET)) return false;
   int digits=(int) MarketInfo(OrderSymbol(),MODE_DIGITS);
   double point=MarketInfo(OrderSymbol(),MODE_POINT);
   bool result=true;
   if(OrderType()==OP_BUY)
     {
      double newsl = OrderClosePrice()-trail*point;
      double activation = OrderOpenPrice()+threshold*point;
      double activation_sl = activation-(trail*point);
      double step_in_pts= newsl-OrderStopLoss();
      if(OrderStopLoss()==0|| compare_doubles(activation_sl,OrderStopLoss(),digits)>0)
        {
         if(compare_doubles(OrderClosePrice(),activation,digits)>=0)
            result=modify(ticket,activation_sl);
        }
      else if(compare_doubles(step_in_pts,step*point,digits)>=0)
        {
         result=modify(ticket,newsl);
        }
     }
   else if(OrderType()==OP_SELL)
     {
      double newsl=OrderClosePrice()+trail*point;
      double activation=OrderOpenPrice()-threshold*point;
      double activation_sl=activation+(trail*point);
      double step_in_pts= OrderStopLoss()-newsl;
      if(OrderStopLoss()==0|| compare_doubles(activation_sl,OrderStopLoss(),digits)<0)
        {
         if(compare_doubles(OrderClosePrice(),activation,digits)<=0)
            result=modify(ticket,activation_sl);
        }
      else if(compare_doubles(step_in_pts,step*point,digits)>=0)
        {
         result=modify(ticket,newsl);
        }
     }
   return result;
  }
  


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
  