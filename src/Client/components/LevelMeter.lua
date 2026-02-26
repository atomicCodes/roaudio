--[[
	VU-style level meter: vertical bar (fill from bottom) or horizontal bar (fill from left).
	Uses real level from the new Audio API (AudioAnalyzer.PeakLevel) when the
	optional `level` prop (0–1) is provided and playing; otherwise shows 0 or simulated.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(ReplicatedStorage.Shared.Theme)

type Props = {
	isPlaying: boolean,
	width: number?,
	height: number?,
	level: number?, -- 0–1, optional override (e.g. from AudioAnalyzer later)
	horizontal: boolean?, -- if true, bar fills left-to-right; width/height define the bar size
}

local function LevelMeter(props: Props)
	local isPlaying = props.isPlaying
	local width = props.width or 16
	local height = props.height or 60
	local levelOverride = props.level
	local horizontal = props.horizontal or false
	local theme = Theme

	-- Simulated level when playing (oscillating so it looks like a VU); use override if provided
	local tick, setTick = React.useState(0)
	React.useEffect(function()
		if not isPlaying then return end
		local RunService = game:GetService("RunService")
		local conn = RunService.Heartbeat:Connect(function()
			setTick(function(n) return n + 1 end)
		end)
		return function()
			conn:Disconnect()
		end
	end, { isPlaying })

	local level
	if type(levelOverride) == "number" and levelOverride >= 0 and levelOverride <= 1 then
		level = levelOverride
	elseif isPlaying then
		local t = (tick % 60) / 60
		level = 0.15 + 0.75 * (0.5 + 0.5 * math.sin(t * math.pi * 6))
	else
		level = 0
	end

	-- VU colors: green low, yellow mid, red high
	local function levelColor(l: number): Color3
		if l <= 0.5 then
			return Color3.fromRGB(0, 200, 120) -- green (theme.Play)
		elseif l <= 0.8 then
			return Color3.fromRGB(220, 180, 0) -- yellow
		else
			return theme.Stop or Color3.fromRGB(220, 80, 80) -- red
		end
	end

	local fillSize, fillPosition, fillAnchor
	local scaleTicks = {}
	if horizontal then
		fillSize = UDim2.new(level, 0, 1, 0)
		fillPosition = UDim2.new(0, 0, 0, 0)
		fillAnchor = Vector2.new(0, 0)
		for pct = 1, 3 do
			local frac = pct / 4
			scaleTicks[pct] = React.createElement("Frame", {
				key = "t" .. pct,
				Size = UDim2.new(0, 1, 1, 0),
				Position = UDim2.new(frac, 0, 0, 0),
				BackgroundColor3 = theme.Border,
				BorderSizePixel = 0,
				BackgroundTransparency = 0.5,
			})
		end
	else
		fillSize = UDim2.new(1, 0, level, 0)
		fillPosition = UDim2.new(0, 0, 1, 0)
		fillAnchor = Vector2.new(0, 1)
		for pct = 1, 3 do
			local frac = pct / 4
			scaleTicks[pct] = React.createElement("Frame", {
				key = "t" .. pct,
				Size = UDim2.new(1, 0, 0, 1),
				Position = UDim2.new(0, 0, 1 - frac, 0),
				BackgroundColor3 = theme.Border,
				BorderSizePixel = 0,
				BackgroundTransparency = 0.5,
			})
		end
	end

	return React.createElement("Frame", {
		Size = UDim2.new(0, width, 0, height),
		BackgroundColor3 = theme.WaveformBg or Color3.fromRGB(24, 24, 28),
		BorderSizePixel = 0,
	}, {
		React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, theme.RadiusSmall) }),
		React.createElement("UIPadding", {
			key = "Pad",
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 2),
		}),
		-- Scale ticks (VU style): horizontal lines at 25%, 50%, 75% (vertical bar) or vertical lines (horizontal bar)
		React.createElement("Frame", {
			key = "Scale",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ClipsDescendants = false,
		}, scaleTicks),
		-- Fill: vertical bar from bottom or horizontal bar from left
		React.createElement("Frame", {
			key = "Fill",
			Size = fillSize,
			Position = fillPosition,
			AnchorPoint = fillAnchor,
			BackgroundColor3 = levelColor(level),
			BorderSizePixel = 0,
		}, {
			React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, 2) }),
		}),
	})
end

return LevelMeter
