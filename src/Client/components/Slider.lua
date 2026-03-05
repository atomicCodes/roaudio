--[[
	Reusable slider: label, value display, and a draggable track.
	Supports click-to-set and drag to slide.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(ReplicatedStorage.Shared.Theme)

type Props = {
	label: string?,
	value: number,
	min: number?,
	max: number?,
	step: number?,
	onChange: (number) -> (),
	width: number?,
	LayoutOrder: number?,
	accentColor: Color3?,
}

local function Slider(props: Props)
	local label = props.label or ""
	local value = props.value
	local min = props.min or 0
	local max = props.max or 1
	local step = props.step or 0.01
	local onChange = props.onChange
	local width = props.width or 120
	local layoutOrder = props.LayoutOrder
	local accentColor = props.accentColor
	local theme = Theme
	local trackColor = accentColor or theme.Accent
	local labelColor = accentColor or theme.TextDim
	local valueColor = accentColor or theme.TextMuted

	local trackRef = React.useRef(nil)
	local isDragging, setDragging = React.useState(false)

	local function valueFromMouseX(track)
		if not track or not track:IsDescendantOf(game) then return value end
		local rel = track.AbsolutePosition.X
		local size = track.AbsoluteSize.X
		if size <= 0 then return value end
		local x = UserInputService:GetMouseLocation().X
		local frac = math.clamp((x - rel) / size, 0, 1)
		local newVal = min + frac * (max - min)
		if step > 0 then
			newVal = math.floor(newVal / step + 0.5) * step
		end
		return math.clamp(newVal, min, max)
	end

	React.useEffect(function()
		if not isDragging then return end
		local connChanged
		local connEnded
		connChanged = UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				local track = trackRef.current
				local newVal = valueFromMouseX(track)
				onChange(newVal)
			end
		end)
		connEnded = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				setDragging(false)
			end
		end)
		return function()
			connChanged:Disconnect()
			connEnded:Disconnect()
		end
	end, { isDragging })

	local normalized = math.clamp((value - min) / (max - min), 0, 1)
	local displayValue = if step >= 1 then string.format("%d", value) else string.format("%.2f", value)

	local frameProps: any = {
		Size = UDim2.new(0, width, 0, 28),
		BackgroundTransparency = 1,
	}
	if layoutOrder ~= nil then
		frameProps.LayoutOrder = layoutOrder
	end
	return React.createElement("Frame", frameProps, {
		React.createElement("UIListLayout", {
			key = "Layout",
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 2),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		React.createElement("Frame", {
			key = "LabelRow",
			Size = UDim2.new(1, 0, 0, 14),
			BackgroundTransparency = 1,
		}, {
			React.createElement("TextLabel", {
				key = "Label",
				Size = UDim2.new(1, -40, 1, 0),
				BackgroundTransparency = 1,
				Text = label,
				TextColor3 = labelColor,
				TextSize = theme.FontSizeSmall,
				Font = theme.Font,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			React.createElement("TextLabel", {
				key = "Value",
				Size = UDim2.new(0, 36, 1, 0),
				Position = UDim2.new(1, -36, 0, 0),
				BackgroundTransparency = 1,
				Text = displayValue,
				TextColor3 = valueColor,
				TextSize = theme.FontSizeSmall,
				Font = theme.Font,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		}),
		React.createElement("TextButton", {
			key = "Track",
			ref = trackRef,
			Size = UDim2.new(1, 0, 0, 6),
			BackgroundColor3 = theme.Surface,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			[React.Event.MouseButton1Down] = function(rbx)
				local newVal = valueFromMouseX(rbx)
				onChange(newVal)
				setDragging(true)
			end,
		}, {
			React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, 3) }),
			React.createElement("Frame", {
				key = "Fill",
				Size = UDim2.new(normalized, 0, 1, 0),
				BackgroundColor3 = trackColor,
				BorderSizePixel = 0,
			}, {
				React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, 3) }),
			}),
		}),
	})
end

return Slider
