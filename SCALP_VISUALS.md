# Scalping EA chart visuals

`InpShowChartObjects` defaults to false. Set it to true in EA Inputs
to show objects; disabling it or removing the EA removes its own objects.

- Blue EMA20 and orange EMA50 (slow line width2), latest100 candles.
- Grey arrows: confirmed signal patterns on recent candles. These are
  not proof of an entry: window, daily cap, spread, volume, broker and
  account checks still apply.
- Green/red arrows: actual own-EA buy/sell fills; gold crosses: exits.
  Hover for fill price and exit reason. Own deal markers are restored
  from the last7 days of broker history when enabling the display.
- Dashed entry, stop and target levels. While flat, forming candidates
  show provisional levels; these may change or disappear before close.
  While holding a trade, levels use the actual position's broker values.
- Gold dotted vertical line: maximum-hold exit deadline. The EA closes
  on the first available tick at/after it; SL/TP can close earlier.
- Dashboard: broker time, entry window, daily count, risk, RR, spread,
  closed-bar ATR, provisional candidate and current blocking condition.

The display refreshes every5 seconds. A forming candidate is not a
trade promise: candle-close confirmation and all entry checks are
required. Dashboard status is informational; the execution checks
remain authoritative. No orders are placed by the display code.

Visual objects are suppressed in nonvisual tester runs. Enable both
MT5 visual testing and the input to view them in Strategy Tester.
Default-off M5 Jul–Sep regression reproduced +$100.32/117 trades,
PF1.21, with zero entry-window or daily-cap violations. A read-only MT5
script verified chart-object creation and cleanup. Compiler:0 errors,
0 warnings. The H1 EA was not modified.
