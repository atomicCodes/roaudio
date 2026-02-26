--[[
	Entry point for the audio player UI.
	Mounts the React app under a ScreenGui.
	Errors are shown in a fallback UI so you can see what went wrong.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function showError(err: string)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "RoAudioError"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 100
	gui.Parent = playerGui
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -40, 1, -40)
	label.Position = UDim2.new(0, 20, 0, 20)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 200, 200)
	label.TextSize = 14
	label.Font = Enum.Font.Code
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = "RoAudio failed to load:\n\n" .. tostring(err)
	label.Parent = frame
	print("[RoAudio] Error:", err)
end

local ok, err = pcall(function()
	local React = require(ReplicatedStorage.Packages.React)
	local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
	local App = require(script.Parent.App)

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RoAudio"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	local root = ReactRoblox.createRoot(screenGui)
	root:render(React.createElement(App))

	-- Logo on its own ScreenGui so nothing can block it. High DisplayOrder = on top.
	local logoId = "115220141563031"
	if logoId and #logoId > 0 and logoId ~= "0" then
		local logoGui = Instance.new("ScreenGui")
		logoGui.Name = "RoAudioLogoGui"
		logoGui.ResetOnSpawn = false
		logoGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		logoGui.DisplayOrder = 50
		logoGui.IgnoreGuiInset = true
		logoGui.Parent = playerGui

		local logo = Instance.new("ImageLabel")
		logo.Name = "RoAudioLogo"
		logo.Size = UDim2.new(0, 120, 0, 60)
		logo.Position = UDim2.new(1, -140, 0, 16)
		logo.AnchorPoint = Vector2.new(1, 0)
		logo.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
		logo.BorderSizePixel = 2
		logo.BorderColor3 = Color3.fromRGB(0, 200, 180)
		logo.Image = "rbxassetid://" .. logoId
		logo.ScaleType = Enum.ScaleType.Fit
		logo.Parent = logoGui

		-- Fallback text: hide it when the image finishes loading so your asset shows
		local label = Instance.new("TextLabel")
		label.Name = "LogoLabel"
		label.Size = UDim2.new(1, 0, 1, 0)
		label.Position = UDim2.new(0, 0, 0, 0)
		label.BackgroundTransparency = 1
		label.Text = "RoAudio"
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Parent = logo

		local function onLoaded()
			if logo.IsLoaded then
				label.Visible = false
			end
		end
		logo:GetPropertyChangedSignal("IsLoaded"):Connect(onLoaded)
		task.defer(onLoaded)

		print("[RoAudio] Logo GUI created at top-right. If you don't see it, check PlayerGui in Explorer for RoAudioLogoGui.")
	end
end)

if not ok then
	showError(tostring(err))
end
