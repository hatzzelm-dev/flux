#!/usr/bin/env python3
"""Generate src/ReplicatedStorage/Riftfall/RiftData.luau from data/*.csv.

The CSVs are the single source of truth for odds, tier colors and Flux income.
tools/simulate_balance.py imports this module so tuning and shipped numbers can
never drift apart.

Usage:
    python tools/gen_data.py            # write the module
    python tools/gen_data.py --check    # verify the module is up to date
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data"
OUT_FILE = ROOT / "src" / "ReplicatedStorage" / "Riftfall" / "RiftData.luau"

TOTAL_WEIGHT = 100.0
INCOME_BASE = 0.4
INCOME_EXPONENT = 0.32
MIN_INCOME = 0.05


@dataclass
class Tier:
    id: int
    name: str
    r: int
    g: int
    b: int
    glow: float
    particles: int


@dataclass
class Rift:
    id: str
    name: str
    tier: int
    weight: float
    storm_weight: float
    odds: float
    income: float

    @property
    def storm_only(self) -> bool:
        return self.weight <= 0.0


def _read_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        raise SystemExit(f"error: missing data file {path}")
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def load_data() -> tuple[list[Tier], list[Rift], str]:
    tier_rows = _read_csv(DATA_DIR / "tiers.csv")
    rift_rows = _read_csv(DATA_DIR / "rarities.csv")

    tiers: list[Tier] = []
    seen_tiers: set[int] = set()
    for row in tier_rows:
        try:
            tier = Tier(
                id=int(row["id"]),
                name=row["name"].strip(),
                r=int(row["r"]),
                g=int(row["g"]),
                b=int(row["b"]),
                glow=float(row["glow"]),
                particles=int(row["particles"]),
            )
        except (KeyError, ValueError) as exc:
            raise SystemExit(f"error: bad tier row {row}: {exc}")
        if tier.id in seen_tiers:
            raise SystemExit(f"error: duplicate tier id {tier.id}")
        if not 1 <= tier.id <= 99:
            raise SystemExit(f"error: tier id out of range: {tier.id}")
        for channel in (tier.r, tier.g, tier.b):
            if not 0 <= channel <= 255:
                raise SystemExit(f"error: color channel out of range in tier {tier.id}")
        seen_tiers.add(tier.id)
        tiers.append(tier)
    tiers.sort(key=lambda t: t.id)

    raw: list[tuple[str, str, int, float, float]] = []
    seen_ids: set[str] = set()
    seen_names: set[str] = set()
    for row in rift_rows:
        try:
            rift_id = row["id"].strip()
            name = row["name"].strip()
            tier = int(row["tier"])
            weight = float(row["weight"])
            storm_weight = float(row["storm_weight"] or 0)
        except (KeyError, ValueError) as exc:
            raise SystemExit(f"error: bad rift row {row}: {exc}")
        if not rift_id or not name:
            raise SystemExit(f"error: rift is missing id/name: {row}")
        if rift_id in seen_ids:
            raise SystemExit(f"error: duplicate rift id {rift_id}")
        if name.lower() in seen_names:
            raise SystemExit(f"error: duplicate rift name {name}")
        if tier not in seen_tiers:
            raise SystemExit(f"error: rift {rift_id} references unknown tier {tier}")
        if weight < 0 or storm_weight < 0:
            raise SystemExit(f"error: negative weight on {rift_id}")
        if weight == 0 and storm_weight == 0:
            raise SystemExit(f"error: {rift_id} can never be rolled")
        seen_ids.add(rift_id)
        seen_names.add(name.lower())
        raw.append((rift_id, name, tier, weight, storm_weight))

    total = sum(item[3] for item in raw)
    if not 99.0 <= total <= 101.0:
        raise SystemExit(
            f"error: base weights must sum to ~100 (got {total:.6f}). "
            "Adjust data/rarities.csv."
        )

    scale = TOTAL_WEIGHT / total
    rifts: list[Rift] = []
    for rift_id, name, tier, weight, storm_weight in raw:
        weight = round(weight * scale, 10)
        storm_weight = round(storm_weight * scale, 10)
        effective = weight if weight > 0 else storm_weight
        odds = TOTAL_WEIGHT / effective
        income = max(MIN_INCOME, INCOME_BASE * (odds ** INCOME_EXPONENT))
        rifts.append(
            Rift(
                id=rift_id,
                name=name,
                tier=tier,
                weight=weight,
                storm_weight=storm_weight,
                odds=round(odds, 4),
                income=round(income, 3),
            )
        )

    rifts.sort(key=lambda r: (r.tier, -max(r.weight, r.storm_weight), r.odds))

    digest = hashlib.sha256()
    for path in (DATA_DIR / "tiers.csv", DATA_DIR / "rarities.csv"):
        digest.update(path.read_bytes())
    return tiers, rifts, digest.hexdigest()


def _num(value: float) -> str:
    if abs(value - round(value)) < 1e-12:
        return str(int(round(value)))
    text = f"{value:.12g}"
    if "e" in text or "E" in text:
        return f"{value:.10f}".rstrip("0").rstrip(".")
    return text


def render(tiers: list[Tier], rifts: list[Rift], digest: str) -> str:
    lines: list[str] = []
    add = lines.append
    add("--!nolint")
    add("-- AUTO-GENERATED FILE - DO NOT EDIT BY HAND.")
    add("-- Source of truth: data/tiers.csv and data/rarities.csv")
    add("-- Regenerate: python tools/gen_data.py")
    add(f'-- source_hash: {digest}')
    add("")
    add("local RiftData = {}")
    add("")
    add(f'RiftData.Hash = "{digest}"')
    add("RiftData.Version = 1")
    add(f"RiftData.TotalWeight = {_num(TOTAL_WEIGHT)}")
    add("")
    add("RiftData.Tiers = {")
    for tier in tiers:
        add("\t{")
        add(f"\t\tid = {tier.id},")
        add(f'\t\tname = "{tier.name}",')
        add(f"\t\tcolor = Color3.fromRGB({tier.r}, {tier.g}, {tier.b}),")
        add(f"\t\tglow = {_num(tier.glow)},")
        add(f"\t\tparticles = {tier.particles},")
        add("\t},")
    add("}")
    add("")
    add("RiftData.TierById = {}")
    add("for _, tier in ipairs(RiftData.Tiers) do")
    add("\tRiftData.TierById[tier.id] = tier")
    add("end")
    add("")
    add("RiftData.Rifts = {")
    for rift in rifts:
        add("\t{")
        add(f'\t\tid = "{rift.id}",')
        add(f'\t\tname = "{rift.name}",')
        add(f"\t\ttier = {rift.tier},")
        add(f"\t\tweight = {_num(rift.weight)},")
        add(f"\t\tstormWeight = {_num(rift.storm_weight)},")
        add(f"\t\todds = {_num(rift.odds)},")
        add(f"\t\tincome = {_num(rift.income)},")
        add(f"\t\tstormOnly = {'true' if rift.storm_only else 'false'},")
        add("\t},")
    add("}")
    add("")
    add("RiftData.RiftById = {}")
    add("for _, rift in ipairs(RiftData.Rifts) do")
    add("\tRiftData.RiftById[rift.id] = rift")
    add("end")
    add("")
    add("RiftData.Count = #RiftData.Rifts")
    add("")
    add("function RiftData.getTier(tierId)")
    add("\treturn RiftData.TierById[tierId]")
    add("end")
    add("")
    add("function RiftData.getRift(riftId)")
    add("\treturn RiftData.RiftById[riftId]")
    add("end")
    add("")
    add("return RiftData")
    add("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify output is current")
    args = parser.parse_args()

    tiers, rifts, digest = load_data()
    source = render(tiers, rifts, digest)

    if args.check:
        if not OUT_FILE.exists():
            print(f"error: {OUT_FILE} is missing; run python tools/gen_data.py")
            return 1
        if OUT_FILE.read_text(encoding="utf-8") != source:
            print(f"error: {OUT_FILE} is stale; run python tools/gen_data.py")
            return 1
        print(f"ok: RiftData.luau is current ({len(rifts)} rifts, hash {digest[:12]})")
        return 0

    OUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    OUT_FILE.write_text(source, encoding="utf-8", newline="\n")
    print(f"wrote {OUT_FILE.relative_to(ROOT)} ({len(rifts)} rifts, {len(tiers)} tiers)")
    print(f"hash {digest[:16]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
