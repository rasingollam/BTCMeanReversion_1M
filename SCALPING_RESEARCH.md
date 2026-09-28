# BTCUSD scalping research — declared before new tests

Objective: frequent lower-timeframe opportunities with positive net
expectancy, not a mandatory trade when conditions are unsuitable.
Report the fraction of calendar days with entries, not just total trades.

Primary research supports testing both intraday momentum and reversal,
but findings from exchange markets do not establish an Exness CFD edge:
https://www.sciencedirect.com/science/article/pii/S1062940822000833
https://centaur.reading.ac.uk/100181/3/21Sep2021Bitcoin%20Intraday%20Time-Series%20Momentum.R2.pdf
MT5 real ticks allow intraminute bid/ask spreads; missing ticks can be
generated, so the journal must be checked:
https://www.metatrader5.com/en/terminal/help/algotrading/tick_generation

Nine predefined trials: three families on M1, M5 and M15.
1. Momentum: last closed candle breaks the preceding 12-bar high/low.
2. Range reversal: prior close outside Bollinger20/2, latest close back
inside that band; prior RSI14 below30/above70; latest ADX14 below20.
3. Trend pullback: close crosses back over EMA20 in EMA20/50 direction,
with EMA50 slope over two closed-bar intervals agreeing.

All entries use completed bars, next-bar market execution, one position,
$10 USD risk excluding costs, 1.5 ATR14 stop, 45-minute time exit.
RR: 1.5 for momentum/pullback, 1.0 for range reversal.
Trade only if ATR14 / current bid-ask spread >=8. No averaging or martingale.

Screening: 2026 January–June, real-tick mode, 100 ms delay.
Chronological check: July–September28, rules frozen before reading that
family's results. This period was used by prior research, so it is NOT
a genuinely untouched historical holdout. New data after September29
must provide independent validation; do not claim an edge from these
tests alone. Do not use the check period to tune rules.

Advance only candidates with positive screening net and PF>=1.10,
at least100 screening trades, and entries on >=70% of calendar days.
Require positive chronological net and cost stress of extra $0.50 per
completed trade before proposing a forward experiment. Daily activity
and profitability cannot be guaranteed. Further tests must be recorded.
H1 source, binary and frozen preset remain unchanged.

## Second predefined batch, after first screening failed

All six frequent breakout/pullback combinations lost money. The three
strict range reversal combinations had only3–8 trades and are rejected
for inadequate frequency. No first-batch candidate reached validation.

Six further development trials, declared before their outcomes:
4. Band reentry: same Bollinger20/2 reentry, without RSI/ADX restrictions;
RR1.0, M1/M5/M15. This tests reversal at a usable signal frequency.
5. Channel fade: opposite direction of the same 12-bar breakout signal,
RR1.5, M1/M5/M15. This is a separate executable strategy, not a claim
that reversing losing trades necessarily makes profits.
All spread, stop, holding-time and risk rules remain fixed. Same
screening and advancement gates. Fifteen total development trials;
selection bias must be acknowledged in all reported findings.

## Final batch in this research pass, declared before its outcomes

All fifteen trials failed advancement. Three further tests: M1/M5/M15
sweep rejection, same preceding12-bar range. Buy if last candle wicks
below the range low, closes back above it and closes above its own open;
sell with the reverse conditions at the range high. RR1.5, ATR/spread
minimum16, other risk/holding rules unchanged. This is a hypothesis,
not an empirically established liquidity or institutional-order signal.
Eighteen total trials. No further retuning of this batch's rules based
on the chronological check period is permitted.
