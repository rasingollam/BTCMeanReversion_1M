#property copyright "BMR_1m"
#property version   "1.20"
#property description "Displays two close-price SMAs and a Stochastic oscillator."

input group "Indicators"
input int InpFastSMAPeriod = 10;  // Fast SMA period
input int InpSlowSMAPeriod = 20;  // Slow SMA period (width 2)
input int InpDisplayBars   = 300; // Number of bars to draw
input int InpStochKPeriod  = 5;   // Stochastic %K period
input int InpStochDPeriod  = 3;   // Stochastic %D period
input int InpStochSlowing  = 3;   // Stochastic slowing

const string LINE_PREFIX = "BMR_1m_SMA_";
int FastHandle = INVALID_HANDLE;
int SlowHandle = INVALID_HANDLE;
int StochHandle = INVALID_HANDLE;
int StochWindow = -1;
string StochName = "";
datetime LastBarTime = 0;

void DeleteLines()
{
   ObjectsDeleteAll(0, LINE_PREFIX);
}

void DrawSegment(const string name, const datetime start_time, const double start_price,
                 const datetime end_time, const double end_price,
                 const color line_color, const int line_width)
{
   if(ObjectFind(0, name) < 0 &&
      !ObjectCreate(0, name, OBJ_TREND, 0, start_time, start_price, end_time, end_price))
      return;
   ObjectMove(0, name, 0, start_time, start_price);
   ObjectMove(0, name, 1, end_time, end_price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, line_width);
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void DrawSMAs()
{
   const int count = MathMin(InpDisplayBars + 1, Bars(_Symbol, PERIOD_CURRENT));
   if(count < MathMax(InpFastSMAPeriod, InpSlowSMAPeriod) + 1)
      return;

   datetime times[];
   double fast[];
   double slow[];
   ArraySetAsSeries(times, true);
   ArraySetAsSeries(fast, true);
   ArraySetAsSeries(slow, true);
   if(CopyTime(_Symbol, PERIOD_CURRENT, 0, count, times) != count ||
      CopyBuffer(FastHandle, 0, 0, count, fast) != count ||
      CopyBuffer(SlowHandle, 0, 0, count, slow) != count)
      return;

   const bool new_bar = (times[0] != LastBarTime);
   if(new_bar)
   {
      DeleteLines();
      LastBarTime = times[0];
   }
   const int oldest = new_bar ? count - 2 : 0;
   for(int i = oldest; i >= 0; --i)
   {
      if(fast[i + 1] != EMPTY_VALUE && fast[i] != EMPTY_VALUE)
         DrawSegment(LINE_PREFIX + "Fast_" + IntegerToString(i),
                     times[i + 1], fast[i + 1], times[i], fast[i], clrDodgerBlue, 1);
      if(slow[i + 1] != EMPTY_VALUE && slow[i] != EMPTY_VALUE)
         DrawSegment(LINE_PREFIX + "Slow_" + IntegerToString(i),
                     times[i + 1], slow[i + 1], times[i], slow[i], clrOrange, 2);
   }
   ChartRedraw();
}

int OnInit()
{
   if(InpFastSMAPeriod < 1 || InpSlowSMAPeriod < 1 || InpDisplayBars < 2 ||
      InpStochKPeriod < 1 || InpStochDPeriod < 1 || InpStochSlowing < 1)
   {
      Print("Indicator periods must be positive and display bars must be at least 2.");
      return INIT_PARAMETERS_INCORRECT;
   }

   FastHandle = iMA(_Symbol, PERIOD_CURRENT, InpFastSMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   SlowHandle = iMA(_Symbol, PERIOD_CURRENT, InpSlowSMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   StochHandle = iStochastic(_Symbol, PERIOD_CURRENT, InpStochKPeriod,
                             InpStochDPeriod, InpStochSlowing, MODE_SMA, STO_LOWHIGH);
   if(FastHandle == INVALID_HANDLE || SlowHandle == INVALID_HANDLE ||
      StochHandle == INVALID_HANDLE)
   {
      PrintFormat("Could not create indicator handles (error %d).", GetLastError());
      return INIT_FAILED;
   }
   StochWindow = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
   if(!ChartIndicatorAdd(0, StochWindow, StochHandle))
   {
      PrintFormat("Could not add Stochastic to chart (error %d).", GetLastError());
      return INIT_FAILED;
   }
   StochName = ChartIndicatorName(0, StochWindow,
                                  ChartIndicatorsTotal(0, StochWindow) - 1);
   DrawSMAs();
   return INIT_SUCCEEDED;
}

void OnTick()
{
   DrawSMAs();
}

void OnDeinit(const int reason)
{
   DeleteLines();
   if(StochWindow >= 0 && StochName != "")
      ChartIndicatorDelete(0, StochWindow, StochName);
   if(FastHandle != INVALID_HANDLE)
      IndicatorRelease(FastHandle);
   if(SlowHandle != INVALID_HANDLE)
      IndicatorRelease(SlowHandle);
   if(StochHandle != INVALID_HANDLE)
      IndicatorRelease(StochHandle);
   ChartRedraw();
}
