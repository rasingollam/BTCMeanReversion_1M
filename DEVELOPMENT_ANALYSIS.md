# Development analysis — BTCUSD M30

549 recorded baseline trades: 310 in 2025, 239 in 2026.
Values below are medians, computed exclusively from completed bars
available before entry. W/L means winning/losing trades by net outcome.

| Feature | 2025 W / L | 2026 W / L |
|---|---:|---:|
| Consecutive EMA-aligned bars | 25.5 / 20.5 | 23 / 21 |
| ATR14 as % of price | 0.3551 / 0.3469 | 0.3579 / 0.3590 |
| Touch penetration beyond slow EMA, in ATR | 0.4111 / 0.4205 | 0.3639 / 0.4036 |
| Exit-implied stop distance / bar spread | 23.12 / 27.25 | 33.26 / 33.62 |

Volatility has no consistent separation; pullback depth is somewhat
shallower among winners, but the difference is small in 2025.
The spread ratio is an approximation: symmetric 1:1 SL/TP comments
provide distance, and entry-bar spread provides the denominator.
It is not an exact execution-level spread measurement.

Trend persistence is the clearest consistent directional relationship.
Exploratory thresholds were 4, 8, 16 and 32 completed bars. Keeping
only recorded trades with at least 32 aligned bars gives:

| Development year | Retained trades | Retained net P/L |
|---|---:|---:|
| 2025 | 102 | -$28.56 |
| 2026 | 80 | +$116.85 |

These are subsets of the baseline trades, NOT a rerun of the filtered
EA. Skipped trades can allow additional entries under the one-position
rule. These figures do not establish filtered strategy profitability.
2025 still loses; the filter is a candidate for rejection or validation.

Feature extraction uses independently reconstructed EMAs with an
adequate pre-2025 warmup and an SMA of the last 14 true ranges.
The executable filter uses MT5's actual EMA buffers.
Raw reports, scripts, bars and trade features are in ignored `logs/`.
Frozen rules and forward protocol are in `RESEARCH_RULES.md`.
