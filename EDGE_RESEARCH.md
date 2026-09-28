# BTC edge research

Goal: positive expectancy after costs that survives validation and demo
forward testing. Finding such an edge is not guaranteed.

Prior 2025/2026 results have already influenced research decisions;
neither year is genuinely untouched. The 2024 baseline used generated
ticks because the broker supplied no real ticks for that year. Do not
label any of these results as real-tick out-of-sample validation.

## Predefined next candidate family

Before examining this family's results: Donchian closed-bar breakout,
lookbacks 20 and 55, timeframes H1 and H4 (four candidates only).
Buy when the last completed candle closes above the highest high of
the preceding N candles; sell below their lowest low. Next-bar market
entry, protective reference at signal close +/- 2 ATR14, plus the
existing spread buffer; target at twice actual entry-to-stop distance.
USD risk $10, one position per symbol, no EMA exit, no stochastic or
EMA filters, normal direction. Stops are subject to minimum-volume
and broker validity checks. Trading costs are not included in sizing.

Development: 2025 generated-tick tests, explicitly labelled.
Robustness: 2026 broker real ticks with 100 ms execution delay;
verify actual coverage and fallback before accepting conclusions.
These historical comparisons are development/robustness checks,
not untouched validation. An unused older real-tick period will be
used only if the broker provides it; otherwise future demo trading
must supply genuinely new observations.

Candidates that lose in either development year are rejected from
deployment. A surviving candidate remains provisional, and needs
cost sensitivity, a frozen rule and at least 8 weeks/50 demo trades.

## Rejected persistence candidate

2024 generated ticks, 100 ms execution delay:
baseline -$162.97 / 295 trades / PF 0.87;
32-bar persistence filter -$99.62 / 110 trades / PF 0.80.
The lower total loss comes with fewer trades, not positive expectancy.
Do not deploy this candidate for an edge-validation demo.

## One fixed trend refinement, declared before its tests

The H1 20-bar breakout returned +$171.91 in 2025 and +$29.76 in 2026,
but an additional $0.25 per round trip makes 2026 lose $11.24.
The H1 55-bar alternative lost $4.14 in 2026; H4 samples were unusable.

Next fixed refinement: H1, 20-bar breakout, EMA50 above EMA200 for
buys and below for sells, with EMA200 rising/falling from closed bar
6 to closed bar 1 respectively. All other breakout rules unchanged.
Test both years and $0.25/$0.50/$1 extra round-trip cost sensitivity.
This is another development trial, increasing multiple-testing risk;
it will require new forward observations even if profitable.

## Frozen demo candidate — 28 September 2026

Trend-filtered H1 20-bar breakout, exact rules above, preset
`BTCUSD_H1_Breakout_Demo.set`, magic 105020, demo-only guard enabled.
2025: +$29.13, PF 1.08, 70 trades, maximum equity DD $86.27.
2026 real-tick mode: +$52.79, PF 1.11, 92 trades, maximum equity DD $99.35.
Tester logs show real ticks beginning 1 January 2026 and no whole-period
fallback warning for the 2026 runs. 2025 remains generated ticks.
Broker commission reported zero; spread and swap are included.
Additional $0.25 per completed trade leaves +$11.63 / +$29.79;
additional $0.50 leaves -$5.87 / +$6.79. This is fragile, provisional
evidence, not a validated edge or untouched historical validation.

Forward experiment: minimum 8 weeks AND 50 closed trades, no retuning.
Keep risk $10; record actual fill prices, commission, swap and fees in
the separate `MQL5/Files/BMR_forward_105020.csv` inside the ignored
research terminal. Observed bid/ask are transaction-time snapshots,
not proof of an exact execution slippage measurement.
Assess net expectancy, drawdown and costs with confidence intervals;
do not infer profitability from a short sequence of wins.
