--[[
	AudioManager: uses the NEW Roblox Audio API (AudioPlayer, Wire, AudioDeviceOutput, AudioAnalyzer).
	- One shared AudioDeviceOutput (2D output to speakers).
	- One AudioPlayer per track, wired to the output and to an AudioAnalyzer for real level metering.
	- PlaybackRegion, Volume, Looping, TimePosition, TimeLength from AudioPlayer.
	- Real-time level from AudioAnalyzer.PeakLevel (client-side only).
	- EQ/Compressor: not available in the new API in the same way; state is kept for future use.
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
	pan: number,
}

function AudioManager.new()
	local self = setmetatable({}, AudioManager)
	self._deviceOutput = nil -- single shared 2D output
	self._players = {}
	self._wiresOut = {} -- Wire from each player to device output
	self._analyzers = {}
	self._wiresAnalyzer = {} -- Wire from each player to its analyzer (for level)
	self._trackStates = {}
	return self
end

local function getOrCreateDeviceOutput(self): Instance
	if self._deviceOutput then
		return self._deviceOutput
	end
	local output = Instance.new("AudioDeviceOutput")
	output.Name = "RoAudio_2DOutput"
	output.Parent = SoundService
	self._deviceOutput = output
	return output
end

-- Creates or updates an AudioPlayer (and Wire + AudioAnalyzer) for the given asset id.
function AudioManager:ensureSound(assetId: string, state: TrackState?): Instance?
	local key = assetId
	state = state or self._trackStates[key]
	local player = self._players[key]

	if not player then
		player = Instance.new("AudioPlayer")
		player.Name = "Track_" .. assetId
		player.Parent = SoundService
		-- Use AssetId (still works; Asset is ContentId for future)
		player.AssetId = "rbxassetid://" .. tostring(assetId)
		player.AutoLoad = true
		self._players[key] = player

		local output = getOrCreateDeviceOutput(self)
		local wireOut = Instance.new("Wire")
		wireOut.SourceInstance = player
		wireOut.TargetInstance = output
		wireOut.Parent = SoundService
		self._wiresOut[key] = wireOut

		local analyzer = Instance.new("AudioAnalyzer")
		analyzer.Name = "Analyzer_" .. assetId
		analyzer.Parent = SoundService
		analyzer.SpectrumEnabled = false -- we only need level for VU; set true if using GetSpectrum
		self._analyzers[key] = analyzer

		local wireAnalyzer = Instance.new("Wire")
		wireAnalyzer.SourceInstance = player
		wireAnalyzer.TargetInstance = analyzer
		wireAnalyzer.Parent = SoundService
		self._wiresAnalyzer[key] = wireAnalyzer
	end

	self._trackStates[key] = state
	self:applyState(player, state)
	return player
end

function AudioManager:applyState(player: Instance, state: TrackState)
	player.Volume = state.volume
	player.Looping = state.looped

	local length = player.TimeLength
	if length == 0 then
		length = 60
	end
	local startSec = math.clamp(state.regionStart, 0, length)
	local endSec = state.regionEnd > 0 and math.clamp(state.regionEnd, startSec, length) or length
	player.PlaybackRegion = NumberRange.new(startSec, endSec)

	-- EQ/Compressor: new API does not expose EqualizerSoundEffect/CompressorSoundEffect on this chain; state kept for UI
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
	state = state or self:getOrCreateState(assetId)
	local player = self:ensureSound(assetId, state)
	if not player then return end
	player.TimePosition = state.regionStart
	player:Play()
end

function AudioManager:stop(assetId: string)
	local player = self._players[assetId]
	if player then
		player:Stop()
	end
end

function AudioManager:playAll(assetIds: { string })
	for _, id in ipairs(assetIds) do
		self:stop(id)
	end
	for _, id in ipairs(assetIds) do
		local state = self:getOrCreateState(id)
		self:ensureSound(id, state)
	end
	for _, id in ipairs(assetIds) do
		local state = self:getOrCreateState(id)
		local player = self._players[id]
		if player then
			player.TimePosition = state.regionStart
			player:Play()
		end
	end
end

function AudioManager:stopAll(assetIds: { string })
	for _, id in ipairs(assetIds) do
		self:stop(id)
	end
end

function AudioManager:isPlaying(assetId: string): boolean
	local player = self._players[assetId]
	return player and player.IsPlaying or false
end

function AudioManager:getTimeLength(assetId: string): number
	local player = self._players[assetId]
	if player then
		return player.TimeLength
	end
	return 0
end

function AudioManager:getTimePosition(assetId: string): number
	local player = self._players[assetId]
	if player then
		return player.TimePosition
	end
	return 0
end

-- Real-time level from AudioAnalyzer (0–1 range; analyzer reports higher values, we clamp).
function AudioManager:getLevel(assetId: string): number
	local analyzer = self._analyzers[assetId]
	if not analyzer then return 0 end
	local peak = analyzer.PeakLevel
	if type(peak) ~= "number" then return 0 end
	return math.clamp(peak, 0, 1)
end

-- Expose players for UI (e.g. property changed signals). Use _players in TrackCard for consistency.
function AudioManager:getPlayer(assetId: string): Instance?
	return self._players[assetId]
end

function AudioManager:destroy()
	for _, w in pairs(self._wiresAnalyzer) do
		if w and w.Parent then w:Destroy() end
	end
	for _, w in pairs(self._wiresOut) do
		if w and w.Parent then w:Destroy() end
	end
	for _, a in pairs(self._analyzers) do
		if a and a.Parent then a:Destroy() end
	end
	for _, p in pairs(self._players) do
		if p and p.Parent then p:Destroy() end
	end
	if self._deviceOutput and self._deviceOutput.Parent then
		self._deviceOutput:Destroy()
	end
	table.clear(self._players)
	table.clear(self._wiresOut)
	table.clear(self._analyzers)
	table.clear(self._wiresAnalyzer)
	self._deviceOutput = nil
	table.clear(self._trackStates)
end

return AudioManager
