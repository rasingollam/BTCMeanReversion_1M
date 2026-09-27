#property copyright "BMR_1m"
#property version   "1.90"
#property description "Trades confirmed ATR-filtered divergences with an EMA expansion filter."

#include <Trade/Trade.mqh>

input group "Indicators"
input int InpFastEMAPeriod = 10;  // Fast EMA period
input int InpSlowEMAPeriod = 20;  // Slow EMA period (width 2)
input int InpDisplayBars   = 300; // Number of bars to draw
input int InpATRPeriod     = 14;  // ATR period for divergence filter
input int InpStochKPeriod  = 5;   // Stochastic %K period
input int InpStochDPeriod  = 3;   // Stochastic %D period
input int InpStochSlowing  = 3;   // Stochastic slowing
input int InpSwingStrength = 2;   // Closed bars on each side of a swing

input group "Trading"
input double InpRiskMoney   = 10.0; // Risk per trade in USD
input double InpRiskReward  = 1.0;  // Reward divided by risk

const string LINE_PREFIX = "BMR_1m_EMA_";
const string DOT_PREFIX = "BMR_1m_Swing_";
const string DIV_PREFIX = "BMR_1m_Divergence_";
int FastHandle = INVALID_HANDLE;
int SlowHandle = INVALID_HANDLE;
int StochHandle = INVALID_HANDLE;
int ATRHandle = INVALID_HANDLE;
int StochWindow = -1;
string StochName = "";
datetime LastBarTime = 0;
datetime LastTradeBarTime = 0;
bool AllowTradeThisBar = false;
CTrade Trade;

void DeleteLines()
{
   ObjectsDeleteAll(0, LINE_PREFIX);
}

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
                        const color line_color)
{
   if(!ObjectCreate(0, name, OBJ_TREND, window, older_time, older_value,
                    newer_time, newer_value))
      return;
   ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void OpenDivergenceTrade(const bool buy, const double swing_stop)
{
   if(!AllowTradeThisBar || PositionSelect(_Symbol))
      return;
   if(AccountInfoString(ACCOUNT_CURRENCY) != "USD")
   {
      Print("Trade skipped: the risk input is in USD, but the account currency is not USD.");
      return;
   }

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;
   const double entry = buy ? tick.ask : tick.bid;
   const double stop = NormalizeDouble(swing_stop, _Digits);
   const double stop_distance = buy ? entry - stop : stop - entry;
   const double broker_distance =
      (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(stop_distance <= 0.0 ||
      (buy && stop >= tick.bid - broker_distance) ||
      (!buy && stop <= tick.ask + broker_distance))
   {
      Print("Trade skipped: swing stop is invalid or too close to market price.");
      return;
   }

   const double take_profit = NormalizeDouble(
      buy ? entry + stop_distance * InpRiskReward
          : entry - stop_distance * InpRiskReward, _Digits);
   if((buy && take_profit <= tick.bid + broker_distance) ||
      (!buy && take_profit >= tick.ask - broker_distance))
   {
      Print("Trade skipped: take profit is too close to market price.");
      return;
   }

   const double min_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double max_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   const double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(min_volume <= 0.0 || max_volume < min_volume || volume_step <= 0.0)
      return;

   const ENUM_ORDER_TYPE order_type = buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double min_volume_profit = 0.0;
   if(!OrderCalcProfit(order_type, _Symbol, min_volume, entry, stop,
                       min_volume_profit) || min_volume_profit >= 0.0)
   {
      PrintFormat("Trade skipped: could not calculate stop loss risk (error %d).",
                  GetLastError());
      return;
   }
   const double raw_volume = InpRiskMoney * min_volume / -min_volume_profit;
   double volume = MathFloor(raw_volume / volume_step + 1e-9) * volume_step;
   volume = MathMin(volume, MathFloor(max_volume / volume_step) * volume_step);
   volume = NormalizeDouble(volume, 8);
   if(volume < min_volume)
   {
      Print("Trade skipped: minimum lot size would exceed the risk amount.");
      return;
   }

   double expected_loss = 0.0;
   if(!OrderCalcProfit(order_type, _Symbol, volume, entry, stop, expected_loss) ||
      expected_loss >= 0.0 || -expected_loss > InpRiskMoney + 0.01)
   {
      Print("Trade skipped: calculated loss exceeds the risk amount.");
      return;
   }

   const bool sent = buy
      ? Trade.Buy(volume, _Symbol, entry, stop, take_profit, "BMR bullish divergence")
      : Trade.Sell(volume, _Symbol, entry, stop, take_profit, "BMR bearish divergence");
   if(!sent || Trade.ResultDeal() == 0)
      PrintFormat("Divergence order failed: %s", Trade.ResultRetcodeDescription());
   else
      PrintFormat("%s divergence trade opened: %.8f lots, SL %.*f, TP %.*f, estimated risk %.2f USD.",
                  buy ? "Bullish" : "Bearish", volume, _Digits, stop,
                  _Digits, take_profit, -expected_loss);
}

bool EMAsExpanding(const bool buy, const double &fast_ema[],
                   const double &slow_ema[])
{
   if(fast_ema[1] == EMPTY_VALUE || fast_ema[2] == EMPTY_VALUE ||
      slow_ema[1] == EMPTY_VALUE || slow_ema[2] == EMPTY_VALUE)
      return false;
   if(buy)
      return fast_ema[1] < slow_ema[1] &&
             fast_ema[1] < fast_ema[2] && slow_ema[1] < slow_ema[2] &&
             slow_ema[1] - fast_ema[1] > slow_ema[2] - fast_ema[2];
   return fast_ema[1] > slow_ema[1] &&
          fast_ema[1] > fast_ema[2] && slow_ema[1] > slow_ema[2] &&
          fast_ema[1] - slow_ema[1] > fast_ema[2] - slow_ema[2];
}

void DrawSwingDots()
{
   ObjectsDeleteAll(0, DOT_PREFIX);
   ObjectsDeleteAll(0, DIV_PREFIX);
   const int count = MathMin(InpDisplayBars + 2 * InpSwingStrength + 1,
                             Bars(_Symbol, PERIOD_CURRENT));
   if(count < 2 * InpSwingStrength + 2)
      return;

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
      return;

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
      return;
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
      return;

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
      if(lows[newer] < lows[older] && stoch[stoch_newer] > stoch[stoch_older] &&
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
         if(MathMin(newer, stoch_newer) == InpSwingStrength + 1 &&
            EMAsExpanding(true, fast_ema, slow_ema))
            OpenDivergenceTrade(true, lows[newer]);
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
      if(highs[newer] > highs[older] && stoch[stoch_newer] < stoch[stoch_older] &&
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
         if(MathMin(newer, stoch_newer) == InpSwingStrength + 1 &&
            EMAsExpanding(false, fast_ema, slow_ema))
            OpenDivergenceTrade(false, highs[newer]);
      }
   }
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

void DrawEMAs()
{
   const int count = MathMin(InpDisplayBars + 1, Bars(_Symbol, PERIOD_CURRENT));
   if(count < MathMax(InpFastEMAPeriod, InpSlowEMAPeriod) + 1)
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
      DrawSwingDots();
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
   if(InpFastEMAPeriod < 1 || InpSlowEMAPeriod < 1 || InpDisplayBars < 2 ||
      InpATRPeriod < 1 ||
      InpStochKPeriod < 1 || InpStochDPeriod < 1 || InpStochSlowing < 1 ||
      InpSwingStrength < 1 || InpRiskMoney <= 0.0 || InpRiskReward <= 0.0)
   {
      Print("Indicator periods and swing strength must be positive; display bars must be at least 2.");
      return INIT_PARAMETERS_INCORRECT;
   }

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
   Trade.SetExpertMagicNumber(110020);
   Trade.SetTypeFillingBySymbol(_Symbol);
   DrawEMAs();
   LastTradeBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   return INIT_SUCCEEDED;
}

void OnTick()
{
   const datetime current_bar = iTime(_Symbol, PERIOD_CURRENT, 0);
   AllowTradeThisBar = (current_bar != 0 && current_bar != LastTradeBarTime);
   DrawEMAs();
   if(LastBarTime == current_bar)
      LastTradeBarTime = current_bar;
   AllowTradeThisBar = false;
}

void OnDeinit(const int reason)
{
   DeleteLines();
   ObjectsDeleteAll(0, DOT_PREFIX);
   ObjectsDeleteAll(0, DIV_PREFIX);
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
