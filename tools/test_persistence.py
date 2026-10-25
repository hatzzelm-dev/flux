#!/usr/bin/env python3
"""Persistence test for DataService, run outside Roblox.

The save/load logic only touches DataStores through UpdateAsync, so it can be
executed against a fake store in a plain Lua runtime. This exercises the real
DataService.luau source (same file the place is built from) for:

  * first join, mutation and save
  * a second live session being locked out without clobbering the first
  * a clean leave writing data and dropping the session lock
  * a fresh session loading every persisted field back

Usage:
    py tools/test_persistence.py
"""

from __future__ import annotations

import sys
from pathlib import Path

from lupa import LuaRuntime

ROOT = Path(__file__).resolve().parent.parent
SHARED = ROOT / "src" / "ReplicatedStorage" / "Riftfall"

PRELUDE = """
math.clamp = function(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

TestStore = {}
Shared = {}

local FakeStore = {}
function FakeStore:UpdateAsync(key, transform)
    local old = TestStore[key]
    local new = transform(old)
    -- Roblox semantics: a nil return cancels the write and hands back the value
    -- that is currently stored (which may belong to another session).
    if new == nil then
        return old
    end
    TestStore[key] = new
    return new
end
function FakeStore:GetAsync(key)
    return TestStore[key]
end

local DataStoreService = { GetDataStore = function(self, name) return FakeStore end }
local PlayersService = { GetPlayers = function(self) return {} end }
local ReplicatedStorage = { WaitForChild = function(self, name) return Shared end }

game = {
    GetService = function(self, name)
        if name == "DataStoreService" then return DataStoreService end
        if name == "Players" then return PlayersService end
        if name == "ReplicatedStorage" then return ReplicatedStorage end
        return {}
    end,
}

local waitBudget = 0
task = {
    -- Runs synchronously; the autosave loop is cut short by the wait budget so
    -- init() can return with a single player instead of spinning forever.
    spawn = function(fn) pcall(fn) end,
    wait = function(seconds)
        waitBudget = waitBudget - 1
        if waitBudget <= 0 then error("wait budget exhausted") end
    end,
    delay = function(seconds, fn) end,
}

function ResetWaits()
    waitBudget = 2000
end

warn = function(...) print("[warn]", ...) end
require = function(value) return value end
"""

TEST = """
function RunPersistenceTest(ds1, ds2, ds3)
    local results = {}
    local function check(name, ok, detail)
        results[#results + 1] = { name = name, ok = ok and true or false, detail = detail and tostring(detail) or "" }
    end

    local riftId = RiftData.Rifts[1].id
    local key = "Player_1001"

    ResetWaits()
    ds1.init()
    local p1 = { UserId = 1001, Name = "Tester", Parent = true }
    local e1 = ds1.load(p1)
    check("first join loads a writable profile", e1.loaded == true and e1.canSave == true, e1.error)

    local d1 = ds1.getData(p1)
    check("fresh profile exists", d1 ~= nil)
    check("new profile starts the guide at step 0", d1.tutorialStep == 0, d1.tutorialStep)
    d1.tutorialStep = 2
    d1.flux = 1234
    d1.rolls = 7
    d1.luckLevel = 2
    d1.speedLevel = 1
    d1.autoRollUnlocked = true
    d1.rifts[riftId] = 3
    ds1.touch(p1)

    ResetWaits()
    check("save returns true", ds1.save(p1, true) == true)
    check("save stores the session lock", TestStore[key] ~= nil and TestStore[key].lock ~= nil)

    ResetWaits()
    ds2.init()
    local p2 = { UserId = 1001, Name = "Tester", Parent = true }
    local e2 = ds2.load(p2)
    check("second live session is locked out", e2.error == "locked" and e2.canSave == false, e2.error)

    local d2 = ds2.getData(p2)
    check("locked session does not inherit stored progress", d2.flux ~= 1234, d2.flux)
    d2.flux = 999
    ds2.touch(p2)
    ResetWaits()
    check("locked session cannot write", ds2.save(p2, true) == false)
    check("locked session does not clobber", TestStore[key].data.flux == 1234, TestStore[key].data.flux)
    ResetWaits()
    ds2.release(p2)

    ResetWaits()
    ds1.release(p1)
    check("leave clears the session lock", TestStore[key].lock == nil)
    check("leave keeps the latest data", TestStore[key].data.flux == 1234, TestStore[key].data.flux)

    ResetWaits()
    ds3.init()
    local p3 = { UserId = 1001, Name = "Tester", Parent = true }
    local e3 = ds3.load(p3)
    check("rejoin loads a writable profile", e3.loaded == true and e3.canSave == true, e3.error)

    local d3 = ds3.getData(p3)
    check("flux persisted", d3.flux == 1234, d3.flux)
    check("roll count persisted", d3.rolls == 7, d3.rolls)
    check("luck level persisted", d3.luckLevel == 2, d3.luckLevel)
    check("speed level persisted", d3.speedLevel == 1, d3.speedLevel)
    check("auto-tear persisted", d3.autoRollUnlocked == true, d3.autoRollUnlocked)
    check("rift counts persisted", d3.rifts[riftId] == 3, d3.rifts[riftId])
    check("tutorial progress persisted", d3.tutorialStep == 2, d3.tutorialStep)
    check("best rift recomputed", d3.bestId == riftId, d3.bestId)
    check("riftodex count restored", ds3.uniqueCount(d3) == 1, ds3.uniqueCount(d3))

    -- Legacy profile from before the guide existed: any recorded roll means the
    -- player has already played, so the guide must stay hidden.
    TestStore["Player_2002"] = { data = { v = 1, flux = 5, rolls = 9 } }
    ResetWaits()
    local p4 = { UserId = 2002, Name = "Legacy", Parent = true }
    local e4 = ds3.load(p4)
    check("legacy profile loads", e4.loaded == true and e4.canSave == true, e4.error)
    local d4 = ds3.getData(p4)
    check("legacy profile skips the guide", d4.tutorialStep == 3, d4.tutorialStep)
    ds3.release(p4)

    -- Out-of-range stored values are clamped, not trusted.
    TestStore["Player_2003"] = { data = { v = 2, flux = 0, rolls = 0, tutorialStep = 99 } }
    ResetWaits()
    local p5 = { UserId = 2003, Name = "Clamp", Parent = true }
    ds3.load(p5)
    local d5 = ds3.getData(p5)
    check("tutorial progress is clamped", d5.tutorialStep == 3, d5.tutorialStep)
    ds3.release(p5)

    return results
end
"""


def load_module(lua, name: str, path: Path):
    source = path.read_text(encoding="utf-8")
    loader = lua.eval("function(src) local chunk = assert(load(src, 'module')); return chunk() end")
    return loader(source)


def main() -> int:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("Color3 = { fromRGB = function(r, g, b) return { r = r, g = g, b = b } end }")
    lua.execute(PRELUDE)

    config = load_module(lua, "Config", SHARED / "Config.luau")
    riftdata = load_module(lua, "RiftData", SHARED / "RiftData.luau")

    shared = lua.globals().Shared
    shared["Config"] = config
    shared["RiftData"] = riftdata
    lua.globals().Config = config
    lua.globals().RiftData = riftdata

    data_service_path = ROOT / "src" / "ServerScriptService" / "Riftfall" / "DataService.luau"
    ds1 = load_module(lua, "DataService", data_service_path)
    ds2 = load_module(lua, "DataService", data_service_path)
    ds3 = load_module(lua, "DataService", data_service_path)

    lua.execute(TEST)
    results = lua.globals().RunPersistenceTest(ds1, ds2, ds3)

    failures = 0
    print("RIFTFALL persistence test")
    print("=" * 60)
    for row in results.values():
        ok = bool(row.ok)
        detail = row.detail
        if not ok:
            failures += 1
        line = f"  {'PASS' if ok else 'FAIL'}: {row.name}"
        if not ok and detail:
            line += f"  [{detail}]"
        print(line)

    total = len(results)
    print("=" * 60)
    if failures:
        print(f"FAILED {failures}/{total}")
        return 1
    print(f"PASS: {total}/{total} persistence checks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
