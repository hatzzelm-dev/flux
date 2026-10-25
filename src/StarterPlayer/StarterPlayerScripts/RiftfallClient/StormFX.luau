--!nolint
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Riftfall")
local Config = require(Shared.Config)
local UIBuilder = require(script.Parent.UIBuilder)
local Fx = require(script.Parent.Fx)
local Audio = require(script.Parent.Audio)

local StormFX = {}

function StormFX.new(hud)
	local self = {
		hud = hud,
		active = false,
		token = 0,
	}

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "RiftfallStormGrade"
	grade.Enabled = false
	grade.Saturation = 0.2
	grade.Contrast = 0.1
	grade.TintColor = Color3.fromRGB(190, 235, 255)
	grade.Parent = Lighting
	self.grade = grade

	local tint = UIBuilder.frame({
		Parent = hud.root,
		Name = "StormTint",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(28, 88, 104),
		BackgroundTransparency = 1,
		ZIndex = 0,
	})
	self.tint = tint

	local flash = UIBuilder.frame({
		Parent = hud.root,
		Name = "StormFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(210, 255, 255),
		BackgroundTransparency = 1,
		ZIndex = 5,
	})
	self.flash = flash

	function self:set(active, duration, luck)
		if active == self.active then
			if active then
				self.hud:setStorm(true, duration or Config.Storm.Duration)
			end
			return
		end
		self.active = active
		self.token = self.token + 1
		if active then
			self.hud:setStorm(true, duration or Config.Storm.Duration)
			self.grade.Enabled = true
			TweenService:Create(self.tint, TweenInfo.new(1.2), { BackgroundTransparency = 0.82 }):Play()
			TweenService:Create(self.grade, TweenInfo.new(1.2), {
				Saturation = 0.55,
				Contrast = 0.2,
				TintColor = Color3.fromRGB(170, 240, 255),
			}):Play()
			Audio.play("storm")
			self.hud:toast(
				string.format("RIFT STORM  |  luck x%.1f  |  storm rifts unlocked", luck or Config.Storm.LuckMultiplier),
				Color3.fromRGB(150, 255, 244)
			)
			local token = self.token
			task.spawn(function()
				while self.active and self.token == token do
					task.wait(math.random(2, 6))
					if not self.active or self.token ~= token then
						break
					end
					self.flash.BackgroundTransparency = 0.62
					TweenService:Create(self.flash, TweenInfo.new(0.28), { BackgroundTransparency = 1 }):Play()
					Audio.play("warn", { volume = 0.28 })
				end
			end)
		else
			self.hud:setStorm(false, 0)
			self.hud:toast("The Rift Storm has passed", Color3.fromRGB(160, 200, 220))
			TweenService:Create(self.tint, TweenInfo.new(1), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(self.grade, TweenInfo.new(1), {
				Saturation = 0.2,
				Contrast = 0.1,
				TintColor = Color3.fromRGB(255, 255, 255),
			}):Play()
			task.delay(1.1, function()
				if not self.active then
					self.grade.Enabled = false
				end
			end)
		end
	end

	return self
end

return StormFX
