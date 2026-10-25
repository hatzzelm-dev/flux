# RIFTFALL — publishing

## Name and description

**Title options:** `RIFTFALL: RNG` (primary) · `RIFTFALL — Tear Reality` · `Riftfall [RNG]`

**Description**

> You do not roll dice. You tear reality.
>
> Every tear opens a rift above your plot — a colour, a size, a rarity, and a passive
> Flux income. 25 rifts, from a 1-in-2 shimmer to THE FIRST RIFT at 1 in 100,000,000.
> Rare tears are broadcast to the whole server. Omega rifts split the sky.
>
> - 25 rifts across 8 tiers + 3 storm-exclusive rifts
> - Rift Storms every few minutes: luck x2.2 and rifts you cannot get any other way
> - Collect in the Riftodex for permanent luck milestones
> - Upgrade Luck, Tempo and Auto-Tear with Flux
> - Your rarest rifts hover over your plot for everyone to see
> - Every roll is server-authoritative
>
> No purchase changes your odds.

**Tags/genre:** Simulation / Adventure, "RNG", "luck", "collection". Device: all.
Max players: 12 (one plot each).

## Art briefs

**Icon (512x512):** near-black background; a vertical tear in space off-centre,
white-gold core with red-violet edges and sparse sparks; tiny "1 in 100,000,000" in
the lower right in condensed caps; no character, no text salad. High contrast at
150px because most discovery happens in a small tile.

**Thumbnails (1920x1080), three concepts:**

1. *Common vs Legendary:* split frame, a small grey shimmer on the left, a 15-stud
   burning portal with a beam on the right. Caption "1 in 2 vs 1 in 100,000,000".
2. *Storm:* plaza bathed in storm teal, lightning, three players mid-tear, banner
   "RIFT STORM +220% LUCK".
3. *Plot walk:* row of portals at different rarities with the odds on the signs,
   another player silhouetted in front for scale.

## Roblox settings

- `File -> Publish to Roblox`, pick the experience, set title/description/genre.
- `Game Settings -> Security -> Enable Studio Access to API Services` for Studio saves.
- Enable **HTTP requests**? Not needed. No external endpoints.
- `Game Settings -> Permissions`: keep default; no HttpService, no third-party teleports.
- Mobile: default touch controls are enough; the UI scales from 0.5x to 1.35x. Verify
  landscape phone before publishing.
- Monetization is off until product ids are pasted into `Config.Products`; the store
  shows `COMING SOON` instead of a broken prompt.

## Policy and safety notes

- The three products are fixed-value: convenience (auto-tear/cooldown), cosmetic
  (aura/title), and a fixed Flux bundle. There is **no paid random item and no paid
  odds boost** in the build, so no paid-odds disclosure is required for the current
  catalogue. If that changes, verify the current Roblox rules before shipping.
- Do not sell Flux that is itself convertible to Robux; Flux is a soft currency only.
- Text chat is Roblox-filtered by default; the game adds no custom chat, no user text
  input and no external links.
- DataStores store only gameplay numbers and purchase receipt ids. No personal data.
- Purchase receipts are logged per player (max 50 ids) so support can audit grants.

## Content hooks for short-form video

1. **The 1-in-100,000,000 moment:** full-screen flash, banner with the player's name,
   other players turning around. Film the reaction, not just the portal.
2. **Storm rush:** "the whole server has 90 seconds to hit the storm-only rifts" —
   countdown banner, sky changing, roll spam.
3. **Plot tour:** walk past portals from 1-in-2 to 1-in-10M with the signs in frame.
4. **Upgrade payoff:** before/after compare of 10 minutes of Flux into Luck.

## Update cadence (post-launch)

- Weekly: one new rift via `data/rarities.csv` (adjust weights so the pool still sums
  to 100), new colour tier if needed, patch notes in the description.
- Bi-weekly: a second storm variant or a limited-time storm-only rift.
- Monthly: a balance pass informed by Riftodex completion and Flux-per-hour data.

## Pre-publish checklist

- [ ] `py tools/validate_place.py` passes.
- [ ] Studio Play test with API access on; save, reload, verify profile.
- [ ] Purchase test completed with a test product; ledger shows one id per receipt.
- [ ] Icon, thumbnails, description uploaded.
- [ ] Product ids configured and the store renders `R$` prices, not placeholders.
- [ ] Second account can join, roll, see the first account's portals.
- [ ] Mobile landscape pass.
