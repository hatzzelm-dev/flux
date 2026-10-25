#!/usr/bin/env python3
"""Build out/Riftfall.rbxlx from src/.

The place contains no geometry on purpose: WorldBuilder generates the map at
runtime, so the only serialized objects are services and scripts. That keeps the
file small, diffable and free of hand-built Roblox assets.

Serialization mirrors Rojo/rbx-dom exactly, because Studio is stricter than a
generic XML parser about script properties:
  * Source is a <string> (not <ProtectedString>)
  * Script carries an explicit Legacy RunContext token
  * numeric referents, no External/namespace scaffolding

Usage:
    py tools/build_place.py
    py tools/build_place.py --check   # verify the built place is current
"""

from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
OUT_FILE = ROOT / "out" / "Riftfall.rbxlx"

REF_COUNTER = 0


def next_ref() -> str:
    global REF_COUNTER
    REF_COUNTER += 1
    return str(REF_COUNTER)


def esc(text: str) -> str:
    return (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def name_prop(name: str) -> str:
    return f'<string name="Name">{esc(name)}</string>'


def source_prop(source: str) -> str:
    # Rojo writes Source as a string property; Studio accepts this everywhere.
    return f'<string name="Source">{esc(source)}</string>'


def item(class_name: str, indent: str, props: list[str], children: list[str]) -> str:
    lines = [f'{indent}<Item class="{class_name}" referent="{next_ref()}">', f"{indent}\t<Properties>"]
    for prop in props:
        lines.append(f"{indent}\t\t{prop}")
    lines.append(f"{indent}\t</Properties>")
    lines.extend(children)
    lines.append(f"{indent}</Item>")
    return "\n".join(lines)


def classify(filename: str) -> tuple[str, str] | None:
    if filename.startswith("init."):
        return None
    for suffix, class_name in (
        (".server.luau", "Script"),
        (".client.luau", "LocalScript"),
        (".luau", "ModuleScript"),
        (".server.lua", "Script"),
        (".client.lua", "LocalScript"),
        (".lua", "ModuleScript"),
    ):
        if filename.endswith(suffix):
            return filename[: -len(suffix)], class_name
    return None


def file_props(class_name: str, name: str, source: str) -> list[str]:
    props = [name_prop(name)]
    if class_name == "Script":
        # Explicit Legacy context: runs on the server inside ServerScriptService.
        props.append('<token name="RunContext">0</token>')
    if source is not None:
        props.append(source_prop(source))
    return props


def file_node(path: Path, name: str, class_name: str, indent: str) -> str:
    source = path.read_text(encoding="utf-8")
    if not source.strip():
        raise SystemExit(f"error: {path.relative_to(ROOT)} is empty")
    return item(class_name, indent, file_props(class_name, name, source), [])


def dir_node(path: Path, name: str, indent: str) -> str:
    init_files = [
        ("init.server.luau", "Script"),
        ("init.client.luau", "LocalScript"),
        ("init.luau", "ModuleScript"),
        ("init.server.lua", "Script"),
        ("init.client.lua", "LocalScript"),
        ("init.lua", "ModuleScript"),
    ]
    class_name = "Folder"
    source = None
    for filename, candidate in init_files:
        init_path = path / filename
        if init_path.exists():
            class_name = candidate
            source = init_path.read_text(encoding="utf-8")
            if not source.strip():
                raise SystemExit(f"error: {init_path.relative_to(ROOT)} is empty")
            break

    props = file_props(class_name, name, source)

    children: list[str] = []
    entries = sorted(path.iterdir(), key=lambda p: (0 if p.is_dir() else 1, p.name.lower()))
    for entry in entries:
        if entry.name.startswith("init."):
            continue
        if entry.is_dir():
            children.append(dir_node(entry, entry.name, indent + "\t"))
            continue
        classified = classify(entry.name)
        if not classified:
            continue
        child_name, child_class = classified
        children.append(file_node(entry, child_name, child_class, indent + "\t"))

    return item(class_name, indent, props, children)


def service(class_name: str, children: list[str]) -> str:
    return item(class_name, "\t", [name_prop(class_name)], children)


def placeholder_world() -> str:
    """A floor and spawn so Play is never an empty sky, even if scripts fail.

    WorldBuilder destroys these on boot and builds the real plaza.
    """
    baseplate = item(
        "Part",
        "\t\t",
        [
            name_prop("Baseplate"),
            '<bool name="Anchored">true</bool>',
            '<Color3uint8 name="Color3uint8">1316644</Color3uint8>',
            '<token name="Material">800</token>',
            '<Vector3 name="Position">\n\t\t\t<X>0</X>\n\t\t\t<Y>-2</Y>\n\t\t\t<Z>0</Z>\n\t\t</Vector3>',
            '<Vector3 name="size">\n\t\t\t<X>512</X>\n\t\t\t<Y>4</Y>\n\t\t\t<Z>512</Z>\n\t\t</Vector3>',
        ],
        [],
    )
    spawn = item(
        "SpawnLocation",
        "\t\t",
        [
            name_prop("SpawnLocation"),
            '<bool name="Anchored">true</bool>',
            '<bool name="CanCollide">true</bool>',
            '<int name="Duration">0</int>',
            '<bool name="Neutral">true</bool>',
            '<Vector3 name="Position">\n\t\t\t<X>0</X>\n\t\t\t<Y>1</Y>\n\t\t\t<Z>46</Z>\n\t\t</Vector3>',
            '<Vector3 name="size">\n\t\t\t<X>16</X>\n\t\t\t<Y>1</Y>\n\t\t\t<Z>16</Z>\n\t\t</Vector3>',
            '<float name="Transparency">1</float>',
        ],
        [],
    )
    return item(
        "Workspace",
        "\t",
        [name_prop("Workspace"), '<bool name="NeedsPivotMigration">false</bool>'],
        [baseplate, spawn],
    )


def build() -> str:
    global REF_COUNTER
    REF_COUNTER = 0

    replicated = dir_node(SRC / "ReplicatedStorage" / "Riftfall", "Riftfall", "\t\t")
    server_scripts = dir_node(SRC / "ServerScriptService" / "Riftfall", "Riftfall", "\t\t")
    server_storage = dir_node(SRC / "ServerStorage" / "World", "World", "\t\t")
    client_scripts = dir_node(
        SRC / "StarterPlayer" / "StarterPlayerScripts" / "RiftfallClient",
        "RiftfallClient",
        "\t\t\t",
    )

    starter_player_scripts = item(
        "StarterPlayerScripts",
        "\t\t",
        [name_prop("StarterPlayerScripts")],
        [client_scripts],
    )

    parts = [
        '<roblox version="4">',
        placeholder_world(),
        service("ReplicatedStorage", [replicated]),
        service("ServerScriptService", [server_scripts]),
        service("ServerStorage", [server_storage]),
        service("StarterPlayer", [starter_player_scripts]),
        "</roblox>",
        "",
    ]
    return "\n".join(parts)


def stats(xml: str) -> dict[str, int]:
    counts = {"Script": 0, "LocalScript": 0, "ModuleScript": 0, "Folder": 0}
    for key in counts:
        counts[key] = xml.count(f'class="{key}"')
    return counts


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify the built place is current")
    args = parser.parse_args()

    xml = build()
    counts = stats(xml)
    digest = hashlib.sha256(xml.encode("utf-8")).hexdigest()

    if args.check:
        if not OUT_FILE.exists():
            print(f"error: {OUT_FILE.relative_to(ROOT)} is missing; run py tools/build_place.py")
            return 1
        if OUT_FILE.read_text(encoding="utf-8") != xml:
            print(f"error: {OUT_FILE.relative_to(ROOT)} is stale; run py tools/build_place.py")
            return 1
        print(f"ok: place is current ({counts['ModuleScript']} modules, hash {digest[:12]})")
        return 0

    OUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    OUT_FILE.write_text(xml, encoding="utf-8", newline="\n")
    size_kb = OUT_FILE.stat().st_size / 1024
    print(f"wrote {OUT_FILE.relative_to(ROOT)} ({size_kb:.1f} KiB)")
    print(
        "scripts: {Script} server, {LocalScript} client, {ModuleScript} modules, {Folder} folders".format(**counts)
    )
    print(f"hash {digest[:16]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
