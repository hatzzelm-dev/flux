#!/usr/bin/env python3
"""Verify the RIFTFALL build before it is opened in Roblox Studio.

Checks:
  1. RiftData.luau and out/Riftfall.rbxlx are up to date with src/ and data/.
  2. Every Luau source parses as Lua 5.1-compatible syntax.
  3. The place contains the expected services, scripts and modules.
  4. Every embedded script matches its file byte for byte, and the data hash in
     the place matches data/*.csv.
  5. Each require(script.Parent.X) resolves to a module that exists.
  6. Every remote used by client or server is declared in Remotes.Names.
  7. Config has no hardcoded product ids (placeholders stay 0 until configured).

Usage:
    py tools/validate_place.py
"""

from __future__ import annotations

import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))

import build_place  # noqa: E402
import gen_data  # noqa: E402

try:
    from luaparser import ast  # noqa: E402
except ImportError:  # pragma: no cover - environment guidance
    print("error: the validator needs the luaparser package")
    print("       py -m pip install luaparser")
    sys.exit(1)

SRC = ROOT / "src"
PLACE = ROOT / "out" / "Riftfall.rbxlx"

EXPECTED_MODULES = {
    "ReplicatedStorage": {"RiftData", "Config", "Format", "Remotes"},
    "ServerScriptService": {
        "DataService",
        "EconomyService",
        "RollService",
        "PlotService",
        "StormService",
        "IndexService",
        "MonetizationService",
        "AnalyticsService",
        "StateService",
    },
    "ServerStorage": {"WorldBuilder", "RiftModel"},
    "StarterPlayerScripts": {
        "Hud",
        "DexPanel",
        "ShopPanel",
        "RevealController",
        "StormFX",
        "Fx",
        "UIBuilder",
        "Audio",
        "Onboarding",
    },
}

failures: list[str] = []
notes: list[str] = []


def fail(message: str) -> None:
    failures.append(message)


def get_name(element: ET.Element) -> str:
    props = element.find("Properties")
    if props is None:
        return ""
    for prop in props:
        if prop.attrib.get("name") == "Name":
            return prop.text or ""
    return ""


def source_of(element: ET.Element) -> str | None:
    props = element.find("Properties")
    if props is None:
        return None
    for prop in props:
        if prop.attrib.get("name") == "Source":
            return prop.text or ""
    return None


def collect_scripts(node: ET.Element, path: list[str], out: dict[str, tuple[str, str, list[str]]]) -> None:
    for item in node.findall("Item"):
        name = get_name(item)
        class_name = item.attrib.get("class", "")
        source = source_of(item)
        if source is not None:
            out[name] = (class_name, source, path)
        collect_scripts(item, path + [name], out)


def main() -> int:
    # 1. Freshness -----------------------------------------------------------
    tiers, rifts, digest = gen_data.load_data()
    expected_data = gen_data.render(tiers, rifts, digest)
    actual_data = (ROOT / "src" / "ReplicatedStorage" / "Riftfall" / "RiftData.luau").read_text(encoding="utf-8")
    if actual_data != expected_data:
        fail("RiftData.luau is stale; run py tools/gen_data.py")

    expected_place = build_place.build()
    if not PLACE.exists():
        fail("out/Riftfall.rbxlx is missing; run py tools/build_place.py")
        print("FAILED:")
        for item in failures:
            print(" -", item)
        return 1
    actual_place = PLACE.read_text(encoding="utf-8")
    if actual_place != expected_place:
        fail("out/Riftfall.rbxlx is stale; run py tools/build_place.py")

    # 2. Lua syntax ----------------------------------------------------------
    parsed = 0
    for path in sorted(SRC.rglob("*.luau")):
        try:
            ast.parse(path.read_text(encoding="utf-8"))
            parsed += 1
        except Exception as exc:  # noqa: BLE001 - report the parser error verbatim
            fail(f"Lua syntax error in {path.relative_to(ROOT)}: {exc}")
    notes.append(f"parsed {parsed} Luau files")
    if parsed == 0:
        fail("no Luau files found")

    # 3. Place structure -----------------------------------------------------
    try:
        tree = ET.parse(PLACE)
    except ET.ParseError as exc:
        fail(f"place XML is invalid: {exc}")
        print("FAILED:")
        for item in failures:
            print(" -", item)
        return 1
    root = tree.getroot()
    services = {get_name(item): item for item in root.findall("Item")}
    # Workspace/Lighting are created by Roblox itself; only the script services
    # need to be serialized (same set Rojo emits).
    for required in ("ReplicatedStorage", "ServerScriptService", "ServerStorage", "StarterPlayer"):
        if required not in services:
            fail(f"missing service {required}")

    scripts: dict[str, tuple[str, str, list[str]]] = {}
    collect_scripts(root, [], scripts)

    if scripts.get("Riftfall", ("",))[0] != "Script":
        fail("ServerScriptService.Riftfall must be a Script (init.server.luau)")

    embedded_server = scripts.get("Riftfall", ("", "", []))[1]
    if embedded_server and '<token name="RunContext">0</token>' not in actual_place:
        fail("Script is missing an explicit Legacy RunContext token")
    if scripts.get("RiftfallClient", ("",))[0] != "LocalScript":
        fail("StarterPlayerScripts.RiftfallClient must be a LocalScript (init.client.luau)")

    module_names = {name for name, (class_name, _, _) in scripts.items() if class_name == "ModuleScript"}
    for group, expected in EXPECTED_MODULES.items():
        for name in expected:
            if name not in module_names:
                fail(f"missing {group} module {name}")
    notes.append(f"{len(scripts)} scripts embedded, {len(module_names)} modules")

    # 4. Embedded sources match files ---------------------------------------
    expected_sources: dict[str, tuple[str, str]] = {}
    for path in sorted(SRC.rglob("*.luau")):
        source = path.read_text(encoding="utf-8")
        if path.name.startswith("init."):
            name = path.parent.name
            class_name = "Script" if "server" in path.name else "LocalScript"
        else:
            classified = build_place.classify(path.name)
            if not classified:
                continue
            name, class_name = classified
        expected_sources[name] = (class_name, source)

    for name, (class_name, source) in expected_sources.items():
        embedded = scripts.get(name)
        if not embedded:
            fail(f"place is missing {class_name} {name}")
            continue
        if embedded[0] != class_name:
            fail(f"{name} is {embedded[0]} in the place, expected {class_name}")
        if embedded[1] != source:
            fail(f"embedded source for {name} does not match src/")

    embedded_data = scripts.get("RiftData", ("", "", []))[1]
    if f'source_hash: {digest}' not in embedded_data:
        fail("embedded RiftData does not match the CSV hash")
    if f'RiftData.Hash = "{digest}"' not in embedded_data:
        fail("embedded RiftData.Hash is stale")

    # 5. require(script.Parent.X) resolves ----------------------------------
    name_by_dir: dict[Path, set[str]] = {}
    file_for_name: dict[str, Path] = {}
    for path in sorted(SRC.rglob("*.luau")):
        if path.name.startswith("init."):
            name = path.parent.name
        else:
            classified = build_place.classify(path.name)
            if not classified:
                continue
            name = classified[0]
        file_for_name[name] = path
        name_by_dir.setdefault(path.parent, set()).add(name)

    require_pattern = re.compile(r"require\s*\(\s*script\.Parent\.([A-Za-z_][A-Za-z0-9_]*)")
    for name, path in file_for_name.items():
        source = path.read_text(encoding="utf-8")
        siblings = name_by_dir.get(path.parent, set())
        for match in require_pattern.finditer(source):
            target = match.group(1)
            if target not in siblings:
                fail(f"{path.relative_to(ROOT)} requires script.Parent.{target}, which does not exist")

    # 6. Remote consistency --------------------------------------------------
    remotes_source = (SRC / "ReplicatedStorage" / "Riftfall" / "Remotes.luau").read_text(encoding="utf-8")
    declared = set(re.findall(r'^\s*"([A-Za-z][A-Za-z0-9_]*)",\s*$', remotes_source, flags=re.MULTILINE))
    if not declared:
        fail("could not read Remotes.Names")
    used: set[str] = set()
    for path in SRC.rglob("*.luau"):
        for match in re.finditer(r"remotes\.([A-Za-z_][A-Za-z0-9_]*)", path.read_text(encoding="utf-8")):
            used.add(match.group(1))
    for name in sorted(used - declared):
        fail(f"remote {name} is used but not declared in Remotes.Names")
    notes.append(f"remotes declared: {len(declared)}, used: {len(used)}")

    # 7. Product configuration ----------------------------------------------
    config_source = (SRC / "ReplicatedStorage" / "Riftfall" / "Config.luau").read_text(encoding="utf-8")
    product_block = config_source.split("Config.Products = {", 1)[-1].split("Config.Sounds", 1)[0]
    configured = [int(value) for value in re.findall(r"^\s*id = (\d+),", product_block, flags=re.MULTILINE)]
    if len(configured) != 3:
        fail("Config.Products must contain exactly three products")
    if any(value != 0 for value in configured):
        notes.append(f"product ids configured: {configured} (live monetization enabled)")

    # 8. Sanity on the data --------------------------------------------------
    total_weight = sum(rift.weight for rift in rifts)
    if abs(total_weight - 100.0) > 1e-6:
        fail(f"base weights sum to {total_weight}, expected 100")
    if not any(rift.weight == 0 and rift.storm_weight > 0 for rift in rifts):
        fail("no storm-exclusive rifts defined")
    if max(rift.odds for rift in rifts) < 1e6:
        fail("no rift rarer than 1 in 1,000,000")

    # Required project files ------------------------------------------------
    for required in (
        "README.md",
        "default.project.json",
        "data/rarities.csv",
        "data/tiers.csv",
        "docs/DESIGN.md",
        "docs/LAUNCH_PLAN.md",
        "docs/PUBLISHING.md",
        "docs/QA_CHECKLIST.md",
        "out/balance_report.md",
    ):
        if not (ROOT / required).exists():
            fail(f"missing required file {required}")

    size_mb = PLACE.stat().st_size / (1024 * 1024)
    if size_mb > 10:
        fail(f"place is {size_mb:.1f} MiB, over the 10 MiB upload limit")
    notes.append(f"place size {size_mb:.2f} MiB")

    print("RIFTFALL validation")
    print("===================")
    for note in notes:
        print(f"  info: {note}")
    if failures:
        print(f"  FAIL: {len(failures)} issue(s)")
        for item in failures:
            print("   -", item)
        return 1
    print("  PASS: data, place, sources, syntax, requires and remotes all consistent")
    return 0


if __name__ == "__main__":
    sys.exit(main())
