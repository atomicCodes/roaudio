--[[
	AudioManager: creates and controls Sound instances with effects.
	Uses Roblox Sound API: Volume, Looped, PlaybackRegion (NumberRange),
	EqualizerSoundEffect, CompressorSoundEffect.
	All Sound instances are parented to SoundService.
]]

local SoundService = game:GetService("SoundService")

local AudioManager = {}
AudioManager.__index = AudioManager

export type TrackState = {
	soundId: string,
	volume: number,
	looped: boolean,
	regionStart: number,
	regionEnd: number, -- 0 means "full length"
	eqLow: number,
	eqMid: number,
	eqHigh: number,
	compressorEnabled: boolean,
	compressorThreshold: number,
	compressorAttack: number,
	compressorRelease: number,
	compressorGainMakeup: number,
	pan: number, -- -1 to 1, stored for when Roblox exposes pan on Sound
}

function AudioManager.new()
	local self = setmetatable({}, AudioManager)
	self._sounds: { [string]: Sound } = {}
	self._trackStates: { [string]: TrackState } = {}
	return self
end

-- Creates or updates a Sound for the given asset id and applies current state.
function AudioManager:ensureSound(assetId: string, state: TrackState?): Sound
	local key = assetId
	local sound = self._sounds[key]
	state = state or self._trackStates[key]

	if not sound then
		sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://" .. tostring(assetId)
		sound.Name = "Track_" .. assetId
		sound.Parent = SoundService
		self._sounds[key] = sound
		self:attachEffects(sound)
	end

	self._trackStates[key] = state
	self:applyState(sound, state)
	return sound
end

function AudioManager:attachEffects(sound: Sound)
	-- Equalizer: Low 0-400Hz, Mid 400-4kHz, High 4kHz+
	local eq = sound:FindFirstChildOfClass("EqualizerSoundEffect")
	if not eq then
		eq = Instance.new("EqualizerSoundEffect")
		eq.Name = "EQ"
		eq.Priority = 0
		eq.Parent = sound
	end

	-- Compressor
	local comp = sound:FindFirstChildOfClass("CompressorSoundEffect")
	if not comp then
		comp = Instance.new("CompressorSoundEffect")
		comp.Name = "Compressor"
		comp.Priority = 1
		comp.Parent = sound
	end
end

function AudioManager:applyState(sound: Sound, state: TrackState)
	sound.Volume = state.volume
	sound.Looped = state.looped

	-- PlaybackRegion: NumberRange(Min, Max). Use 0 and sound.TimeLength for full.
	local length = sound.TimeLength
	if length == 0 then
		length = 60 -- fallback while loading
	end
	local startSec = math.clamp(state.regionStart, 0, length)
	local endSec = state.regionEnd > 0 and math.clamp(state.regionEnd, startSec, length) or length
	sound.PlaybackRegion = NumberRange.new(startSec, endSec)

	local eq = sound:FindFirstChildOfClass("EqualizerSoundEffect")
	if eq then
		eq.LowGain = state.eqLow
		eq.MidGain = state.eqMid
		eq.HighGain = state.eqHigh
	end

	local comp = sound:FindFirstChildOfClass("CompressorSoundEffect")
	if comp then
		comp.Enabled = state.compressorEnabled
		comp.Threshold = state.compressorThreshold
		comp.Attack = state.compressorAttack
		comp.Release = state.compressorRelease
		comp.GainMakeup = state.compressorGainMakeup
	end

	-- Pan: Roblox Sound does not expose panStereo in Luau; store for future API.
	-- If your engine has it: sound.Pan = state.pan (or similar)
end

function AudioManager:getDefaultState(soundId: string): TrackState
	return {
		soundId = soundId,
		volume = 1,
		looped = false,
		regionStart = 0,
		regionEnd = 0,
		eqLow = 0,
		eqMid = 0,
		eqHigh = 0,
		compressorEnabled = false,
		compressorThreshold = 0,
		compressorAttack = 0.1,
		compressorRelease = 0.1,
		compressorGainMakeup = 0,
		pan = 0,
	}
end

function AudioManager:getOrCreateState(assetId: string): TrackState
	local key = assetId
	if not self._trackStates[key] then
		self._trackStates[key] = self:getDefaultState(assetId)
	end
	return self._trackStates[key]
end

function AudioManager:play(assetId: string, state: TrackState?)
	local state = state or self:getOrCreateState(assetId)
	local sound = self:ensureSound(assetId, state)
	sound.TimePosition = state.regionStart
	sound:Play()
	return sound
end

function AudioManager:stop(assetId: string)
	local sound = self._sounds[assetId]
	if sound then
		sound:Stop()
	end
end

function AudioManager:isPlaying(assetId: string): boolean
	local sound = self._sounds[assetId]
	return sound and sound.IsPlaying or false
end

function AudioManager:getTimeLength(assetId: string): number
	local sound = self._sounds[assetId]
	if sound then
		return sound.TimeLength
	end
	return 0
end

function AudioManager:getTimePosition(assetId: string): number
	local sound = self._sounds[assetId]
	if sound then
		return sound.TimePosition
	end
	return 0
end

function AudioManager:destroy()
	for _, sound in pairs(self._sounds) do
		sound:Destroy()
	end
	table.clear(self._sounds)
	table.clear(self._trackStates)
end

return AudioManager
