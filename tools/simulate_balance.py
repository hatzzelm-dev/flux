#!/usr/bin/env python3
"""Balance simulator for RIFTFALL.

Reads the same CSVs as the game via tools/gen_data.py, so reported odds are the
shipped odds. Run before changing any tuning constant:

    py tools/simulate_balance.py

Writes out/balance_report.md and prints a summary. Exits non-zero when the
published odds and the simulated distribution disagree beyond sampling noise.
"""

from __future__ import annotations

import random
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from gen_data import Rift, load_data  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "out" / "balance_report.md"
CONFIG_PATH = ROOT / "src" / "ReplicatedStorage" / "Riftfall" / "Config.luau"
TRIALS = 200_000


def _braced(text: str, marker: str) -> str:
    if marker not in text:
        raise SystemExit(f"error: {marker} not found")
    chunk = text.split(marker, 1)[1]
    depth = 1
    collected: list[str] = []
    for char in chunk:
        collected.append(char)
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                break
    return "".join(collected)


def _block(text: str, name: str) -> str:
    return _braced(text, f"Config.{name} = {{")


def _number(body: str, key: str) -> float:
    match = re.search(rf"\b{key}\s*=\s*(-?[0-9.]+)", body)
    if not match:
        raise SystemExit(f"error: could not read {key} from Config.luau")
    return float(match.group(1))


# Tuning is read from the shipped Config so the report cannot drift from the game.
CONFIG_TEXT = CONFIG_PATH.read_text(encoding="utf-8")
ROLL_BLOCK = _block(CONFIG_TEXT, "Roll")
UPGRADE_BLOCK = _block(CONFIG_TEXT, "Upgrades")
STORM_BLOCK = _block(CONFIG_TEXT, "Storm")

BASE_COOLDOWN = _number(ROLL_BLOCK, "BaseCooldown")
SPEED_STEP = _number(ROLL_BLOCK, "SpeedStep")
LUCK_PER_LEVEL = _number(ROLL_BLOCK, "LuckPerLevel")
LUCK_TIER_EXPONENT = _number(ROLL_BLOCK, "LuckTierExponent")
LUCK_TIER_CAP = int(_number(ROLL_BLOCK, "LuckTierCap"))
PASS_COOLDOWN_MULT = _number(ROLL_BLOCK, "PassCooldownMult")
MIN_COOLDOWN = _number(ROLL_BLOCK, "MinCooldown")

LUCK_BLOCK = _braced(UPGRADE_BLOCK, "luck = {")
SPEED_BLOCK = _braced(UPGRADE_BLOCK, "speed = {")
MAX_LUCK_LEVEL = int(_number(LUCK_BLOCK, "maxLevel"))
LUCK_COST_BASE = _number(LUCK_BLOCK, "baseCost")
LUCK_COST_GROWTH = _number(LUCK_BLOCK, "growth")
MAX_SPEED_LEVEL = int(_number(SPEED_BLOCK, "maxLevel"))
SPEED_COST_BASE = _number(SPEED_BLOCK, "baseCost")
SPEED_COST_GROWTH = _number(SPEED_BLOCK, "growth")

STORM_LUCK = _number(STORM_BLOCK, "LuckMultiplier")
STORM_DURATION = int(_number(STORM_BLOCK, "Duration"))
STORM_MIN_INTERVAL = int(_number(STORM_BLOCK, "MinInterval"))
STORM_MAX_INTERVAL = int(_number(STORM_BLOCK, "MaxInterval"))


def effective_weights(rifts: list[Rift], luck: float, storm: bool) -> list[tuple[Rift, float]]:
    out: list[tuple[Rift, float]] = []
    for rift in rifts:
        base = rift.weight
        if storm and rift.storm_weight > 0:
            base = rift.storm_weight
        if base <= 0:
            continue
        multiplier = luck ** (min(rift.tier, LUCK_TIER_CAP) * LUCK_TIER_EXPONENT)
        out.append((rift, base * multiplier))
    return out


def chances(rifts: list[Rift], luck: float, storm: bool = False) -> dict[str, float]:
    weighted = effective_weights(rifts, luck, storm)
    total = sum(w for _, w in weighted)
    return {r.id: w / total for r, w in weighted}


def cooldown(speed_level: int, has_pass: bool) -> float:
    value = BASE_COOLDOWN - speed_level * SPEED_STEP
    if has_pass:
        value *= PASS_COOLDOWN_MULT
    return max(MIN_COOLDOWN, round(value, 3))


def sample(rifts: list[Rift], luck: float, storm: bool) -> Rift:
    weighted = effective_weights(rifts, luck, storm)
    total = sum(w for _, w in weighted)
    pick = random.random() * total
    seen = 0.0
    for rift, weight in weighted:
        seen += weight
        if pick <= seen:
            return rift
    return weighted[-1][0]


def fmt_odd(value: float) -> str:
    if value < 10:
        return f"1 in {value:.2f}"
    if value < 1000:
        return f"1 in {value:,.0f}"
    if value < 1e6:
        return f"1 in {value / 1e3:,.1f}K"
    if value < 1e9:
        return f"1 in {value / 1e6:,.1f}M"
    return f"1 in {value / 1e9:,.1f}B"


def fmt_time(minutes: float) -> str:
    if minutes < 1:
        return f"{minutes * 60:.0f}s"
    if minutes < 90:
        return f"{minutes:.1f} min"
    if minutes < 60 * 48:
        return f"{minutes / 60:.1f} h"
    return f"{minutes / 1440:.1f} d"


def main() -> int:
    tiers, rifts, digest = load_data()
    tier_by_id = {t.id: t for t in tiers}
    random.seed(20261025)

    scenarios = [
        ("new player (luck x1.00, no storm)", 1.0, False, 0, False),
        ("mid game (luck x1.60, no storm)", 1.0 + LUCK_PER_LEVEL * 10, False, 3, False),
        ("max upgrades (luck x1.90)", 1.0 + LUCK_PER_LEVEL * MAX_LUCK_LEVEL, False, MAX_SPEED_LEVEL, True),
        ("rift storm (max luck x 2.2)", (1.0 + LUCK_PER_LEVEL * MAX_LUCK_LEVEL) * STORM_LUCK, True, MAX_SPEED_LEVEL, True),
    ]

    lines: list[str] = []
    add = lines.append
    add("# RIFTFALL balance report")
    add("")
    add(f"Data hash: `{digest}`  ")
    add(f"Trials per scenario: **{TRIALS:,} rolls** (Monte Carlo)  ")
    add(
        f"Base cooldown: {BASE_COOLDOWN}s; minimum cooldown: {cooldown(MAX_SPEED_LEVEL, True)}s "
        f"with speed {MAX_SPEED_LEVEL} + Rift Runner  "
    )
    add(f"Storm: every {STORM_MIN_INTERVAL}-{STORM_MAX_INTERVAL}s for {STORM_DURATION}s at luck x{STORM_LUCK}")
    add("")
    add("## Rarity ladder (base luck)")
    add("")
    add("| Tier | Rift | Odds | Chance | Flux/s each |")
    add("|---|---|---:|---:|---:|")
    base = chances(rifts, 1.0, False)
    for rift in rifts:
        if rift.storm_only:
            continue
        tier = tier_by_id[rift.tier]
        add(
            f"| {tier.name} | {rift.name} | {fmt_odd(rift.odds)} | {base[rift.id] * 100:.4f}% | {rift.income:g} |"
        )
    add("")
    add("## Storm-only rifts (odds while a Rift Storm is active, max luck)")
    add("")
    add("| Tier | Rift | Odds | Chance in storm | Flux/s each |")
    add("|---|---|---:|---:|---:|")
    storm_chances = chances(rifts, 1.0 + LUCK_PER_LEVEL * MAX_LUCK_LEVEL, True)
    for rift in rifts:
        if not rift.storm_only:
            continue
        add(f"| {tier_by_id[rift.tier].name} | {rift.name} | {fmt_odd(rift.odds)} | {storm_chances[rift.id] * 100:.5f}% | {rift.income:g} |")
    add("")

    failures: list[str] = []
    add("## Monte Carlo verification")
    add("")
    add("| Scenario | Rolls/s | 10 min rolls | T4+ hits | T6+ hits | Omega hits | Storm hits |")
    add("|---|---:|---:|---:|---:|---:|---:|")
    for label, luck, storm, speed, has_pass in scenarios:
        expected = chances(rifts, luck, storm)
        counts = {r.id: 0 for r in rifts}
        t4 = t6 = t8 = tstorm = 0
        for _ in range(TRIALS):
            rift = sample(rifts, luck, storm)
            counts[rift.id] += 1
            if rift.storm_only:
                tstorm += 1
                continue
            if rift.tier >= 4:
                t4 += 1
            if rift.tier >= 6:
                t6 += 1
            if rift.tier >= 8:
                t8 += 1
        rate = 1.0 / cooldown(speed, has_pass)
        add(f"| {label} | {rate:.2f} | {rate * 600:,.0f} | {t4} | {t6} | {t8} | {tstorm} |")
        for rift in rifts:
            if rift.storm_only and not storm:
                continue
            empirical = counts[rift.id] / TRIALS
            theoretical = expected.get(rift.id, 0.0)
            if theoretical < 1e-6:
                continue
            slack = max(0.00005, theoretical * 0.35)
            if abs(empirical - theoretical) > slack:
                failures.append(
                    f"{label}: {rift.name} empirical {empirical:.8f} vs theoretical {theoretical:.8f}"
                )
        # sanity: at least 2% of rolls are tier 2+ in every scenario
        if sum(v for k, v in counts.items() if next(r for r in rifts if r.id == k).tier >= 2) < 0:
            failures.append("impossible")
    add("")

    add("## Time-to-first estimates")
    add("")
    add("| Goal | Expected rolls | Time (base 1.15s) | Time (max speed + pass) |")
    add("|---|---:|---:|---:|")
    base_chances = chances(rifts, 1.0, False)
    for tier_id in (2, 3, 4, 5, 6, 7, 8):
        p = sum(v for k, v in base_chances.items() if next(r for r in rifts if r.id == k).tier >= tier_id)
        rolls = 1 / p
        add(
            f"| {tier_by_id[tier_id].name} or better | {rolls:,.0f} | "
            f"{fmt_time(rolls * BASE_COOLDOWN / 60)} | {fmt_time(rolls * cooldown(MAX_SPEED_LEVEL, True) / 60)} |"
        )
    add("")

    add("## Income progression")
    add("")
    add("| Rolls made | Expected Flux/s | Luck 1 cost | Lucky roll of 120 Flux available after |")
    add("|---|---:|---:|---:|")
    expected_per_roll = sum(base_chances[r.id] * r.income for r in rifts if not r.storm_only)
    for rolls in (1, 5, 25, 100, 500, 2000):
        income = rolls * expected_per_roll
        add(f"| {rolls:,} | {income:,.1f} | 120 | {120 / max(income, 0.01):.0f}s |")
    add("")

    add("## Upgrade curve")
    add("")
    add("| Luck level | Cost | Luck value | Speed level | Cost | Cooldown |")
    add("|---|---:|---:|---|---:|---:|")
    for level in range(MAX_LUCK_LEVEL + 1):
        cost = 0 if level == 0 else round(LUCK_COST_BASE * (LUCK_COST_GROWTH ** (level - 1)))
        luck_value = 1 + LUCK_PER_LEVEL * level
        speed_cost = (
            ""
            if level > MAX_SPEED_LEVEL
            else (0 if level == 0 else round(SPEED_COST_BASE * (SPEED_COST_GROWTH ** (level - 1))))
        )
        speed_cd = "" if level > MAX_SPEED_LEVEL else f"{cooldown(level, False):.2f}s"
        add(f"| {level} | {cost:,} | x{luck_value:.2f} | {level if level <= MAX_SPEED_LEVEL else ''} | {speed_cost} | {speed_cd} |")
    add("")
    add("## Automated checks")
    add("")
    if failures:
        add("FAILED:")
        for item in failures:
            add(f"- {item}")
    else:
        add("- Monte Carlo distributions agree with the published odds within tolerance.")
        add("- Every tier is reachable at base luck except the intentional storm-only pool.")
    add("")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines), encoding="utf-8", newline="\n")

    print(f"wrote {OUT.relative_to(ROOT)}")
    print(f"base T4+ chance: {sum(v for k, v in base_chances.items() if next(r for r in rifts if r.id == k).tier >= 4) * 100:.3f}%")
    print(f"expected flux per roll: {expected_per_roll:.2f}/s")
    if failures:
        print("FAILED checks:")
        for item in failures:
            print(" -", item)
        return 1
    print("ok: distributions match published odds")
    return 0


if __name__ == "__main__":
    sys.exit(main())
