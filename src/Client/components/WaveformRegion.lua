--[[
	Waveform-style bar display with draggable start/end region.

	With the NEW Audio API, AudioPlayer:GetWaveformAsync(timeRange, samples) returns
	an array of waveform samples for the whole file (or a time range). When
	waveformSamples is provided, we draw a real waveform overview; otherwise a placeholder.
	AudioAnalyzer.GetSpectrum() gives per-buffer data (live only) for a rolling display.
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
	timePosition: number?, -- current playhead in seconds; when set, draw playhead line
	waveformSamples: { number }?, -- from AudioPlayer:GetWaveformAsync; when set, draw real waveform
	onRegionChange: (start: number, end_: number) -> (),
}

-- Placeholder "waveform": simple bars when no real samples
local function makeBars(count: number, height: number): { number }
	local bars = {}
	for i = 1, count do
		local t = (i - 1) / math.max(count - 1, 1)
		local h = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(t * 12))
		table.insert(bars, h * height)
	end
	return bars
end

-- Build bar heights from GetWaveformAsync samples (downsample to barCount, normalize)
local function samplesToBars(samples: { number }, barCount: number, height: number): { number }
	if not samples or #samples == 0 then return makeBars(barCount, height) end
	local n = #samples
	local maxVal = 0.001
	for i = 1, n do
		local v = math.abs((samples[i]) or 0)
		if v > maxVal then maxVal = v end
	end
	local bars = {}
	for i = 1, barCount do
		local idx = math.floor((i - 0.5) / barCount * n) + 1
		idx = math.clamp(idx, 1, n)
		local v = math.abs((samples[idx]) or 0) / maxVal
		table.insert(bars, v * height)
	end
	return bars
end

local function formatTime(seconds: number): string
	local m = math.floor(seconds / 60)
	local s = math.floor(seconds % 60)
	local h = math.floor((seconds % 1) * 100)
	return string.format("%d:%02d.%02d", m, s, h)
end

local function WaveformRegion(props: Props)
	local width = props.width
	local height = props.height
	local duration = math.max(props.duration, 0.001)
	local regionStart = math.clamp(props.regionStart, 0, duration)
	local regionEnd = props.regionEnd > 0 and math.clamp(props.regionEnd, regionStart, duration) or duration
	local timePosition = props.timePosition
	local waveformSamples = props.waveformSamples
	local onRegionChange = props.onRegionChange
	local theme = Theme
	local containerRef = React.useRef(nil)
	local draggingMarker, setDraggingMarker = React.useState(nil :: "start" | "end" | nil)

	local startFrac = regionStart / duration
	local endFrac = regionEnd / duration
	local playheadFrac = (type(timePosition) == "number" and duration > 0) and math.clamp(timePosition / duration, 0, 1) or nil
	local barCount = math.floor(width / 4)
	local bars
	if waveformSamples and #waveformSamples > 0 then
		bars = samplesToBars(waveformSamples, barCount, height)
	else
		bars = makeBars(barCount, height)
	end

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
	}, (function()
		local outerChildren = {
			React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, theme.RadiusSmall) }),
			React.createElement("Frame", {
				key = "Clip",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				ref = containerRef,
			}, (function()
			local playheadEl = nil
			if playheadFrac ~= nil then
				playheadEl = React.createElement("Frame", {
					key = "Playhead",
					Size = UDim2.new(0, 2, 1, 0),
					Position = UDim2.new(playheadFrac, -1, 0, 0),
					BackgroundColor3 = theme.Playhead or Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 1 - (theme.PlayheadAlpha or 0.9),
					BorderSizePixel = 0,
					ZIndex = 3,
				}, {
					React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, 1) }),
				})
			end
			local clipChildren = {
				React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, theme.RadiusSmall) }),
				React.createElement("Frame", {
					key = "Bars",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
				}, (function()
					local els = {}
								for i = 1, barCount do
						local barHeight = bars[i] or 0
						local x = (i - 1) / barCount
						els[i] = React.createElement("Frame", {
							key = "b" .. i,
							Size = UDim2.new(0, 2, barHeight / height, -2),
							Position = UDim2.new(x, 2, 0.5, 0),
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
			}
			if playheadEl then table.insert(clipChildren, playheadEl) end
			table.insert(clipChildren, React.createElement("TextButton", {
				key = "StartHandle",
				Size = UDim2.new(0, 2, 1, 0),
				Position = UDim2.new(startFrac, -1, 0, 0),
				BackgroundColor3 = theme.Accent,
				BorderSizePixel = 0,
				Text = "",
				AutoButtonColor = false,
				ZIndex = 2,
				[React.Event.MouseButton1Down] = function()
					setDraggingMarker("start")
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
							setDraggingMarker(nil)
						end
					end)
				end,
			}, {
				React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, 1) }),
			}))
			table.insert(clipChildren, React.createElement("TextButton", {
				key = "EndHandle",
				Size = UDim2.new(0, 2, 1, 0),
				Position = UDim2.new(endFrac, -1, 0, 0),
				BackgroundColor3 = theme.Accent,
				BorderSizePixel = 0,
				Text = "",
				AutoButtonColor = false,
				ZIndex = 2,
				[React.Event.MouseButton1Down] = function()
					setDraggingMarker("end")
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
							setDraggingMarker(nil)
						end
					end)
				end,
			}, {
				React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, 1) }),
			}))
			return clipChildren
		end)()),
		}
		-- Always show start and end position under their markers (stay after moving)
		table.insert(outerChildren, React.createElement("Frame", {
			key = "StartTooltip",
			Position = UDim2.new(startFrac, 0, 1, 4),
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.new(0, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = theme.WaveformBg or Color3.fromRGB(40, 40, 40),
			BorderSizePixel = 0,
			ZIndex = 10,
		}, {
			React.createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
			React.createElement("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }),
			React.createElement("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				Text = formatTime(regionStart),
				TextColor3 = theme.Text or Color3.fromRGB(255, 255, 255),
				TextSize = 12,
				Font = Enum.Font.Gotham,
			}),
		}))
		table.insert(outerChildren, React.createElement("Frame", {
			key = "EndTooltip",
			Position = UDim2.new(endFrac, 0, 1, 4),
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.new(0, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = theme.WaveformBg or Color3.fromRGB(40, 40, 40),
			BorderSizePixel = 0,
			ZIndex = 10,
		}, {
			React.createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
			React.createElement("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }),
			React.createElement("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				Text = formatTime(regionEnd),
				TextColor3 = theme.Text or Color3.fromRGB(255, 255, 255),
				TextSize = 12,
				Font = Enum.Font.Gotham,
			}),
		}))
		return outerChildren
	end)())
	end

return WaveformRegion
