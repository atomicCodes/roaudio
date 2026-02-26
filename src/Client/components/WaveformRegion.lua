--[[
	Waveform-style bar display with draggable start/end region.
	Roblox does not expose raw waveform data; we show a placeholder bar chart
	by duration and allow adjusting the playback region (start/end).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(ReplicatedStorage.Shared.Theme)

type Props = {
	width: number,
	height: number,
	duration: number,
	regionStart: number,
	regionEnd: number, -- 0 = full
	onRegionChange: (start: number, end_: number) -> (),
}

-- Placeholder "waveform": simple bars so it looks like a waveform
local function makeBars(count: number, height: number): { number }
	local bars = {}
	for i = 1, count do
		-- Slight variation for visual interest
		local t = (i - 1) / math.max(count - 1, 1)
		local h = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(t * 12))
		table.insert(bars, h * height)
	end
	return bars
end

local function WaveformRegion(props: Props)
	local width = props.width
	local height = props.height
	local duration = math.max(props.duration, 0.001)
	local regionStart = math.clamp(props.regionStart, 0, duration)
	local regionEnd = props.regionEnd > 0 and math.clamp(props.regionEnd, regionStart, duration) or duration
	local onRegionChange = props.onRegionChange
	local theme = Theme
	local containerRef = React.useRef(nil)

	local startFrac = regionStart / duration
	local endFrac = regionEnd / duration
	local barCount = math.floor(width / 4)
	local bars = makeBars(barCount, height)

	local function updateFromMouse(isStart: boolean?)
		local frame = containerRef.current
		if not frame then return end
		local mouse = game:GetService("UserInputService"):GetMouseLocation()
		local rx = frame.AbsolutePosition.X
		local rw = frame.AbsoluteSize.X
		local frac = math.clamp((mouse.X - rx) / rw, 0, 1)
		local time = frac * duration
		if isStart == true then
			onRegionChange(time, math.max(regionEnd, time))
		elseif isStart == false then
			onRegionChange(math.min(regionStart, time), time)
		end
	end

	return React.createElement("Frame", {
		Size = UDim2.new(0, width, 0, height),
		BackgroundColor3 = theme.WaveformBg,
		BorderSizePixel = 0,
	}, {
		React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, theme.RadiusSmall) }),
		React.createElement("Frame", {
			key = "Clip",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			ref = containerRef,
		}, {
			React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, theme.RadiusSmall) }),
			React.createElement("Frame", {
				key = "Bars",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
			}, (function()
				local els = {}
				for i, barHeight in ipairs(bars) do
					local x = (i - 1) / barCount
					els[i] = React.createElement("Frame", {
						key = "b" .. i,
						Size = UDim2.new(0, 2, barHeight / height, -2),
						Position = UDim2.new(x, 2, 0.5, -barHeight / 2),
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundColor3 = theme.WaveformBar,
						BorderSizePixel = 0,
					}, {
						React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, 1) }),
					})
				end
				return els
			end)()),
			React.createElement("Frame", {
				key = "RegionOverlay",
				Size = UDim2.new(endFrac - startFrac, 0, 1, 0),
				Position = UDim2.new(startFrac, 0, 0, 0),
				BackgroundColor3 = theme.WaveformRegion,
				BackgroundTransparency = 1 - theme.WaveformRegionAlpha,
				BorderSizePixel = 0,
				ZIndex = 1,
			}, {
				React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, theme.RadiusSmall) }),
			}),
			React.createElement("TextButton", {
				key = "StartHandle",
				Size = UDim2.new(0, 8, 1, 4),
				Position = UDim2.new(startFrac, -4, 0, -2),
				BackgroundColor3 = theme.Accent,
				BorderSizePixel = 0,
				Text = "",
				AutoButtonColor = false,
				ZIndex = 2,
				[React.Event.MouseButton1Down] = function()
					local uis = game:GetService("UserInputService")
					local conn
					conn = uis.InputChanged:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseMovement then
							updateFromMouse(true)
						end
					end)
					uis.InputEnded:Once(function(i)
						if i.UserInputType == Enum.UserInputType.MouseButton1 then
							conn:Disconnect()
						end
					end)
				end,
			}, {
				React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, 2) }),
			}),
			React.createElement("TextButton", {
				key = "EndHandle",
				Size = UDim2.new(0, 8, 1, 4),
				Position = UDim2.new(endFrac, -4, 0, -2),
				BackgroundColor3 = theme.Accent,
				BorderSizePixel = 0,
				Text = "",
				AutoButtonColor = false,
				ZIndex = 2,
				[React.Event.MouseButton1Down] = function()
					local uis = game:GetService("UserInputService")
					local conn
					conn = uis.InputChanged:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseMovement then
							updateFromMouse(false)
						end
					end)
					uis.InputEnded:Once(function(i)
						if i.UserInputType == Enum.UserInputType.MouseButton1 then
							conn:Disconnect()
						end
					end)
				end,
			}, {
				React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, 2) }),
			}),
		}),
	})
end

return WaveformRegion
