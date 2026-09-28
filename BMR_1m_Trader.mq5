#property version "1.21"
#property description "Trades slow-EMA pullbacks with money risk and a fast-EMA candle-close exit."
#include <Trade/Trade.mqh>

input int InpFastEMAPeriod = 10;
input int InpSlowEMAPeriod = 20;
input int InpSwingStrength = 2;
input int InpLookbackBars = 300;
input double InpRiskMoney = 10.0; // Risk in USD, excluding costs and slippage
input double InpRiskReward = 1.0; // Reward divided by risk
input bool InpEnableTrailingStop = false; // Enable fast EMA candle-close trailing exit
input bool InpReverseDirection = false; // Reverse entries with RR from actual reversed entry
input bool InpReverseKeepNormalLevels = false; // Reverse using exact normal SL/TP levels
input ulong InpMagicNumber = 105003;
input int InpStochKPeriod = 5;
input int InpStochDPeriod = 3;
input int InpStochSlowing = 3;
input double InpOversold = 40.0;   // Buy only below this %K value
input double InpOverbought = 60.0; // Sell only above this %K value
input bool InpUseH1TrendFilter = false; // Require closed H1 EMA alignment and slopes
input bool InpUseStochRecovery = false; // Cross out of oversold/overbought at entry
input bool InpUsePersistenceFilter = false; // Frozen research filter: 32 aligned closed bars
input bool InpDemoOnly = false; // Refuse non-demo accounts outside the tester
input bool InpResearchBreakout = false; // Research: closed-bar Donchian breakout
input int InpBreakoutBars = 20;
input double InpBreakoutStopATR = 2.0;
input bool InpBreakoutTrendFilter = false; // Require EMA alignment and five-bar slow-EMA slope
input bool InpWriteForwardAudit = false; // Write own trade fills/costs to a separate CSV

CTrade Trade;
int FastHandle = INVALID_HANDLE;
int SlowHandle = INVALID_HANDLE;
int StochHandle = INVALID_HANDLE;
int H1FastHandle = INVALID_HANDLE;
int H1SlowHandle = INVALID_HANDLE;
int ATRHandle = INVALID_HANDLE;
datetime LastBar = 0;

int OnInit()
{
   if(InpDemoOnly && !MQLInfoInteger(MQL_TESTER) &&
      AccountInfoInteger(ACCOUNT_TRADE_MODE) != ACCOUNT_TRADE_MODE_DEMO)
      return INIT_FAILED;
   if(InpFastEMAPeriod < 1 || InpSlowEMAPeriod < 1 || InpSwingStrength < 1 ||
      InpLookbackBars < 2 * InpSwingStrength + 3 ||
      InpRiskMoney <= 0 || InpRiskReward <= 0 ||
      InpStochKPeriod < 1 || InpStochDPeriod < 1 || InpStochSlowing < 1 ||
      InpOversold <= 0 || InpOverbought >= 100 || InpOversold >= InpOverbought)
      return INIT_PARAMETERS_INCORRECT;
   if(InpResearchBreakout && (InpBreakoutBars < 2 || InpBreakoutBars >= InpLookbackBars || InpBreakoutStopATR <= 0))
      return INIT_PARAMETERS_INCORRECT;
   ATRHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
   if(ATRHandle == INVALID_HANDLE) return INIT_FAILED;
   FastHandle = iMA(_Symbol, PERIOD_CURRENT, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   SlowHandle = iMA(_Symbol, PERIOD_CURRENT, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   StochHandle = iStochastic(_Symbol, PERIOD_CURRENT, InpStochKPeriod,
                             InpStochDPeriod, InpStochSlowing, MODE_SMA, STO_LOWHIGH);
   if(InpUseH1TrendFilter)
   {
      H1FastHandle = iMA(_Symbol, PERIOD_H1, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      H1SlowHandle = iMA(_Symbol, PERIOD_H1, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(H1FastHandle == INVALID_HANDLE || H1SlowHandle == INVALID_HANDLE)
         return INIT_FAILED;
   }
   if(FastHandle == INVALID_HANDLE || SlowHandle == INVALID_HANDLE ||
      StochHandle == INVALID_HANDLE)
      return INIT_FAILED;
   Trade.SetExpertMagicNumber(InpMagicNumber);
   Trade.SetTypeFillingBySymbol(_Symbol);
   LastBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   PrintFormat("BMR initialized: breakout=%s, trend_filter=%s, demo_only=%s, magic=%I64u, algo_allowed=%s",
      InpResearchBreakout ? "true" : "false", InpBreakoutTrendFilter ? "true" : "false",
      InpDemoOnly ? "true" : "false", InpMagicNumber,
      MQLInfoInteger(MQL_TRADE_ALLOWED) && TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ? "true" : "false");
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
      if(InpEnableTrailingStop &&
         ((buy && last_close < fast_ema) || (!buy && last_close > fast_ema)))
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

void EnterTrade(bool buy, const double swing)
{
   if(InpDemoOnly && !MQLInfoInteger(MQL_TESTER) &&
      AccountInfoInteger(ACCOUNT_TRADE_MODE) != ACCOUNT_TRADE_MODE_DEMO) return;
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
   double entry = buy ? tick.ask : tick.bid;
   const double raw_stop = buy ? swing - spread : swing + spread;
   double stop = NormalizeDouble(
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
   double tp = NormalizeDouble(MathRound(raw_tp / tick_size) * tick_size, _Digits);
   if(buy ? tp <= tick.bid + min_stop : tp >= tick.ask - min_stop)
      return;
   if(InpReverseDirection)
   {
      buy = !buy;
      entry = buy ? tick.ask : tick.bid;
      const double normal_stop = stop;
      stop = tp;
      const double reversed_distance = buy ? entry - stop : stop - entry;
      if(reversed_distance <= 0)
         return;
      const double reversed_tp = buy ? entry + reversed_distance * InpRiskReward
                                    : entry - reversed_distance * InpRiskReward;
      tp = InpReverseKeepNormalLevels ? normal_stop :
           NormalizeDouble(MathRound(reversed_tp / tick_size) * tick_size, _Digits);
      if((buy && (stop >= tick.bid - min_stop || tp <= tick.bid + min_stop)) ||
         (!buy && (stop <= tick.ask + min_stop || tp >= tick.ask - min_stop)))
      {
         Print("Entry skipped: reversed stop/target levels are too close to market.");
         return;
      }
   }
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

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request, const MqlTradeResult &result)
{
   if(!InpWriteForwardAudit || trans.type != TRADE_TRANSACTION_DEAL_ADD ||
      !HistoryDealSelect(trans.deal) || HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol ||
      (ulong)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpMagicNumber) return;
   const string name = StringFormat("BMR_forward_%I64u.csv", InpMagicNumber);
   const int file = FileOpen(name, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ, ',');
   if(file == INVALID_HANDLE) { PrintFormat("Forward audit file error: %d", GetLastError()); return; }
   if(FileSize(file) == 0)
      FileWrite(file, "time", "deal", "position", "entry", "type", "volume", "fill_price",
                "profit", "commission", "swap", "fee", "observed_bid", "observed_ask");
   FileSeek(file, 0, SEEK_END);
   MqlTick quote; SymbolInfoTick(_Symbol, quote);
   FileWrite(file, TimeToString((datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME), TIME_DATE|TIME_SECONDS),
      trans.deal, HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID),
      HistoryDealGetInteger(trans.deal, DEAL_ENTRY), HistoryDealGetInteger(trans.deal, DEAL_TYPE),
      HistoryDealGetDouble(trans.deal, DEAL_VOLUME), HistoryDealGetDouble(trans.deal, DEAL_PRICE),
      HistoryDealGetDouble(trans.deal, DEAL_PROFIT), HistoryDealGetDouble(trans.deal, DEAL_COMMISSION),
      HistoryDealGetDouble(trans.deal, DEAL_SWAP), HistoryDealGetDouble(trans.deal, DEAL_FEE), quote.bid, quote.ask);
   FileFlush(file); FileClose(file);
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
   if(ManagePosition(bars[1].close, fast[1]) || PositionSelect(_Symbol))
   {
      LastBar = current;
      return;
   }
   if(InpResearchBreakout)
   {
      if(count < InpBreakoutBars + 2) return;
      double atr[1];
      if(CopyBuffer(ATRHandle, 0, 1, 1, atr) != 1 || atr[0] <= 0 || atr[0] == EMPTY_VALUE) return;
      LastBar = current;
      double upper = bars[2].high, lower = bars[2].low;
      for(int i = 3; i <= InpBreakoutBars + 1; ++i)
      {
         upper = MathMax(upper, bars[i].high);
         lower = MathMin(lower, bars[i].low);
      }
      const bool trend_buy = !InpBreakoutTrendFilter || (fast[1] > slow[1] && slow[1] > slow[6]);
      const bool trend_sell = !InpBreakoutTrendFilter || (fast[1] < slow[1] && slow[1] < slow[6]);
      if(bars[1].close > upper && trend_buy)
         EnterTrade(true, bars[1].close - InpBreakoutStopATR * atr[0]);
      else if(bars[1].close < lower && trend_sell)
         EnterTrade(false, bars[1].close + InpBreakoutStopATR * atr[0]);
      return;
   }
   double stoch[];
   ArraySetAsSeries(stoch, true);
   if(CopyBuffer(StochHandle, 0, 1, 2, stoch) != 2 ||
      stoch[0] == EMPTY_VALUE || stoch[1] == EMPTY_VALUE)
      return;
   bool allow_buy = true, allow_sell = true;
   if(InpUseH1TrendFilter)
   {
      double h1fast[], h1slow[];
      ArraySetAsSeries(h1fast, true);
      ArraySetAsSeries(h1slow, true);
      if(CopyBuffer(H1FastHandle, 0, 1, 2, h1fast) != 2 ||
         CopyBuffer(H1SlowHandle, 0, 1, 2, h1slow) != 2 ||
         h1fast[0] == EMPTY_VALUE || h1fast[1] == EMPTY_VALUE ||
         h1slow[0] == EMPTY_VALUE || h1slow[1] == EMPTY_VALUE)
         return;
      allow_buy = h1fast[0] > h1slow[0] &&
                  h1fast[0] > h1fast[1] && h1slow[0] > h1slow[1];
      allow_sell = h1fast[0] < h1slow[0] &&
                   h1fast[0] < h1fast[1] && h1slow[0] < h1slow[1];
   }
   const bool stoch_buy = InpUseStochRecovery
      ? stoch[1] < InpOversold && stoch[0] >= InpOversold
      : stoch[0] < InpOversold;
   const bool stoch_sell = InpUseStochRecovery
      ? stoch[1] > InpOverbought && stoch[0] <= InpOverbought
      : stoch[0] > InpOverbought;
   if(InpUsePersistenceFilter)
   {
      if(count < 33) return;
      for(int i = 1; i <= 32; ++i)
      {
         allow_buy = allow_buy && fast[i] > slow[i];
         allow_sell = allow_sell && fast[i] < slow[i];
      }
   }
   LastBar = current;
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
         if(i == 1 && stoch_buy && allow_buy)
            EnterTrade(true, NearestSwing(true, bars, count));
         pending_buy = -1;
      }
      else if(pending_sell >= 0 && bars[i].close < bars[pending_sell].open)
      {
         if(i == 1 && stoch_sell && allow_sell)
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
   if(ATRHandle != INVALID_HANDLE) IndicatorRelease(ATRHandle);
   if(FastHandle != INVALID_HANDLE) IndicatorRelease(FastHandle);
   if(SlowHandle != INVALID_HANDLE) IndicatorRelease(SlowHandle);
   if(StochHandle != INVALID_HANDLE) IndicatorRelease(StochHandle);
   if(H1FastHandle != INVALID_HANDLE) IndicatorRelease(H1FastHandle);
   if(H1SlowHandle != INVALID_HANDLE) IndicatorRelease(H1SlowHandle);
}
