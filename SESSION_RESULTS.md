# Session and two-trade-cap results — 29 September 2026

Updated `BTC_Scalp_Research.mq5` version1.10. Compiled with zero errors/warnings. User-selected broker-server entry windows: 13:00–17:00 and 17:00–21:00, start inclusive/end exclusive. Daily ceiling two successful entry orders per symbol and EA magic, reconstructed from broker history on restart. Use one EA copy per symbol. Zero daily-cap or window violations across all32 reports.

## Selected provisional research candidate

M5 trend pullback: EMA20/50 alignment and EMA50 slope; close crosses back over EMA20 in the trend direction. First two eligible entries per broker date, 13:00–17:00. Risk $10 excluding costs; 1.5 ATR14 stop, RR1.5, ATR/spread >=8, maximum45-minute hold. Preset `BTC_Scalp_M5_13_17_2Trades_Demo.set`. This has not been attached automatically.

| Period | Net | Trades | PF | Active days | Max equity DD | Extra $0.50/trade net |
|---|---:|---:|---:|---:|---:|---:|
| Jan–Jun screening | $111.18 | 238 | 1.12 | 146/181 | $102.78 (1.01%) | $-7.82 |
| Jul1–Sep27 chronological check | $100.32 | 117 | 1.21 | 70/89 | $63.00 (0.63%) | $41.82 |

Combined net $211.50, 355 trades. Extra $0.25 per trade leaves $122.75; extra $0.50 leaves $34.00. January–June alone loses money under the $0.50 stress, so cost robustness is limited. Real-tick mode and100 ms delay were used; reported commission zero, historical spread and swap included.

The candidate trades on about80% of days, not every day. The cap is a maximum, not an instruction to force two entries. Thirty screening trials were compared; selection bias remains. July–September market data had influenced previous research and is not a genuinely untouched holdout. No proven scalping edge is claimed; new frozen demo observations are required.

M15 channel fade 17–21 qualified in screening but its check returned only+$7.86 and -$34.64 with $0.50 extra per trade, so it is rejected. M15 sweep rejection17–21 returned+$73.79 in screening but traded on only91/181 days, failing the declared daily-frequency gate.

## Complete comparison

| Stage | TF | Rule | Hours | Net | Trades | PF | Active days | Extra $0.50 net |
|---|---|---|---|---:|---:|---:|---:|---:|
| screen | M1 | Breakout | 13–17 | $-248.03 | 281 | 0.85 | 144/181 | $-388.53 |
| screen | M1 | Breakout | 17–21 | $-319.98 | 201 | 0.74 | 109/181 | $-420.48 |
| screen | M1 | Trend pullback | 13–17 | $122.44 | 265 | 1.09 | 140/181 | $-10.06 |
| screen | M1 | Trend pullback | 17–21 | $-288.70 | 152 | 0.70 | 90/181 | $-364.70 |
| screen | M1 | Band reentry | 13–17 | $-234.62 | 277 | 0.83 | 143/181 | $-373.12 |
| screen | M1 | Band reentry | 17–21 | $84.06 | 193 | 1.10 | 109/181 | $-12.44 |
| screen | M1 | Channel fade | 13–17 | $-253.54 | 281 | 0.85 | 144/181 | $-394.04 |
| screen | M1 | Channel fade | 17–21 | $-156.22 | 201 | 0.87 | 109/181 | $-256.72 |
| screen | M1 | Sweep rejection | 13–17 | $-105.45 | 58 | 0.68 | 39/181 | $-134.45 |
| screen | M1 | Sweep rejection | 17–21 | $-32.20 | 24 | 0.76 | 15/181 | $-44.20 |
| screen | M5 | Breakout | 13–17 | $-104.98 | 325 | 0.93 | 169/181 | $-267.48 |
| screen | M5 | Breakout | 17–21 | $-218.95 | 309 | 0.84 | 159/181 | $-373.45 |
| screen | M5 | Trend pullback | 13–17 | $111.18 | 238 | 1.12 | 146/181 | $-7.82 |
| screen | M5 | Trend pullback | 17–21 | $-103.74 | 251 | 0.89 | 147/181 | $-229.24 |
| screen | M5 | Band reentry | 13–17 | $-450.07 | 320 | 0.69 | 172/181 | $-610.07 |
| screen | M5 | Band reentry | 17–21 | $-167.14 | 280 | 0.86 | 159/181 | $-307.14 |
| screen | M5 | Channel fade | 13–17 | $-370.03 | 326 | 0.78 | 169/181 | $-533.03 |
| screen | M5 | Channel fade | 17–21 | $-132.78 | 309 | 0.90 | 159/181 | $-287.28 |
| screen | M5 | Sweep rejection | 13–17 | $-207.96 | 212 | 0.77 | 126/181 | $-313.96 |
| screen | M5 | Sweep rejection | 17–21 | $-8.52 | 152 | 0.98 | 98/181 | $-84.52 |
| screen | M15 | Breakout | 13–17 | $-54.23 | 268 | 0.94 | 160/181 | $-188.23 |
| screen | M15 | Breakout | 17–21 | $-111.88 | 179 | 0.75 | 134/181 | $-201.38 |
| screen | M15 | Trend pullback | 13–17 | $21.95 | 144 | 1.05 | 104/181 | $-50.05 |
| screen | M15 | Trend pullback | 17–21 | $-75.30 | 115 | 0.69 | 85/181 | $-132.80 |
| screen | M15 | Band reentry | 13–17 | $-77.27 | 226 | 0.88 | 160/181 | $-190.27 |
| screen | M15 | Band reentry | 17–21 | $-90.05 | 113 | 0.68 | 88/181 | $-146.55 |
| screen | M15 | Channel fade | 13–17 | $-28.84 | 277 | 0.97 | 160/181 | $-167.34 |
| screen | M15 | Channel fade | 17–21 | $46.80 | 187 | 1.12 | 134/181 | $-46.70 |
| screen | M15 | Sweep rejection | 13–17 | $-95.69 | 177 | 0.83 | 128/181 | $-184.19 |
| screen | M15 | Sweep rejection | 17–21 | $73.79 | 114 | 1.45 | 91/181 | $16.79 |
| check | M5 | Trend pullback | 13–17 | $100.32 | 117 | 1.21 | 70/89 | $41.82 |
| check | M15 | Channel fade | 17–21 | $7.86 | 85 | 1.04 | 60/89 | $-34.64 |
