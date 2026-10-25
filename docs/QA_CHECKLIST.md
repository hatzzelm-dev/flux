# RIFTFALL — QA checklist

Run A here, B-I in Roblox Studio. The workspace has no Roblox runtime, so nothing in
section B onward can be marked complete from this environment.

## A. Automated (already passing here)

```bash
py tools/gen_data.py --check
py tools/build_place.py --check
py tools/validate_place.py
py tools/check_layout.py
py tools/test_persistence.py
py tools/simulate_balance.py
```

- [x] 26 Luau files parse with a Lua parser.
- [x] 26 scripts embedded in `out/Riftfall.rbxlx`, all sources byte-identical to `src/`.
- [x] Data hash in the place matches `data/*.csv`.
- [x] Every `require(script.Parent.X)` resolves; every remote used is declared.
- [x] Place is 0.15 MiB (limit 10 MiB).
- [x] 800,000 simulated rolls match published odds within tolerance.
- [x] 24 save/load checks pass, including session lock, rejoin restore, tutorial
      progress and legacy-profile migration.
- [x] Layout check passes at 640x360, 1024x768 and 1920x1080: controls >= 56px, no
      overlaps, panel/guide layers above the control layer.
- [ ] Roblox runtime behaviour: not verifiable here.

## B. First launch (Studio)

1. Open `out/Riftfall.rbxlx`.
2. `Game Settings -> Security -> Enable Studio Access to API Services`.
3. Press **Play** (F5). Wait 2 seconds.

- [ ] Spawn on a glowing pad inside a plaza; no falling through the world.
- [ ] Obelisk crystal, starfield, fog and bloom visible; no missing textures.
- [ ] Output has no red errors (warnings about DataStores only if API access is off).
- [ ] HUD shows RIFTFALL, Flux 0, LUCK x1.00, DEX 0/25, TEAR A RIFT.
- [ ] Pressing R produces a 0.6s reveal with the rift name, odds and `NEW`.
- [ ] Flux starts ticking up roughly one second after the first rift.
- [ ] Sound plays on tear, reveal, tier-4 sting, panel open/close, upgrade and storm;
      `SFX ON/OFF` in the top right silences everything without a respawn resetting it.
- [ ] A new profile shows the guide: step 1 arrow on the tear button, step 2 on the
      Rift Lab after the first roll, step 3 on the Riftodex after an upgrade.
- [ ] `SKIP`, the `OK` button and `Esc` each dismiss the guide; rejoining a profile
      stopped at step 2 resumes at step 2, and a finished profile never sees it again.
- [ ] Rift Storm warning banner counts down from 10 at ~50s, storm starts at ~60s.

## C. Gameplay matrix

| Test | Expected |
|---|---|
| Roll 20 times | Several duplicates; income climbs; DEX count rises |
| Duplicate rift | Reveal shows `x2` count; income increases by that rift's rate |
| Open Riftodex (Q) | Discovered entries coloured, undiscovered show `???` |
| Buy Luck (1) | Cost 120 Flux; LUCK rises to 1.06; Flux deducted |
| Buy Tempo (1) | Cost 90 Flux; cooldown label drops to 1.09s |
| Auto-Tear unlock (3,000 Flux) | Button changes to AUTO: ON; rolls continue while idle |
| Auto-Tear toggle off | Rolling stops within one cooldown |
| 5 unique rifts | Milestone banner: +500 Flux, +2% luck |
| Tier 4+ roll | Screen flash, shake and the rare sting; tiers 1-3 stay quiet |
| Open/close Riftodex and Rift Lab | A UI cue on each open and each close, from the panel itself |
| Storm warning at ~50s | Amber `RIFT STORM IN 10` banner + warning cue |
| Storm at ~60s | Banner, teal tint, lightning, `storm_start` in analytics |
| Storm roll | Stormglass/Thunderhead can appear; only during storm |
| Storm ends at 90s | Tint clears, banner hides, storm rifts stop dropping |
| Plot display | Your rarest rifts appear above your pedestal, largest = rarest |
| Plot sign | Shows your name and best `1 in ...` |
| Server-best board | Updates when a new server record is rolled |
| Tier 6+ roll | All clients receive the slide-in banner with your name |
| Reload page (F5) | Flux, rifts, levels, dex and best are restored |

## D. Persistence and concurrency

- [ ] Roll, wait 5s, stop the Play session with the Studio stop button; re-play: data
      restored (last save happens on PlayerRemoving/BindToClose).
- [ ] Leave 100+ seconds idle: autosave fires with no error in Output.
- [ ] Start a **second server** with the same account (Studio `Test -> Start` with two
      players, or publish to a private place). Second session should show
      "Profile is busy on another server" and must **not** overwrite the first.
- [ ] Turn off Studio API access, join: notice about not saving, game still playable.
- [ ] Force a DataStore error mid-session (offline toggle): saves fail with a warning,
      no data corruption, client keeps playing.
- [ ] Verify `profile.purchases` never exceeds 50 entries after repeated grants.

## E. Purchases (test place only)

- [ ] With product ids at 0: Rift Lab buttons read `COMING SOON`; clicking does not prompt.
- [ ] Configure a **test** developer product id and pass ids in `Config.Products`.
- [ ] Buy the Flux Pack: Flux increases exactly once, success toast appears.
- [ ] Buy again: another grant, ledger has two ids.
- [ ] Simulate a receipt replay by calling `ProcessReceipt` twice with the same
      `PurchaseId` in a test harness: second call returns `PurchaseGranted` with no
      extra Flux.
- [ ] Force `DataService.save` to fail during a receipt: Flux is rolled back and the
      receipt returns `NotProcessedYet`, so Roblox retries later.
- [ ] Buy Rift Runner: AUTO becomes available without the Flux unlock, cooldown x0.8.
- [ ] Buy Omega Aura: character particles + OMEGA title appear; respawn keeps them.
- [ ] Confirm no product changes luck or rarity weights anywhere in the UI.

## F. Mobile

- [ ] Studio device emulator, 844x390 landscape: HUD fits, roll button reachable.
- [ ] 640x360 (smallest phone landscape): every button >= 56px, top row clear of the
      Roblox topbar, storm banner between the Flux cards and the mute button.
- [ ] Tap the jump button repeatedly: DEX/SHOP stay above it (130px band) and never
      receive the tap; the jump button stays fully visible.
- [ ] Open the Riftodex on 640x360: the panel draws over the TEAR/DEX/SHOP buttons,
      its bottom row is visible, and clicking where a button would be does nothing.
- [ ] 1024x768 and 1920x1080: layout identical in structure, nothing clipped.
- [ ] 390x844 portrait: panels fit within the screen; no clipped close button.
- [ ] Touch targets >= 56px; no reliance on hover or keyboard.
- [ ] Cooldown fill and reveal card stay readable on a small screen.
- [ ] Scrolling works in the Riftodex (25 cards) and Rift Lab.

## G. Anti-exploit (client command bar)

```lua
-- spam rolls: expect at most one result, no errors
local remote = game:GetService("ReplicatedStorage").Riftfall.Remotes.RequestRoll
for i = 1, 60 do remote:FireServer() end
```

```lua
-- bogus upgrade key: expect silence, no Flux change
game:GetService("ReplicatedStorage").Riftfall.Remotes.RequestUpgrade:FireServer("flux")
```

```lua
-- malformed auto-tear payload: expect ignored
game:GetService("ReplicatedStorage").Riftfall.Remotes.SetAutoRoll:FireServer("yes")
```

- [ ] Spamming rolls cannot beat cooldown or the 30-rolls/10s window.
- [ ] Upgrade costs are server-computed (try buying with low Flux: "Not enough Flux").
- [ ] No remote accepts a rift id, luck value, odds or result from the client.
- [ ] Plot portals always match owned rifts after rejoining.

## H. Performance and stability

- [ ] `#workspace.RiftfallWorld:GetDescendants()` under ~1,800 instances at 12 plots.
- [ ] Server heartbeat steady with 4 clients; no growing memory after 10 minutes.
- [ ] 10 minutes of auto-tear in one client: no script timeout, no reveal backlog
      beyond a few queued cards.
- [ ] Output free of repeated warnings (DataStore retries, remote spam).
- [ ] Storm start/end repeated twice with no leftover tint or grade.

## I. Release candidate sign-off

| Item | Result | Tester | Date |
|---|---|---|---|
| B first launch | | | |
| C gameplay matrix | | | |
| D persistence | | | |
| E purchases | | | |
| F mobile | | | |
| G anti-exploit | | | |
| H performance | | | |
| Public store listing | | | |

### Useful server-console snippets (switch command bar context to Server)

```lua
-- grant Flux for shop testing
local DataService = require(game.ServerScriptService.Riftfall.DataService)
local player = game.Players:GetPlayers()[1]
DataService.getData(player).flux = 500000
```

```lua
-- force a Rift Storm immediately
require(game.ServerScriptService.Riftfall.StormService).start()
```

```lua
-- wipe one test profile (test place only)
local player = game.Players:GetPlayers()[1]
game:GetService("DataStoreService"):GetDataStore("Riftfall_Data_v1"):RemoveAsync("Player_" .. player.UserId)
```

## Known limitations before launch

- Roblox runtime was not available while building, so every item in B onward is an
  open test, not a verified pass.
- Audio uses built-in `rbxasset://` tones, so nothing can be missing, but the tone
  choice itself is a taste call — swap `Config.Sounds` values if it does not fit.
- Server-best board is per server, not global, by launch-scope decision.
- Storm visuals use primitives/particles only; no skybox asset is shipped.
