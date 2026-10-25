"""Recompute the HUD and onboarding rectangles from the real Luau sources.

The mobile completion criteria are geometric: every control is at least 56px on
every side, nothing overlaps, and nothing leaves the screen. Rather than mirror
the layout here (a second copy that can silently drift), this reads the actual
size / position / anchor literals out of Hud.luau, Onboarding.luau and the two
panel modules, then checks the criteria at 640x360, 1024x768 and 1920x1080.

Run: py tools/check_layout.py
"""

import re
import sys
import types
from pathlib import Path

CLIENT = Path("src/StarterPlayer/StarterPlayerScripts/RiftfallClient")
HUD = (CLIENT / "Hud.luau").read_text(encoding="utf-8")
ONBOARDING = (CLIENT / "Onboarding.luau").read_text(encoding="utf-8")
DEX = (CLIENT / "DexPanel.luau").read_text(encoding="utf-8")
SHOP = (CLIENT / "ShopPanel.luau").read_text(encoding="utf-8")
REVEAL = (CLIENT / "RevealController.luau").read_text(encoding="utf-8")

INSET = 36  # GuiService:GetGuiInset().Y on a phone topbar: a device fact, not a layout value
MIN_TOUCH = 56  # the plan's touch minimum
TOUCH_BAND = 130  # Roblox's touch jump button owns the bottom-right corner

failures = []
checks = 0


def check(ok, message, detail=""):
    global checks
    checks += 1
    if not ok:
        failures.append(f"{message} {detail}".strip())


def read(pattern, source, what):
    match = re.search(pattern, source)
    check(match is not None, f"cannot read {what} from source")
    return match.group(1) if match else "0"


def read_block(source, anchor):
    start = source.find(anchor)
    if start < 0:
        check(False, f"missing anchor {anchor}")
        return ""
    rest = source[start:]
    return rest[: rest.index("})")] if "})" in rest else rest


def prop(block, name, anchor, required=True):
    pattern = rf"(?<![\w.]){name} = (UDim2\.(?:new|fromOffset|fromScale)\([^)]*\)|Vector2\.new\([^)]*\))"
    match = re.search(pattern, block)
    if match:
        return match.group(1)
    if required:
        check(False, f"cannot read {name} ({anchor})")
    return None


TOP_OFFSET = INSET + int(read(r"local topOffset = inset\.Y \+ (\d+)", HUD, "topOffset"))
ENV = {"topOffset": TOP_OFFSET, "inset": types.SimpleNamespace(Y=INSET)}


def number(expr):
    return float(eval(expr, {"__builtins__": {}}, ENV))


def udim2(expr, width, height):
    kind, args = re.fullmatch(r"UDim2\.(\w+)\((.*)\)", expr).groups()
    values = [part.strip() for part in args.split(",")]
    if kind == "fromOffset":
        parts = (0, number(values[0]), 0, number(values[1]))
    elif kind == "fromScale":
        parts = (number(values[0]), 0, number(values[1]), 0)
    else:
        parts = tuple(number(part) for part in values)
    sx, offset_x, sy, offset_y = parts
    return sx * width + offset_x, sy * height + offset_y


def vector2(expr):
    x, y = (part.strip() for part in re.fullmatch(r"Vector2\.new\((.*)\)", expr).group(1).split(","))
    return number(x), number(y)


def rect(x, y, w, h):
    return {"x0": x, "y0": y, "x1": x + w, "y1": y + h, "w": w, "h": h}


ELEMENTS = [
    ("storm banner", HUD, 'Name = "StormBanner"', "gui"),
    ("mute", HUD, 'Name = "MuteButton"', "gui"),
    ("toast", HUD, 'Name = "Toast"', "gui"),
    ("tear", HUD, "rollButton", "gui"),
    ("auto", HUD, 'Name = "AutoButton"', "gui"),
    ("dex", HUD, 'Name = "DexButton"', "gui"),
    ("shop", HUD, 'Name = "ShopButton"', "gui"),
    ("flux card", HUD, 'Name = "FluxCard"', "layer"),
    ("luck card", HUD, 'Name = "LuckCard"', "layer"),
    ("guide card", ONBOARDING, 'Name = "Card"', "gui"),
    ("guide OK", ONBOARDING, 'Text = "OK"', "card"),
    ("guide SKIP", ONBOARDING, 'Text = "SKIP"', "card"),
    ("riftodex card", DEX, 'Name = "DexCard"', "layer"),
    ("rift lab card", SHOP, 'Name = "ShopCard"', "layer"),
]

GUIDE_POSITION = read(r"self\.card\.Position = (UDim2\.[^\n]+)", ONBOARDING, "guide card position")
ARROW_SIZE = prop(read_block(ONBOARDING, 'Name = "Arrow"'), "Size", "arrow")
ARROW_GAP = int(read(r"self\.arrow\.AbsoluteSize\.Y - (\d+)", ONBOARDING, "arrow gap"))
BASE_WIDTH = int(read(r"local BASE_WIDTH = (\d+)", HUD, "root width"))
BASE_HEIGHT = int(read(r"local BASE_HEIGHT = (\d+)", HUD, "root height"))
SCALE_MIN, SCALE_MAX = (float(v) for v in re.search(
    r"scale\.Scale = math\.clamp\(factor, ([\d.]+), ([\d.]+)\)", HUD
).groups())


def element(name, anchor, source, position=None):
    """Return (size, position, anchor) expressions for one UI object."""
    if anchor == "rollButton":
        return (
            read(r"rollButton\.Size = (UDim2\.[^\n]+)", source, f"{name} size"),
            read(r"rollButton\.Position = (UDim2\.[^\n]+)", source, f"{name} position"),
            read(r"rollButton\.AnchorPoint = (Vector2\.[^\n]+)", source, f"{name} anchor"),
        )
    block = read_block(source, anchor)
    return (
        prop(block, "Size", anchor),
        position or prop(block, "Position", anchor) or "UDim2.new(0, 0, 0, 0)",
        prop(block, "AnchorPoint", anchor, required=False) or "Vector2.new(0, 0)",
    )


def place(size, position, anchor, space_width, space_height, scale=1.0, origin=(0.0, 0.0)):
    w, h = udim2(size, space_width, space_height)
    x, y = udim2(position, space_width, space_height)
    ax, ay = vector2(anchor)
    return rect(origin[0] + (x - ax * w) * scale, origin[1] + (y - ay * h) * scale, w * scale, h * scale)


def overlaps(a, b):
    return not (a["x1"] <= b["x0"] or b["x1"] <= a["x0"] or a["y1"] <= b["y0"] or b["y1"] <= a["y0"])


def inside(r, width, height):
    return r["x0"] >= 0 and r["y0"] >= 0 and r["x1"] <= width and r["y1"] <= height


# --- layering: one owner for what covers the HUD ------------------------------
def check_overlay(label, source):
    # Anchor the whole table so the Parent line above Name is inside the block.
    block = read_block(source, "local overlay = UIBuilder.frame({")
    check("Parent = hud.panelLayer" in block, f"{label} overlay is not on the panel layer")
    check(re.search(r"(?<![\w.])Active = true", block) is not None, f"{label} overlay does not sink input")


check_overlay("Riftodex", DEX)
check_overlay("Rift lab", SHOP)
check("card.Parent = hud.panelLayer" in REVEAL, "Reveal card is not on the panel layer")
check(
    HUD.index("local panelLayer") > HUD.index("local controls"),
    "panelLayer must be a later sibling than Controls to draw above it",
)
check("panelScale.Scale = scale.Scale" in HUD, "panel layer scale is not driven by the root scale")


def report():
    print(f"RIFTFALL layout check ({checks} assertions from source)")
    for failure in failures:
        print("  FAIL:", failure)
    if failures:
        print(f"FAIL: {len(failures)} layout assertions failed")
        sys.exit(1)


LAYOUT = {
    name: element(name, anchor, source, GUIDE_POSITION if name == "guide card" else None) + (space,)
    for name, source, anchor, space in ELEMENTS
}
if failures:
    report()

for width, height in ((640, 360), (1024, 768), (1920, 1080)):
    tag = f"{width}x{height}"
    scale = max(SCALE_MIN, min(width / BASE_WIDTH, height / BASE_HEIGHT, SCALE_MAX))
    layer_w, layer_h = BASE_WIDTH * scale, BASE_HEIGHT * scale
    layer_origin = ((width - layer_w) / 2, (height - layer_h) / 2)

    card_size, card_pos, card_anchor = LAYOUT["guide card"][:3]
    guide_card = dict(place(card_size, card_pos, card_anchor, width, height), name="guide card")
    shapes = {"guide card": guide_card}
    for name, (size, pos, anc, space) in LAYOUT.items():
        if name == "guide card":
            continue
        if space == "layer":
            shape = place(size, pos, anc, BASE_WIDTH, BASE_HEIGHT, scale, layer_origin)
        elif space == "card":
            local = place(size, pos, anc, guide_card["w"], guide_card["h"])
            shape = rect(guide_card["x0"] + local["x0"], guide_card["y0"] + local["y0"], local["w"], local["h"])
        else:
            shape = place(size, pos, anc, width, height)
        shapes[name] = dict(shape, name=name)

    storm, mute, toast, tear = (shapes[k] for k in ("storm banner", "mute", "toast", "tear"))
    auto, dex, shop = (shapes[k] for k in ("auto", "dex", "shop"))
    ok, skip, card = shapes["guide OK"], shapes["guide SKIP"], guide_card

    def arrow(target):
        ax, ay = udim2(ARROW_SIZE, 0, 0)
        return rect(target["x0"] + target["w"] / 2 - ax / 2, target["y0"] - ay - ARROW_GAP, ax, ay)

    for item in (tear, auto, dex, shop, mute, ok, skip):
        check(
            item["w"] >= MIN_TOUCH and item["h"] >= MIN_TOUCH,
            f"{tag}: {item['name']} under {MIN_TOUCH}px",
            f"{item['w']:.0f}x{item['h']:.0f}",
        )
        check(inside(item, width, height), f"{tag}: {item['name']} leaves the screen")

    for label, a, b in (
        ("tear / auto", tear, auto),
        ("tear / dex", tear, dex),
        ("guide card / mute", card, mute),
        ("storm banner / flux card", storm, shapes["flux card"]),
        ("storm banner / luck card", storm, shapes["luck card"]),
        ("storm banner / mute", storm, mute),
        ("toast / shop", toast, shop),
        ("toast / dex", toast, dex),
        ("toast / auto", toast, auto),
        ("toast / tear", toast, tear),
        ("guide card / shop", card, shop),
        ("guide card / dex", card, dex),
        ("guide card / tear arrow", card, arrow(tear)),
        ("guide card / shop arrow", card, arrow(shop)),
        ("guide card / dex arrow", card, arrow(dex)),
        ("guide OK / guide SKIP", ok, skip),
    ):
        check(not overlaps(a, b), f"{tag}: overlap {label}")

    for item in (dex, shop):
        band = height - item["y1"]
        check(band >= TOUCH_BAND, f"{tag}: {item['name']} sits in the jump-button band", f"{band:.0f}px")

    for name in ("riftodex card", "rift lab card"):
        check(inside(shapes[name], width, height), f"{tag}: {name} does not fit")
    for target in (tear, shop, dex):
        check(inside(arrow(target), width, height), f"{tag}: guide arrow for {target['name']} leaves the screen")
    check(card["x1"] <= width and card["y0"] >= INSET, f"{tag}: guide card not clear of the top bar")

report()
print("PASS: controls >= 56px, no overlaps, panels above the controls at 640x360, 1024x768 and 1920x1080")
