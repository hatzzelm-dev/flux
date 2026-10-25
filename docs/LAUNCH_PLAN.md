# RIFTFALL — 7-day launch plan

**Model:** AI-assisted solo development. **Target:** playable, monetizable MVP in
seven days, then let real player data decide what gets built next.

The schedule is a sequence of gates, not a promise. The build in this repository is the
Day 1-5 deliverable; Days 6-7 are Studio QA and store setup, which need a Roblox account.

## Launch scope (locked)

**In:** server-authoritative rolls and cooldowns · 25 rifts / 8 tiers · procedural
portals · plots, duplicate stacking, passive Flux · Luck / Tempo / Auto-Tear ·
Riftodex + 5 milestones · one Rift Storm event (first at 60s, 10s warning) ·
3-step first-run guide · built-in audio with a mute toggle · persistent profiles with
autosave, lock and shutdown save · responsive PC/mobile UI · 3 fixed-value products
· analytics.

**Out at launch:** global/cross-server leaderboard (server-best board only) ·
Multi-Roll · rebirth · trading · co-op trials · multiple storm types · paid luck.

**Never cut:** data integrity, purchase correctness, server-side validation, mobile
usability. If time slips, cut storm visuals and cosmetic polish.

## Day-by-day gates

| Day | Work | Gate |
|---|---|---|
| 1 | Data CSV → codegen, roll math, luck, cooldown, remotes | Simulator matches published odds; invalid remote payloads rejected |
| 2 | World, plots, portal models, reveal FX | Every tier is readable at a glance; plaza spawns correctly |
| 3 | Flux, duplicates, upgrades, Riftodex, milestones | First upgrade reachable in ~30-60s; 800k-roll sim shows no runaway inflation |
| 4 | HUD, Rift Lab, Riftodex UI, persistence, mobile layout | Reload keeps progress; duplicate login cannot dupe; UI fits phone landscape |
| 5 | 2 passes + 1 dev product, receipt ledger, analytics | Replayed receipt grants once; failed save does not grant |
| 6 | QA matrix in Studio Play mode | `docs/QA_CHECKLIST.md` signed off |
| 7 | Store copy, icon/thumbnail, settings, publish | Live experience loadable by a second account |

Assumes 6-10 focused hours per day and existing Studio access. If behind, postpone the
server-best board polish and storm lightning before touching saving or purchases.

## Monetization at launch

| Product | Price (test) | Type | Benefit | Odds impact |
|---|---:|---|---|---|
| Rift Runner | 99 R$ | Game Pass | Auto-Tear always available, cooldown x0.8 | none |
| Omega Aura | 149 R$ | Game Pass | Cosmetic aura, OMEGA title, cosmetic only | none |
| Flux Pack | 29 R$ | Dev Product | Fixed 2,500 Flux | none |

These are test prices, not optimised ones. Free players keep the whole loop; paid items
are convenience or cosmetics only. Do not add paid luck or paid random rewards without
verifying the current Roblox policy and disclosure requirements first — the code does
not contain such a product today.

## Revenue scenarios (planning assumptions, not forecasts)

| Scenario | Unique visitors | Purchase conversion | Avg spend per buyer | Gross Robux |
|---|---:|---:|---:|---:|
| Low traction | 500 | 0.5% | 75 | ~188 |
| Initial validation | 3,000 | 2% | 100 | ~6,000 |
| Strong response | 10,000 | 3% | 125 | ~37,500 |
| Viral traction | 50,000 | 3% | 150 | ~225,000 |

At a simplified 70% developer share, the initial validation scenario is roughly 4,200
Robux before cash-out considerations. DevEx is a separate eligibility milestone
(minimum earned Robux, account requirements, rate changes); treat revenue generation
and cash-out eligibility as different goals. Nothing here is a guarantee.

## 14-day validation targets (internal, experimental)

| Metric | Target | If below |
|---|---|---|
| Average first-session playtime | 8+ min | Improve first roll, first upgrade, early milestone |
| Day 1 retention | 15%+ | Strengthen collection goals, storm frequency, return reward |
| First-upgrade completion | 60%+ | Lower Luck 1 cost or raise early Flux |
| Purchase conversion | 1%+ experimental | Review price, presentation and product value |
| Successful purchase fulfilment | 100% | Stop and fix grants immediately; receipts are auditable in the ledger |

Use Roblox analytics; do not draw conclusions from tiny samples. Keep pricing and
acquisition constant long enough to compare.

### Acquisition

Organic short-form first: a 1-in-1,000,000 reveal, a Rift Storm sky event, a plot
walk showing common vs Omega, and a Riftodex completion. No paid ads before retention
is proven.

## Analytics events emitted

`session_start`, `first_roll`, `roll_rare` (tier as value), `upgrade`,
`dex_milestone` (milestone index), `storm_start`, `purchase_pass`,
`purchase_flux_pack`. All are throttled to one per second per event per player and
wrapped in pcall, so analytics failure never affects gameplay.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| 7-day slip | Fixed cut order: cosmetics → storm visuals → server-best polish. Never saving/purchases. |
| Rare rifts distort economy | CSV-driven simulation gates the economy before UI polish. |
| Players leave after a short session | Fast first roll, first upgrade inside a minute, milestone at 5 uniques, first storm at 60s with a warning banner. |
| Monetization underperforms | Three transparent fixed-value products; change one variable at a time. |
| Purchase or data bugs | Idempotent receipts, session lock, autosave, shutdown save, explicit QA cases. |
| Robux ≠ cash | Revenue table framed as planning assumptions; DevEx tracked separately. |
| Content drought after launch | Weekly new rift drop using the CSV pipeline; new storm variant second. |

## Post-launch gate (not built now)

After 14 days against the targets above, unlock in this order if data supports it:
cross-server rarest-roll leaderboard, Multi-Roll, second storm type, rebirth. Nothing
in the current build blocks those additions.
