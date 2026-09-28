#property copyright "BMR_1m"
#property version   "2.40"
#property description "Displays EMAs, Stochastic, swings, and ATR-filtered divergences."
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2
#property indicator_label1  "Fast EMA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumOrchid
#property indicator_width1  1
#property indicator_label2  "Slow EMA"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDarkTurquoise
#property indicator_width2  2

input group "Indicators"
input int InpFastEMAPeriod = 10;  // Fast EMA period
input int InpSlowEMAPeriod = 50;  // Slow EMA period (width 2)
input int InpDisplayBars   = 300; // Number of bars to draw
input int InpATRPeriod     = 14;  // ATR period for divergence filter
input int InpStochKPeriod  = 5;   // Stochastic %K period
input int InpStochDPeriod  = 3;   // Stochastic %D period
input int InpStochSlowing  = 3;   // Stochastic slowing
input int InpSwingStrength = 2;   // Closed bars on each side of a swing

const string DOT_PREFIX = "BMR_1m_Swing_";
const string DIV_PREFIX = "BMR_1m_Divergence_";
const string PULLBACK_PREFIX = "BMR_1m_Pullback_";
double FastEMABuffer[];
double SlowEMABuffer[];
int FastHandle = INVALID_HANDLE;
int SlowHandle = INVALID_HANDLE;
int StochHandle = INVALID_HANDLE;
int ATRHandle = INVALID_HANDLE;
int StochWindow = -1;
string StochName = "";
datetime LastBarTime = 0;
datetime LastPullbackBarTime = 0;

int NearestPivot(const int &pivots[], const int pivot_count,
                 const int target, const int max_distance)
{
   int nearest = -1;
   int best_distance = max_distance + 1;
   for(int i = 0; i < pivot_count; ++i)
   {
      const int distance = MathAbs(pivots[i] - target);
      if(distance < best_distance)
      {
         nearest = pivots[i];
         best_distance = distance;
      }
   }
   return nearest;
}

void DrawDivergenceLine(const string name, const int window,
                        const datetime older_time, const double older_value,
                        const datetime newer_time, const double newer_value,
                        const color line_color,
                        const ENUM_LINE_STYLE line_style = STYLE_DASH)
{
   if(!ObjectCreate(0, name, OBJ_TREND, window, older_time, older_value,
                    newer_time, newer_value))
      return;
   ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_STYLE, line_style);
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

bool DrawSwingDots()
{
   ObjectsDeleteAll(0, DOT_PREFIX);
   ObjectsDeleteAll(0, DIV_PREFIX);
   const int count = MathMin(InpDisplayBars + 2 * InpSwingStrength + 1,
                             Bars(_Symbol, PERIOD_CURRENT));
   if(count < 2 * InpSwingStrength + 2)
      return false;

   datetime times[];
   double highs[];
   double lows[];
   double closes[];
   ArraySetAsSeries(times, true);
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   ArraySetAsSeries(closes, true);
   if(CopyTime(_Symbol, PERIOD_CURRENT, 0, count, times) != count ||
      CopyHigh(_Symbol, PERIOD_CURRENT, 0, count, highs) != count ||
      CopyLow(_Symbol, PERIOD_CURRENT, 0, count, lows) != count ||
      CopyClose(_Symbol, PERIOD_CURRENT, 0, count, closes) != count)
      return false;

   int price_highs[];
   int price_lows[];
   int price_high_count = 0;
   int price_low_count = 0;
   ArrayResize(price_highs, count);
   ArrayResize(price_lows, count);
   for(int i = InpSwingStrength + 1;
       i < count - InpSwingStrength && i <= InpDisplayBars; ++i)
   {
      bool swing_high = true;
      bool swing_low = true;
      for(int j = 1; j <= InpSwingStrength; ++j)
      {
         if(highs[i] <= highs[i - j] || highs[i] <= highs[i + j])
            swing_high = false;
         if(lows[i] >= lows[i - j] || lows[i] >= lows[i + j])
            swing_low = false;
      }
      if(swing_high)
      {
         price_highs[price_high_count++] = i;
         const string name = DOT_PREFIX + "High_" + IntegerToString((long)times[i]);
         if(ObjectCreate(0, name, OBJ_TEXT, 0, times[i], highs[i]))
         {
            ObjectSetString(0, name, OBJPROP_TEXT, ShortToString(0x25CF));
            ObjectSetString(0, name, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
            ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
         }
      }
      if(swing_low)
      {
         price_lows[price_low_count++] = i;
         const string name = DOT_PREFIX + "Low_" + IntegerToString((long)times[i]);
         if(ObjectCreate(0, name, OBJ_TEXT, 0, times[i], lows[i]))
         {
            ObjectSetString(0, name, OBJPROP_TEXT, ShortToString(0x25CF));
            ObjectSetString(0, name, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
            ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrLime);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
         }
      }
   }

   double stoch[];
   ArraySetAsSeries(stoch, true);
   if(StochWindow < 0 || CopyBuffer(StochHandle, 0, 0, count, stoch) != count)
      return false;
   int stoch_highs[];
   int stoch_lows[];
   int stoch_high_count = 0;
   int stoch_low_count = 0;
   ArrayResize(stoch_highs, count);
   ArrayResize(stoch_lows, count);
   for(int i = InpSwingStrength + 1;
       i < count - InpSwingStrength && i <= InpDisplayBars; ++i)
   {
      if(stoch[i] == EMPTY_VALUE)
         continue;
      bool swing_high = true;
      bool swing_low = true;
      for(int j = 1; j <= InpSwingStrength; ++j)
      {
         if(stoch[i - j] == EMPTY_VALUE || stoch[i + j] == EMPTY_VALUE)
         {
            swing_high = false;
            swing_low = false;
            break;
         }
         if(stoch[i] <= stoch[i - j] || stoch[i] <= stoch[i + j])
            swing_high = false;
         if(stoch[i] >= stoch[i - j] || stoch[i] >= stoch[i + j])
            swing_low = false;
      }
      if(!swing_high && !swing_low)
         continue;
      if(swing_high)
         stoch_highs[stoch_high_count++] = i;
      if(swing_low)
         stoch_lows[stoch_low_count++] = i;
      const string name = DOT_PREFIX + "Stoch_" +
                          (swing_high ? "High_" : "Low_") +
                          IntegerToString((long)times[i]);
      if(ObjectCreate(0, name, OBJ_TEXT, StochWindow, times[i], stoch[i]))
      {
         ObjectSetString(0, name, OBJPROP_TEXT, ShortToString(0x25CF));
         ObjectSetString(0, name, OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
         ObjectSetInteger(0, name, OBJPROP_COLOR, swing_high ? clrRed : clrLime);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      }
   }

   double fast_ema[];
   double slow_ema[];
   double atr[];
   ArraySetAsSeries(fast_ema, true);
   ArraySetAsSeries(slow_ema, true);
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(FastHandle, 0, 0, count, fast_ema) != count ||
      CopyBuffer(SlowHandle, 0, 0, count, slow_ema) != count ||
      CopyBuffer(ATRHandle, 0, 0, count, atr) != count)
      return false;

   const int match_distance = InpSwingStrength;
   for(int p = 0; p + 1 < price_low_count; ++p)
   {
      const int newer = price_lows[p];
      const int older = price_lows[p + 1];
      const int stoch_newer = NearestPivot(stoch_lows, stoch_low_count,
                                           newer, match_distance);
      const int stoch_older = NearestPivot(stoch_lows, stoch_low_count,
                                           older, match_distance);
      if(stoch_newer < 0 || stoch_older < 0 || stoch_newer >= stoch_older)
         continue;
      if(fast_ema[newer] > slow_ema[newer] &&
         lows[newer] < lows[older] && stoch[stoch_newer] > stoch[stoch_older] &&
         atr[newer] > 0.0 && atr[newer] != EMPTY_VALUE &&
         fast_ema[newer] != EMPTY_VALUE && slow_ema[newer] != EMPTY_VALUE &&
         closes[newer] < fast_ema[newer] - atr[newer] &&
         closes[newer] < slow_ema[newer] - atr[newer])
      {
         const string id = IntegerToString((long)times[newer]);
         DrawDivergenceLine(DIV_PREFIX + "BullPrice_" + id, 0,
                            times[older], lows[older], times[newer], lows[newer],
                            clrLime);
         DrawDivergenceLine(DIV_PREFIX + "BullStoch_" + id, StochWindow,
                            times[stoch_older], stoch[stoch_older],
                            times[stoch_newer], stoch[stoch_newer], clrLime);
      }
      if(fast_ema[newer] != EMPTY_VALUE && slow_ema[newer] != EMPTY_VALUE &&
         fast_ema[newer] > slow_ema[newer] &&
         lows[newer] > lows[older] && stoch[stoch_newer] < stoch[stoch_older])
      {
         const string id = IntegerToString((long)times[newer]);
         DrawDivergenceLine(DIV_PREFIX + "ContinuationBullPrice_" + id, 0,
                            times[older], lows[older], times[newer], lows[newer],
                            clrLime, STYLE_DOT);
         DrawDivergenceLine(DIV_PREFIX + "ContinuationBullStoch_" + id, StochWindow,
                            times[stoch_older], stoch[stoch_older],
                            times[stoch_newer], stoch[stoch_newer], clrLime, STYLE_DOT);
      }
   }
   for(int p = 0; p + 1 < price_high_count; ++p)
   {
      const int newer = price_highs[p];
      const int older = price_highs[p + 1];
      const int stoch_newer = NearestPivot(stoch_highs, stoch_high_count,
                                           newer, match_distance);
      const int stoch_older = NearestPivot(stoch_highs, stoch_high_count,
                                           older, match_distance);
      if(stoch_newer < 0 || stoch_older < 0 || stoch_newer >= stoch_older)
         continue;
      if(fast_ema[newer] < slow_ema[newer] &&
         highs[newer] > highs[older] && stoch[stoch_newer] < stoch[stoch_older] &&
         atr[newer] > 0.0 && atr[newer] != EMPTY_VALUE &&
         fast_ema[newer] != EMPTY_VALUE && slow_ema[newer] != EMPTY_VALUE &&
         closes[newer] > fast_ema[newer] + atr[newer] &&
         closes[newer] > slow_ema[newer] + atr[newer])
      {
         const string id = IntegerToString((long)times[newer]);
         DrawDivergenceLine(DIV_PREFIX + "BearPrice_" + id, 0,
                            times[older], highs[older], times[newer], highs[newer],
                            clrRed);
         DrawDivergenceLine(DIV_PREFIX + "BearStoch_" + id, StochWindow,
                            times[stoch_older], stoch[stoch_older],
                            times[stoch_newer], stoch[stoch_newer], clrRed);
      }
      if(fast_ema[newer] != EMPTY_VALUE && slow_ema[newer] != EMPTY_VALUE &&
         fast_ema[newer] < slow_ema[newer] &&
         highs[newer] < highs[older] && stoch[stoch_newer] > stoch[stoch_older])
      {
         const string id = IntegerToString((long)times[newer]);
         DrawDivergenceLine(DIV_PREFIX + "ContinuationBearPrice_" + id, 0,
                            times[older], highs[older], times[newer], highs[newer],
                            clrRed, STYLE_DOT);
         DrawDivergenceLine(DIV_PREFIX + "ContinuationBearStoch_" + id, StochWindow,
                            times[stoch_older], stoch[stoch_older],
                            times[stoch_newer], stoch[stoch_newer], clrRed, STYLE_DOT);
      }
   }

   // Check the newest closed candles before they have enough right-hand bars
   // to become confirmed swings. These provisional lines are recalculated
   // on each new bar and are replaced by confirmed lines when eligible.
   for(int i = 1; i <= InpSwingStrength && i + InpSwingStrength < count; ++i)
   {
      if(stoch[i] == EMPTY_VALUE || atr[i] == EMPTY_VALUE || atr[i] <= 0.0 ||
         fast_ema[i] == EMPTY_VALUE || slow_ema[i] == EMPTY_VALUE)
         continue;

      bool new_low = true;
      bool new_high = true;
      for(int j = 1; j <= InpSwingStrength; ++j)
      {
         if(lows[i] >= lows[i + j])
            new_low = false;
         if(highs[i] <= highs[i + j])
            new_high = false;
      }

      if(new_low && fast_ema[i] > slow_ema[i] &&
         closes[i] < fast_ema[i] - atr[i] &&
         closes[i] < slow_ema[i] - atr[i])
      {
         int previous = -1;
         for(int p = 0; p < price_low_count; ++p)
         {
            if(price_lows[p] > i + InpSwingStrength)
            {
               previous = price_lows[p];
               break;
            }
         }
         if(previous >= 0)
         {
            const int stoch_previous = NearestPivot(stoch_lows, stoch_low_count,
                                                    previous, match_distance);
            if(stoch_previous >= 0 && lows[i] < lows[previous] &&
               stoch[i] > stoch[stoch_previous])
            {
               const string id = IntegerToString((long)times[i]);
               DrawDivergenceLine(DIV_PREFIX + "EarlyBullPrice_" + id, 0,
                                  times[previous], lows[previous], times[i], lows[i],
                                  clrLime);
               DrawDivergenceLine(DIV_PREFIX + "EarlyBullStoch_" + id, StochWindow,
                                  times[stoch_previous], stoch[stoch_previous],
                                  times[i], stoch[i], clrLime);
            }
         }
      }

      if(new_high && fast_ema[i] < slow_ema[i] &&
         closes[i] > fast_ema[i] + atr[i] &&
         closes[i] > slow_ema[i] + atr[i])
      {
         int previous = -1;
         for(int p = 0; p < price_high_count; ++p)
         {
            if(price_highs[p] > i + InpSwingStrength)
            {
               previous = price_highs[p];
               break;
            }
         }
         if(previous >= 0)
         {
            const int stoch_previous = NearestPivot(stoch_highs, stoch_high_count,
                                                    previous, match_distance);
            if(stoch_previous >= 0 && highs[i] > highs[previous] &&
               stoch[i] < stoch[stoch_previous])
            {
               const string id = IntegerToString((long)times[i]);
               DrawDivergenceLine(DIV_PREFIX + "EarlyBearPrice_" + id, 0,
                                  times[previous], highs[previous], times[i], highs[i],
                                  clrRed);
               DrawDivergenceLine(DIV_PREFIX + "EarlyBearStoch_" + id, StochWindow,
                                  times[stoch_previous], stoch[stoch_previous],
                                  times[i], stoch[i], clrRed);
            }
         }
      }
   }
   return true;
}

void DrawPullbacks(const bool reset)
{
   const int count = MathMin(InpDisplayBars + 1, Bars(_Symbol, PERIOD_CURRENT));
   MqlRates bars[];
   double fast[];
   double slow[];
   ArraySetAsSeries(bars, true);
   ArraySetAsSeries(fast, true);
   ArraySetAsSeries(slow, true);
   if(count < 2 || CopyRates(_Symbol, PERIOD_CURRENT, 0, count, bars) != count ||
      CopyBuffer(FastHandle, 0, 0, count, fast) != count ||
      CopyBuffer(SlowHandle, 0, 0, count, slow) != count)
      return;
   if(reset || bars[0].time != LastPullbackBarTime)
   {
      ObjectsDeleteAll(0, PULLBACK_PREFIX);
      LastPullbackBarTime = bars[0].time;
   }
   int pending_buy = -1;
   int pending_sell = -1;
   for(int i = count - 1; i >= 0; --i)
   {
      if(fast[i] == EMPTY_VALUE || slow[i] == EMPTY_VALUE)
         continue;
      const bool bullish = fast[i] > slow[i];
      const bool bearish = fast[i] < slow[i];
      if(!bullish)
         pending_buy = -1;
      if(!bearish)
         pending_sell = -1;

      int confirmed = -1;
      int setup = -1;
      bool buy = false;
      if(i > 0 && pending_buy >= 0 && bars[i].close > bars[pending_buy].open)
      {
         confirmed = i;
         setup = pending_buy;
         buy = true;
         pending_buy = -1;
      }
      else if(i > 0 && pending_sell >= 0 && bars[i].close < bars[pending_sell].open)
      {
         confirmed = i;
         setup = pending_sell;
         pending_sell = -1;
      }
      if(confirmed >= 0)
      {
         const string name = PULLBACK_PREFIX + (buy ? "Buy_" : "Sell_") +
                             IntegerToString((long)bars[confirmed].time);
         const int half_bar = MathMax(1, PeriodSeconds(PERIOD_CURRENT) / 2);
         if(ObjectFind(0, name) < 0 &&
            ObjectCreate(0, name, OBJ_RECTANGLE, 0,
                         bars[setup].time - half_bar, bars[setup].open,
                         bars[confirmed].time + half_bar, bars[confirmed].close))
         {
            ObjectSetInteger(0, name, OBJPROP_COLOR, buy ? clrDarkGreen : clrDarkRed);
            ObjectSetInteger(0, name, OBJPROP_FILL, true);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
         }
      }
      // A setup candle must close before a subsequent candle can break its open.
      if(i > 0 && bars[i].low <= slow[i] && bars[i].high >= slow[i])
      {
         if(bullish && bars[i].close < bars[i].open)
            pending_buy = i;
         else if(bearish && bars[i].close > bars[i].open)
            pending_sell = i;
      }
   }
}

int OnInit()
{
   if(InpFastEMAPeriod < 1 || InpSlowEMAPeriod < 1 || InpDisplayBars < 2 ||
      InpATRPeriod < 1 ||
      InpStochKPeriod < 1 || InpStochDPeriod < 1 || InpStochSlowing < 1 ||
      InpSwingStrength < 1)
   {
      Print("Indicator periods and swing strength must be positive; display bars must be at least 2.");
      return INIT_PARAMETERS_INCORRECT;
   }

   SetIndexBuffer(0, FastEMABuffer, INDICATOR_DATA);
   SetIndexBuffer(1, SlowEMABuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpFastEMAPeriod - 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpSlowEMAPeriod - 1);
   IndicatorSetString(INDICATOR_SHORTNAME, "BMR_1m");

   FastHandle = iMA(_Symbol, PERIOD_CURRENT, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   SlowHandle = iMA(_Symbol, PERIOD_CURRENT, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   ATRHandle = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   StochHandle = iStochastic(_Symbol, PERIOD_CURRENT, InpStochKPeriod,
                             InpStochDPeriod, InpStochSlowing, MODE_SMA, STO_LOWHIGH);
   if(FastHandle == INVALID_HANDLE || SlowHandle == INVALID_HANDLE ||
      StochHandle == INVALID_HANDLE || ATRHandle == INVALID_HANDLE)
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
   return INIT_SUCCEEDED;
}

int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[], const double &high[],
                const double &low[], const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
{
   if(rates_total < MathMax(InpFastEMAPeriod, InpSlowEMAPeriod))
      return 0;
   if(CopyBuffer(FastHandle, 0, 0, rates_total, FastEMABuffer) != rates_total ||
      CopyBuffer(SlowHandle, 0, 0, rates_total, SlowEMABuffer) != rates_total)
      return prev_calculated;

   const datetime current_bar = iTime(_Symbol, PERIOD_CURRENT, 0);
   DrawPullbacks(prev_calculated == 0);
   if(current_bar != 0 && current_bar != LastBarTime)
   {
      if(DrawSwingDots())
         LastBarTime = current_bar;
   }
   return rates_total;
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, DOT_PREFIX);
   ObjectsDeleteAll(0, DIV_PREFIX);
   ObjectsDeleteAll(0, PULLBACK_PREFIX);
   if(StochWindow >= 0 && StochName != "")
      ChartIndicatorDelete(0, StochWindow, StochName);
   if(FastHandle != INVALID_HANDLE)
      IndicatorRelease(FastHandle);
   if(SlowHandle != INVALID_HANDLE)
      IndicatorRelease(SlowHandle);
   if(StochHandle != INVALID_HANDLE)
      IndicatorRelease(StochHandle);
   if(ATRHandle != INVALID_HANDLE)
      IndicatorRelease(ATRHandle);
   ChartRedraw();
}
