--[[
	Theme and layout constants for the audio UI.
]]

local Theme = {
	-- Surfaces
	Background = Color3.fromRGB(22, 22, 28),
	Surface = Color3.fromRGB(32, 32, 40),
	SurfaceHover = Color3.fromRGB(42, 42, 52),
	Border = Color3.fromRGB(50, 50, 60),

	-- Accent (teal/cyan)
	Accent = Color3.fromRGB(0, 200, 180),
	AccentDim = Color3.fromRGB(0, 160, 145),
	Play = Color3.fromRGB(0, 200, 120),
	Stop = Color3.fromRGB(220, 80, 80),

	-- Text
	Text = Color3.fromRGB(240, 240, 245),
	TextDim = Color3.fromRGB(160, 160, 170),
	TextMuted = Color3.fromRGB(100, 100, 110),

	-- Waveform
	WaveformBg = Color3.fromRGB(28, 28, 35),
	WaveformBar = Color3.fromRGB(80, 80, 100),
	WaveformRegion = Color3.fromRGB(0, 200, 180),
	WaveformRegionAlpha = 0.35,
	Playhead = Color3.fromRGB(255, 255, 255),
	PlayheadAlpha = 0.9,

	-- Spacing
	Padding = 12,
	PaddingSmall = 6,
	Gap = 8,
	GapSmall = 4,
	Radius = 6,
	RadiusSmall = 4,

	-- Font
	Font = Enum.Font.Gotham,
	FontSize = 14,
	FontSizeSmall = 12,
	FontSizeTitle = 16,
}

return Theme
