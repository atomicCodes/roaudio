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
-- All effect boxes same height; Level box fits: slider (28) + gap (4) + meter (8) + padding
local EFFECT_BOX_HEIGHT = 64
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

	-- Fetch real waveform overview via AudioPlayer:GetWaveformAsync (yields)
	local waveformSamples, setWaveformSamples = React.useState(nil)
	React.useEffect(function()
		if duration <= 0 then return end
		task.spawn(function()
			local samples = audioManager:getWaveformAsync(assetId, 400)
			setWaveformSamples(samples or {})
		end)
	end, { assetId, duration })

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

	local function formatDuration(sec: number): string
		if not sec or sec <= 0 then return "0:00" end
		local m = math.floor(sec / 60)
		local s = math.floor(sec % 60)
		return string.format("%d:%02d", m, s)
	end

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
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = theme.Surface,
		BorderSizePixel = 0,
	}, {
		React.createElement("UIListLayout", {
			key = "Layout",
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, theme.Gap),
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		React.createElement("UIPadding", {
			key = "Padding",
			PaddingTop = UDim.new(0, theme.Padding),
			PaddingBottom = UDim.new(0, theme.Padding),
			PaddingLeft = UDim.new(0, theme.Padding),
			PaddingRight = UDim.new(0, theme.Padding),
		}),
		React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, theme.Radius) }),

		-- Row: metadata (left) | waveform + level meter (right)
		React.createElement("Frame", {
			key = "MainRow",
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, {
			React.createElement("UIListLayout", {
				key = "Layout",
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, theme.Gap),
				VerticalAlignment = Enum.VerticalAlignment.Top,
			}),
			-- Left: metadata column
			React.createElement("Frame", {
				key = "MetadataCol",
				Size = UDim2.new(0, 200, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
			}, {
				React.createElement("UIListLayout", {
					key = "Layout",
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, theme.GapSmall),
					VerticalAlignment = Enum.VerticalAlignment.Top,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				React.createElement("TextLabel", {
					key = "AssetId",
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Text = "Asset ID: " .. assetId,
					TextColor3 = theme.TextDim,
					TextSize = theme.FontSizeSmall,
					Font = theme.Font,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextWrapped = true,
				}),
				React.createElement("TextLabel", {
					key = "Title",
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Text = (assetInfo and assetInfo.Name and #assetInfo.Name > 0) and assetInfo.Name or ("ID: " .. string.sub(assetId, 1, 12) .. (#assetId > 12 and "..." or "")),
					TextColor3 = theme.Text,
					TextSize = theme.FontSizeTitle,
					Font = theme.Font,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextWrapped = true,
				}),
				React.createElement("TextLabel", {
					key = "Creator",
					LayoutOrder = 3,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Text = assetInfo and assetInfo.Creator and type(assetInfo.Creator.Name) == "string" and ("Creator: " .. assetInfo.Creator.Name) or "",
					TextColor3 = theme.TextDim,
					TextSize = theme.FontSizeSmall,
					Font = theme.Font,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextWrapped = true,
				}),
				React.createElement("Frame", {
					key = "ButtonRow",
					LayoutOrder = 4,
					Size = UDim2.new(1, 0, 0, 28),
					BackgroundTransparency = 1,
				}, {
					React.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, theme.GapSmall),
						VerticalAlignment = Enum.VerticalAlignment.Center,
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
							updateState(function(s) s.looped = not s.looped end)
							audioManager:ensureSound(assetId, audioManager:getOrCreateState(assetId))
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
						[React.Event.MouseButton1Click] = function() onRemove(assetId) end,
					}, {
						React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, theme.RadiusSmall) }),
					}),
				}),
			}),
			-- Right: waveform box (with duration top-right) + level meter
			React.createElement("Frame", {
				key = "WaveformCol",
				Size = UDim2.new(1, -200 - theme.Gap, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
			}, {
				React.createElement("UIListLayout", {
					key = "Layout",
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, theme.Gap),
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
				React.createElement("Frame", {
					key = "WaveformWrap",
					Size = UDim2.new(0, waveformWidth, 0, WAVEFORM_HEIGHT),
					BackgroundTransparency = 1,
				}, {
					React.createElement(WaveformRegion, {
						key = "Waveform",
						width = waveformWidth,
						height = WAVEFORM_HEIGHT,
						duration = duration,
						regionStart = currentState.regionStart,
						regionEnd = currentState.regionEnd,
						timePosition = isPlaying and timePosition or nil,
						waveformSamples = waveformSamples,
						onRegionChange = onRegionChange,
					}),
					React.createElement("TextLabel", {
						key = "Duration",
						Size = UDim2.new(0, 0, 0, 0),
						AutomaticSize = Enum.AutomaticSize.XY,
						Position = UDim2.new(1, -theme.PaddingSmall, 0, theme.PaddingSmall),
						AnchorPoint = Vector2.new(1, 0),
						BackgroundTransparency = 1,
						Text = formatDuration(duration),
						TextColor3 = theme.TextDim,
						TextSize = theme.FontSizeSmall,
						Font = theme.Font,
						ZIndex = 5,
					}),
				}),
			}),
		}),

		-- Effect row: spacer (align with metadata) then controls under the waveform
		React.createElement("Frame", {
			key = "ControlsRow",
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, {
			React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, theme.Gap),
				VerticalAlignment = Enum.VerticalAlignment.Top,
			}),
			React.createElement("Frame", {
				key = "ControlsSpacer",
				Size = UDim2.new(0, 200, 0, 0),
				BackgroundTransparency = 1,
			}),
			React.createElement("Frame", {
				key = "Controls",
				Size = UDim2.new(1, -200 - theme.Gap, 0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
			}, {
				React.createElement("UIListLayout", {
					key = "Layout",
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, theme.Gap),
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			-- 1. Volume/Level first (blue-grey box, UIStroke border) – horizontal level meter under fader; fixed height to match other boxes
			React.createElement("Frame", {
				key = "LevelBox",
				LayoutOrder = 1,
				Size = UDim2.new(0, 0, 0, EFFECT_BOX_HEIGHT),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = Color3.fromRGB(26, 30, 42),
				BorderSizePixel = 0,
			}, {
				React.createElement("UIStroke", { Color = Color3.fromRGB(120, 140, 180), Thickness = 2 }),
				React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, 4) }),
				React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, theme.Gap),
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, theme.Padding),
					PaddingRight = UDim.new(0, theme.Padding),
					PaddingTop = UDim.new(0, theme.Padding),
					PaddingBottom = UDim.new(0, theme.Padding),
				}),
				React.createElement("TextLabel", {
					key = "Title",
					LayoutOrder = 1,
					Size = UDim2.new(0, 36, 0, 16),
					BackgroundTransparency = 1,
					Text = "Level",
					TextColor3 = Color3.fromRGB(120, 140, 180),
					TextSize = theme.FontSizeSmall,
					Font = theme.FontBold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				React.createElement("Frame", {
					key = "SliderMeterCol",
					LayoutOrder = 2,
					Size = UDim2.new(0, 140, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
				}, {
					React.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, theme.GapSmall),
						VerticalAlignment = Enum.VerticalAlignment.Top,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					React.createElement(Slider, {
						key = "Level",
						LayoutOrder = 1,
						label = "Vol",
						value = currentState.muted and 0 or currentState.volume,
						min = 0,
						max = 2,
						step = 0.05,
						width = 140,
						onChange = function(v)
							if not currentState.muted then
								updateState(function(s) s.volume = v end)
								audioManager:ensureSound(assetId, audioManager:getOrCreateState(assetId))
							end
						end,
					}),
					React.createElement(LevelMeter, {
						key = "LevelMeter",
						LayoutOrder = 2,
						isPlaying = isPlaying,
						width = 140,
						height = 8,
						level = level,
						horizontal = true,
					}),
				}),
				React.createElement("TextButton", {
					key = "Mute",
					LayoutOrder = 3,
					Size = UDim2.new(0, 44, 0, 28),
					BackgroundColor3 = if currentState.muted then theme.Stop else theme.SurfaceHover,
					BorderSizePixel = 0,
					Text = if currentState.muted then "Muted" else "Mute",
					TextColor3 = theme.Text,
					TextSize = theme.FontSizeSmall,
					Font = theme.Font,
					[React.Event.MouseButton1Click] = function()
						updateState(function(s) s.muted = not s.muted end)
						audioManager:ensureSound(assetId, audioManager:getOrCreateState(assetId))
					end,
				}, {
					React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, theme.RadiusSmall) }),
				}),
			}),
			-- 2. EQ second (green box, UIStroke border)
			React.createElement("Frame", {
				key = "EQBox",
				LayoutOrder = 2,
				Size = UDim2.new(0, 0, 0, EFFECT_BOX_HEIGHT),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = Color3.fromRGB(26, 38, 32),
				BorderSizePixel = 0,
			}, {
				React.createElement("UIStroke", { Color = Color3.fromRGB(80, 180, 110), Thickness = 2 }),
				React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, 4) }),
				React.createElement("UIListLayout", {
					key = "Layout",
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, theme.Gap),
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, theme.Padding),
					PaddingRight = UDim.new(0, theme.Padding),
					PaddingTop = UDim.new(0, theme.Padding),
					PaddingBottom = UDim.new(0, theme.Padding),
				}),
				React.createElement("TextLabel", {
					key = "Title",
					LayoutOrder = 0,
					Size = UDim2.new(0, 28, 0, 16),
					BackgroundTransparency = 1,
					Text = "EQ",
					TextColor3 = Color3.fromRGB(80, 180, 110),
					TextSize = theme.FontSizeSmall,
					Font = theme.FontBold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				React.createElement(Slider, {
					key = "L",
					LayoutOrder = 1,
					label = "Low",
					value = currentState.eqLow,
					min = -20,
					max = 10,
					step = 0.5,
					width = 52,
					onChange = function(v)
						updateState(function(s) s.eqLow = v end)
						audioManager:ensureSound(assetId, audioManager:getOrCreateState(assetId))
					end,
				}),
				React.createElement(Slider, {
					key = "MidLo",
					LayoutOrder = 2,
					label = "MidLo",
					value = currentState.eqMidRangeMin,
					min = 200,
					max = 20000,
					step = 100,
					width = 56,
					accentColor = Color3.fromRGB(220, 170, 70),
					onChange = function(v)
						updateState(function(s) s.eqMidRangeMin = v end)
						audioManager:ensureSound(assetId, audioManager:getOrCreateState(assetId))
					end,
				}),
				React.createElement(Slider, {
					key = "M",
					LayoutOrder = 3,
					label = "Mid",
					value = currentState.eqMid,
					min = -20,
					max = 10,
					step = 0.5,
					width = 52,
					onChange = function(v)
						updateState(function(s) s.eqMid = v end)
						audioManager:ensureSound(assetId, audioManager:getOrCreateState(assetId))
					end,
				}),
				React.createElement(Slider, {
					key = "MidHi",
					LayoutOrder = 4,
					label = "MidHi",
					value = currentState.eqMidRangeMax,
					min = 200,
					max = 20000,
					step = 100,
					width = 56,
					accentColor = Color3.fromRGB(220, 170, 70),
					onChange = function(v)
						updateState(function(s) s.eqMidRangeMax = v end)
						audioManager:ensureSound(assetId, audioManager:getOrCreateState(assetId))
					end,
				}),
				React.createElement(Slider, {
					key = "H",
					LayoutOrder = 5,
					label = "High",
					value = currentState.eqHigh,
					min = -20,
					max = 10,
					step = 0.5,
					width = 52,
					onChange = function(v)
						updateState(function(s) s.eqHigh = v end)
						audioManager:ensureSound(assetId, audioManager:getOrCreateState(assetId))
					end,
				}),
				React.createElement("TextButton", {
					key = "EQToggle",
					LayoutOrder = 6,
					Size = UDim2.new(0, 44, 0, 28),
					BackgroundColor3 = if currentState.eqEnabled then theme.Accent else theme.SurfaceHover,
					BorderSizePixel = 0,
					Text = if currentState.eqEnabled then "On" else "Off",
					TextColor3 = theme.Text,
					TextSize = theme.FontSizeSmall,
					Font = theme.Font,
					[React.Event.MouseButton1Click] = function()
						updateState(function(s) s.eqEnabled = not s.eqEnabled end)
						audioManager:ensureSound(assetId, audioManager:getOrCreateState(assetId))
					end,
				}, {
					React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, theme.RadiusSmall) }),
				}),
			}),
			-- 3. Compressor third (red box, UIStroke border)
			React.createElement("Frame", {
				key = "CompBox",
				LayoutOrder = 3,
				Size = UDim2.new(0, 0, 0, EFFECT_BOX_HEIGHT),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = Color3.fromRGB(42, 26, 30),
				BorderSizePixel = 0,
			}, {
				React.createElement("UIStroke", { Color = Color3.fromRGB(180, 90, 100), Thickness = 2 }),
				React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, 4) }),
				React.createElement("UIListLayout", {
					key = "Layout",
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, theme.Gap),
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, theme.Padding),
					PaddingRight = UDim.new(0, theme.Padding),
					PaddingTop = UDim.new(0, theme.Padding),
					PaddingBottom = UDim.new(0, theme.Padding),
				}),
				React.createElement("TextLabel", {
					key = "Title",
					LayoutOrder = 1,
					Size = UDim2.new(0, 56, 0, 16),
					BackgroundTransparency = 1,
					Text = "Comp",
					TextColor3 = Color3.fromRGB(180, 90, 100),
					TextSize = theme.FontSizeSmall,
					Font = theme.FontBold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				React.createElement(Slider, {
					key = "Thresh",
					LayoutOrder = 2,
					label = "Thr",
					value = currentState.compressorThreshold,
					min = -40,
					max = 0,
					step = 1,
					width = 48,
					onChange = function(v)
						updateState(function(s) s.compressorThreshold = v end)
						audioManager:ensureSound(assetId, audioManager:getOrCreateState(assetId))
					end,
				}),
				React.createElement(Slider, {
					key = "Ratio",
					LayoutOrder = 3,
					label = "Ratio",
					value = currentState.compressorRatio,
					min = 1,
					max = 50,
					step = 1,
					width = 48,
					onChange = function(v)
						updateState(function(s) s.compressorRatio = v end)
						audioManager:ensureSound(assetId, audioManager:getOrCreateState(assetId))
					end,
				}),
				React.createElement(Slider, {
					key = "Attack",
					LayoutOrder = 4,
					label = "Att",
					value = currentState.compressorAttack,
					min = 0.001,
					max = 0.5,
					step = 0.01,
					width = 48,
					onChange = function(v)
						updateState(function(s) s.compressorAttack = v end)
						audioManager:ensureSound(assetId, audioManager:getOrCreateState(assetId))
					end,
				}),
				React.createElement(Slider, {
					key = "Release",
					LayoutOrder = 5,
					label = "Rel",
					value = currentState.compressorRelease,
					min = 0.01,
					max = 0.5,
					step = 0.01,
					width = 48,
					onChange = function(v)
						updateState(function(s) s.compressorRelease = v end)
						audioManager:ensureSound(assetId, audioManager:getOrCreateState(assetId))
					end,
				}),
				React.createElement(Slider, {
					key = "Gain",
					LayoutOrder = 6,
					label = "Gain",
					value = currentState.compressorGainMakeup,
					min = 0,
					max = 20,
					step = 0.5,
					width = 48,
					onChange = function(v)
						updateState(function(s) s.compressorGainMakeup = v end)
						audioManager:ensureSound(assetId, audioManager:getOrCreateState(assetId))
					end,
				}),
				React.createElement("TextButton", {
					key = "CompToggle",
					LayoutOrder = 7,
					Size = UDim2.new(0, 44, 0, 28),
					BackgroundColor3 = if currentState.compressorEnabled then theme.Accent else theme.SurfaceHover,
					BorderSizePixel = 0,
					Text = if currentState.compressorEnabled then "On" else "Off",
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
			-- 4. Pan last (neutral box, compact – one control)
			React.createElement("Frame", {
				key = "PanBox",
				LayoutOrder = 4,
				Size = UDim2.new(0, 0, 0, EFFECT_BOX_HEIGHT),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = Color3.fromRGB(38, 38, 45),
				BorderSizePixel = 0,
			}, {
				React.createElement("UIStroke", { Color = Color3.fromRGB(130, 130, 150), Thickness = 2 }),
				React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, 4) }),
				React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, theme.GapSmall),
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, theme.PaddingSmall),
					PaddingRight = UDim.new(0, theme.PaddingSmall),
					PaddingTop = UDim.new(0, theme.PaddingSmall),
					PaddingBottom = UDim.new(0, theme.PaddingSmall),
				}),
				React.createElement("TextLabel", {
					key = "Title",
					LayoutOrder = 1,
					Size = UDim2.new(0, 28, 0, 16),
					BackgroundTransparency = 1,
					Text = "Pan",
					TextColor3 = Color3.fromRGB(130, 130, 150),
					TextSize = theme.FontSizeSmall,
					Font = theme.FontBold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				React.createElement(Slider, {
					key = "Pan",
					LayoutOrder = 2,
					label = "L↔R",
					value = currentState.pan,
					min = -100,
					max = 100,
					step = 1,
					width = 52,
					onChange = function(v)
						updateState(function(s) s.pan = v end)
					end,
				}),
				}),
			}),
		}),
	})
end

return TrackCard
