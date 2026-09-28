# BTCUSD scalping results — 29 September 2026

**No scalping edge found in this research pass.** All candidates rejected.

Screening period: 1 January–30 June 2026, 181 calendar days. Broker real-tick mode, 100 ms execution delay, $10 risk excluding costs, one position, 45-minute maximum holding time. Spread and swap included; reported commission zero. No averaging or martingale.

Journal entries confirm real ticks beginning 1 January 2026. No whole-period fallback or tick-mismatch warning was found in the test journal. This is a journal check, not an independent reconstruction proving every minute has complete ticks.

| Rule | Timeframe | Net P/L | Trades | PF | Active days | Max equity DD | Net with $0.50 extra/trade |
|---|---|---:|---:|---:|---:|---:|---:|
| Channel breakout | M1 | $-2 569.19 | 3522 | 0.87 | 161/181 | $2 698.63 (26.86%) | $-4330.19 |
| Channel breakout | M5 | $-1 243.42 | 3167 | 0.91 | 178/181 | $1 460.41 (14.45%) | $-2826.92 |
| Channel breakout | M15 | $-490.14 | 1432 | 0.89 | 180/181 | $534.37 (5.34%) | $-1206.14 |
| Strict range reversal | M1 | $-0.29 | 8 | 0.99 | 8/181 | $42.44 (0.42%) | $-4.29 |
| Strict range reversal | M5 | $2.73 | 3 | 1.33 | 3/181 | $10.91 (0.11%) | $1.23 |
| Strict range reversal | M15 | $11.23 | 3 | 0.00 | 2/181 | $3.28 (0.03%) | $9.73 |
| Trend pullback | M1 | $-1 223.23 | 1397 | 0.85 | 155/181 | $1 259.68 (12.55%) | $-1921.73 |
| Trend pullback | M5 | $-987.54 | 1533 | 0.85 | 173/181 | $1 030.72 (10.28%) | $-1754.04 |
| Trend pullback | M15 | $-263.67 | 836 | 0.88 | 179/181 | $406.83 (4.04%) | $-681.67 |
| Band reentry | M1 | $-1 504.27 | 2651 | 0.88 | 165/181 | $1 647.40 (16.30%) | $-2829.77 |
| Band reentry | M5 | $-1 485.22 | 2297 | 0.85 | 178/181 | $1 539.72 (15.34%) | $-2633.72 |
| Band reentry | M15 | $-463.59 | 974 | 0.82 | 179/181 | $567.84 (5.67%) | $-950.59 |
| Channel fade | M1 | $-1 281.48 | 3983 | 0.94 | 161/181 | $1 398.08 (13.95%) | $-3272.98 |
| Channel fade | M5 | $-1 912.13 | 3648 | 0.88 | 178/181 | $1 991.15 (19.86%) | $-3736.13 |
| Channel fade | M15 | $-211.45 | 1596 | 0.95 | 180/181 | $325.87 (3.23%) | $-1009.45 |
| Sweep rejection | M1 | $-193.26 | 266 | 0.86 | 62/181 | $216.70 (2.16%) | $-326.26 |
| Sweep rejection | M5 | $-443.06 | 761 | 0.85 | 145/181 | $590.46 (5.90%) | $-823.56 |
| Sweep rejection | M15 | $-229.63 | 726 | 0.87 | 159/181 | $296.35 (2.95%) | $-592.63 |

The positive strict-reversal results had only three trades; PF 0.00 on the M15 report is an undefined/no-loss convention, not proof of an edge. Frequent strategies traded on up to 180/181 days but all lost money. Trading frequently did not meet the profitability requirement.

## Advancement and validation

None passed the declared screening gate (positive net, PF >=1.10, >=100 trades, entries on >=70% of days). Therefore no July–September check was run, and none was attached to a demo/live chart. The daily trading requirement is not fulfilled by the rare reversal results.

The July–September period had already influenced earlier research and would have been a chronological check, not a genuinely untouched holdout. No independent validation or scalping edge is claimed. New future data is still required for genuine validation of any future qualifying candidate.

This rejects these eighteen implementations, not all possible BTC strategies. Selecting a lucky result through unlimited parameter searches would not establish an edge. Further research needs a new, explicitly documented hypothesis before testing.

## Artifacts and runtime

Research EA: `BTC_Scalp_Research.mq5`; final compile zero errors/warnings. It is experimental and must not be attached as a profitable scalper. H1 EA/preset remain unchanged. Temporary tester closed; only `D:\Trading\terminal64.exe` remains running.

Raw reports, configurations, run scripts and summaries are in ignored `logs/`. Research declarations and primary-source references are in `SCALPING_RESEARCH.md`.
