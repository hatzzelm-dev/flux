--!nolint
local TweenService = game:GetService("TweenService")

local UIBuilder = {}

function UIBuilder.create(className, props)
	local instance = Instance.new(className)
	local parent = nil
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			instance[key] = value
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UIBuilder.corner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = parent
	return corner
end

function UIBuilder.stroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(60, 74, 120)
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function UIBuilder.gradient(parent, colorA, colorB, rotation)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(colorA, colorB)
	gradient.Rotation = rotation or 90
	gradient.Parent = parent
	return gradient
end

function UIBuilder.padding(parent, top, right, bottom, left)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, top or 0)
	pad.PaddingRight = UDim.new(0, right or top or 0)
	pad.PaddingBottom = UDim.new(0, bottom or top or 0)
	pad.PaddingLeft = UDim.new(0, left or right or top or 0)
	pad.Parent = parent
	return pad
end

function UIBuilder.frame(props)
	props.BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(16, 20, 36)
	props.BorderSizePixel = 0
	return UIBuilder.create("Frame", props)
end

function UIBuilder.label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.BorderSizePixel = 0
	props.Font = props.Font or Enum.Font.Gotham
	props.TextColor3 = props.TextColor3 or Color3.fromRGB(236, 240, 255)
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center
	props.Text = props.Text or ""
	return UIBuilder.create("TextLabel", props)
end

function UIBuilder.button(props)
	props.BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(32, 42, 72)
	props.BorderSizePixel = 0
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or Color3.fromRGB(236, 240, 255)
	props.Text = props.Text or ""
	props.AutoButtonColor = true
	return UIBuilder.create("TextButton", props)
end

function UIBuilder.scrolling(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.BorderSizePixel = 0
	props.ScrollBarThickness = props.ScrollBarThickness or 6
	props.ScrollBarImageColor3 = props.ScrollBarImageColor3 or Color3.fromRGB(90, 110, 160)
	props.CanvasSize = props.CanvasSize or UDim2.new()
	return UIBuilder.create("ScrollingFrame", props)
end

function UIBuilder.tween(instance, time, goal, style, direction)
	local info = TweenInfo.new(
		time or 0.25,
		style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out
	)
	local tween = TweenService:Create(instance, info, goal)
	tween:Play()
	return tween
end

return UIBuilder
