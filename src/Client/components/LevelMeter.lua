--[[
	Level meter: shows a vertical bar meter for the channel.
	With the Sound API we don't have real-time level (PeakLevel/RmsLevel);
	that requires the new Audio API + AudioAnalyzer wired to the stream.
	So we show a simulated meter: when playing, bars animate; when stopped, flat at 0.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(ReplicatedStorage.Shared.Theme)

type Props = {
	isPlaying: boolean,
	width: number?,
	height: number?,
	bars?: number,
}

local function LevelMeter(props: Props)
	local isPlaying = props.isPlaying
	local width = props.width or 24
	local height = props.height or 60
	local barCount = props.bars or 8
	local theme = Theme

	-- Simulated level when playing: gentle animation so it looks like activity
	local tick, setTick = React.useState(0)
	React.useEffect(function()
		if not isPlaying then return end
		local RunService = game:GetService("RunService")
		local conn
		conn = RunService.Heartbeat:Connect(function()
			setTick(function(n) return n + 1 end)
		end)
		return function()
			conn:Disconnect()
		end
	end, { isPlaying })

	local bars = {}
	for i = 1, barCount do
		local frac = (i - 1) / barCount
		local level
		if isPlaying then
			local t = (tick + i * 7) % 100 / 100
			level = 0.2 + 0.8 * (0.5 + 0.5 * math.sin(t * math.pi * 4 + frac * 2))
		else
			level = 0
		end
		bars[i] = React.createElement("Frame", {
			key = "bar" .. i,
			Size = UDim2.new(1, -4, level / barCount, -2),
			Position = UDim2.new(0, 2, 1 - frac - level / barCount, 2),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = level > 0.8 and (theme.Stop or Color3.fromRGB(220, 80, 80)) or theme.Accent,
			BorderSizePixel = 0,
		}, {
			React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, 2) }),
		})
	end

	return React.createElement("Frame", {
		Size = UDim2.new(0, width, 0, height),
		BackgroundColor3 = theme.WaveformBg or theme.Surface,
		BorderSizePixel = 0,
	}, {
		React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, theme.RadiusSmall) }),
		React.createElement("UIPadding", { key = "Pad", PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2) }),
		React.createElement("Frame", {
			key = "Bars",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, bars),
	})
end

return LevelMeter
