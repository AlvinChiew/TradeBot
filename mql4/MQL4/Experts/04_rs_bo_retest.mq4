#property copyright     "Copyright 2021, AlvinChiew"
#property link          "https://www.linkedin.com/in/chiewjingjie/"
#property version       "1.0"

#property icon          "\\Files\\ea03.ico"
#property description   "Trading EA based on William's Fractal"
#property description   "WARNING : You use this EA at your own risk."
#property description   "The creator cannot be held responsible for damage or loss."
//#include <MQLTA ErrorHandling.mqh>

#property strict

// entry new bar has issue //


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum ENUM_TRADE_SIGNAL
  {
   TRADE_SIGNAL_VOID=-1,
   TRADE_SIGNAL_NEUTRAL,
   TRADE_SIGNAL_BUY,
   TRADE_SIGNAL_SELL
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum ENUM_ORDER_SET
  {
   ORDER_SET_ALL=-1,
   ORDER_SET_BUY,
   ORDER_SET_SELL,
   ORDER_SET_BUY_LIMIT,
   ORDER_SET_SELL_LIMIT,
   ORDER_SET_BUY_STOP,
   ORDER_SET_SELL_STOP,
   ORDER_SET_LONG,
   ORDER_SET_SHORT,
   ORDER_SET_LIMIT,
   ORDER_SET_STOP,
   ORDER_SET_MARKET,
   ORDER_SET_PENDING
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum MM
  {
   MM_FIXED_LOT,
   MM_RISK_PERCENT,
   //MM_FIXED_RATIO,
   MM_FIXED_RISK,
   //MM_FIXED_RISK_PER_POINT,
  };


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+



// --- Chart info --- //
// currency pairs; NULL = Follow chart; e.g. "EURUSD"
input string symbol = NULL;
// chart timeframe; 0 = Follow chart; e.g. "PERIOD_H4"
int timeframe = 0;

// --- Order Detail ---- //
input int stoploss=300;
input int takeprofit=300;
int virtual_sl=0;
int virtual_tp=0;
int max_slippage=10;
// Set SL and TP after order //
bool market_exec= false;
string order_comment="";
int order_magic=-1;

// --- Pending Order --- //
// expiration in sec
int order_expire=0;

// --- Money Management --- //
input MM money_management=MM_FIXED_RISK;
input double mmfixedlot_lotsize = 0.1;
input double mmriskperc_risk = 0.05;
input double mmfixedrisk_usd = 100;
double mm2_lots = 0.1;
double mm2_per = 1000;
double mm4_risk = 50;

// ---- Update SL - breakeven --- //
int breakeven_threshold=500;
int breakeven_plus=0;

// --- Update SL - trailing --- //
int trail_value=20;
int trail_threshold=500;
int trail_step=20;

// --- Orders Management --- //
input int maxtrades=1;
// Exit all opposite trade during entry; e.g. Exit all short position when enter long;
input bool exit_opposite_signal=false;
// Avoid multiple entry in the same bar
input bool entry_new_bar=false;
// Hold order until first bar is loaded
bool wait_next_bar_on_load=true;
input bool long_allowed=true;
input bool short_allowed=true;

// --- Cosmetics --- //
// nothing changed ...
color arrow_color_long=clrGreen;
color arrow_color_short=clrRed;

// --- Trade Period --- //
// deactivated when start time == end time //
input int start_time_hour=0;
input int start_time_minute=0;
input int end_time_hour=0;
input int end_time_minute=0;
input int gmt=0;


// --- Indicator Inputs --- //

// SR //

enum ENUM_CUSTOMTIMEFRAMES{
   CURRENT=PERIOD_CURRENT,             //CURRENT PERIOD
   M1=PERIOD_M1,                       //M1
   M5=PERIOD_M5,                       //M5
   M15=PERIOD_M15,                     //M15
   M30=PERIOD_M30,                     //M30
   H1=PERIOD_H1,                       //H1
   H4=PERIOD_H4,                       //H4
   D1=PERIOD_D1,                       //D1
   W1=PERIOD_W1,                       //W1
   MN1=PERIOD_MN1,                     //MN1
};

enum ENUM_ACCURACY{
   HIGH=1,                             //HIGH
   MEDIUM=2,                           //MEDIUM
   LOW=3,                              //LOW
};

enum ENUM_FILLBUFFERS{
   LEVELS=0,         //SUPPORT/RESISTANCE LEVELS
   DISTANCES=1,      //DISTANCES FROM LEVELS
};


extern ENUM_CUSTOMTIMEFRAMES signal_tf = H1;
extern ENUM_CUSTOMTIMEFRAMES SRTimeframe = H1;
extern ENUM_ACCURACY SRAccuracy=LOW;
extern int BarsToIgnore=0;                         //Recent Candles to Ignore
extern int MaxBars=1000;                           //Bars to Analyze
extern int MaxRange=0;                             //Max Price Range to Analyze (points) (0=No Limit)
//input string Comment_4="====================";     //Graphical Objects
//extern bool DrawLinesEnabled=true;                 //Draw Lines
//extern color ResistanceColor=clrGreen;             //Resistance Color
//extern color SupportColor=clrRed;                  //Support Color
//extern ENUM_THICKNESS LineThickness=THREE;         //Line Thickness
//extern bool DrawWindowEnabled=false;                //Draw Window
//extern int Xoff=20;                                //Horizontal spacing for the control panel
//extern int Yoff=20;                                //Vertical spacing for the control panel
int ATRPeriod=100;
int CalculatedBars=0;
double LevelAbove=0;
double LevelBelow=0;
double sr_zones_all[];
double sr_zones[];


void calcSRs()
{
   double Highest=iHigh(NULL,SRTimeframe,iHighest(NULL,SRTimeframe,MODE_HIGH,MaxBars,0));
   double Lowest=iLow(NULL,SRTimeframe,iLowest(NULL,SRTimeframe,MODE_LOW,MaxBars,0));
   double Step=NormalizeDouble(iATR(NULL,SRTimeframe,ATRPeriod,0)*SRAccuracy,Digits);
   if(Step==0){
      Print("Not Enough Historical Data, Please load more candles for the selected timeframe");
      return;
   }
   int Steps=int(MathCeil((Highest-Lowest)/Step)+1);
   double MidRange=MaxRange/2*Point;
   ArrayResize(sr_zones_all,Steps);
   ArrayInitialize(sr_zones_all,0);
   for(int i=0;i<ArraySize(sr_zones_all);i++){
      double StartRange=Lowest+Step*i;
      double EndRange=Lowest+Step*(i+1);
      if(MidRange>0 && StartRange<Close[0]-MidRange) continue;
      if(MidRange>0 && EndRange>Close[0]+MidRange) continue;
      int BarCount=0;
      double AvgPrice=0;
      double TotalPrice=0;
      sr_zones_all[i]=0;
      for(int j=BarsToIgnore;j<MaxBars+BarsToIgnore;j++){
         double Fractal=0;
         if(iFractals(NULL,SRTimeframe,MODE_UPPER,j)>0) Fractal=iFractals(NULL,SRTimeframe,MODE_UPPER,j);
         else if(iFractals(NULL,SRTimeframe,MODE_LOWER,j)>0) Fractal=iFractals(NULL,SRTimeframe,MODE_LOWER,j);
         double AvgValue=0;
         if(Fractal>=StartRange && Fractal<=EndRange){
            BarCount++;
            AvgValue=Fractal;
            TotalPrice+=AvgValue;
         }
      }
      if(BarCount>0) AvgPrice=NormalizeDouble(TotalPrice/BarCount,Digits);
      sr_zones_all[i]=AvgPrice;
   }
}

bool get_zones()
{
   // check if new bar //
   if (is_new_bar(symbol,timeframe,wait_next_bar_on_load)) 
      return true;
      
   calcSRs();
   if(iBars(Symbol(),SRTimeframe)<MaxBars+BarsToIgnore)
   {
      MaxBars=iBars(Symbol(),SRTimeframe)-BarsToIgnore;
      Print("Please Load More Historical Candles, Calculation on only ",MaxBars," Bars");
      if(MaxBars<0){
         return false;
      }
   }   
   
   
   ArrayResize(sr_zones,4);
   ArrayInitialize(sr_zones,0);
   int j=0;
   for(int i=ArraySize(sr_zones_all)-1;i>=0;i--){
      if(sr_zones_all[i]>0 && sr_zones_all[i]<Close[0]){
         if(j==0){
            sr_zones[0]=NormalizeDouble(sr_zones_all[i],Digits);
         }
         if(j==1){
            sr_zones[1]=NormalizeDouble(sr_zones_all[i],Digits);
            break;
         }
         j++;
      }
   }   
   j=0;
   for(int i=0;i<ArraySize(sr_zones_all);i++){
      if(sr_zones_all[i]>Close[0]){
         if(j==0){
            sr_zones[2]=NormalizeDouble(sr_zones_all[i],Digits);
         }
         if(j==1){
            sr_zones[3]=NormalizeDouble(sr_zones_all[i],Digits);
            break;
         }
         j++;
      }
   }

   return true;
}

bool retested_sell_bo;
bool retested_buy_bo;

bool check_history()
{
   get_zones();
   retested_sell_bo = false;
   retested_buy_bo = false;

   double curr_high = iHigh(NULL, signal_tf, 0);
   double curr_low = iLow(NULL, signal_tf, 0);
   bool was_floating = false;
   
   for(int i=1; i<=2; i++)
   {
      // check if current bar is on line
      was_floating = false;
      if(curr_high >= sr_zones[i] && curr_low <= sr_zones[i])
      {
         Comment("Price is on line");
         
         // check for retested sell breakout
         for(int j=BarsToIgnore;j<MaxBars+BarsToIgnore;j++)
         {
            // check if price floated between zone
            if (was_floating == false)
            {
               if(iHigh(NULL, signal_tf, j) < sr_zones[i] && iLow(NULL, signal_tf, j) > sr_zones[i-1])
               {
                  Comment("sell_bo: Price was floating");
                  was_floating = true;
               }
               else if (iLow(NULL, signal_tf, j) > sr_zones[i])
               {
                  Comment("sell_bo: breakout not yet retested");
                  break;
               }
            }
            // price floated, check for breakout
            else
            {
               if(iHigh(NULL, signal_tf, j) > sr_zones[i+1])
               {
                  Comment("sell_bo: breakout restest!");
                  retested_sell_bo = true;
                  return true;
               }
               else if (iLow(NULL, signal_tf, j) < sr_zones[i-1])
               {
                  Comment("sell_bo: Buy breakout in 2 zones");
                  return false;
                  break;
               }
            }
         }         
      
         // check for retested buy breakout
         was_floating = false;
         for(int j=BarsToIgnore;j<MaxBars+BarsToIgnore;j++)
         {
            // check if price floated between zone
            if (was_floating == false)
            {
               if(iHigh(NULL, signal_tf, j) < sr_zones[i+1] && iLow(NULL, signal_tf, j) > sr_zones[i])
               {
                  Comment("buy_bo: Price was floating");
                  was_floating = true;
               }
               else if (iLow(NULL, signal_tf, j) > sr_zones[i+1])
               {
                  Comment("buy_bo: breakout not yet retested");
                  break;
               }
            }
            // price floated, check for breakout
            else
            {
               if(iLow(NULL, signal_tf, j) < sr_zones[i-1])
               {
                  Comment("buy_bo: sell breakout restest!");
                  retested_buy_bo= true;
                  return true;
               }
               else if (iHigh(NULL, signal_tf, j) > sr_zones[i+1])
               {
                  Comment("buy_bo: Sell breakout in 2 zones");
                  return false;
                  break;
               }
            }
         }
      }
      else            
         Comment("bar not touching zone."); 
   }
   return false;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int signal_breakout()
{
   int signal = TRADE_SIGNAL_NEUTRAL;
   bool retested_breakout = check_history();
   
   if(!retested_breakout) 
      return signal;
      
   if (retested_buy_bo)
      signal = TRADE_SIGNAL_BUY;
   else if (retested_sell_bo)
      signal = TRADE_SIGNAL_SELL;
      
   return signal;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int signal_entry()
  {
   int signal=TRADE_SIGNAL_NEUTRAL;
   
   //add entry signals below
   signal = signal_add(signal,signal_breakout());

   //Print(signal);
   return signal;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int signal_exit()
  {
   int signal=TRADE_SIGNAL_NEUTRAL;
   
   //add entry signals below
   signal = signal_add(signal,signal_breakout());
   
   return signal;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calculate_volume()
  {
   double volume=mm(money_management,symbol,mmfixedlot_lotsize,stoploss,mmriskperc_risk,mm2_lots,mm2_per,mmfixedrisk_usd,mm4_risk);
   return volume;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void enter_order(ENUM_ORDER_TYPE type)
  {
   color arrow_color = arrow_color_long;
   if(type==OP_BUY || type==OP_BUYSTOP || type==OP_BUYLIMIT)
   {
      arrow_color = arrow_color_long;
      if(!long_allowed) return;
   }   
   if(type==OP_SELL || type==OP_SELLSTOP || type==OP_SELLLIMIT)
   {
      arrow_color = arrow_color_short;
      if(!short_allowed) return;
   }
   double volume=calculate_volume();    
   entry(NULL,type,volume,0,max_slippage,stoploss,takeprofit,order_comment,order_magic,order_expire,arrow_color,market_exec);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void close_all()
  {
   exit_all_set(ORDER_SET_ALL,order_magic);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void close_all_long()
  {
   exit_all_set(ORDER_SET_BUY,order_magic);
//exit_all_set(ORDER_SET_BUY_STOP,order_magic);
//exit_all_set(ORDER_SET_BUY_LIMIT,order_magic);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void close_all_short()
  {
   exit_all_set(ORDER_SET_SELL,order_magic);
//exit_all_set(ORDER_SET_SELL_STOP,order_magic);
//exit_all_set(ORDER_SET_SELL_LIMIT,order_magic);
  }
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
   
   /* time check */
   bool time_in_range=is_time_in_range(TimeCurrent(),start_time_hour,start_time_minute,end_time_hour,end_time_minute,gmt);
   if (time_in_range)
   {      

   /* signals */
      int entry=0,exit=0;
      entry=signal_entry();
      exit=signal_exit();
   
   /* exit */
      if(exit==TRADE_SIGNAL_BUY)
        {
         close_all_short();
        }
      else if(exit==TRADE_SIGNAL_SELL)
        {
         close_all_long();
        }
      else if(exit==TRADE_SIGNAL_VOID)
        {
         close_all();
        }
   
   /* entry */
      int count_orders=0;
      if(entry>0)
        {
         if(entry==TRADE_SIGNAL_BUY)
           {
            if(exit_opposite_signal)
               exit_all_set(ORDER_SET_SELL,order_magic);
            count_orders=count_orders(-1,order_magic);
            if(maxtrades>count_orders)
              {
               if(!entry_new_bar || (entry_new_bar && is_new_bar(symbol,timeframe,wait_next_bar_on_load)))
                  enter_order(OP_BUY);
              }
           }
         else if(entry==TRADE_SIGNAL_SELL)
           {
            if(exit_opposite_signal)
               exit_all_set(ORDER_SET_BUY,order_magic);
            count_orders=count_orders(-1,order_magic);
            if(maxtrades>count_orders)
              {
              //Print("is_new_bar" + IntegerToString(is_new_bar(symbol,timeframe,wait_next_bar_on_load))));
               if(!entry_new_bar || (entry_new_bar && is_new_bar(symbol,timeframe,wait_next_bar_on_load)))
               {
                  //Print("SELLING");
                  enter_order(OP_SELL);
               }
              }
           }
        }
   
   /* misc tasks */
   //if(breakeven_threshold>0) breakeven_check(breakeven_threshold,breakeven_plus,order_magic);
   //if(trail_value>0) trailingstop_check(trail_value,trail_threshold,trail_step,order_magic);
      virtualstop_check(virtual_sl,virtual_tp);
   }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void signal_manage(ENUM_TRADE_SIGNAL &entry,ENUM_TRADE_SIGNAL &exit)
  {
   if(exit==TRADE_SIGNAL_VOID)
      entry=TRADE_SIGNAL_NEUTRAL;
   if(exit==TRADE_SIGNAL_BUY && entry==TRADE_SIGNAL_SELL)
      entry=TRADE_SIGNAL_NEUTRAL;
   if(exit==TRADE_SIGNAL_SELL && entry==TRADE_SIGNAL_BUY)
      entry=TRADE_SIGNAL_NEUTRAL;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool breakeven_check_order(int ticket,int threshold,int plus)
  {
   if(ticket<=0) return true;
   if(!OrderSelect(ticket,SELECT_BY_TICKET)) return false;
   int digits=(int)MarketInfo(OrderSymbol(),MODE_DIGITS);
   double point=MarketInfo(OrderSymbol(),MODE_POINT);
   bool result=true;
   if(OrderType()==OP_BUY)
     {
      double newsl=OrderOpenPrice()+plus*point;
      double profit_in_pts=OrderClosePrice()-OrderOpenPrice();
      if(OrderStopLoss()==0 || compare_doubles(newsl,OrderStopLoss(),digits)>0)
         if(compare_doubles(profit_in_pts,threshold*point,digits)>=0)
            result=modify(ticket,newsl);
     }
   else if(OrderType()==OP_SELL)
     {
      double newsl=OrderOpenPrice()-plus*point;
      double profit_in_pts=OrderOpenPrice()-OrderClosePrice();
      if(OrderStopLoss()==0 || compare_doubles(newsl,OrderStopLoss(),digits)<0)
         if(compare_doubles(profit_in_pts,threshold*point,digits)>=0)
            result=modify(ticket,newsl);
     }
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void breakeven_check(int threshold,int plus,int magic=-1)
  {
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS))
         if(magic==-1 || magic==OrderMagicNumber())
            breakeven_check_order(OrderTicket(),threshold,plus);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool modify_order(int ticket,double sl,double tp=-1,double price=-1,datetime expire=0,color a_color=clrNONE)
  {
   bool result=false;
   if(OrderSelect(ticket,SELECT_BY_TICKET))
     {
      string ins=OrderSymbol();
      int digits=(int)MarketInfo(ins,MODE_DIGITS);
      if(sl==-1) sl=OrderStopLoss();
      else sl=NormalizeDouble(sl,digits);
      if(tp==-1) tp=OrderTakeProfit();
      else tp=NormalizeDouble(tp,digits);
      if(OrderType()<=1)
        {
         if(compare_doubles(sl,OrderStopLoss(),digits)==0 && 
            compare_doubles(tp,OrderTakeProfit(),digits)==0)
            return true;
         price=OrderOpenPrice();
        }
      else if(OrderType()>1)
        {
         if(price==-1)
            price= OrderOpenPrice();
         else price=NormalizeDouble(price,digits);
         if(compare_doubles(price,OrderOpenPrice(),digits)==0 && 
            compare_doubles(sl,OrderStopLoss(),digits)==0 && 
            compare_doubles(tp,OrderTakeProfit(),digits)==0 && 
            expire==OrderExpiration())
            return true;
        }
      result=OrderModify(ticket,price,sl,tp,expire,a_color);
     }
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool modify(int ticket,double sl,double tp=-1,double price=-1,datetime expire=0,color a_color=clrNONE,int retries=3,int sleep=500)
  {
   bool result=false;
   if(ticket>0)
     {
      for(int i=0;i<retries;i++)
        {
         if(!IsConnected()) Print("No internet connection");
         else if(!IsExpertEnabled()) Print("Experts not enabled in trading platform");
         else if(IsTradeContextBusy()) Print("Trade context is busy");
         else if(!IsTradeAllowed()) Print("Trade is not allowed in trading platform");
         else result=modify_order(ticket,sl,tp,price,expire,a_color);
         if(result)
            break;
         Sleep(sleep);
        }
     }
   else Print("Invalid ticket for modify function");
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int compare_doubles(double var1,double var2,int precision)
  {
   double point=MathPow(10,-precision); //10^(-precision)
   int var1_int = (int) (var1/point);
   int var2_int = (int) (var2/point);
   if(var1_int>var2_int)
      return 1;
   else if(var1_int<var2_int)
      return -1;
   return 0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool exit_order(int ticket,double size=-1,color a_color=clrNONE,int slippage=50)
  {
   bool result=false;
   if(OrderSelect(ticket,SELECT_BY_TICKET))
     {
      if(OrderType()<=1)
        {
         result=OrderClose(ticket,OrderLots(),OrderClosePrice(),slippage,a_color);
        }
      else if(OrderType()>1)
        {
         result=OrderDelete(ticket,a_color);
        }
     }
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool exit(int ticket,color a_color=clrNONE,int slippage=50,int retries=3,int sleep=500)
  {
   bool result=false;
   for(int i=0;i<retries;i++)
     {
      if(!IsConnected()) Print("No internet connection");
      else if(!IsExpertEnabled()) Print("Experts not enabled in trading platform");
      else if(IsTradeContextBusy()) Print("Trade context is busy");
      else if(!IsTradeAllowed()) Print("Trade is not allowed in trading platform");
      else result=exit_order(ticket,a_color,slippage);
      if(result)
         break;
      Print("Closing order# "+DoubleToStr(OrderTicket(),0)+" failed "+DoubleToStr(GetLastError(),0));
      Sleep(sleep);
     }
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void exit_all(int type=-1,int magic=-1)
  {
   for(int i=OrdersTotal();i>=0;i--)
     {
      if(OrderSelect(i,SELECT_BY_POS))
        {
         if((type==-1 || type==OrderType()) && (magic==-1 || magic==OrderMagicNumber()))
            exit(OrderTicket());
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void exit_all_set(ENUM_ORDER_SET type=-1,int magic=-1)
  {
   for(int i=OrdersTotal();i>=0;i--)
     {
      if(OrderSelect(i,SELECT_BY_POS))
        {
         if(magic==-1 || magic==OrderMagicNumber())
           {
            int ordertype=OrderType();
            int ticket=OrderTicket();
            switch(type)
              {
               case ORDER_SET_BUY:
                  if(ordertype==OP_BUY) exit(ticket);
                  break;
               case ORDER_SET_SELL:
                  if(ordertype==OP_SELL) exit(ticket);
                  break;
               case ORDER_SET_BUY_LIMIT:
                  if(ordertype==OP_BUYLIMIT) exit(ticket);
                  break;
               case ORDER_SET_SELL_LIMIT:
                  if(ordertype==OP_SELLLIMIT) exit(ticket);
                  break;
               case ORDER_SET_BUY_STOP:
                  if(ordertype==OP_BUYSTOP) exit(ticket);
                  break;
               case ORDER_SET_SELL_STOP:
                  if(ordertype==OP_SELLSTOP) exit(ticket);
                  break;
               case ORDER_SET_LONG:
                  if(ordertype==OP_BUY || ordertype==OP_BUYLIMIT || ordertype==OP_BUYSTOP)
                  exit(ticket);
                  break;
               case ORDER_SET_SHORT:
                  if(ordertype==OP_SELL || ordertype==OP_SELLLIMIT || ordertype==OP_SELLSTOP)
                  exit(ticket);
                  break;
               case ORDER_SET_LIMIT:
                  if(ordertype==OP_BUYLIMIT || ordertype==OP_SELLLIMIT)
                  exit(ticket);
                  break;
               case ORDER_SET_STOP:
                  if(ordertype==OP_BUYSTOP || ordertype==OP_SELLSTOP)
                  exit(ticket);
                  break;
               case ORDER_SET_MARKET:
                  if(ordertype<=1) exit(ticket);
                  break;
               case ORDER_SET_PENDING:
                  if(ordertype>1) exit(ticket);
                  break;
               default: exit(ticket);
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int send_order(string ins,int cmd,double volume,int distance,int slippage,int sl,int tp,string comment=NULL,int magic=0,int expire=0,color a_clr=clrNONE,bool market=false)
  {
   double price=0;
   double price_sl = 0;
   double price_tp = 0;
   double point=MarketInfo(ins,MODE_POINT);
   datetime expiry= 0;
   int order_type = -1;
   RefreshRates();
   if(cmd==OP_BUY)
     {
      if(distance>0) order_type=OP_BUYSTOP;
      else if(distance<0) order_type=OP_BUYLIMIT;
      else order_type=OP_BUY;
      if(order_type==OP_BUY) distance=0;
      price=MarketInfo(ins,MODE_ASK)+distance*point;
      if(!market)
        {
         if(sl>0) price_sl = price-sl*point;
         if(tp>0) price_tp = price+tp*point;
        }
     }
   else if(cmd==OP_SELL)
     {
      if(distance>0) order_type=OP_SELLLIMIT;
      else if(distance<0) order_type=OP_SELLSTOP;
      else order_type=OP_SELL;
      if(order_type==OP_SELL) distance=0;
      price=MarketInfo(ins,MODE_BID)+distance*point;
      if(!market)
        {
         if(sl>0) price_sl = price+sl*point;
         if(tp>0) price_tp = price-tp*point;
        }
     }
   if(order_type<0) return 0;
   else  if(order_type==0 || order_type==1) expiry=0;
   else if(expire>0)
      expiry=(datetime)MarketInfo(ins,MODE_TIME)+expire;
   if(market)
     {
      int ticket=OrderSend(ins,order_type,volume,price,slippage,0,0,comment,magic,expiry,a_clr);
      if(ticket>0)
        {
         if(OrderSelect(ticket,SELECT_BY_TICKET))
           {
            if(cmd==OP_BUY)
              {
               if(sl>0) price_sl = OrderOpenPrice()-sl*point;
               if(tp>0) price_tp = OrderOpenPrice()+tp*point;
              }
            else if(cmd==OP_SELL)
              {
               if(sl>0) price_sl = OrderOpenPrice()+sl*point;
               if(tp>0) price_tp = OrderOpenPrice()-tp*point;
              }
            bool result=modify(ticket,price_sl,price_tp);
           }
        }
      return ticket;
     }
   return OrderSend(ins,order_type,volume,price,slippage,price_sl,price_tp,comment,magic,expiry,a_clr);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int entry(string ins,int cmd,double volume,int distance,int slippage,int sl,int tp,string comment=NULL,int magic=0,int expire=0,color a_clr=clrNONE,bool market=false,int retries=3,int sleep=500)
  {
   int ticket=0;
   for(int i=0;i<retries;i++)
     {
      if(IsStopped()) Print("Expert was stopped");
      else if(!IsConnected()) Print("No internet connection");
      else if(!IsExpertEnabled()) Print("Experts not enabled in trading platform");
      else if(IsTradeContextBusy()) Print("Trade context is busy");
      else if(!IsTradeAllowed()) Print("Trade is not allowed in trading platform");
      else ticket=send_order(ins,cmd,volume,distance,slippage,sl,tp,comment,magic,expire,a_clr,market);
      if(ticket>0)
         break;
      else Print("Error in sending order ("+IntegerToString(GetLastError(),0)+"), retry: "+IntegerToString(i,0)+"/"+IntegerToString(retries));
      Sleep(sleep);
     }
   return ticket;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool trailingstop_check_order(int ticket,int trail,int threshold,int step)
  {
   if(ticket<=0) return true;
   if(!OrderSelect(ticket,SELECT_BY_TICKET)) return false;
   int digits=(int) MarketInfo(OrderSymbol(),MODE_DIGITS);
   double point=MarketInfo(OrderSymbol(),MODE_POINT);
   bool result=true;
   if(OrderType()==OP_BUY)
     {
      double newsl=OrderClosePrice()-trail*point;
      double activation=OrderOpenPrice()+threshold*point;
      double activation_sl=activation-(trail*point);
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
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void trailingstop_check(int trail,int threshold,int step,int magic=-1)
  {
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS))
        {
         if(magic==-1 || magic==OrderMagicNumber())
            trailingstop_check_order(OrderTicket(),trail,threshold,step);
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int signal_add(int current,int add,bool exit=false)
  {
   if(current==TRADE_SIGNAL_VOID)
      return current;
   else if(current==TRADE_SIGNAL_NEUTRAL)
      return add;
   else
     {
      if(add==TRADE_SIGNAL_NEUTRAL)
         return current;
      else if(add==TRADE_SIGNAL_VOID)
         return add;
      else if(add!=current)
        {
         if(exit)
            return TRADE_SIGNAL_VOID;
         else
            return TRADE_SIGNAL_NEUTRAL;
        }
     }
   return add;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double mm(MM method,string ins,double lots,int sl,double risk_mm1,double lots_mm2,double per_mm2,double risk_mm3,double risk_mm4)
  {
   double balance=AccountBalance();
   double tick_value=MarketInfo(ins,MODE_TICKVALUE);
   double volume=lots;
   switch(method)
     {
      case MM_RISK_PERCENT:
         if(sl>0) volume=((balance*risk_mm1)/sl)/tick_value;
         break;
      //case MM_FIXED_RATIO:
      //   volume=balance*lots_mm2/per_mm2;
      //   break;
      case MM_FIXED_RISK:
         if(sl>0) volume=(risk_mm3/tick_value)/sl;
         break;
      //case MM_FIXED_RISK_PER_POINT:
      //   volume=risk_mm4/tick_value;
      //   break;
     }
   double min_lot=MarketInfo(ins,MODE_MINLOT);
   double max_lot=MarketInfo(ins,MODE_MAXLOT);
   int lot_digits=(int) -MathLog10(MarketInfo(ins,MODE_LOTSTEP));
   volume=NormalizeDouble(volume,lot_digits);
   if(volume<min_lot) volume=min_lot;
   if(volume>max_lot) volume=max_lot;
   return volume;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool is_new_bar(string ins,int tf,bool wait=false)
  {
   static datetime bar_time=0;
   static double open_price=0;
   datetime current_bar_time=iTime(ins,tf,0);
   double current_open_price=iOpen(ins,tf,0);
   int digits = (int)MarketInfo(ins,MODE_DIGITS);
   if(bar_time==0 && open_price==0)
     {
      bar_time=current_bar_time;
      open_price=current_open_price;
      if(wait)
         return false;
      else return true;
     }
   else if(current_bar_time>bar_time && 
      compare_doubles(open_price,current_open_price,digits)!=0)
        {
         bar_time=current_bar_time;
         open_price=current_open_price;
         return true;
        }
      return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int count_orders(ENUM_ORDER_SET type=-1,int magic=-1)
  {
   int count= 0;
   for(int i=OrdersTotal();i>=0;i--)
     {
      if(OrderSelect(i,SELECT_BY_POS))
        {
         if(magic==-1 || magic==OrderMagicNumber())
           {
            int ordertype=OrderType();
            int ticket=OrderTicket();
            switch(type)
              {
               case ORDER_SET_BUY:
                  if(ordertype==OP_BUY) count++;
                  break;
               case ORDER_SET_SELL:
                  if(ordertype==OP_SELL) count++;
                  break;
               case ORDER_SET_BUY_LIMIT:
                  if(ordertype==OP_BUYLIMIT) count++;
                  break;
               case ORDER_SET_SELL_LIMIT:
                  if(ordertype==OP_SELLLIMIT) count++;
                  break;
               case ORDER_SET_BUY_STOP:
                  if(ordertype==OP_BUYSTOP) count++;
                  break;
               case ORDER_SET_SELL_STOP:
                  if(ordertype==OP_SELLSTOP) count++;
                  break;
               case ORDER_SET_LONG:
                  if(ordertype==OP_BUY || ordertype==OP_BUYLIMIT || ordertype==OP_BUYSTOP)
                  count++;
                  break;
               case ORDER_SET_SHORT:
                  if(ordertype==OP_SELL || ordertype==OP_SELLLIMIT || ordertype==OP_SELLSTOP)
                  count++;
                  break;
               case ORDER_SET_LIMIT:
                  if(ordertype==OP_BUYLIMIT || ordertype==OP_SELLLIMIT)
                  count++;
                  break;
               case ORDER_SET_STOP:
                  if(ordertype==OP_BUYSTOP || ordertype==OP_SELLSTOP)
                  count++;
                  break;
               case ORDER_SET_MARKET:
                  if(ordertype<=1) count++;
                  break;
               case ORDER_SET_PENDING:
                  if(ordertype>1) count++;
                  break;
               default: count++;
              }
           }
        }
     }
   return count;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool is_time_in_range(datetime time,int start_hour,int start_min,int end_hour,int end_min,int gmt_offset=0)
  {
   if(gmt_offset!=0)
     {
      start_hour+=gmt_offset;
      end_hour+=gmt_offset;
     }
   if(start_hour>23) start_hour=(start_hour-23)-1;
   else if(start_hour<0) start_hour=23+start_hour+1;
   if(end_hour>23) end_hour=(end_hour-23)-1;
   else if(end_hour<0) end_hour=23+end_hour+1;
   int hour=TimeHour(time);
   int minute=TimeMinute(time);
   int t = (hour*3600)+(minute*60);
   int s = (start_hour*3600)+(start_min*60);
   int e = (end_hour*3600)+(end_min*60);
   if(s==e)
      return true;
   else if(s<e)
     {
      if(t>=s && t<e)
         return true;
     }
   else if(s>e)
     {
      if(t>=s || t<e)
         return true;
     }
   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool virtualstop_check_order(int ticket,int sl,int tp)
  {
   if(ticket<=0) return true;
   if(!OrderSelect(ticket,SELECT_BY_TICKET)) return false;
   int digits=(int) MarketInfo(OrderSymbol(),MODE_DIGITS);
   double point=MarketInfo(OrderSymbol(),MODE_POINT);
   bool result=true;
   if(OrderType()==OP_BUY)
     {
      double virtual_stoploss=OrderOpenPrice()-sl*point;
      double virtual_takeprofit=OrderOpenPrice()+tp*point;
      if((sl>0 && compare_doubles(OrderClosePrice(),virtual_stoploss,digits)<=0) || 
         (tp>0 && compare_doubles(OrderClosePrice(),virtual_takeprofit,digits)>=0))
        {
         result=exit_order(ticket);
        }
     }
   else if(OrderType()==OP_SELL)
     {
      double virtual_stoploss=OrderOpenPrice()+sl*point;
      double virtual_takeprofit=OrderOpenPrice()-tp*point;
      if((sl>0 && compare_doubles(OrderClosePrice(),virtual_stoploss,digits)>=0) || 
         (tp>0 && compare_doubles(OrderClosePrice(),virtual_takeprofit,digits)<=0))
        {
         result=exit_order(ticket);
        }
     }
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void virtualstop_check(int sl,int tp,int magic=-1)
  {
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS))
         if(magic==-1 || magic==OrderMagicNumber())
            virtualstop_check_order(OrderTicket(),sl,tp);
     }
  }
//+------------------------------------------------------------------+