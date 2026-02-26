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
end)

if not ok then
	showError(tostring(err))
end
