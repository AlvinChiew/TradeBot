#property link          "https://www.earnforex.com/metatrader-indicators/support-resistance-lines/"
#property version       "1.01"
#property strict
#property copyright     "EarnForex.com - 2019-2021"
#property description   "This Indicator will show you the support and resistance" 
#property description   "levels."
#property description   " "
#property description   "WARNING : You use this software at your own risk."
#property description   "The creator of these plugins cannot be held responsible for damage or loss."
#property description   " "
#property description   "Find More on EarnForex.com"
#property icon          "\\Files\\EF-Icon-64x64px.ico"

#property indicator_chart_window

#include <MQLTA ErrorHandling.mqh>
#include <MQLTA Utils.mqh>

#property indicator_buffers 8


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


enum ENUM_THICKNESS{
   ONE=1,      //1
   TWO=2,      //2
   THREE=3,    //3
   FOUR=4,     //4
   FIVE=5,     //5
};

enum ENUM_WHENNOTIFY{
   SAFETY=0,      //SAFE AREA
   DANGER=1,      //DANGER AREA
};

enum ENUM_NOTIFICATION_INTERVAL_TIME{
   MIN1=1,          //1 MINUTE
   MIN5=5,          //5 MINUTES
   MIN15=15,        //15 MINUTES
   MIN30=30,        //30 MINUTES
   MIN60=60,        //60 MINUTES
};

enum ENUM_FILLBUFFERS{
   LEVELS=0,         //SUPPORT/RESISTANCE LEVELS
   DISTANCES=1,      //DISTANCES FROM LEVELS
};


input string Comment_1="====================";     //Indicator Settings
extern ENUM_CUSTOMTIMEFRAMES SRTimeframe=CURRENT;  //Timeframe to Analyze
extern ENUM_ACCURACY SRAccuracy=MEDIUM;            //Number of Levels
extern int SafeDistance=50;                        //Safety Distance From Closest Level (points)
input string Comment_2a="====================";    //iCustom Utility (For Expert Advisors)
input ENUM_FILLBUFFERS FillBuffersWith=LEVELS;     //Fill Buffers With
input string Comment_2="====================";     //Limits for the Analysis
extern int BarsToIgnore=0;                         //Recent Candles to Ignore
extern int MaxBars=1000;                           //Bars to Analyze
extern int MaxRange=0;                             //Max Price Range to Analyze (points) (0=No Limit)
input string Comment_3="====================";     //Notification Options
extern bool EnableNotify=false;                    //Enable Notifications feature
extern ENUM_WHENNOTIFY WhenNotify=DANGER;          //Notify In 
input ENUM_NOTIFICATION_INTERVAL_TIME NotInterval=MIN60;   //Notification Interval
extern bool SendAlert=true;                        //Send Alert Notification
extern string AlertSound="alert.wav";              //Alert Sound (wav in the Sounds Folder of MetaTrader)
extern bool SendApp=true;                          //Send Notification to Mobile
extern bool SendEmail=true;                        //Send Notification via Email
input string Comment_4="====================";     //Graphical Objects
extern bool DrawLinesEnabled=true;                 //Draw Lines
extern color ResistanceColor=clrGreen;             //Resistance Color
extern color SupportColor=clrRed;                  //Support Color
extern ENUM_THICKNESS LineThickness=THREE;         //Line Thickness
extern bool DrawWindowEnabled=true;                //Draw Window
extern int Xoff=20;                                //Horizontal spacing for the control panel
extern int Yoff=20;                                //Vertical spacing for the control panel
extern string IndicatorName="MQLTA-SR";            //Indicator Name (to name the objects)



int ATRPeriod=100;            
double Array[];
int CalculatedBars=0;
double LevelAbove=0;
double LevelBelow=0;
int DistanceFromSupport=0;
int DistanceFromResistance=0;
int MinDistance=0;
datetime LastNotificationTime;
int NotificationInterval=NotInterval*60;
bool Notified=false;

double BufferZero[1];
double BufferOne[1];
double BufferTwo[1];
double BufferThree[1];
double BufferFour[1];
double BufferFive[1];
double BufferSix[1];
double BufferSeven[1];


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit(){
   IndicatorSetString(INDICATOR_SHORTNAME,IndicatorName);

   CleanChart();
   CalculatedBars=0;
   LevelAbove=0;
   LevelBelow=0;
   DistanceFromSupport=0;
   DistanceFromResistance=0;
   MinDistance=0;
   Notified=false;
   LastNotificationTime=TimeCurrent()-NotInterval*60;
   SetIndexBuffer(0,BufferZero);
   SetIndexBuffer(1,BufferOne);
   SetIndexBuffer(2,BufferTwo);
   SetIndexBuffer(3,BufferThree);
   SetIndexBuffer(4,BufferFour);
   SetIndexBuffer(5,BufferFive);
   SetIndexBuffer(6,BufferSix);
   SetIndexBuffer(7,BufferSeven);
   SetIndexStyle(0,DRAW_NONE);
   SetIndexStyle(1,DRAW_NONE);
   SetIndexStyle(2,DRAW_NONE);
   SetIndexStyle(3,DRAW_NONE);
   SetIndexStyle(4,DRAW_NONE);
   SetIndexStyle(5,DRAW_NONE);
   SetIndexStyle(6,DRAW_NONE);
   SetIndexStyle(7,DRAW_NONE);
   CalculateLevels();
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
                const int &spread[]){

   if(CalculatedBars!=prev_calculated){
      CalculateLevels();
      CalculatedBars=prev_calculated;
   }
   //Print(CalculatedBars," ",prev_calculated," ",iBars(Symbol(),SRTimeframe));
   if(iBars(Symbol(),SRTimeframe)<MaxBars+BarsToIgnore){
      MaxBars=iBars(Symbol(),SRTimeframe)-BarsToIgnore;
      Print("Please Load More Historical Candles, Calculation on only ",MaxBars," Bars");
      if(MaxBars<0){
         return(0);
      }
   }
   CalculatedBars=prev_calculated;
   LevelAbove=CalculateLevelAbove();
   LevelBelow=CalculateLevelBelow();
   if(LevelAbove>0) DistanceFromResistance=int((LevelAbove-Close[0])/Point);
   if(LevelBelow>0) DistanceFromSupport=int((Close[0]-LevelBelow)/Point);
   if((DistanceFromResistance>0 && DistanceFromResistance<DistanceFromSupport) || DistanceFromSupport==0) MinDistance=DistanceFromResistance;
   if((DistanceFromSupport>0 && DistanceFromSupport<DistanceFromResistance) || DistanceFromResistance==0) MinDistance=DistanceFromSupport;
   FillBuffers();
   if(EnableNotify){
      Notify();
   }
   if(DrawLinesEnabled) DrawLines();
   if(DrawWindowEnabled) DrawPanel();
   return(rates_total);
}



void OnDeinit(const int reason){
   CleanChart();
}


void CleanChart()
{
   ObjectsDeleteAll(0, IndicatorName);
}


void CalculateLevels(){
   double Highest=iHigh(NULL,SRTimeframe,iHighest(NULL,SRTimeframe,MODE_HIGH,MaxBars,0));
   double Lowest=iLow(NULL,SRTimeframe,iLowest(NULL,SRTimeframe,MODE_LOW,MaxBars,0));
   double Step=NormalizeDouble(iATR(NULL,SRTimeframe,ATRPeriod,0)*SRAccuracy,Digits);
   //Print(Step," ",iATR(NULL,SRTimeframe,ATRPeriod,0)," ",iBars(Symbol(),SRTimeframe));
   if(Step==0){
      Print("Not Enough Historical Data, Please load more candles for the selected timeframe");
      return;
   }
   int Steps=int(MathCeil((Highest-Lowest)/Step)+1);
   double MidRange=MaxRange/2*Point;
   ArrayResize(Array,Steps);
   ArrayInitialize(Array,0);
   //Print(Lowest," ",Highest," ",Step," ",Steps);
   for(int i=0;i<ArraySize(Array);i++){
      double StartRange=Lowest+Step*i;
      double EndRange=Lowest+Step*(i+1);
      if(MidRange>0 && StartRange<Close[0]-MidRange) continue;
      if(MidRange>0 && EndRange>Close[0]+MidRange) continue;
      int BarCount=0;
      double AvgPrice=0;
      double TotalPrice=0;
      Array[i]=0;
      for(int j=BarsToIgnore;j<MaxBars+BarsToIgnore;j++){
         double Fractal=0;
         if(iFractals(NULL,SRTimeframe,MODE_UPPER,j)>0) Fractal=iFractals(NULL,SRTimeframe,MODE_UPPER,j);
         else if(iFractals(NULL,SRTimeframe,MODE_LOWER,j)>0) Fractal=iFractals(NULL,SRTimeframe,MODE_LOWER,j);
         double AvgValue=0;
         //Print(j," ",Fractal," ",StartRange," ",EndRange);
         if(Fractal>=StartRange && Fractal<=EndRange){
            BarCount++;
            AvgValue=Fractal;
            TotalPrice+=AvgValue;
         }
      }
      if(BarCount>0) AvgPrice=NormalizeDouble(TotalPrice/BarCount,Digits);
      //Print(StartRange," ",EndRange," ",BarCount," ",TotalPrice," ",AvgPrice);
      Array[i]=AvgPrice;
   }
}


void FillBuffers(){
   BufferZero[0]=0;;
   BufferOne[0]=0;;
   BufferTwo[0]=0;;
   BufferThree[0]=0;;
   BufferFour[0]=0;;
   BufferFive[0]=0;;
   BufferSix[0]=0;;
   BufferSeven[0]=0;;
   if(FillBuffersWith==LEVELS){
   int j=0;
      for(int i=0;i<ArraySize(Array);i++){
         if(Array[i]>Close[0]){
            if(j==0){
               BufferFour[0]=NormalizeDouble(Array[i],Digits);
            }
            if(j==1){
               BufferFive[0]=NormalizeDouble(Array[i],Digits);
            }
            if(j==2){
               BufferSix[0]=NormalizeDouble(Array[i],Digits);
            }
            if(j==3){
               BufferSeven[0]=NormalizeDouble(Array[i],Digits);
            }
            j++;
            if(j==4) break;
         }
      }
      j=0;
      for(int i=ArraySize(Array)-1;i>=0;i--){
         if(Array[i]>0 && Array[i]<Close[0]){
            if(j==0){
               BufferThree[0]=NormalizeDouble(Array[i],Digits);
            }
            if(j==1){
               BufferTwo[0]=NormalizeDouble(Array[i],Digits);
            }
            if(j==2){
               BufferOne[0]=NormalizeDouble(Array[i],Digits);
            }
            if(j==3){
               BufferZero[0]=NormalizeDouble(Array[i],Digits);
            }
            j++;
            if(j==4) break;
         }
      }
   }
   if(FillBuffersWith==DISTANCES){
      if(MinDistance>0 && MinDistance>SafeDistance) BufferZero[0]=1;
      BufferOne[0]=LevelAbove;
      BufferTwo[0]=LevelBelow;
      BufferThree[0]=DistanceFromResistance;
      BufferFour[0]=DistanceFromSupport;
   }
   //Print(BufferZero[0]," ",BufferOne[0]," ",BufferTwo[0]," ",BufferThree[0]," ",BufferFour[0]," ",BufferFive[0]," ",BufferSix[0]," ",BufferSeven[0]);
}


void Notify(){
   if(!SendAlert && !SendApp && !SendEmail) return;
   if(LastNotificationTime>(TimeCurrent()-NotInterval*60)) return;
   //Print(MinDistance," ",SafeDistance);
   if(WhenNotify==DANGER && MinDistance>SafeDistance) return;
   if(WhenNotify==SAFETY && MinDistance<SafeDistance) return;
   string EmailSubject=IndicatorName+" "+Symbol()+" Notification ";
   string EmailBody="\r\n"+AccountCompany()+" - "+AccountName()+" - "+IntegerToString(AccountNumber())+"\r\n\r\n"+IndicatorName+" Notification for "+Symbol()+"\r\n\r\n";
   if(WhenNotify==DANGER) EmailBody+="The Price is approaching a Support/Resistance Level\r\n\r\n";
   if(WhenNotify==SAFETY) EmailBody+="The Price is at a safe distance from the closest Support/Resistance Level\r\n\r\n";
   string AlertText=IndicatorName+" - "+Symbol()+" Notification\r\n";
   if(WhenNotify==DANGER) AlertText+="Price is in Danger Zone";
   if(WhenNotify==SAFETY) AlertText+="Price is in Safe Zone";
   string AppText=AccountCompany()+" - "+AccountName()+" - "+IntegerToString(AccountNumber())+" - "+IndicatorName+" - "+Symbol()+" - ";
   if(WhenNotify==DANGER) AppText+="Price is in Danger Zone";
   if(WhenNotify==SAFETY) AppText+="Price is in Safe Zone";
   if(SendAlert) Alert(AlertText);
   if(SendEmail){
      if(!SendMail(EmailSubject,EmailBody)) Print("Error sending email "+IntegerToString(GetLastError()));
   }
   if(SendApp){
      if(!SendNotification(AppText)) Print("Error sending notification "+IntegerToString(GetLastError()));
   }
   Notified=true;
   LastNotificationTime=TimeCurrent();
   Print(IndicatorName+"-"+Symbol()+" last notification sent "+TimeToString(LastNotificationTime));
}


void DrawLines(){
   CleanLines();
   for(int i=0;i<ArraySize(Array);i++){
      if(Array[i]>0){
         int LineNumber=int(Array[i]/Point);
         string LineName=StringConcatenate(IndicatorName,"-HLINE-",LineNumber);
         color Color=(Array[i]>Close[0]) ? ResistanceColor : SupportColor;
         ObjectCreate(0,LineName,OBJ_HLINE,0,0,Array[i]);
         ObjectSet(LineName,OBJPROP_COLOR,Color);
         ObjectSet(LineName,OBJPROP_WIDTH,LineThickness);
         ObjectSet(LineName,OBJPROP_SELECTABLE,false);
      }
   }
}


void CleanLines()
{
   ObjectsDeleteAll(0, IndicatorName + "-HLINE-");
}


double CalculateLevelAbove(){
   double Level=0;
   for(int i=0;i<ArraySize(Array);i++){
      if(Array[i]>Close[0]){
         Level=NormalizeDouble(Array[i],Digits);
         break;
      }
   }
   return Level;
}


double CalculateLevelBelow(){
   double Level=0;
   for(int i=ArraySize(Array)-1;i>=0;i--){
      if(Array[i]>0 && Array[i]<Close[0]){
         Level=NormalizeDouble(Array[i],Digits);
         break;
      }
   }
   return Level;
}




string PanelBase=IndicatorName+"-P-BAS";
string PanelLabel=IndicatorName+"-P-LAB";
string PanelDAbove=IndicatorName+"-P-DABOVE";
string PanelDBelow=IndicatorName+"-P-DBELOW";
string PanelSig=IndicatorName+"-P-SIG";

int PanelMovX=26;
int PanelMovY=26;
int PanelLabX=200;
int PanelLabY=PanelMovY;
int PanelRecX=PanelLabX+4;

void DrawPanel(){
//   CleanPanel();
   int Rows=1;
   ObjectCreate(0,PanelBase,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSet(PanelBase,OBJPROP_XDISTANCE,Xoff);
   ObjectSet(PanelBase,OBJPROP_YDISTANCE,Yoff);
   ObjectSetInteger(0,PanelBase,OBJPROP_XSIZE,PanelRecX);
   ObjectSetInteger(0,PanelBase,OBJPROP_YSIZE,(PanelMovY+2)*1+2);
   ObjectSetInteger(0,PanelBase,OBJPROP_BGCOLOR,White);
   ObjectSetInteger(0,PanelBase,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,PanelBase,OBJPROP_STATE,false);
   ObjectSetInteger(0,PanelBase,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,PanelBase,OBJPROP_FONTSIZE,8);
   ObjectSet(PanelBase,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,PanelBase,OBJPROP_COLOR,clrBlack);
      
   ObjectCreate(0,PanelLabel,OBJ_EDIT,0,0,0);
   ObjectSet(PanelLabel,OBJPROP_XDISTANCE,Xoff+2);
   ObjectSet(PanelLabel,OBJPROP_YDISTANCE,Yoff+2);
   ObjectSetInteger(0,PanelLabel,OBJPROP_XSIZE,PanelLabX);
   ObjectSetInteger(0,PanelLabel,OBJPROP_YSIZE,PanelLabY);
   ObjectSetInteger(0,PanelLabel,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,PanelLabel,OBJPROP_STATE,false);
   ObjectSetInteger(0,PanelLabel,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,PanelLabel,OBJPROP_READONLY,true);
   ObjectSetInteger(0,PanelLabel,OBJPROP_ALIGN,ALIGN_CENTER);
   ObjectSetString(0,PanelLabel,OBJPROP_TOOLTIP,"Drag to Move");
   ObjectSetString(0,PanelLabel,OBJPROP_TEXT,"MQLTA SUPP-RES LINES");
   ObjectSetString(0,PanelLabel,OBJPROP_FONT,"Consolas");
   ObjectSetInteger(0,PanelLabel,OBJPROP_FONTSIZE,12);
   ObjectSet(PanelLabel,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,PanelLabel,OBJPROP_COLOR,clrNavy);
   ObjectSetInteger(0,PanelLabel,OBJPROP_BGCOLOR,clrKhaki);
   ObjectSetInteger(0,PanelLabel,OBJPROP_BORDER_COLOR,clrBlack);

   string DAboveText="";
   if(DistanceFromResistance>0){
      DAboveText=StringConcatenate("To Next Resistance: ",DistanceFromResistance," points");
   }
   else{
      DAboveText=StringConcatenate("No Resistance Found");
   }
   ObjectCreate(0,PanelDAbove,OBJ_EDIT,0,0,0);
   ObjectSet(PanelDAbove,OBJPROP_XDISTANCE,Xoff+2);
   ObjectSet(PanelDAbove,OBJPROP_YDISTANCE,Yoff+(PanelMovY+1)*Rows+2);
   ObjectSetInteger(0,PanelDAbove,OBJPROP_XSIZE,PanelLabX);
   ObjectSetInteger(0,PanelDAbove,OBJPROP_YSIZE,PanelLabY);
   ObjectSetInteger(0,PanelDAbove,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,PanelDAbove,OBJPROP_STATE,false);
   ObjectSetInteger(0,PanelDAbove,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,PanelDAbove,OBJPROP_READONLY,true);
   ObjectSetInteger(0,PanelDAbove,OBJPROP_FONTSIZE,8);
   ObjectSetString(0,PanelDAbove,OBJPROP_TOOLTIP,"Distance To The Above Level of Resistance");
   ObjectSetInteger(0,PanelDAbove,OBJPROP_ALIGN,ALIGN_CENTER);
   ObjectSetString(0,PanelDAbove,OBJPROP_FONT,"Consolas");
   ObjectSetString(0,PanelDAbove,OBJPROP_TEXT,DAboveText);
   ObjectSet(PanelDAbove,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,PanelDAbove,OBJPROP_COLOR,clrNavy);
   ObjectSetInteger(0,PanelDAbove,OBJPROP_BGCOLOR,clrKhaki);
   ObjectSetInteger(0,PanelDAbove,OBJPROP_BORDER_COLOR,clrBlack);
   Rows++;
   
   string DBelowText="";
   if(DistanceFromSupport>0){
      DBelowText=StringConcatenate("To Next Support: ",DistanceFromSupport," points");
   }
   else{
      DBelowText=StringConcatenate("No Support Found");
   }
   ObjectCreate(0,PanelDBelow,OBJ_EDIT,0,0,0);
   ObjectSet(PanelDBelow,OBJPROP_XDISTANCE,Xoff+2);
   ObjectSet(PanelDBelow,OBJPROP_YDISTANCE,Yoff+(PanelMovY+1)*Rows+2);
   ObjectSetInteger(0,PanelDBelow,OBJPROP_XSIZE,PanelLabX);
   ObjectSetInteger(0,PanelDBelow,OBJPROP_YSIZE,PanelLabY);
   ObjectSetInteger(0,PanelDBelow,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,PanelDBelow,OBJPROP_STATE,false);
   ObjectSetInteger(0,PanelDBelow,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,PanelDBelow,OBJPROP_READONLY,true);
   ObjectSetInteger(0,PanelDBelow,OBJPROP_FONTSIZE,8);
   ObjectSetString(0,PanelDBelow,OBJPROP_TOOLTIP,"Distance To The Below Level of Support");
   ObjectSetInteger(0,PanelDBelow,OBJPROP_ALIGN,ALIGN_CENTER);
   ObjectSetString(0,PanelDBelow,OBJPROP_FONT,"Consolas");
   ObjectSetString(0,PanelDBelow,OBJPROP_TEXT,DBelowText);
   ObjectSet(PanelDBelow,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,PanelDBelow,OBJPROP_COLOR,clrNavy);
   ObjectSetInteger(0,PanelDBelow,OBJPROP_BGCOLOR,clrKhaki);
   ObjectSetInteger(0,PanelDBelow,OBJPROP_BORDER_COLOR,clrBlack);
   Rows++;

   string SigText="";
   color SigColor=clrNavy;
   color SigBack=clrKhaki;
   if(MinDistance>SafeDistance){
      SigText=StringConcatenate("SAFE TO TRADE");
      SigColor=clrWhite;
      SigBack=clrDarkGreen;
   }
   else{
      SigText=StringConcatenate("WAIT TO TRADE");
      SigColor=clrWhite;
      SigBack=clrDarkRed;
   }
   ObjectCreate(0,PanelSig,OBJ_EDIT,0,0,0);
   ObjectSet(PanelSig,OBJPROP_XDISTANCE,Xoff+2);
   ObjectSet(PanelSig,OBJPROP_YDISTANCE,Yoff+(PanelMovY+1)*Rows+2);
   ObjectSetInteger(0,PanelSig,OBJPROP_XSIZE,PanelLabX);
   ObjectSetInteger(0,PanelSig,OBJPROP_YSIZE,PanelLabY);
   ObjectSetInteger(0,PanelSig,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,PanelSig,OBJPROP_STATE,false);
   ObjectSetInteger(0,PanelSig,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,PanelSig,OBJPROP_READONLY,true);
   ObjectSetInteger(0,PanelSig,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,PanelSig,OBJPROP_ALIGN,ALIGN_CENTER);
   ObjectSetString(0,PanelSig,OBJPROP_FONT,"Consolas");
   ObjectSetString(0,PanelSig,OBJPROP_TOOLTIP,"Suggestion Based On The Safe Distance Set");
   ObjectSetString(0,PanelSig,OBJPROP_TEXT,SigText);
   ObjectSet(PanelSig,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,PanelSig,OBJPROP_COLOR,SigColor);
   ObjectSetInteger(0,PanelSig,OBJPROP_BGCOLOR,SigBack);
   ObjectSetInteger(0,PanelSig,OBJPROP_BORDER_COLOR,clrBlack);
   Rows++;

   
   ObjectSetInteger(0,PanelBase,OBJPROP_XSIZE,PanelRecX);
   ObjectSetInteger(0,PanelBase,OBJPROP_YSIZE,(PanelMovY+1)*Rows+3);
}


void CleanPanel()
{
   ObjectsDeleteAll(0, IndicatorName + "-P-");
}

