--[[
	Main App: layout, add-track input, and list of track cards.
	Toggle between GUI view and World view (blocks in workspace per track).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(ReplicatedStorage.Shared.Theme)
local AudioManager = require(ReplicatedStorage.Shared.AudioManager)
local TrackCard = require(script.Parent.components.TrackCard)
local WorldBlocks = require(script.Parent.WorldBlocks)

-- No default asset IDs: external IDs often 403 (permissions/region). Add your own via the Add box
-- (Toolbox → Audio, or your uploaded sounds) to avoid load errors.
local DEFAULT_ASSET_IDS = {}

-- Logo: IMAGE asset ID (Creator Hub → Images). Use "0" to hide. Decals don't load in ImageLabel.
local LOGO_ASSET_ID = "88773897350118"

local function App(_props)
	local audioManagerRef = React.useRef(nil)
	if audioManagerRef.current == nil then
		audioManagerRef.current = AudioManager.new()
	end
	local audioManager = audioManagerRef.current

	local tracks, setTracks = React.useState(DEFAULT_ASSET_IDS)
	local addInput, setAddInput = React.useState("135496497649002")
	local viewMode, setViewMode = React.useState("gui") -- "gui" | "world"

	local onAddTrack = React.useCallback(function()
		local id = addInput:gsub("%D", "")
		if #id > 0 then
			setTracks(function(prev)
				local next = table.clone(prev)
				table.insert(next, id)
				return next
			end)
			setAddInput("")
		end
	end, { addInput })

	local onRemoveTrack = React.useCallback(function(assetId: string)
		audioManager:stop(assetId)
		setTracks(function(prev)
			local next = {}
			for _, id in ipairs(prev) do
				if id ~= assetId then
					table.insert(next, id)
				end
			end
			return next
		end)
	end, {})

	local onPlayAll = React.useCallback(function()
		audioManager:playAll(tracks)
	end, { tracks })

	local onStopAll = React.useCallback(function()
		audioManager:stopAll(tracks)
	end, { tracks })

	local onMoveTrack = React.useCallback(function(fromIndex: number, direction: number)
		local toIndex = fromIndex + direction
		if toIndex < 1 or toIndex > #tracks then return end
		setTracks(function(prev)
			local next = table.clone(prev)
			next[fromIndex], next[toIndex] = next[toIndex], next[fromIndex]
			return next
		end)
	end, { tracks })

	-- Master playhead and global play state: show time and whether any track is playing
	local masterTime, setMasterTime = React.useState(0)
	local anyPlaying, setAnyPlaying = React.useState(false)
	React.useEffect(function()
		local RunService = game:GetService("RunService")
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local t = 0
			local playing = false
			for _, id in ipairs(tracks) do
				if audioManager:isPlaying(id) then
					t = audioManager:getTimePosition(id)
					playing = true
					break
				end
			end
			setMasterTime(t)
			setAnyPlaying(playing)
		end)
		return function()
			conn:Disconnect()
		end
	end, { tracks })

	local function formatTime(sec: number): string
		local m = math.floor(sec / 60)
		local s = math.floor(sec % 60)
		local h = math.floor((sec % 1) * 100)
		return string.format("%d:%02d.%02d", m, s, h)
	end

	local playheadMinutes = math.floor(masterTime / 60)
	local playheadSeconds = math.floor(masterTime % 60)
	local playheadHundredths = math.floor((masterTime % 1) * 100)
	local playheadHours = math.floor(playheadMinutes / 60)
	local playheadM = playheadMinutes % 60

	React.useEffect(function()
		return function()
			audioManager:destroy()
		end
	end, {})

	-- When switching to world view or when tracks change in world view, sync blocks
	React.useEffect(function()
		if viewMode == "world" then
			WorldBlocks.sync(tracks)
		end
	end, { viewMode, tracks })

	local theme = Theme
	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = theme.Background,
		BackgroundTransparency = if viewMode == "world" then 1 else 0,
		BorderSizePixel = 0,
	}, {
		React.createElement("Frame", {
			key = "Content",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, {
			React.createElement("UIListLayout", {
				key = "Layout",
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, theme.Padding),
				VerticalAlignment = Enum.VerticalAlignment.Top,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
			}),
			React.createElement("UIPadding", {
				key = "Padding",
				PaddingTop = UDim.new(0, theme.Padding),
				PaddingBottom = UDim.new(0, theme.Padding),
				PaddingLeft = UDim.new(0, theme.Padding),
				PaddingRight = UDim.new(0, theme.Padding),
			}),
			React.createElement("Frame", {
			key = "Header",
			Size = UDim2.new(1, 0, 0, 56),
			BackgroundTransparency = 1,
			ClipsDescendants = false,
		}, {
			React.createElement("UIListLayout", {
				key = "Layout",
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, theme.Gap),
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			React.createElement("TextButton", {
				key = "ViewToggle",
				LayoutOrder = 0,
				Size = UDim2.new(0, 160, 0, 44),
				BackgroundColor3 = if viewMode == "gui" then Color3.fromRGB(0, 150, 200) else theme.Accent,
				BorderSizePixel = 0,
				Text = if viewMode == "gui" then "3D World" else "Back to GUI",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 18,
				Font = Enum.Font.GothamBold,
				[React.Event.MouseButton1Click] = function()
					setViewMode(if viewMode == "gui" then "world" else "gui")
				end,
			}, {
				React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, 8) }),
				React.createElement("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 2 }),
			}),
			React.createElement("Frame", {
				key = "Playhead",
				LayoutOrder = 1,
				Size = UDim2.new(0, 0, 0, 36),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = theme.Surface,
				BorderSizePixel = 0,
			}, {
				React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, theme.RadiusSmall) }),
				React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 0),
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, theme.PaddingSmall),
					PaddingRight = UDim.new(0, theme.PaddingSmall),
				}),
				-- Fixed-width segments: H : MM : SS . cc (LayoutOrder forces correct order)
				React.createElement("TextLabel", {
					key = "H",
					LayoutOrder = 1,
					Size = UDim2.new(0, 28, 1, 0),
					BackgroundTransparency = 1,
					Text = string.format("%d", playheadHours),
					TextColor3 = theme.Text,
					TextSize = 20,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Right,
				}),
				React.createElement("TextLabel", {
					key = "Sep0",
					LayoutOrder = 2,
					Size = UDim2.new(0, 10, 1, 0),
					BackgroundTransparency = 1,
					Text = ":",
					TextColor3 = theme.Text,
					TextSize = 20,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Center,
				}),
				React.createElement("TextLabel", {
					key = "M",
					LayoutOrder = 3,
					Size = UDim2.new(0, 28, 1, 0),
					BackgroundTransparency = 1,
					Text = string.format("%02d", playheadM),
					TextColor3 = theme.Text,
					TextSize = 20,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Right,
				}),
				React.createElement("TextLabel", {
					key = "Sep1",
					LayoutOrder = 4,
					Size = UDim2.new(0, 10, 1, 0),
					BackgroundTransparency = 1,
					Text = ":",
					TextColor3 = theme.Text,
					TextSize = 20,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Center,
				}),
				React.createElement("TextLabel", {
					key = "SS",
					LayoutOrder = 5,
					Size = UDim2.new(0, 28, 1, 0),
					BackgroundTransparency = 1,
					Text = string.format("%02d", playheadSeconds),
					TextColor3 = theme.Text,
					TextSize = 20,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Right,
				}),
				React.createElement("TextLabel", {
					key = "Sep2",
					LayoutOrder = 6,
					Size = UDim2.new(0, 10, 1, 0),
					BackgroundTransparency = 1,
					Text = ":",
					TextColor3 = theme.Text,
					TextSize = 20,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Center,
				}),
				React.createElement("TextLabel", {
					key = "CC",
					LayoutOrder = 7,
					Size = UDim2.new(0, 28, 1, 0),
					BackgroundTransparency = 1,
					Text = string.format("%02d", playheadHundredths),
					TextColor3 = theme.Text,
					TextSize = 20,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Right,
				}),
			}),
			React.createElement("TextButton", {
				key = "PlayStopAll",
				LayoutOrder = 2,
				Size = UDim2.new(0, 90, 0, 32),
				BackgroundColor3 = if anyPlaying then theme.Stop else theme.Play,
				BorderSizePixel = 0,
				Text = if anyPlaying then "Stop" else "Play",
				TextColor3 = theme.Text,
				TextSize = theme.FontSizeSmall,
				Font = theme.Font,
				[React.Event.MouseButton1Click] = function()
					if anyPlaying then
						onStopAll()
					else
						onPlayAll()
					end
				end,
			}, {
				React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, theme.RadiusSmall) }),
			}),
		}),
		React.createElement("ScrollingFrame", {
			key = "Scroll",
			Visible = (viewMode == "gui"),
			Size = UDim2.new(1, -theme.Padding * 2, 1, -88),
			Position = UDim2.new(0, theme.Padding, 0, 64),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = theme.Border,
			CanvasSize = UDim2.fromScale(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.XY,
		}, {
			React.createElement("UIListLayout", {
				key = "List",
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, theme.Gap),
				VerticalAlignment = Enum.VerticalAlignment.Top,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
			}),
			React.createElement("UIPadding", {
				key = "Content",
				PaddingLeft = UDim.new(0, theme.Padding),
				PaddingRight = UDim.new(0, theme.Padding),
			}),
			React.createElement(React.Fragment, { key = "Tracks" }, (function()
				local els = {}
				for i, assetId in ipairs(tracks) do
					els[i] = React.createElement(TrackCard, {
						key = assetId,
						assetId = assetId,
						audioManager = audioManager,
						index = i,
						trackCount = #tracks,
						onRemove = onRemoveTrack,
						onMoveUp = function() onMoveTrack(i, -1) end,
						onMoveDown = function() onMoveTrack(i, 1) end,
					})
				end
				return els
			end)()),
			React.createElement("Frame", {
				key = "AddRow",
				Size = UDim2.new(1, 0, 0, 56),
				BackgroundColor3 = theme.Surface,
				BorderSizePixel = 0,
			}, {
				React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, theme.Radius) }),
				React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, theme.Gap),
					VerticalAlignment = Enum.VerticalAlignment.Center,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
				}),
				React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, theme.Padding),
					PaddingRight = UDim.new(0, theme.Padding),
					PaddingTop = UDim.new(0, theme.PaddingSmall),
					PaddingBottom = UDim.new(0, theme.PaddingSmall),
				}),
				React.createElement("Frame", {
					key = "AddBox",
					Size = UDim2.new(0, 200, 0, 32),
					BackgroundColor3 = theme.Background,
					BorderSizePixel = 0,
				}, {
					React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, theme.RadiusSmall) }),
					React.createElement("UIPadding", {
						PaddingLeft = UDim.new(0, theme.PaddingSmall),
						PaddingRight = UDim.new(0, theme.PaddingSmall),
					}),
					React.createElement("TextBox", {
						key = "Input",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						PlaceholderText = "Asset ID to add...",
						PlaceholderColor3 = theme.TextMuted,
						Text = addInput,
						TextColor3 = theme.Text,
						TextSize = theme.FontSizeSmall,
						Font = theme.Font,
						ClearTextOnFocus = false,
						[React.Change.Text] = function(rbx)
							setAddInput(rbx.Text)
						end,
					}),
				}),
				React.createElement("TextButton", {
					key = "AddBtn",
					Size = UDim2.new(0, 80, 0, 32),
					BackgroundColor3 = theme.Accent,
					BorderSizePixel = 0,
					Text = "Add",
					TextColor3 = theme.Text,
					TextSize = theme.FontSize,
					Font = theme.Font,
					[React.Event.MouseButton1Click] = onAddTrack,
				}, {
					React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, theme.RadiusSmall) }),
				}),
			}),
		}),
		}),
		(LOGO_ASSET_ID and #LOGO_ASSET_ID > 0 and LOGO_ASSET_ID ~= "0" and viewMode == "gui") and React.createElement("ImageLabel", {
			key = "Logo",
			Size = UDim2.new(0, 240, 0, 100),
			Position = UDim2.new(1, -theme.Padding - 240, 0, theme.Padding),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
			Image = "rbxassetid://" .. LOGO_ASSET_ID,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 10,
		}) or nil,
	})
end

return App
