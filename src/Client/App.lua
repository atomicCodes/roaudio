--[[
	Main App: layout, add-track input, and list of track cards.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(ReplicatedStorage.Shared.Theme)
local AudioManager = require(ReplicatedStorage.Shared.AudioManager)
local TrackCard = require(script.Parent.components.TrackCard)

-- Default asset IDs for testing (replace with your own or remove)
local DEFAULT_ASSET_IDS = { "1843528702", "912376939" }

local function App(_props)
	local audioManagerRef = React.useRef(nil)
	if audioManagerRef.current == nil then
		audioManagerRef.current = AudioManager.new()
	end
	local audioManager = audioManagerRef.current

	local tracks, setTracks = React.useState(DEFAULT_ASSET_IDS)
	local addInput, setAddInput = React.useState("")

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

	React.useEffect(function()
		return function()
			audioManager:destroy()
		end
	end, {})

	local theme = Theme
	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = theme.Background,
		BorderSizePixel = 0,
	}, {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, theme.Padding),
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
		Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, theme.Padding),
			PaddingBottom = UDim.new(0, theme.Padding),
			PaddingLeft = UDim.new(0, theme.Padding),
			PaddingRight = UDim.new(0, theme.Padding),
		}),
		Header = React.createElement("Frame", {
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundTransparency = 1,
		}, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, theme.Gap),
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			Title = React.createElement("TextLabel", {
				Size = UDim2.new(0, 160, 1, 0),
				BackgroundTransparency = 1,
				Text = "RoAudio",
				TextColor3 = theme.Text,
				TextSize = theme.FontSizeTitle,
				Font = theme.Font,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			AddBox = React.createElement("Frame", {
				Size = UDim2.new(0, 200, 0, 32),
				BackgroundColor3 = theme.Surface,
				BorderSizePixel = 0,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, theme.RadiusSmall) }),
				Padding = React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, theme.PaddingSmall),
					PaddingRight = UDim.new(0, theme.PaddingSmall),
				}),
				Input = React.createElement("TextBox", {
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
			AddBtn = React.createElement("TextButton", {
				Size = UDim2.new(0, 80, 0, 32),
				BackgroundColor3 = theme.Accent,
				BorderSizePixel = 0,
				Text = "Add",
				TextColor3 = theme.Text,
				TextSize = theme.FontSize,
				Font = theme.Font,
				[React.Event.MouseButton1Click] = onAddTrack,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, theme.RadiusSmall) }),
			}),
		}),
		Scroll = React.createElement("ScrollingFrame", {
			Size = UDim2.new(1, -theme.Padding * 2, 1, -80),
			Position = UDim2.new(0, theme.Padding, 0, 56),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = theme.Border,
			CanvasSize = UDim2.fromScale(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
		}, {
			List = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, theme.Gap),
				VerticalAlignment = Enum.VerticalAlignment.Top,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
			Content = React.createElement("UIPadding", {
				PaddingRight = UDim.new(0, theme.Padding),
			}),
			Tracks = React.createElement(React.Fragment, nil, (function()
				local els = {}
				for i, assetId in ipairs(tracks) do
					els["track_" .. assetId] = React.createElement(TrackCard, {
						key = assetId,
						assetId = assetId,
						audioManager = audioManager,
						onRemove = onRemoveTrack,
					})
				end
				return els
			end)()),
		}),
	})
end

return App
