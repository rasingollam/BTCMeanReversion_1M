#property version "1.00"
#property description "Trades slow-EMA pullbacks with money risk and a fast-EMA candle-close exit."
#include <Trade/Trade.mqh>

input int InpFastEMAPeriod = 10;
input int InpSlowEMAPeriod = 50;
input int InpSwingStrength = 2;
input int InpLookbackBars = 300;
input double InpRiskMoney = 10.0; // Risk in USD, excluding costs and slippage
input double InpRiskReward = 3.0; // Reward divided by risk
input ulong InpMagicNumber = 105003;

CTrade Trade;
int FastHandle = INVALID_HANDLE;
int SlowHandle = INVALID_HANDLE;
datetime LastBar = 0;

int OnInit()
{
   if(InpFastEMAPeriod < 1 || InpSlowEMAPeriod < 1 || InpSwingStrength < 1 ||
      InpLookbackBars < 2 * InpSwingStrength + 3 ||
      InpRiskMoney <= 0 || InpRiskReward <= 0)
      return INIT_PARAMETERS_INCORRECT;
   FastHandle = iMA(_Symbol, PERIOD_CURRENT, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   SlowHandle = iMA(_Symbol, PERIOD_CURRENT, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(FastHandle == INVALID_HANDLE || SlowHandle == INVALID_HANDLE)
      return INIT_FAILED;
   Trade.SetExpertMagicNumber(InpMagicNumber);
   Trade.SetTypeFillingBySymbol(_Symbol);
   LastBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   return INIT_SUCCEEDED;
}

bool ManagePosition(const double last_close, const double fast_ema)
{
   bool found = false;
   for(int p = PositionsTotal() - 1; p >= 0; --p)
   {
      const ulong ticket = PositionGetTicket(p);
      if(ticket == 0 || PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      found = true;
      const bool buy = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
      // Virtual EMA trailing exit: wick crossings do not trigger this exit.
      if((buy && last_close < fast_ema) || (!buy && last_close > fast_ema))
      {
         if(!Trade.PositionClose(ticket) ||
            Trade.ResultRetcode() != TRADE_RETCODE_DONE)
            PrintFormat("EMA close failed: %s", Trade.ResultRetcodeDescription());
      }
   }
   return found;
}

double NearestSwing(const bool buy, const MqlRates &bars[], const int count)
{
   // The swing must already be confirmed when the break candle closes.
   for(int i = InpSwingStrength + 1; i + InpSwingStrength < count; ++i)
   {
      bool pivot = true;
      for(int j = 1; j <= InpSwingStrength; ++j)
      {
         if(buy ? (bars[i].low >= bars[i-j].low || bars[i].low >= bars[i+j].low)
                : (bars[i].high <= bars[i-j].high || bars[i].high <= bars[i+j].high))
         {
            pivot = false;
            break;
         }
      }
      if(pivot)
         return buy ? bars[i].low : bars[i].high;
   }
   return 0.0;
}

void EnterTrade(const bool buy, const double swing)
{
   if(PositionSelect(_Symbol) || swing <= 0)
      return;
   if(AccountInfoString(ACCOUNT_CURRENCY) != "USD")
   {
      Print("Entry skipped: money risk is USD; a USD account is required.");
      return;
   }
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;
   const double spread = tick.ask - tick.bid;
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0)
      return;
   const double entry = buy ? tick.ask : tick.bid;
   const double raw_stop = buy ? swing - spread : swing + spread;
   const double stop = NormalizeDouble(
      (buy ? MathFloor(raw_stop / tick_size) : MathCeil(raw_stop / tick_size)) *
      tick_size, _Digits);
   const double distance = buy ? entry - stop : stop - entry;
   const double min_stop = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(distance <= 0 || (buy ? stop >= tick.bid - min_stop : stop <= tick.ask + min_stop))
   {
      Print("Entry skipped: nearest swing stop is not valid at current prices.");
      return;
   }
   const double raw_tp = buy ? entry + distance * InpRiskReward
                            : entry - distance * InpRiskReward;
   const double tp = NormalizeDouble(MathRound(raw_tp / tick_size) * tick_size, _Digits);
   if(buy ? tp <= tick.bid + min_stop : tp >= tick.ask - min_stop)
      return;
   const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   const double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   const ENUM_ORDER_TYPE type = buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double loss = 0;
   if(min_lot <= 0 || step <= 0 ||
      !OrderCalcProfit(type, _Symbol, min_lot, entry, stop, loss) || loss >= 0)
      return;
   double lots = MathFloor((InpRiskMoney * min_lot / -loss) / step + 1e-9) * step;
   lots = NormalizeDouble(MathMin(lots, MathFloor(max_lot / step) * step), 8);
   if(lots < min_lot)
   {
      Print("Entry skipped: minimum lot would exceed the risk budget.");
      return;
   }
   if(!OrderCalcProfit(type, _Symbol, lots, entry, stop, loss) ||
      loss >= 0 || -loss > InpRiskMoney + 0.01)
      return;
   const bool sent = buy ? Trade.Buy(lots, _Symbol, entry, stop, tp, "BMR pullback buy")
                         : Trade.Sell(lots, _Symbol, entry, stop, tp, "BMR pullback sell");
   if(!sent || Trade.ResultDeal() == 0)
      PrintFormat("Pullback entry failed: %s", Trade.ResultRetcodeDescription());
   else
      PrintFormat("Pullback entry: %.8f lots, estimated SL risk %.2f USD.", lots, -loss);
}

void OnTick()
{
   const datetime current = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(current == 0 || current == LastBar)
      return;
   const int count = MathMin(InpLookbackBars + 1, Bars(_Symbol, PERIOD_CURRENT));
   MqlRates bars[];
   double fast[], slow[];
   ArraySetAsSeries(bars, true);
   ArraySetAsSeries(fast, true);
   ArraySetAsSeries(slow, true);
   if(count < 2 * InpSwingStrength + 3 ||
      CopyRates(_Symbol, PERIOD_CURRENT, 0, count, bars) != count ||
      CopyBuffer(FastHandle, 0, 0, count, fast) != count ||
      CopyBuffer(SlowHandle, 0, 0, count, slow) != count)
      return;
   LastBar = current;
   if(ManagePosition(bars[1].close, fast[1]) || PositionSelect(_Symbol))
      return;
   int pending_buy = -1, pending_sell = -1;
   for(int i = count - 1; i >= 1; --i)
   {
      if(fast[i] == EMPTY_VALUE || slow[i] == EMPTY_VALUE)
         continue;
      const bool bullish = fast[i] > slow[i];
      const bool bearish = fast[i] < slow[i];
      if(!bullish) pending_buy = -1;
      if(!bearish) pending_sell = -1;
      if(pending_buy >= 0 && bars[i].close > bars[pending_buy].open)
      {
         if(i == 1)
            EnterTrade(true, NearestSwing(true, bars, count));
         pending_buy = -1;
      }
      else if(pending_sell >= 0 && bars[i].close < bars[pending_sell].open)
      {
         if(i == 1)
            EnterTrade(false, NearestSwing(false, bars, count));
         pending_sell = -1;
      }
      if(bars[i].low <= slow[i] && bars[i].high >= slow[i])
      {
         if(bullish && bars[i].close < bars[i].open) pending_buy = i;
         else if(bearish && bars[i].close > bars[i].open) pending_sell = i;
      }
   }
}

void OnDeinit(const int reason)
{
   if(FastHandle != INVALID_HANDLE) IndicatorRelease(FastHandle);
   if(SlowHandle != INVALID_HANDLE) IndicatorRelease(SlowHandle);
}
