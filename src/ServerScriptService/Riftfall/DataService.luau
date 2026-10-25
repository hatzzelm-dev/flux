--!nolint
-- Profile storage for RIFTFALL.
--
-- Design notes:
--  * One DataStore entry per player, written with UpdateAsync so a stale server
--    cannot clobber a newer save.
--  * A session lock is claimed on join with a timestamp. If another live job
--    holds the lock the profile loads read-only (nothing is written) instead of
--    risking a rollback of the player's real data.
--  * If DataStores are unavailable (Studio without API access) the game still
--    plays: the profile is memory-only and the client is told it will not save.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Riftfall")
local Config = require(Shared.Config)
local RiftData = require(Shared.RiftData)

local DataService = {}

local STORE_NAME = Config.Data.StoreName
local LOCK_TTL = Config.Data.LockTtl
local KEY_PREFIX = Config.Data.KeyPrefix
local JOB_ID = string.format("%d-%d", os.time(), math.random(100000, 999999))

local store = nil
local storeOk = false
local profiles = {}

local function now()
	return os.time()
end

local function newProfile()
	return {
		v = Config.Version,
		flux = Config.Rewards.StartingFlux,
		rolls = 0,
		luckLevel = 0,
		speedLevel = 0,
		autoRollUnlocked = false,
		autoRoll = false,
		rifts = {},
		bestId = nil,
		bestOdds = 0,
		milestone = 0,
		tutorialStep = 0,
		purchases = {},
		playtime = 0,
		createdAt = now(),
		lastJoin = now(),
	}
end

local function clampInt(value, minimum, maximum, fallback)
	local number = tonumber(value)
	if not number or number ~= number then
		return fallback
	end
	number = math.floor(number)
	return math.clamp(number, minimum, maximum)
end

local function sanitize(raw)
	local data = newProfile()
	if type(raw) ~= "table" then
		return data
	end

	data.flux = math.max(0, tonumber(raw.flux) or 0)
	data.rolls = clampInt(raw.rolls, 0, 1e12, 0)
	data.luckLevel = clampInt(raw.luckLevel, 0, Config.Upgrades.luck.maxLevel, 0)
	data.speedLevel = clampInt(raw.speedLevel, 0, Config.Upgrades.speed.maxLevel, 0)
	data.autoRollUnlocked = raw.autoRollUnlocked == true
	-- Auto-tear can also be provided by the Rift Runner pass, so do not clear a
	-- saved preference just because the Flux upgrade is not owned.
	data.autoRoll = raw.autoRoll == true
	data.milestone = clampInt(raw.milestone, 0, #Config.Milestones, 0)
	-- First-run guide progress. Profiles that already rolled before the guide
	-- existed are treated as finished so nobody sees it twice.
	local tutorial = clampInt(raw.tutorialStep, 0, 3, nil)
	if raw.tutorialStep == nil and (tonumber(raw.rolls) or 0) > 0 then
		tutorial = 3
	end
	data.tutorialStep = tutorial or 0
	data.playtime = math.max(0, tonumber(raw.playtime) or 0)
	data.createdAt = clampInt(raw.createdAt, 0, 9999999999, now())
	data.lastJoin = now()

	if type(raw.rifts) == "table" then
		for riftId, count in pairs(raw.rifts) do
			if RiftData.RiftById[riftId] and type(count) == "number" and count > 0 then
				data.rifts[riftId] = math.min(math.floor(count), 1e9)
			end
		end
	end

	if type(raw.purchases) == "table" then
		for _, purchaseId in ipairs(raw.purchases) do
			if type(purchaseId) == "string" and #purchaseId <= 128 and #data.purchases < Config.Data.MaxPurchaseLog then
				table.insert(data.purchases, purchaseId)
			end
		end
	end

	-- Recompute the best rift from what is actually owned. This repairs legacy
	-- data and any tampered bestId / bestOdds pair.
	local bestId = nil
	local bestOdds = 0
	for riftId in pairs(data.rifts) do
		local rift = RiftData.RiftById[riftId]
		if rift and rift.odds > bestOdds then
			bestOdds = rift.odds
			bestId = rift.id
		end
	end
	data.bestId = bestId
	data.bestOdds = bestOdds

	return data
end

--- Serialize only plain Lua values (DataStore cannot store Instances, Color3, etc.).
function DataService.serialize(data)
	local copy = {
		v = Config.Version,
		flux = data.flux,
		rolls = data.rolls,
		luckLevel = data.luckLevel,
		speedLevel = data.speedLevel,
		autoRollUnlocked = data.autoRollUnlocked,
		autoRoll = data.autoRoll,
		rifts = {},
		bestId = data.bestId,
		bestOdds = data.bestOdds,
		milestone = data.milestone,
		tutorialStep = data.tutorialStep,
		purchases = {},
		playtime = data.playtime,
		createdAt = data.createdAt,
		lastJoin = data.lastJoin,
	}
	for riftId, count in pairs(data.rifts) do
		copy.rifts[riftId] = count
	end
	for index, purchaseId in ipairs(data.purchases) do
		copy.purchases[index] = purchaseId
	end
	return copy
end

function DataService.uniqueCount(data)
	local total = 0
	for _ in pairs(data.rifts) do
		total = total + 1
	end
	return total
end

function DataService.get(player)
	if not player then
		return nil
	end
	return profiles[player.UserId]
end

function DataService.getData(player)
	local entry = DataService.get(player)
	if entry and entry.loaded then
		return entry.data
	end
	return nil
end

--- Profile data for display, even while the DataStore request is still running.
--- Gameplay actions still go through getData, which only answers once the
--- profile has settled, so nothing can be granted against a provisional copy.
function DataService.peek(player)
	local entry = DataService.get(player)
	if entry then
		return entry.data
	end
	return nil
end

function DataService.touch(player)
	local entry = DataService.get(player)
	if entry then
		entry.dirty = true
		entry.revision = (entry.revision or 0) + 1
	end
end

function DataService.init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok and result then
		store = result
		storeOk = true
	else
		storeOk = false
		warn("Riftfall: DataStores unavailable, progress will not persist this session")
	end

	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveInterval)
			for _, player in ipairs(Players:GetPlayers()) do
				local entry = DataService.get(player)
				if entry and entry.loaded and entry.dirty and entry.canSave then
					DataService.save(player)
				end
			end
		end
	end)
end

function DataService.isPersistent()
	return storeOk
end

--- Load (or create) a profile. Waits at most Config.Data.LoadTimeout seconds for
--- DataStores, so a slow or unavailable store can never freeze the join. When
--- the wait expires the session becomes read-only and the late answer is thrown
--- away instead of replacing progress the player already made.
function DataService.load(player)
	local entry = {
		data = newProfile(),
		canSave = false,
		loaded = false,
		dirty = false,
		saving = false,
		revision = 0,
		lastSave = 0,
		sessionStart = now(),
		error = nil,
		abandoned = false,
	}
	profiles[player.UserId] = entry
	entry.data.lastJoin = now()

	if not storeOk or not store then
		entry.loaded = true
		entry.error = "no-api"
		return entry
	end

	local key = KEY_PREFIX .. tostring(player.UserId)
	local resolved = false

	task.spawn(function()
		for attempt = 1, 3 do
			if entry.abandoned or not player.Parent then
				return
			end
			local ok, stored = pcall(function()
				return store:UpdateAsync(key, function(old)
					if old and type(old) == "table" and old.lock and old.lock.job ~= JOB_ID then
						local age = now() - (tonumber(old.lock.time) or 0)
						if age < LOCK_TTL then
							return nil -- held by another live server
						end
					end
					local payload = nil
					if old and type(old) == "table" then
						payload = old.data
					end
					return { data = payload, lock = { job = JOB_ID, time = now() } }
				end)
			end)

			if ok and stored then
				-- A cancelled update (another live session holds the lock) hands back
				-- the stored value, which still carries the other session's job id.
				-- Check that instead of trusting the return to mean "we wrote".
				if stored.lock and stored.lock.job and stored.lock.job ~= JOB_ID then
					entry.error = "locked"
					entry.loaded = true
					entry.canSave = false
					resolved = true
					return
				end
				if not entry.abandoned then
					entry.data = sanitize(stored.data)
					entry.canSave = true
					entry.error = nil
				end
				entry.loaded = true
				resolved = true
				return
			end

			if ok and not stored then
				entry.error = "locked"
			else
				entry.error = "fetch-failed"
				warn(string.format("Riftfall: profile load attempt %d failed for %s", attempt, player.Name))
			end

			if attempt < 3 then
				task.wait(1.2 * attempt)
			end
		end

		if not entry.abandoned then
			-- Never overwrite data we could not read. Memory-only session.
			entry.loaded = true
			entry.canSave = false
		end
		resolved = true
	end)

	local deadline = os.clock() + (Config.Data.LoadTimeout or 5)
	while not resolved and os.clock() < deadline and player.Parent do
		task.wait(0.1)
	end

	if not resolved then
		entry.abandoned = true
		entry.loaded = true
		entry.canSave = false
		entry.error = "timeout"
	end

	return entry
end

--- Save a profile. Never throws; returns true when the write landed.
function DataService.save(player, force)
	local entry = DataService.get(player)
	if not entry or not entry.loaded then
		return false
	end
	if not entry.canSave or not storeOk or not store then
		entry.dirty = false
		return false
	end
	if not entry.dirty and not force then
		return true
	end
	if entry.saving then
		-- One write at a time per profile: avoids an older snapshot landing after
		-- a newer one. The pending change stays dirty for the next save.
		entry.dirty = true
		return false
	end

	local revision = entry.revision or 0
	local snapshot = DataService.serialize(entry.data)
	local key = KEY_PREFIX .. tostring(player.UserId)
	entry.saving = true
	local ok, result = pcall(function()
		return store:UpdateAsync(key, function(old)
			if old and type(old) == "table" and old.lock and old.lock.job ~= JOB_ID then
				return nil -- lost the lock: do not clobber another session
			end
			return { data = snapshot, lock = { job = JOB_ID, time = now() } }
		end)
	end)

	entry.saving = false
	if ok and result then
		if result.lock and result.lock.job and result.lock.job ~= JOB_ID then
			warn("Riftfall: save skipped, profile is locked by another session")
			return false
		end
		-- Only clear the dirty flag if nothing changed during the write.
		entry.dirty = (entry.revision or 0) ~= revision
		entry.lastSave = now()
		return true
	end
	warn("Riftfall: save failed for " .. player.Name)
	return false
end

--- Final write + release the session lock (used on leave / shutdown).
function DataService.release(player)
	local entry = DataService.get(player)
	if not entry then
		return
	end
	if entry.loaded and entry.canSave and storeOk and store then
		local waited = 0
		while entry.saving and waited < 5 do
			task.wait(0.2)
			waited = waited + 0.2
		end
		local snapshot = DataService.serialize(entry.data)
		local key = KEY_PREFIX .. tostring(player.UserId)
		pcall(function()
			store:UpdateAsync(key, function(old)
				if old and type(old) == "table" and old.lock and old.lock.job ~= JOB_ID then
					return nil
				end
				return { data = snapshot }
			end)
		end)
	end
	profiles[player.UserId] = nil
end

return DataService
