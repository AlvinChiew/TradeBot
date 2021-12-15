#property copyright "Copyright 2021, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property show_inputs


enum MM {
   // MM_FIXED_LOT,
   MM_RISK_PERCENT,
   MM_FIXED_RATIO,
   MM_FIXED_RISK,
   MM_FIXED_RISK_PER_POINT
};

extern MM method = MM_RISK_PERCENT;
extern double stoploss_pt = 200;
extern double mm1_risk_bal_perc = 0.25;
extern double mm2_lots = 1.0;
extern double mm2_perc = 1000;
extern double mm3_risk_usd = 100;
extern double mm4_risk = 50;



//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()  // Or OnTick()
{
//---
   Print("Expected lot size : " +  DoubleToString(mm(method, NULL, 0.01, stoploss_pt, mm1_risk_bal_perc, mm2_lots, mm2_perc, mm3_risk_usd, mm4_risk)));
   
}
//+------------------------------------------------------------------+


double mm(MM method,string ins,double lots,int sl,double risk_mm1,double lots_mm2,double per_mm2,double risk_mm3,double risk_mm4)
{
   double balance=AccountBalance();
   double tick_value=MarketInfo(ins,MODE_TICKVALUE);
   double volume=lots;
   switch(method)
     {
      // x% of acc bal based on mutable sl.
      case MM_RISK_PERCENT:
         if(sl>0) volume=((balance*risk_mm1)/sl)/tick_value;
         break;
      // x% of acc bal based on fixed sl.
      case MM_FIXED_RATIO:
         volume=balance*lots_mm2/per_mm2;
         break;
      // $x based on mutable sl
      case MM_FIXED_RISK:
         if(sl>0) volume=(risk_mm3/tick_value)/sl;
         break;
      // $x per pt based on fixed sl   
      case MM_FIXED_RISK_PER_POINT:
         volume=risk_mm4/tick_value;
         break;
     }
   double min_lot=MarketInfo(ins,MODE_MINLOT);
   double max_lot=MarketInfo(ins,MODE_MAXLOT);
   int lot_digits=(int) -MathLog10(MarketInfo(ins,MODE_LOTSTEP));
   volume=NormalizeDouble(volume,lot_digits);
   if(volume<min_lot) volume=min_lot;
   if(volume>max_lot) volume=max_lot;
   return volume;
}   
