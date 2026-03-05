--[[
	AudioManager: uses the NEW Roblox Audio API (AudioPlayer, Wire, AudioDeviceOutput, AudioAnalyzer).
	- One shared AudioDeviceOutput (2D output to speakers).
	- Per track: AudioPlayer → AudioEqualizer → [AudioCompressor] → AudioDeviceOutput (Wires).
	- AudioAnalyzer wired from Player for level metering.
	- Volume, PlaybackRegion, Looping on AudioPlayer; EQ on AudioEqualizer; Compressor on AudioCompressor when enabled.
]]

local SoundService = game:GetService("SoundService")

local AudioManager = {}
AudioManager.__index = AudioManager

export type TrackState = {
	soundId: string,
	volume: number,
	muted: boolean,
	looped: boolean,
	regionStart: number,
	regionEnd: number, -- 0 means "full length"
	eqLow: number,
	eqMid: number,
	eqHigh: number,
	eqMidRangeMin: number,
	eqMidRangeMax: number,
	eqEnabled: boolean,
	compressorEnabled: boolean,
	compressorThreshold: number,
	compressorAttack: number,
	compressorRelease: number,
	compressorRatio: number,
	compressorGainMakeup: number,
	pan: number,
}

function AudioManager.new()
	local self = setmetatable({}, AudioManager)
	self._deviceOutput = nil
	self._players = {}
	self._equalizers = {}
	self._compressors = {} -- optional; may not exist in all Roblox versions
	self._wiresPlayerToEq = {}
	self._wiresEqToComp = {}
	self._wiresOut = {}
	self._wiresAnalyzer = {}
	self._analyzers = {}
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

-- Wire chain: Player → Equalizer → (Compressor?) → Output. Player → Analyzer for level.
function AudioManager:ensureSound(assetId: string, state: TrackState?): Instance?
	local key = assetId
	state = state or self._trackStates[key]
	local player = self._players[key]

	if not player then
		player = Instance.new("AudioPlayer")
		player.Name = "Track_" .. assetId
		player.Parent = SoundService
		player.AssetId = "rbxassetid://" .. tostring(assetId)
		player.AutoLoad = true
		self._players[key] = player

		local equalizer = Instance.new("AudioEqualizer")
		equalizer.Name = "EQ_" .. assetId
		equalizer.Parent = SoundService
		self._equalizers[key] = equalizer

		-- Player → Equalizer
		local wirePlayerToEq = Instance.new("Wire")
		wirePlayerToEq.SourceInstance = player
		wirePlayerToEq.TargetInstance = equalizer
		wirePlayerToEq.Parent = SoundService
		self._wiresPlayerToEq[key] = wirePlayerToEq

		-- Compressor (optional; chain Equalizer → Compressor → Output)
		local compressor = nil
		local ok, comp = pcall(function()
			return Instance.new("AudioCompressor")
		end)
		if ok and comp then
			comp.Name = "Comp_" .. assetId
			comp.Parent = SoundService
			self._compressors[key] = comp
			compressor = comp
		end

		local output = getOrCreateDeviceOutput(self)
		if compressor then
			local wireEqToComp = Instance.new("Wire")
			wireEqToComp.SourceInstance = equalizer
			wireEqToComp.TargetInstance = compressor
			wireEqToComp.Parent = SoundService
			self._wiresEqToComp[key] = wireEqToComp
			local wireOut = Instance.new("Wire")
			wireOut.SourceInstance = compressor
			wireOut.TargetInstance = output
			wireOut.Parent = SoundService
			self._wiresOut[key] = wireOut
		else
			local wireOut = Instance.new("Wire")
			wireOut.SourceInstance = equalizer
			wireOut.TargetInstance = output
			wireOut.Parent = SoundService
			self._wiresOut[key] = wireOut
		end

		local analyzer = Instance.new("AudioAnalyzer")
		analyzer.Name = "Analyzer_" .. assetId
		analyzer.Parent = SoundService
		analyzer.SpectrumEnabled = false
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
	player.Volume = state.muted and 0 or state.volume
	player.Looping = state.looped

	local length = player.TimeLength
	if length == 0 then
		length = 60
	end
	local startSec = math.clamp(state.regionStart, 0, length)
	local endSec = state.regionEnd > 0 and math.clamp(state.regionEnd, startSec, length) or length
	player.PlaybackRegion = NumberRange.new(startSec, endSec)

	local key = nil
	for k, p in pairs(self._players) do
		if p == player then key = k break end
	end
	if key and self._equalizers[key] then
		local eq = self._equalizers[key]
		eq.Bypass = not state.eqEnabled
		eq.LowGain = state.eqLow
		eq.MidGain = state.eqMid
		eq.HighGain = state.eqHigh
		local midMin = math.clamp(state.eqMidRangeMin, 200, 20000)
		local midMax = math.clamp(state.eqMidRangeMax, 200, 20000)
		eq.MidRange = NumberRange.new(midMin, math.max(midMin, midMax))
	end
	if key and self._compressors[key] then
		local comp = self._compressors[key]
		comp.Threshold = state.compressorThreshold
		comp.Attack = state.compressorAttack
		comp.Release = state.compressorRelease
		comp.Ratio = state.compressorRatio
		comp.MakeupGain = state.compressorGainMakeup
		comp.Bypass = not state.compressorEnabled
	end
end

function AudioManager:getDefaultState(soundId: string): TrackState
	return {
		soundId = soundId,
		volume = 1,
		muted = false,
		looped = false,
		regionStart = 0,
		regionEnd = 0,
		eqLow = 0,
		eqMid = 0,
		eqHigh = 0,
		eqMidRangeMin = 400,
		eqMidRangeMax = 3000,
		eqEnabled = true,
		compressorEnabled = false,
		compressorThreshold = 0,
		compressorAttack = 0.1,
		compressorRelease = 0.1,
		compressorRatio = 4,
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

-- Yields: returns waveform samples for the full file (AudioPlayer:GetWaveformAsync). Call from task.spawn.
function AudioManager:getWaveformAsync(assetId: string, numSamples: number): { number }?
	local player = self:getPlayer(assetId)
	if not player then return nil end
	for _ = 1, 50 do
		if player.IsReady and player.TimeLength > 0 then break end
		task.wait(0.1)
	end
	local length = player.TimeLength
	if length <= 0 then return nil end
	local ok, result = pcall(function()
		return player:GetWaveformAsync(NumberRange.new(0, length), numSamples)
	end)
	if ok and type(result) == "table" then return result end
	return nil
end

function AudioManager:destroy()
	for _, w in pairs(self._wiresAnalyzer) do
		if w and w.Parent then w:Destroy() end
	end
	for _, w in pairs(self._wiresOut) do
		if w and w.Parent then w:Destroy() end
	end
	for _, w in pairs(self._wiresEqToComp) do
		if w and w.Parent then w:Destroy() end
	end
	for _, w in pairs(self._wiresPlayerToEq) do
		if w and w.Parent then w:Destroy() end
	end
	for _, c in pairs(self._compressors) do
		if c and c.Parent then c:Destroy() end
	end
	for _, eq in pairs(self._equalizers) do
		if eq and eq.Parent then eq:Destroy() end
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
	table.clear(self._equalizers)
	table.clear(self._compressors)
	table.clear(self._wiresPlayerToEq)
	table.clear(self._wiresEqToComp)
	table.clear(self._wiresOut)
	table.clear(self._analyzers)
	table.clear(self._wiresAnalyzer)
	self._deviceOutput = nil
	table.clear(self._trackStates)
end

return AudioManager
