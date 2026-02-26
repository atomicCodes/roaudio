--[[
	TrackCard: one track row with waveform, play/stop, loop, and effect controls.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(ReplicatedStorage.Shared.Theme)
local AudioManager = require(ReplicatedStorage.Shared.AudioManager)
local Slider = require(script.Parent.Slider)
local WaveformRegion = require(script.Parent.WaveformRegion)
local LevelMeter = require(script.Parent.LevelMeter)

type AudioManager = typeof(AudioManager.new())

type Props = {
	assetId: string,
	audioManager: AudioManager,
	onRemove: (assetId: string) -> (),
	index: number?,
	trackCount: number?,
	onMoveUp: (() -> ())?,
	onMoveDown: (() -> ())?,
}

local WAVEFORM_HEIGHT = 48
-- Waveform width scales with file duration so length matches the track
local PIXELS_PER_SECOND = 50
local MIN_WAVEFORM_WIDTH = 120
local MAX_WAVEFORM_WIDTH = 1200

local function TrackCard(props: Props)
	local assetId = props.assetId
	local audioManager = props.audioManager
	local onRemove = props.onRemove
	local index = props.index or 1
	local trackCount = props.trackCount or 1
	local onMoveUp = props.onMoveUp
	local onMoveDown = props.onMoveDown
	local theme = Theme

	local state = audioManager:getOrCreateState(assetId)
	-- Force re-render when we update state in the manager
	local updateCounter, setUpdateCounter = React.useState(0)
	local function updateState(updater: (any) -> ())
		local s = audioManager:getOrCreateState(assetId)
		updater(s)
		setUpdateCounter(function(c) return c + 1 end)
	end

	-- Ensure sound exists so we can read TimeLength; use current state for effects
	local currentState = audioManager:getOrCreateState(assetId)
	audioManager:ensureSound(assetId, currentState)
	local duration = audioManager:getTimeLength(assetId)
	local isPlaying = audioManager:isPlaying(assetId)

	-- Waveform width = same length as file (duration); clamp for usability
	local waveformWidth = duration > 0
		and math.clamp(duration * PIXELS_PER_SECOND, MIN_WAVEFORM_WIDTH, MAX_WAVEFORM_WIDTH)
		or MIN_WAVEFORM_WIDTH

	-- Re-render when sound loads (TimeLength) or ends
	React.useEffect(function()
		local player = audioManager:getPlayer(assetId)
		if not player then return end
		local connLength
		local connEnded
		connLength = player:GetPropertyChangedSignal("TimeLength"):Connect(function()
			setUpdateCounter(function(c) return c + 1 end)
		end)
		connEnded = player.Ended:Connect(function()
			setUpdateCounter(function(c) return c + 1 end)
		end)
		return function()
			connLength:Disconnect()
			connEnded:Disconnect()
		end
	end, { assetId })

	-- Poll playhead and real level when playing (new Audio API provides both)
	local timePosition, setTimePosition = React.useState(0)
	local level, setLevel = React.useState(0)
	React.useEffect(function()
		if not isPlaying then
			setLevel(0)
			return
		end
		local RunService = game:GetService("RunService")
		local conn
		conn = RunService.Heartbeat:Connect(function()
			setTimePosition(audioManager:getTimePosition(assetId))
			setLevel(audioManager:getLevel(assetId))
		end)
		return function()
			conn:Disconnect()
		end
	end, { assetId, isPlaying })

	local onPlayStop = React.useCallback(function()
		if isPlaying then
			audioManager:stop(assetId)
		else
			audioManager:play(assetId, currentState)
		end
		setUpdateCounter(function(c) return c + 1 end)
	end, { assetId, isPlaying, currentState })

	local onRegionChange = React.useCallback(function(startSec: number, endSec: number)
		updateState(function(s)
			s.regionStart = startSec
			s.regionEnd = endSec
		end)
	end, { assetId })

	-- Fetch asset metadata (Name, Description, Creator) from MarketplaceService
	local assetInfo, setAssetInfo = React.useState(nil)
	React.useEffect(function()
		local id = tonumber(assetId)
		if not id then return end
		task.spawn(function()
			local ok, result = pcall(function()
				return MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.Asset)
			end)
			if ok and type(result) == "table" then
				setAssetInfo({
					Name = tostring(result.Name or ""),
					Description = tostring(result.Description or ""),
					Creator = type(result.Creator) == "table" and result.Creator or nil,
				})
			else
				setAssetInfo(nil)
			end
		end)
	end, { assetId })

	return React.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = theme.Surface,
		BorderSizePixel = 0,
	}, {
		React.createElement("UIListLayout", {
			key = "Layout",
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, theme.Gap),
			VerticalAlignment = Enum.VerticalAlignment.Top,
		}),
		React.createElement("UIPadding", {
			key = "Padding",
			PaddingTop = UDim.new(0, theme.Padding),
			PaddingBottom = UDim.new(0, theme.Padding),
			PaddingLeft = UDim.new(0, theme.Padding),
			PaddingRight = UDim.new(0, theme.Padding),
		}),
		React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, theme.Radius) }),

		React.createElement("Frame", {
			key = "Row1",
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundTransparency = 1,
		}, {
			React.createElement("UIListLayout", {
				key = "Layout",
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, theme.Gap),
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			React.createElement("TextLabel", {
				key = "Title",
				Size = UDim2.new(0, 180, 1, 0),
				BackgroundTransparency = 1,
				Text = (assetInfo and assetInfo.Name and #assetInfo.Name > 0) and assetInfo.Name or ("ID: " .. string.sub(assetId, 1, 12) .. (#assetId > 12 and "..." or "")),
				TextColor3 = theme.Text,
				TextSize = theme.FontSize,
				Font = theme.Font,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			React.createElement("TextButton", {
				key = "PlayStop",
				Size = UDim2.new(0, 56, 0, 28),
				BackgroundColor3 = if isPlaying then theme.Stop else theme.Play,
				BorderSizePixel = 0,
				Text = if isPlaying then "Stop" else "Play",
				TextColor3 = theme.Text,
				TextSize = theme.FontSizeSmall,
				Font = theme.Font,
				[React.Event.MouseButton1Click] = onPlayStop,
			}, {
				React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, theme.RadiusSmall) }),
			}),
			React.createElement("TextButton", {
				key = "Loop",
				Size = UDim2.new(0, 60, 0, 28),
				BackgroundColor3 = if currentState.looped then theme.Accent else theme.SurfaceHover,
				BorderSizePixel = 0,
				Text = "Loop",
				TextColor3 = theme.Text,
				TextSize = theme.FontSizeSmall,
				Font = theme.Font,
				[React.Event.MouseButton1Click] = function()
					updateState(function(s)
						s.looped = not s.looped
					end)
					audioManager:ensureSound(assetId, audioManager:getOrCreateState(assetId))
				end,
			}, {
				React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, theme.RadiusSmall) }),
			}),
			React.createElement("TextButton", {
				key = "MoveUp",
				Size = UDim2.new(0, 32, 0, 28),
				BackgroundColor3 = theme.SurfaceHover,
				BorderSizePixel = 0,
				Text = "↑",
				TextColor3 = if index > 1 then theme.Text else theme.TextDim,
				TextSize = theme.FontSizeSmall,
				Font = theme.Font,
				Active = index > 1,
				[React.Event.MouseButton1Click] = function()
					if index > 1 and onMoveUp then onMoveUp() end
				end,
			}, {
				React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, theme.RadiusSmall) }),
			}),
			React.createElement("TextButton", {
				key = "MoveDown",
				Size = UDim2.new(0, 32, 0, 28),
				BackgroundColor3 = theme.SurfaceHover,
				BorderSizePixel = 0,
				Text = "↓",
				TextColor3 = if index < trackCount then theme.Text else theme.TextDim,
				TextSize = theme.FontSizeSmall,
				Font = theme.Font,
				Active = index < trackCount,
				[React.Event.MouseButton1Click] = function()
					if index < trackCount and onMoveDown then onMoveDown() end
				end,
			}, {
				React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, theme.RadiusSmall) }),
			}),
			React.createElement("TextButton", {
				key = "Remove",
				Size = UDim2.new(0, 28, 0, 28),
				BackgroundColor3 = theme.SurfaceHover,
				BorderSizePixel = 0,
				Text = "×",
				TextColor3 = theme.TextDim,
				TextSize = 18,
				Font = theme.Font,
				[React.Event.MouseButton1Click] = function()
					onRemove(assetId)
				end,
			}, {
				React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, theme.RadiusSmall) }),
			}),
		}),

		React.createElement("Frame", {
			key = "Metadata",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, (function()
			local lines = {}
			if assetInfo then
				local desc = assetInfo.Description and #assetInfo.Description > 0 and assetInfo.Description or nil
				if desc and #desc > 80 then desc = string.sub(desc, 1, 77) .. "..." end
				local creatorName = assetInfo.Creator and type(assetInfo.Creator.Name) == "string" and assetInfo.Creator.Name or nil
				if desc then table.insert(lines, desc) end
				if creatorName then table.insert(lines, "Creator: " .. creatorName) end
			end
			table.insert(lines, "Asset ID: " .. assetId)
			if duration and duration > 0 then
				table.insert(lines, string.format("Duration: %.1fs", duration))
			end
			return {
				React.createElement("UIListLayout", {
					key = "Layout",
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, theme.GapSmall),
					VerticalAlignment = Enum.VerticalAlignment.Top,
				}),
				React.createElement("TextLabel", {
					key = "Meta",
					Size = UDim2.new(1, -theme.Padding * 2, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Text = table.concat(lines, "\n"),
					TextColor3 = theme.TextDim,
					TextSize = theme.FontSizeSmall,
					Font = theme.Font,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					TextWrapped = true,
				}),
			}
		end)()),

		React.createElement("Frame", {
			key = "WaveformRow",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, {
			React.createElement("UIListLayout", {
				key = "Layout",
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, theme.Gap),
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			React.createElement(WaveformRegion, {
				key = "Waveform",
				width = waveformWidth,
				height = WAVEFORM_HEIGHT,
				duration = duration,
				regionStart = currentState.regionStart,
				regionEnd = currentState.regionEnd,
				timePosition = isPlaying and timePosition or nil,
				onRegionChange = onRegionChange,
			}),
			React.createElement(LevelMeter, {
				key = "LevelMeter",
				isPlaying = isPlaying,
				width = 20,
				height = WAVEFORM_HEIGHT,
				level = level,
			}),
		}),

		React.createElement("Frame", {
			key = "Controls",
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, {
			React.createElement("UIListLayout", {
				key = "Layout",
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, theme.Padding),
				VerticalAlignment = Enum.VerticalAlignment.Top,
			}),
			React.createElement(Slider, {
				key = "Level",
				label = "Level",
				value = currentState.volume,
				min = 0,
				max = 2,
				step = 0.05,
				width = 90,
				onChange = function(v)
					updateState(function(s) s.volume = v end)
					audioManager:ensureSound(assetId, audioManager:getOrCreateState(assetId))
				end,
			}),
			React.createElement(Slider, {
				key = "Pan",
				label = "Pan",
				value = currentState.pan,
				min = -1,
				max = 1,
				step = 0.05,
				width = 90,
				onChange = function(v)
					updateState(function(s) s.pan = v end)
				end,
			}),
			React.createElement("Frame", {
				key = "EQ",
				Size = UDim2.new(0, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
			}, {
				React.createElement("UIListLayout", {
					key = "Layout",
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, theme.GapSmall),
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
				React.createElement(Slider, {
					key = "L",
					label = "Low",
					value = currentState.eqLow,
					min = -20,
					max = 10,
					step = 0.5,
					width = 70,
					onChange = function(v)
						updateState(function(s) s.eqLow = v end)
						audioManager:ensureSound(assetId, audioManager:getOrCreateState(assetId))
					end,
				}),
				React.createElement(Slider, {
					key = "M",
					label = "Mid",
					value = currentState.eqMid,
					min = -20,
					max = 10,
					step = 0.5,
					width = 70,
					onChange = function(v)
						updateState(function(s) s.eqMid = v end)
						audioManager:ensureSound(assetId, audioManager:getOrCreateState(assetId))
					end,
				}),
				React.createElement(Slider, {
					key = "H",
					label = "High",
					value = currentState.eqHigh,
					min = -20,
					max = 10,
					step = 0.5,
					width = 70,
					onChange = function(v)
						updateState(function(s) s.eqHigh = v end)
						audioManager:ensureSound(assetId, audioManager:getOrCreateState(assetId))
					end,
				}),
			}),
			React.createElement("Frame", {
				key = "Comp",
				Size = UDim2.new(0, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
			}, {
				React.createElement("UIListLayout", {
					key = "Layout",
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, theme.GapSmall),
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
				React.createElement(Slider, {
					key = "Thresh",
					label = "Thresh",
					value = currentState.compressorThreshold,
					min = -40,
					max = 0,
					step = 1,
					width = 72,
					onChange = function(v)
						updateState(function(s) s.compressorThreshold = v end)
						audioManager:ensureSound(assetId, audioManager:getOrCreateState(assetId))
					end,
				}),
				React.createElement(Slider, {
					key = "Gain",
					label = "Gain",
					value = currentState.compressorGainMakeup,
					min = 0,
					max = 20,
					step = 0.5,
					width = 72,
					onChange = function(v)
						updateState(function(s) s.compressorGainMakeup = v end)
						audioManager:ensureSound(assetId, audioManager:getOrCreateState(assetId))
					end,
				}),
				React.createElement("TextButton", {
					key = "CompToggle",
					Size = UDim2.new(0, 52, 0, 28),
					BackgroundColor3 = if currentState.compressorEnabled then theme.Accent else theme.SurfaceHover,
					BorderSizePixel = 0,
					Text = "Comp",
					TextColor3 = theme.Text,
					TextSize = theme.FontSizeSmall,
					Font = theme.Font,
					[React.Event.MouseButton1Click] = function()
						updateState(function(s)
							s.compressorEnabled = not s.compressorEnabled
						end)
						audioManager:ensureSound(assetId, audioManager:getOrCreateState(assetId))
					end,
				}, {
					React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, theme.RadiusSmall) }),
				}),
			}),
		}),
	})
end

return TrackCard
