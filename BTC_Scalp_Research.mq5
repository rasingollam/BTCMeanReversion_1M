#property version "1.21"
#property description "BTC scalping research: closed-bar signals, capped money risk, no averaging."
#include <Trade/Trade.mqh>
enum SCALP_RULE { CHANNEL_BREAKOUT=0, RANGE_REVERSION=1, TREND_PULLBACK=2, BAND_REENTRY=3, CHANNEL_FADE=4, SWEEP_REJECTION=5 };
input SCALP_RULE InpRule=CHANNEL_BREAKOUT;
input double InpRiskMoney=10.0;
input double InpRR=1.5;
input double InpStopATR=1.5;
input double InpMinATRSpread=8.0;
input int InpMaxHoldMinutes=45;
input bool InpDemoOnly=true;
input ulong InpMagic=109001;
input bool InpUseTimeWindow=true;
input int InpStartHour=13; // MT5 broker-server hour, inclusive
input int InpEndHour=17; // MT5 broker-server hour, exclusive; 24 allowed
input int InpMaxTradesPerDay=2; // Hard ceiling: at most two successful entries
input bool InpShowChartObjects=false; // Optional dashboard, signals and trade levels
CTrade trade;
int atrH,fastH,slowH,bandsH,rsiH,adxH;
datetime lastBar=0;
#include "BTC_Scalp_Visuals.mqh"
int OnInit()
{
 if(InpRiskMoney<=0 || InpRR<=0 || InpStopATR<=0 || InpMinATRSpread<=0 || InpMaxHoldMinutes<1) return INIT_PARAMETERS_INCORRECT;
 if(InpMaxTradesPerDay<1 || InpMaxTradesPerDay>2 || InpStartHour<0 || InpStartHour>23 ||
    InpEndHour<0 || InpEndHour>24 || (InpUseTimeWindow && InpStartHour==InpEndHour)) return INIT_PARAMETERS_INCORRECT;
 if(InpDemoOnly && !MQLInfoInteger(MQL_TESTER) && AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_DEMO) return INIT_FAILED;
 atrH=iATR(_Symbol,PERIOD_CURRENT,14);
 fastH=iMA(_Symbol,PERIOD_CURRENT,20,0,MODE_EMA,PRICE_CLOSE);
 slowH=iMA(_Symbol,PERIOD_CURRENT,50,0,MODE_EMA,PRICE_CLOSE);
 bandsH=iBands(_Symbol,PERIOD_CURRENT,20,0,2.0,PRICE_CLOSE);
 rsiH=iRSI(_Symbol,PERIOD_CURRENT,14,PRICE_CLOSE);
 adxH=iADX(_Symbol,PERIOD_CURRENT,14);
 if(atrH==INVALID_HANDLE || fastH==INVALID_HANDLE || slowH==INVALID_HANDLE || bandsH==INVALID_HANDLE || rsiH==INVALID_HANDLE || adxH==INVALID_HANDLE) return INIT_FAILED;
 trade.SetExpertMagicNumber(InpMagic);trade.SetTypeFillingBySymbol(_Symbol);
 lastBar=iTime(_Symbol,PERIOD_CURRENT,0);
 if(VisualEnabled()){EventSetTimer(5);RefreshVisuals();}
 return INIT_SUCCEEDED;
}
bool Read(const int handle,const int buffer,double &values[])
{
 ArraySetAsSeries(values,true);
 return CopyBuffer(handle,buffer,1,3,values)==3 && values[0]!=EMPTY_VALUE && values[2]!=EMPTY_VALUE;
}
bool EntryWindowOpen()
{
 if(!InpUseTimeWindow)return true;
 MqlDateTime clock;TimeToStruct(TimeCurrent(),clock);
 if(InpStartHour<InpEndHour)return clock.hour>=InpStartHour && clock.hour<InpEndHour;
 return clock.hour>=InpStartHour || clock.hour<InpEndHour;
}
int EntriesToday()
{
 // Broker-date history survives EA/chart/terminal restarts. Count orders,
 // not deals, so partial fills of a single entry consume one slot.
 MqlDateTime clock;TimeToStruct(TimeCurrent(),clock);clock.hour=0;clock.min=0;clock.sec=0;
 if(!HistorySelect(StructToTime(clock),TimeCurrent()))return InpMaxTradesPerDay;
 ulong orders[];int count=0;
 for(int i=0;i<HistoryDealsTotal();++i)
 {
  ulong deal=HistoryDealGetTicket(i);
  if(deal==0 || HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol ||
     (ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagic)continue;
  long entry=HistoryDealGetInteger(deal,DEAL_ENTRY);
  if(entry!=DEAL_ENTRY_IN && entry!=DEAL_ENTRY_INOUT)continue;
  ulong order=(ulong)HistoryDealGetInteger(deal,DEAL_ORDER);bool seen=false;
  for(int j=0;j<count;++j)if(orders[j]==order){seen=true;break;}
  if(!seen){ArrayResize(orders,count+1);orders[count++]=order;}
 }
 return count;
}
void Open(const bool buy,const double atr)
{
 if(!EntryWindowOpen() || EntriesToday()>=InpMaxTradesPerDay)return;
 if(PositionSelect(_Symbol) || AccountInfoString(ACCOUNT_CURRENCY)!="USD") return;
 if(InpDemoOnly && !MQLInfoInteger(MQL_TESTER) && AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_DEMO) return;
 MqlTick tick;if(!SymbolInfoTick(_Symbol,tick))return;
 double spread=tick.ask-tick.bid;
 if(spread<=0 || atr/spread<InpMinATRSpread)return;
 double size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
 double minimum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
 if(size<=0 || minimum<=0 || step<=0)return;
 double entry=buy?tick.ask:tick.bid;
 double raw=buy?entry-InpStopATR*atr:entry+InpStopATR*atr;
 double stop=NormalizeDouble((buy?MathFloor(raw/size):MathCeil(raw/size))*size,_Digits);
 double distance=MathAbs(entry-stop),limit=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
 if(distance<=0 || (buy?stop>=tick.bid-limit:stop<=tick.ask+limit))return;
 double target=NormalizeDouble(MathRound((buy?entry+distance*InpRR:entry-distance*InpRR)/size)*size,_Digits);
 if(buy?target<=tick.bid+limit:target>=tick.ask-limit)return;
 ENUM_ORDER_TYPE type=buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
 double loss;
 if(!OrderCalcProfit(type,_Symbol,minimum,entry,stop,loss) || loss>=0)return;
 double lots=NormalizeDouble(MathFloor(InpRiskMoney*minimum/-loss/step+1e-9)*step,8);
 lots=MathMin(lots,MathFloor(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX)/step)*step);
 if(lots<minimum || !OrderCalcProfit(type,_Symbol,lots,entry,stop,loss) || loss>=0 || -loss>InpRiskMoney+0.01)return;
 bool sent=buy?trade.Buy(lots,_Symbol,entry,stop,target,"BTC scalp research"):trade.Sell(lots,_Symbol,entry,stop,target,"BTC scalp research");
 if(!sent || trade.ResultDeal()==0)PrintFormat("Scalp entry failed: %s",trade.ResultRetcodeDescription());
}
void OnTick()
{
 // Time exits evaluated on ticks; protective SL/TP remain on the broker.
 if(PositionSelect(_Symbol))
 {
  lastBar=iTime(_Symbol,PERIOD_CURRENT,0);
  if((ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic && TimeCurrent()-PositionGetInteger(POSITION_TIME)>=InpMaxHoldMinutes*60)
   if(!trade.PositionClose(_Symbol))Print("Scalp time exit failed");
  return;
 }
 datetime now=iTime(_Symbol,PERIOD_CURRENT,0);if(now==0 || now==lastBar)return;
 MqlRates bars[];ArraySetAsSeries(bars,true);
 double atr[],fast[],slow[],upper[],lower[],rsi[],adx[];
 if(CopyRates(_Symbol,PERIOD_CURRENT,0,60,bars)!=60 || !Read(atrH,0,atr) || atr[0]<=0 ||
    !Read(fastH,0,fast) || !Read(slowH,0,slow) || !Read(bandsH,1,upper) || !Read(bandsH,2,lower) ||
    !Read(rsiH,0,rsi) || !Read(adxH,0,adx))return;
 lastBar=now;
 bool buy=false,sell=false;
 if(InpRule==CHANNEL_BREAKOUT || InpRule==CHANNEL_FADE || InpRule==SWEEP_REJECTION)
 {
  double high=bars[2].high,low=bars[2].low;
  for(int i=3;i<=13;++i){high=MathMax(high,bars[i].high);low=MathMin(low,bars[i].low);}
  buy=bars[1].close>high;sell=bars[1].close<low;
  if(InpRule==CHANNEL_FADE){bool was_buy=buy;buy=sell;sell=was_buy;}
  if(InpRule==SWEEP_REJECTION)
  {
   buy=bars[1].low<low && bars[1].close>low && bars[1].close>bars[1].open;
   sell=bars[1].high>high && bars[1].close<high && bars[1].close<bars[1].open;
  }
 }
 else if(InpRule==RANGE_REVERSION || InpRule==BAND_REENTRY)
 {
  buy=bars[2].close<lower[1] && bars[1].close>=lower[0] && (InpRule==BAND_REENTRY || (adx[0]<20 && rsi[1]<30));
  sell=bars[2].close>upper[1] && bars[1].close<=upper[0] && (InpRule==BAND_REENTRY || (adx[0]<20 && rsi[1]>70));
 }
 else
 {
  buy=fast[0]>slow[0] && slow[0]>slow[2] && bars[2].close<=fast[1] && bars[1].close>fast[0];
  sell=fast[0]<slow[0] && slow[0]<slow[2] && bars[2].close>=fast[1] && bars[1].close<fast[0];
 }
 if(buy || sell)VisualSignal(buy,bars[1].time,buy?bars[1].low:bars[1].high);
 if(buy)Open(true,atr[0]);else if(sell)Open(false,atr[0]);
}
void OnTimer(){if(VisualEnabled())RefreshVisuals();}
void OnTradeTransaction(const MqlTradeTransaction &transaction,const MqlTradeRequest &request,const MqlTradeResult &result)
{
 if(!VisualEnabled())return;
 VisualStatsDirty=true;
 if(transaction.type==TRADE_TRANSACTION_DEAL_ADD)VisualDeal(transaction.deal);
 RefreshVisuals();
}
void OnDeinit(const int reason)
{
 EventKillTimer();ObjectsDeleteAll(0,VisualPrefix());
 IndicatorRelease(atrH);IndicatorRelease(fastH);IndicatorRelease(slowH);
 IndicatorRelease(bandsH);IndicatorRelease(rsiH);IndicatorRelease(adxH);
}
