// Presentation only. No orders, exits or changes to trading state.
bool VisualEnabled()
{
 return InpShowChartObjects && (!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE));
}
string VisualPrefix(){return StringFormat("BTCScalp_%I64u_",InpMagic);}
void VisualLabel(const string suffix,const string text,const int row,const color shade)
{
 string name=VisualPrefix()+suffix;
 if(ObjectFind(0,name)<0)ObjectCreate(0,name,OBJ_LABEL,0,0,0);
 ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
 ObjectSetInteger(0,name,OBJPROP_XDISTANCE,12);ObjectSetInteger(0,name,OBJPROP_YDISTANCE,25+row*19);
 ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);ObjectSetInteger(0,name,OBJPROP_COLOR,shade);
 ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);ObjectSetString(0,name,OBJPROP_TEXT,text);
}
void VisualLine(const string suffix,const double price,const color shade,const string description)
{
 string name=VisualPrefix()+suffix;
 if(ObjectFind(0,name)<0)ObjectCreate(0,name,OBJ_HLINE,0,0,price);
 ObjectSetDouble(0,name,OBJPROP_PRICE,price);ObjectSetInteger(0,name,OBJPROP_COLOR,shade);
 ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DASH);ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
 ObjectSetString(0,name,OBJPROP_TOOLTIP,description+" "+DoubleToString(price,_Digits));
}
void VisualDeadline(const datetime stamp)
{
 string name=VisualPrefix()+"deadline";
 if(ObjectFind(0,name)<0)ObjectCreate(0,name,OBJ_VLINE,0,stamp,0);
 ObjectSetInteger(0,name,OBJPROP_TIME,stamp);ObjectSetInteger(0,name,OBJPROP_COLOR,clrGold);
 ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DOT);ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
 ObjectSetString(0,name,OBJPROP_TOOLTIP,"Maximum-hold exit on first tick at/after "+TimeToString(stamp,TIME_DATE|TIME_MINUTES));
}
void VisualArrow(const string suffix,const datetime stamp,const double price,const int code,const color shade,const string description)
{
 string name=VisualPrefix()+suffix;
 if(ObjectFind(0,name)<0)ObjectCreate(0,name,OBJ_ARROW,0,stamp,price);
 ObjectSetInteger(0,name,OBJPROP_ARROWCODE,code);ObjectSetInteger(0,name,OBJPROP_COLOR,shade);
 ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_CENTER);ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
 ObjectSetString(0,name,OBJPROP_TOOLTIP,description+" @ "+DoubleToString(price,_Digits));
}
void VisualSignal(const bool buy,const datetime stamp,const double price)
{
 if(!VisualEnabled())return;
 VisualArrow("signal_"+(string)(long)stamp,stamp,price,buy?233:234,clrSilver,
   buy?"Closed buy signal; entry filters still apply":"Closed sell signal; entry filters still apply");
}
void VisualDeal(const ulong ticket)
{
 if(ticket==0 || !HistoryDealSelect(ticket) || HistoryDealGetString(ticket,DEAL_SYMBOL)!=_Symbol ||
    (ulong)HistoryDealGetInteger(ticket,DEAL_MAGIC)!=InpMagic)return;
 long type=HistoryDealGetInteger(ticket,DEAL_TYPE),entry=HistoryDealGetInteger(ticket,DEAL_ENTRY);
 if(type!=DEAL_TYPE_BUY && type!=DEAL_TYPE_SELL)return;
 bool opening=entry==DEAL_ENTRY_IN;
 string reason=EnumToString((ENUM_DEAL_REASON)HistoryDealGetInteger(ticket,DEAL_REASON));
 double net=HistoryDealGetDouble(ticket,DEAL_PROFIT)+HistoryDealGetDouble(ticket,DEAL_COMMISSION)+HistoryDealGetDouble(ticket,DEAL_SWAP)+HistoryDealGetDouble(ticket,DEAL_FEE);
 string text=opening?(type==DEAL_TYPE_BUY?"BUY filled":"SELL filled"):"EXIT "+reason+"; net "+DoubleToString(net,2)+" USD";
 VisualArrow("deal_"+(string)ticket,(datetime)HistoryDealGetInteger(ticket,DEAL_TIME),HistoryDealGetDouble(ticket,DEAL_PRICE),
   opening?(type==DEAL_TYPE_BUY?233:234):251,opening?(type==DEAL_TYPE_BUY?clrLime:clrTomato):clrGold,text);
}
void RestoreVisualDeals()
{
 if(!HistorySelect(TimeCurrent()-7*86400,TimeCurrent()))return;
 ulong tickets[];int count=HistoryDealsTotal();ArrayResize(tickets,count);
 // HistoryDealSelect resets the history list, so save tickets first.
 for(int i=0;i<count;++i)tickets[i]=HistoryDealGetTicket(i);
 for(int i=0;i<count;++i)VisualDeal(tickets[i]);
}
void VisualPattern(const int i,const MqlRates &bars[],const double &fast[],const double &slow[],
                   const double &upper[],const double &lower[],const double &rsi[],const double &adx[],bool &buy,bool &sell)
{
 buy=false;sell=false;double high=bars[i+1].high,low=bars[i+1].low;
 for(int k=i+2;k<=i+12;++k){high=MathMax(high,bars[k].high);low=MathMin(low,bars[k].low);}
 if(InpRule==CHANNEL_BREAKOUT || InpRule==CHANNEL_FADE)
 {
  buy=bars[i].close>high;sell=bars[i].close<low;
  if(InpRule==CHANNEL_FADE){bool original=buy;buy=sell;sell=original;}
 }
 else if(InpRule==SWEEP_REJECTION)
 {
  buy=bars[i].low<low && bars[i].close>low && bars[i].close>bars[i].open;
  sell=bars[i].high>high && bars[i].close<high && bars[i].close<bars[i].open;
 }
 else if(InpRule==RANGE_REVERSION || InpRule==BAND_REENTRY)
 {
  buy=bars[i+1].close<lower[i+1] && bars[i].close>=lower[i] && (InpRule==BAND_REENTRY || (adx[i]<20 && rsi[i+1]<30));
  sell=bars[i+1].close>upper[i+1] && bars[i].close<=upper[i] && (InpRule==BAND_REENTRY || (adx[i]<20 && rsi[i+1]>70));
 }
 else
 {
  buy=fast[i]>slow[i] && slow[i]>slow[i+2] && bars[i+1].close<=fast[i+1] && bars[i].close>fast[i];
  sell=fast[i]<slow[i] && slow[i]<slow[i+2] && bars[i+1].close>=fast[i+1] && bars[i].close<fast[i];
 }
}
void RefreshVisuals()
{
 if(!VisualEnabled())return;
 MqlRates bars[];double fast[],slow[],atr[],upper[],lower[],rsi[],adx[];
 ArraySetAsSeries(bars,true);ArraySetAsSeries(fast,true);ArraySetAsSeries(slow,true);ArraySetAsSeries(atr,true);
 ArraySetAsSeries(upper,true);ArraySetAsSeries(lower,true);ArraySetAsSeries(rsi,true);ArraySetAsSeries(adx,true);
 if(CopyRates(_Symbol,PERIOD_CURRENT,0,101,bars)!=101 || CopyBuffer(fastH,0,0,101,fast)!=101 ||
    CopyBuffer(slowH,0,0,101,slow)!=101 || CopyBuffer(atrH,0,0,3,atr)!=3 ||
    CopyBuffer(bandsH,1,0,101,upper)!=101 || CopyBuffer(bandsH,2,0,101,lower)!=101 ||
    CopyBuffer(rsiH,0,0,101,rsi)!=101 || CopyBuffer(adxH,0,0,101,adx)!=101)return;
 for(int i=0;i<100;++i)
 {
  for(int line=0;line<2;++line)
  {
   string name=VisualPrefix()+"ema"+(string)line+"_"+(string)i;
   double older=line==0?fast[i+1]:slow[i+1],newer=line==0?fast[i]:slow[i];
   if(older==EMPTY_VALUE || newer==EMPTY_VALUE)continue;
   if(ObjectFind(0,name)<0)ObjectCreate(0,name,OBJ_TREND,0,bars[i+1].time,older,bars[i].time,newer);
   ObjectMove(0,name,0,bars[i+1].time,older);ObjectMove(0,name,1,bars[i].time,newer);
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);ObjectSetInteger(0,name,OBJPROP_COLOR,line==0?clrDodgerBlue:clrOrange);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,line==0?1:2);ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,line==0?"Fast EMA20":"Slow EMA50");
  }
 }
 for(int i=1;i<=88;++i)
 {
  bool buy,sell;VisualPattern(i,bars,fast,slow,upper,lower,rsi,adx,buy,sell);
  if(buy || sell)VisualSignal(buy,bars[i].time,buy?bars[i].low:bars[i].high);
 }
 int used=EntriesToday();MqlTick quote;if(!SymbolInfoTick(_Symbol,quote))return;
 double spread=quote.ask-quote.bid;
 string window=InpUseTimeWindow?StringFormat("%02d:00-%02d:00",InpStartHour,InpEndHour):"all hours";
 VisualLabel("title","BTC scalp | "+EnumToString(InpRule)+" | EMA20 blue / EMA50 orange",0,clrWhite);
 VisualLabel("session","Broker time "+TimeToString(TimeCurrent(),TIME_MINUTES)+" | Entry window "+window+" | "+(EntryWindowOpen()?"OPEN":"CLOSED"),1,EntryWindowOpen()?clrLime:clrSilver);
 VisualLabel("count",StringFormat("Entries today %d/%d | Risk %.2f USD | RR %.2f",used,InpMaxTradesPerDay,InpRiskMoney,InpRR),2,used<InpMaxTradesPerDay?clrWhite:clrTomato);
 VisualLabel("spread",StringFormat("Spread %.2f | ATR14 %.2f | ATR/spread %.1f (minimum %.1f)",spread,atr[1],spread>0?atr[1]/spread:0,InpMinATRSpread),3,clrWhite);
 bool owned=PositionSelect(_Symbol) && (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic;
 if(owned)
 {
  bool buy=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
  VisualLine("entry",PositionGetDouble(POSITION_PRICE_OPEN),clrDodgerBlue,"Filled entry");
  VisualLine("sl",PositionGetDouble(POSITION_SL),clrTomato,"Protective SL");VisualLine("tp",PositionGetDouble(POSITION_TP),clrLime,"Target TP");
  datetime deadline=(datetime)PositionGetInteger(POSITION_TIME)+InpMaxHoldMinutes*60;VisualDeadline(deadline);
  VisualLabel("state",(buy?"BUY open":"SELL open")+" | Max-hold exit "+TimeToString(deadline,TIME_MINUTES)+" (SL/TP may close earlier)",4,clrGold);
  VisualLabel("preview","Trade levels shown are actual broker levels",5,clrWhite);
 }
 else
 {
  ObjectDelete(0,VisualPrefix()+"deadline");bool buy=false,sell=false;
  VisualPattern(0,bars,fast,slow,upper,lower,rsi,adx,buy,sell);
  string blocked=!EntryWindowOpen()?"Window closed":used>=InpMaxTradesPerDay?"Daily cap reached":PositionSelect(_Symbol)?"Symbol already has a position":spread<=0 || atr[1]/spread<InpMinATRSpread?"Spread filter blocks entry":!MQLInfoInteger(MQL_TRADE_ALLOWED) || !TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)?"Algo Trading disabled":"Waiting for a closed-bar signal";
  VisualLabel("state",blocked,4,clrSilver);
  VisualLabel("preview",buy?"Forming BUY candidate — requires candle close and all entry checks":sell?"Forming SELL candidate — requires candle close and all entry checks":"No forming candidate | grey arrows: confirmed signals; coloured arrows: fills/exits",5,(buy || sell)?clrGold:clrSilver);
  if((buy || sell) && atr[0]>0 && spread>0)
  {
   double entry=buy?quote.ask:quote.bid,distance=InpStopATR*atr[0];
   VisualLine("entry",entry,clrSilver,"Provisional entry; not an order");
   VisualLine("sl",buy?entry-distance:entry+distance,clrTomato,"Provisional SL; recalculated after close");
   VisualLine("tp",buy?entry+distance*InpRR:entry-distance*InpRR,clrLime,"Provisional TP; recalculated after close");
  }
  else{ObjectDelete(0,VisualPrefix()+"entry");ObjectDelete(0,VisualPrefix()+"sl");ObjectDelete(0,VisualPrefix()+"tp");}
 }
 static bool restored=false;if(!restored){RestoreVisualDeals();restored=true;}
 ChartRedraw();
}
