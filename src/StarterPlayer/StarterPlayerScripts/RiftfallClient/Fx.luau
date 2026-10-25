--!nolint
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Fx = {}

local gui = nil
local shakeUntil = 0
local shakePower = 0
local baseFov = 70

function Fx.init(hud)
	gui = hud.gui
	local camera = Workspace.CurrentCamera
	if camera then
		baseFov = camera.FieldOfView
	end
	RunService:BindToRenderStep("RiftfallShake", Enum.RenderPriority.Camera.Value + 1, function()
		local activeCamera = Workspace.CurrentCamera
		if not activeCamera then
			return
		end
		if os.clock() < shakeUntil then
			local offset = Vector3.new(
				(math.random() - 0.5) * shakePower,
				(math.random() - 0.5) * shakePower,
				(math.random() - 0.5) * shakePower * 0.4
			)
			activeCamera.CFrame = activeCamera.CFrame * CFrame.new(offset)
		end
	end)
end

function Fx.shake(power, duration)
	shakePower = power
	shakeUntil = os.clock() + duration
end

function Fx.punch(amount, time)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local outward = TweenService:Create(camera, TweenInfo.new(time or 0.12), {
		FieldOfView = baseFov + amount,
	})
	outward.Completed:Connect(function()
		local activeCamera = Workspace.CurrentCamera
		if not activeCamera then
			return
		end
		TweenService:Create(activeCamera, TweenInfo.new((time or 0.12) * 2.2), {
			FieldOfView = baseFov,
		}):Play()
	end)
	outward:Play()
end

--- Colored full-screen flash, parented to the HUD screen.
function Fx.flash(color, alpha)
	if not gui then
		return
	end
	local frame = Instance.new("Frame")
	frame.Name = "Flash"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = color or Color3.fromRGB(255, 255, 255)
	frame.BackgroundTransparency = alpha or 0.4
	frame.BorderSizePixel = 0
	frame.ZIndex = 40
	frame.Parent = gui
	TweenService:Create(frame, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	task.delay(0.55, function()
		if frame.Parent then
			frame:Destroy()
		end
	end)
end

return Fx
