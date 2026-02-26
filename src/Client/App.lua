--[[
	Main App: layout, add-track input, and list of track cards.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Theme = require(ReplicatedStorage.Shared.Theme)
local AudioManager = require(ReplicatedStorage.Shared.AudioManager)
local TrackCard = require(script.Parent.components.TrackCard)

-- Default asset IDs for testing (use Add to add your own; empty avoids 403 on load)
local DEFAULT_ASSET_IDS = {}

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
		React.createElement("UIListLayout", {
			key = "Layout",
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, theme.Padding),
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
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
			Size = UDim2.new(1, 0, 0, 44),
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
				Size = UDim2.new(0, 160, 1, 0),
				BackgroundTransparency = 1,
				Text = "RoAudio",
				TextColor3 = theme.Text,
				TextSize = theme.FontSizeTitle,
				Font = theme.Font,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			React.createElement("Frame", {
				key = "AddBox",
				Size = UDim2.new(0, 200, 0, 32),
				BackgroundColor3 = theme.Surface,
				BorderSizePixel = 0,
			}, {
				React.createElement("UICorner", { key = "Corner", CornerRadius = UDim.new(0, theme.RadiusSmall) }),
				React.createElement("UIPadding", {
					key = "Padding",
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
		React.createElement("ScrollingFrame", {
			key = "Scroll",
			Size = UDim2.new(1, -theme.Padding * 2, 1, -80),
			Position = UDim2.new(0, theme.Padding, 0, 56),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = theme.Border,
			CanvasSize = UDim2.fromScale(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
		}, {
			React.createElement("UIListLayout", {
				key = "List",
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, theme.Gap),
				VerticalAlignment = Enum.VerticalAlignment.Top,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
			React.createElement("UIPadding", {
				key = "Content",
				PaddingRight = UDim.new(0, theme.Padding),
			}),
			React.createElement(React.Fragment, { key = "Tracks" }, (function()
				local els = {}
				for i, assetId in ipairs(tracks) do
					els[i] = React.createElement(TrackCard, {
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
