# RIFTFALL — design

## 1. Fantasy

You do not roll objects. You **tear reality**. Each roll rips a portal open above
your plot; the size, colour and motion of the tear encode its rarity. Commons are a
faint shimmer. Omega rifts are a 15-stud wound in space with a vertical beam visible
from the plaza, and the whole server gets a banner with your name on it.

Three things make it different from dice / coin / egg RNG:

1. **The collection is spatial.** Rifts hover over your plot, in rarity order, where
   other players walk past them. It is a flex you can see from across the map.
2. **The world reacts.** Rift Storms periodically turn the sky storm-blue, double
   luck and unlock three rifts that cannot be rolled otherwise.
3. **Nothing is bought that changes odds.** Products are convenience and cosmetics.

## 2. Core loop

```
 tear -> rarity reveal (0.6s charge, tier FX, broadcast if rare)
   |
   v
 own rift -> passive Flux/s (duplicates stack) + Riftodex entry
   |
   +-> spend Flux: Luck, Tempo, Auto-Tear
   +-> milestones at 5/10/15/20/25 unique rifts (Flux + permanent luck)
   +-> plot display updates, server-best board may update
   |
   v
 Rift Storm (first at 60s with a 10s warning, then 90s storm / 210-330s calm):
   luck x2.2, storm rifts, back to tearing
```

## 3. Rarity ladder

Odds are the exact base-pool probabilities generated from `data/rarities.csv`
(weights normalised to a pool of 100). `tools/simulate_balance.py` verifies them.

| Tier | Rift | Base odds | Chance | Flux/s per copy |
|---|---|---:|---:|---:|
| Faint | Spark | 1 in 2.27 | 44.0000% | 0.52 |
| Faint | Haze | 1 in 5 | 20.0000% | 0.669 |
| Faint | Dust Vein | 1 in 9.49 | 10.5318% | 0.822 |
| Drift | Mist Rift | 1 in 8 | 12.5000% | 0.778 |
| Drift | Ember Scar | 1 in 15 | 6.6667% | 0.952 |
| Surge | Prism Tear | 1 in 35 | 2.8571% | 1.248 |
| Surge | Aurora Wisp | 1 in 60 | 1.6667% | 1.483 |
| Surge | Static Bloom | 1 in 100 | 1.0000% | 1.746 |
| Fracture | Glass Storm | 1 in 250 | 0.4000% | 2.341 |
| Fracture | Thunder Scar | 1 in 500 | 0.2000% | 2.922 |
| Fracture | Nova Shard | 1 in 1,000 | 0.1000% | 3.648 |
| Rupture | Chrono Wound | 1 in 2,500 | 0.0400% | 4.891 |
| Rupture | Gravity Bloom | 1 in 5,000 | 0.0200% | 6.106 |
| Rupture | Mirror Void | 1 in 10,000 | 0.0100% | 7.622 |
| Collapse | Event Horizon | 1 in 25,000 | 0.0040% | 10.219 |
| Collapse | Hollow Crown | 1 in 50,000 | 0.0020% | 12.756 |
| Collapse | Starfall Gate | 1 in 100,000 | 0.0010% | 15.924 |
| Singularity | Genesis Tear | 1 in 250,000 | 0.0004% | 21.35 |
| Singularity | Void Bloom | 1 in 500,000 | 0.0002% | 26.652 |
| Singularity | Riftwyrm | 1 in 1,000,000 | 0.0001% | 33.271 |
| Omega | Oblivion Rift | 1 in 10,000,000 | 0.00001% | 69.512 |
| Omega | The First Rift | 1 in 100,000,000 | 0.000001% | 145.231 |
| Storm | Stormglass | 1 in 400 (storm pool) | 0.72% in storm* | 2.721 |
| Storm | Thunderhead | 1 in 5,000 (storm pool) | 0.058% in storm* | 6.106 |
| Storm | Eye of the Storm | 1 in 250,000 (storm pool) | 0.0012% in storm* | 21.35 |

`*` storm chances shown at max luck (x1.9 upgrades x2.2 storm). Outside a storm the
storm-only pool has zero weight.

### Roll math

```
weight(rift) = baseWeight * luck ^ (min(tier, 8) * 0.25)
             (storm rifts use stormWeight as baseWeight)
total        = sum(weight)
roll         = random() * total
pick first rift whose cumulative weight >= roll
```

- Luck is `1 + 0.06 * luckLevel + milestone bonuses`. Max upgrade luck is x1.9.
- A storm multiplies luck by 2.2 (max x4.18).
- The exponent is capped at tier 8 so storm-exclusive rifts never become common.
- Common rifts are pushed down as rare weights are boosted, which is why the UI shows
  **base** odds in the Riftodex and reveal, and the live luck value on the HUD. The
  odds label is honest about the pool, not a promise about the current roll.

### Pacing (base luck, 1.15s cooldown)

| Goal | Expected rolls | Time |
|---|---:|---:|
| Any Drift | 4 | 5s |
| Surge or better | 16 | 18s |
| Fracture or better | 129 | 2.5 min |
| Rupture or better | 1,287 | 25 min |
| Collapse or better | 12,968 | 4.1 h |
| Singularity or better | 140,647 | 45 h |
| Omega | 9,090,909 | ~121 days of nonstop tearing |

Omegas are a guild-level legend, not a day-one goal. Tiers 4-6 carry the mid-game
hype; the server broadcast threshold is tier 6 (Collapse) or odds >= 1/100,000.

## 4. Flux economy

```
incomePerCopy = 0.4 * odds ^ 0.32   (min 0.05)
totalIncome  = sum(incomePerCopy * copiesOwned)
```

A new player's expected income per roll is **0.71 Flux/s**, so the first 120 Flux
Luck upgrade arrives after roughly 30-60 seconds of holding a few rifts. Duplicates
are never wasted: each copy pays full income, which is why common rifts stay useful.

Upgrade curves (server-side, validated on purchase):

| Luck level | Cost | Luck | Tempo level | Cost | Cooldown |
|---:|---:|---:|---:|---:|---:|
| 1 | 120 | x1.06 | 1 | 90 | 1.09s |
| 2 | 246 | x1.12 | 2 | 198 | 1.04s |
| 4 | 1,034 | x1.24 | 4 | 958 | 0.93s |
| 6 | 4,345 | x1.36 | 6 | 4,638 | 0.82s |
| 10 | 76,730 | x1.60 | — | — | — |
| 15 | 2,778,020 | x1.90 | — | — | — |

Auto-Tear is a one-time 3,000 Flux unlock (also included with Rift Runner, no odds
change). Riftodex milestones award 500 / 2,500 / 12,000 / 60,000 / 400,000 Flux plus
+2%/+2%/+3%/+3%/+5% luck, which is how the endgame Luck ceiling rises to x2.05.

Minimum cooldown is 0.45s; with Tempo 6 and Rift Runner it is 0.656s (~91 rolls/min
theoretical, capped by the server at 30 rolls per 10s).

## 5. Moments that make clips

- **Reveal choreography:** 0.2s pop with a tier-coloured gradient, full-screen flash
  from Fracture up, camera shake scaled by tier, FOV punch from Rupture, rare sting
  from Singularity, and a NEW badge on first discovery.
- **Server broadcast:** tier 6+ rolls are announced to every player with the roller's
  name and the odds. The roller's screen fills; everyone else sees a slide-in banner.
- **Storm:** sky tint + lighting grade + lightning + banner + loot that only exists
  for 90 seconds. Everyone in the server rolls at once, which is the shared high.
  The first storm is timed to land 60 seconds after the server starts so a new
  player sees one inside the first session; a 10s `RIFT STORM IN n` banner and a
  warning cue precede every storm.
- **First 60 seconds:** roll (sound + 0.6-0.9s charge reveal) -> first duplicate ->
  first Rift Lab upgrade -> Riftodex entry -> storm. A three-step guide points at
  the tear button, the Rift Lab and the Riftodex; it is stored on the profile
  (`tutorialStep`) so it is shown once per account and can be skipped.
- **Audio:** one bus, built-in `rbxasset://` tones re-pitched per event, master volume
  in `Config.Audio`, session mute in the HUD. No marketplace asset can disappear and
  take the game's sound with it.
- **Plot walk:** rare portals are physically bigger and brighter. Other players can
  read your best odds on your plot sign and on the plaza's server-best board.

## 6. Data model

```
profile = {
  v, flux, rolls, playtime,
  luckLevel, speedLevel, autoRollUnlocked, autoRoll,
  rifts = { [riftId] = count },
  bestId, bestOdds,
  milestone,
  tutorialStep,                    -- 0-3, only ever moves forward server-side
  purchases = { PurchaseId... },   -- capped at 50
  createdAt, lastJoin
}
```

Save path: `DataStore "Riftfall_Data_v1"`, key `Player_<UserId>`.

- **Claim:** `UpdateAsync` writes `{data, lock={job, time}}` only if unlocked or the
  lock is older than 120s.
- **Save:** `UpdateAsync` refuses to write if another job holds the lock. One write
  is in flight per profile; a revision counter keeps later changes dirty when they
  happen during a write, so an older snapshot can never clear them.
- **Leave/shutdown:** final write without a lock, then release.
- **Load failure:** play memory-only and never overwrite unreadable data.

Sanitizing on load clamps levels and Flux, drops unknown rift ids, recomputes the best
rift from owned rifts and caps the purchase ledger.

## 7. Anti-exploit checklist

- Client sends: roll request, auto-tear toggle, upgrade key, product key, tutorial
  step. Nothing else. The tutorial step is clamped to 0-3 and only accepted when it
  is higher than the stored value, so a client cannot rewind or farm it, and a
  profile with rolls but no stored step (pre-v2 data) loads as completed.
- Server owns: rift pick, luck, cooldown, rate window, upgrade cost, Flux totals,
  milestone awards, purchase grants, broadcast thresholds.
- Cooldown is enforced server-side with a 50ms slack; the rate window caps bursts at
  30 rolls / 10s independent of cooldown.
- Upgrade keys are whitelisted (`luck`, `speed`, `auto`); costs are recomputed.
- Receipts are idempotent by `PurchaseId` and acknowledged only after a successful save.
- Plot visuals are server-built from owned rifts; nothing client-authored is trusted.

## 8. Performance budget

- Map: 1 floor, 1 plaza, 12 pads, 12 pedestals, 12 signs, 170 stars, ~1 emitter.
- Plots display at most 6 portals of 16-19 parts each: worst case ~1,400 parts with a
  full 12-player server. All anchored, no shadows, no touch/query.
- Rift models rebuild only when the displayed set changes (signature comparison).
- Client UI is ~120 instances, code-built; no per-frame allocation beyond the cooldown
  tick and camera shake binding.
- Server loops: 1s Flux accrual, 0.5s state push, 0.2s auto-tear check, 1s storm timer.
  State payload is a flat table of numbers, one RemoteEvent per 0.5s per player.

## 9. Deliberately deferred

Rebirth/Compression, trading, co-op trials, multiple storm types, global (cross-server)
leaderboard, second plot, seasonal rifts. The server-best board is per server at launch,
as specified in the launch plan. Add cross-server leaderboards only after retention data
justifies the DataStore cost and the read budget.

## 10. Changing balance

1. Edit `data/rarities.csv` (weights) or `src/ReplicatedStorage/Riftfall/Config.luau`.
2. `py tools/gen_data.py` regenerates `RiftData.luau`.
3. `py tools/simulate_balance.py` rewrites `out/balance_report.md`; read the pacing table.
4. `py tools/build_place.py && py tools/validate_place.py`.
5. Re-test in Studio Play mode: first roll, first upgrade, storm, save/reload.

Never hand-edit `RiftData.luau`; the validator rejects a stale hash.
