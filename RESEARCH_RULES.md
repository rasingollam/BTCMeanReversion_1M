# Frozen BTCUSD M30 research test

Frozen before examining 2024 results, 28 September 2026.

Development sample: recorded M30 baseline trades from 2025 and 2026.
One new filter: permit a buy only when EMA(10) > EMA(20) for each of
the 32 most recent completed M30 bars. Permit a sell with the reverse
inequality for all 32 bars. Equality fails. No forming bars are used.
The threshold was selected from exploratory 4, 8, 16 and 32 bar bins;
this is a research candidate, not evidence of a profitable strategy.

Other rules fixed: normal direction, stochastic 5/3/3 with 40/60,
original pullback confirmation, confirmed swing stop plus spread,
$10 risk, 1:1 target, EMA exit off, H1 and stochastic recovery filters off.
Holdout: 2024, no retuning after results. Compare baseline and filtered
EA using real ticks, recorded bid/ask, swap and broker commission.
Execution delay 100 ms is a stress assumption, not measured latency.
Check logs for missing tick data and generated replacements before
accepting results. Generated-tick results are not a valid substitute.

Forward protocol: demo account only, BTCUSD M30, same frozen inputs,
one position per symbol, unique magic 105032. Record at least 8 weeks
and 50 closed trades, whichever takes longer. Evaluate net expectancy,
profit factor, drawdown, spread, execution costs and rule adherence.
Do not retune during the run. Demo fills do not establish live profitability.

## Execution status

EA compilation completed with zero errors and zero warnings.
The isolated terminal is downloading broker tick history for the 2024
baseline. `logs/finish_holdout.py` waits for it, runs the filtered test,
and writes `logs/holdout-status.json` and `logs/holdout-comparison.md`.
The controller has a two-hour download/test limit and reports failures.
No holdout performance or full real-tick coverage is claimed yet.

Demo startup configuration is prepared in
`logs/test-terminal/demo-forward.ini`; it uses the already authenticated
demo account, unique magic 105032 and `BTCUSD_M30_Frozen_Demo.set`.
It has NOT been launched. Review completed holdout tick coverage and
costs first. Forward results require actual elapsed time.
