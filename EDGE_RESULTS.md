# BTC research results — 28 September 2026

## Current provisional candidate

BTCUSD H1: 20-bar closed-price breakout, EMA50/EMA200 alignment,
EMA200 slope over five completed bars, 2 ATR14 stop reference,
spread buffer, 2:1 target, $10 risk. No EMA exit or stochastic filter.

| Period | Net P/L | Trades | Profit factor | Max equity drawdown |
|---|---:|---:|---:|---:|
| 2025, generated ticks | $29.13 | 70 | 1.08 | $86.27 |
| 2026 Jan 1–Sep 28, real-tick mode | $52.79 | 92 | 1.11 | $99.35 |

100 ms execution delay. Spread and swap included; reported broker
commission zero. The 2026 journal confirms real ticks beginning
1 January 2026, without the whole-period fallback warning seen in 2024.
This does not prove absence of every minute-level data correction.

Extra round-trip cost sensitivity (a stress assumption, not a measured fee):

| Extra cost per trade | 2025 adjusted net | 2026 adjusted net |
|---|---:|---:|
| $0.25 | $11.63 | $29.79 |
| $0.50 | -$5.87 | $6.79 |
| $1.00 | -$40.87 | -$39.21 |

The candidate is fragile. These years have been used for research;
the results are not untouched validation and do not establish an edge.

## Forward test started

28 September 2026, broker-server time 23:52. Isolated research terminal,
existing Exness demo account, BTCUSD H1, magic 105020.
Journal verified `breakout=true`, `trend_filter=true`, `demo_only=true`,
`algo_allowed=true`. No positions or pending orders existed at launch.
EA compilation: zero errors, zero warnings.

Frozen preset: `BTCUSD_H1_Breakout_Demo.set`.
Minimum assessment period: 8 weeks AND 50 closed trades.
No forward outcomes yet; the computer and research terminal must stay
running. Trade fill and cost records go to the separate CSV described
in `EDGE_RESEARCH.md`; all runtime logs remain under ignored `logs/`.

## Rejected alternatives

32-bar persistence pullback: 2024 PF 0.80, net -$99.62;
2024 real ticks unavailable, generated fallback explicitly logged.
Unfiltered H1 55-bar breakout: 2026 net -$4.14.
Unfiltered H1 20-bar breakout: 2026 +$29.76, but -$11.24 with $0.25 extra cost.
H4 breakout: two or zero trades, inadequate samples at the $10 risk limit.

Broker API probes for 2023/2025 ticks failed; a 2026 probe returned ticks.
Historical tick availability outside 2026 remains unverified.
Continue gathering new demo observations; do not declare success from
these development results or retune against the forward sample.

## Runtime verification update

The first demo process exited cleanly shortly after startup, with no
recorded fills. It was relaunched as a detached hidden process to avoid
dependency on the launch session. `logs/check_forward.py` is a read-only
check that verifies the actual process, demo account, connection and own
deal history; it never starts a missing terminal.

At the first check after relaunch: connected demo account, zero own
positions, zero deals and zero realized P/L. The CSV is created on the
first fill, so its absence before a trade is expected. No forward edge
can be assessed from these observations.

Illustrative independent-trade 95% intervals for historical mean net
profit include zero: 2025 approximately -$2.38 to +$3.22 per trade;
2026 -$1.78 to +$2.93. Serial dependence and candidate selection can
make this simple interval overconfident. Positive backtest totals do
not establish positive expectancy.
