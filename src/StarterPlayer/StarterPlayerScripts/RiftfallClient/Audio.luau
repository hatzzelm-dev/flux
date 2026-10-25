--!nolint
-- One audio bus for the whole client.
--
-- Every cue is a built-in client sound (see Config.Sounds) pitched into a single
-- identity: two base tones carry the game, so nothing depends on a marketplace
-- asset that could be moderated or pulled. Playback is wrapped in pcall and a
-- failed cue is silently skipped - audio can never break gameplay.

local HapticService = game:GetService("HapticService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Riftfall")
local Config = require(Shared.Config)

local Audio = {}

local master = math.clamp(tonumber(Config.Audio and Config.Audio.MasterVolume) or 0.55, 0, 1)
local muted = false
local listeners = {}

local KINDS = {
	roll = { id = "Roll", speed = 0.74, volume = 0.5 },
	charge = { id = "Roll", speed = 0.8, volume = 0.5, sweep = 1.9 },
	reveal = { id = "Reveal", speed = 1.55, volume = 0.65 },
	rare = { id = "Rare", speed = 0.9, volume = 0.75 },
	storm = { id = "Storm", speed = 0.72, volume = 0.8 },
	warn = { id = "Storm", speed = 1.4, volume = 0.5 },
	milestone = { id = "Milestone", speed = 1.05, volume = 0.75 },
	buy = { id = "Buy", speed = 1.25, volume = 0.55 },
	ui = { id = "UI", speed = 1.1, volume = 0.32 },
}

function Audio.isMuted()
	return muted
end

function Audio.setMuted(value)
	local nextState = value == true
	if nextState == muted then
		return
	end
	muted = nextState
	for _, listener in ipairs(listeners) do
		task.spawn(listener, muted)
	end
end

function Audio.onMuteChanged(listener)
	table.insert(listeners, listener)
end

function Audio.toggle()
	Audio.setMuted(not muted)
	return muted
end

--- Play a named cue. Returns the Sound (or nil) so callers can stop/tween it.
function Audio.play(kind, options)
	local spec = KINDS[kind]
	if not spec then
		return nil
	end
	local soundId = Config.Sounds and Config.Sounds[spec.id]
	if muted or type(soundId) ~= "string" or soundId == "" then
		return nil
	end

	local settings = options or {}
	local ok, sound = pcall(function()
		local created = Instance.new("Sound")
		created.Name = "Riftfall_" .. kind
		created.SoundId = soundId
		created.Volume = math.clamp((settings.volume or spec.volume) * master, 0, 10)
		created.PlaybackSpeed = settings.speed or spec.speed
		created.Parent = SoundService
		created:Play()
		return created
	end)
	if not ok or not sound then
		return nil
	end

	if spec.sweep then
		pcall(function()
			TweenService:Create(
				sound,
				TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ PlaybackSpeed = spec.speed * spec.sweep }
			):Play()
		end)
	end

	task.delay(5, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
	return sound
end

function Audio.stop(sound)
	if sound and sound.Parent then
		sound:Destroy()
	end
end

--- Best-effort rumble. Supported on gamepads; on platforms without a motor the
--- call fails inside pcall and nothing happens.
function Audio.haptic(power)
	if not (Config.Audio and Config.Audio.Haptics) then
		return
	end
	local ok = pcall(function()
		HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, math.clamp(power or 0.35, 0, 1))
	end)
	if not ok then
		return
	end
	task.delay(0.12, function()
		pcall(function()
			HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0)
		end)
	end)
end

return Audio
