# Scalping session filter — 29 September 2026

User-selected windows: broker-server 13:00–17:00 and 17:00–21:00.
Start inclusive, end exclusive. Inputs permit other windows, including
overnight windows. Daily counter resets at broker-server midnight.
Maximum two successful entry orders per EA magic and symbol per day,
including already closed trades. Partial fills count as one order.
Trade history reconstructs the count on restarts; unavailable history
blocks entry. Failed entry attempts and closing deals do not count.
Use one copy of this EA per symbol. Existing positions retain protective
SL/TP and the 45-minute exit even outside the entry window.

Thirty declared screening trials: M1/M5/M15, breakout/trend pullback/
band reentry/channel fade/sweep rejection, each in both windows.
The strict reversal family is excluded because its original sample
contained only 3–8 trades. Other parameters match prior research.
No continuous optimization of hours or parameters.

2026 January–June screening, broker real-tick mode, 100 ms delay.
Advance only positive net, PF>=1.10, >=100 trades, >=70% active days.
July–September28 chronological check for qualifiers, unchanged rules.
That period was used previously and is not truly untouched; new future
data is still needed to establish independent validation. A result
selected from thirty additional trials is provisional and potentially
affected by multiple testing. Every report is checked for <=2 entry
orders per day and entries inside the selected hours.
