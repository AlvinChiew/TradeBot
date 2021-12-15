//+------------------------------------------------------------------+
//|                                          03_myFirstIndicator.mq4 |
//|                        Copyright 2021, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property indicator_chart_window

#property indicator_buffers 4
#property indicator_color1 clrWhite
#property indicator_style1 STYLE_SOLID
#property indicator_type1 DRAW_LINE
#property  indicator_width1 5

input int iPeriod = 14;  // MA Period
input ENUM_MA_METHOD iMethod = MODE_SMA; // MA Method

double BufferMA[];
double BufferData[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping

   IndicatorBuffers(2); // didnn't set 2 in #property so that input & data window only show `BufferMA`

   SetIndexBuffer(0, BufferMA);
   SetIndexBuffer(1, BufferData); // set as buffer instead of array so that it gets refreshed automatically in new bars
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//---
   int limit = rates_total-prev_calculated;
   if (prev_calculated>0) limit++;
   
   for (int i = limit - 1; i >= 0; i--)
   {
      BufferData[i] = iClose(Symbol(), Period(), i);
      int period = (rates_total-i) < iPeriod ? (rates_total - i) : iPeriod;
      BufferMA[i] = iMAOnArray(BufferData, 0, period, 0, iMethod, i);
   }
   
//--- return value of prev_calculated for next call
   return(rates_total);
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---
   
  }
//+------------------------------------------------------------------+
