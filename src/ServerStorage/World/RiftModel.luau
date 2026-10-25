--!nolint
-- Builds a rift portal out of primitives so the game needs no imported meshes
-- or art assets. The model is fully anchored; only particles and the point
-- light animate.

local RiftModel = {}

local SEGMENTS = 14
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local function basePart(props)
	local part = Instance.new("Part")
	part.Name = props.name or "Part"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = props.material or Enum.Material.Neon
	part.Color = props.color or Color3.fromRGB(255, 255, 255)
	part.Size = props.size
	part.CFrame = props.cframe
	part.Transparency = props.transparency or 0
	part.Parent = props.parent
	return part
end

--- Build a portal at `cframe` (portal plane is XY, faces -Z).
--- scale is the diameter in studs.
function RiftModel.build(rift, tier, cframe, scale)
	local model = Instance.new("Model")
	model.Name = "RiftModel_" .. rift.id

	local color = tier.color
	local radius = scale * 0.5
	local thickness = math.max(0.35, scale * 0.07)
	local segmentLength = (2 * math.pi * radius / SEGMENTS) * 0.68
	local tierIndex = math.min(rift.tier, 8)

	for index = 1, SEGMENTS do
		local angle = (index / SEGMENTS) * math.pi * 2
		basePart({
			name = "Ring",
			parent = model,
			size = Vector3.new(segmentLength, thickness, thickness),
			cframe = cframe
				* CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, 0)
				* CFrame.Angles(0, 0, angle + math.pi / 2),
			color = color,
			transparency = 0.05,
			material = Enum.Material.Neon,
		})
	end

	local core = basePart({
		name = "Core",
		parent = model,
		size = Vector3.new(thickness * 0.9, scale, scale),
		cframe = cframe * CFrame.Angles(0, math.rad(90), 0),
		color = color,
		transparency = 0.3,
		material = Enum.Material.ForceField,
	})
	core.Shape = Enum.PartType.Cylinder

	local inner = basePart({
		name = "Inner",
		parent = model,
		size = Vector3.new(thickness * 0.5, scale * 0.52, scale * 0.52),
		cframe = cframe * CFrame.Angles(0, math.rad(90), 0),
		color = color,
		transparency = 0.45,
		material = Enum.Material.Neon,
	})
	inner.Shape = Enum.PartType.Cylinder

	if tierIndex >= 6 then
		basePart({
			name = "Tear",
			parent = model,
			size = Vector3.new(math.max(0.4, scale * 0.06), scale * 4.2, math.max(0.4, scale * 0.06)),
			cframe = cframe,
			color = color,
			transparency = 0.75,
			material = Enum.Material.Neon,
		})
	end

	if tierIndex >= 8 then
		basePart({
			name = "Halo",
			parent = model,
			size = Vector3.new(thickness * 0.4, scale * 1.9, scale * 1.9),
			cframe = cframe * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(18)),
			color = Color3.fromRGB(255, 246, 214),
			transparency = 0.72,
			material = Enum.Material.Neon,
		}).Shape = Enum.PartType.Cylinder
	end

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "RiftParticles"
	emitter.Texture = SPARKLE_TEXTURE
	emitter.Rate = tier.particles
	emitter.Lifetime = NumberRange.new(0.7, 1.5)
	emitter.Speed = NumberRange.new(scale * 0.12, scale * 0.4)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, math.max(0.12, scale * 0.05)),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Parent = core

	local light = Instance.new("PointLight")
	light.Name = "RiftLight"
	light.Color = color
	light.Brightness = 1.2 + tierIndex * 0.55
	light.Range = 24 + scale * 1.4
	light.Shadows = false
	light.Parent = core

	model.PrimaryPart = core
	return model
end

return RiftModel
