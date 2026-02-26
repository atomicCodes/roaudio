# RoAudio

A Roblox experience that plays multiple audio files with a clean UI. Uses the Roblox **Sound** API with **EqualizerSoundEffect**, **CompressorSoundEffect**, **PlaybackRegion**, and the official **React Lua** ([jsdotlua/react-lua](https://github.com/Roblox/react-lua)) for the interface. Synced to Roblox Studio via **Rojo**. Package management via **Wally**.

## Features

- **Multiple tracks** – Add and remove tracks by Roblox audio asset ID
- **Playback region** – Waveform-style display with draggable start/end handles (region is applied via `Sound.PlaybackRegion`)
- **Loop** – Per-track loop toggle
- **Level** – Per-track volume (0–200%)
- **EQ** – Low / Mid / High gain per track (EqualizerSoundEffect)
- **Compression** – Threshold, gain makeup, and on/off (CompressorSoundEffect)
- **Pan** – Per-track pan slider (stored in state; Roblox Sound does not expose pan in Luau yet)

## Setup

1. **Install Wally** (package manager):
   - [Wally](https://wally.run/install) – e.g. `brew install wally` or install via [Aftman](https://github.com/LPGhatguy/aftman): `aftman add UpliftGames/wally` then `aftman install`.

2. **Install dependencies**:
   ```bash
   wally install
   ```
   This creates a `Packages` folder with React and ReactRoblox (official React Lua).

3. **Install Rojo** and connect Studio:
   - [Rojo](https://rojo.space/) – install the Rojo plugin for Roblox Studio and the `rojo` CLI.
   - In the project folder, run:
     ```bash
     rojo serve
     ```
   - In Roblox Studio: Plugins → Rojo → Connect, then sync.

4. **Open the place** in Roblox Studio and hit Play. The RoAudio UI appears in the corner; add asset IDs and use the controls.

## Project structure

- `default.project.json` – Rojo project (syncs `src/` and `Packages/` into the game).
- `wally.toml` – Wally package manifest (React, ReactRoblox from jsdotlua).
- `src/Shared/` – ReplicatedStorage: `AudioManager.lua`, `Theme.lua`.
- `src/Client/` – StarterPlayerScripts: `main.client.lua` (entry), `App.lua`, `components/` (TrackCard, Slider, WaveformRegion).

## Notes

- **Waveform**: Roblox does not expose raw waveform data. The UI shows a placeholder bar “waveform” and uses it to set the playback region (start/end) via `Sound.PlaybackRegion`.
- **Pan**: The pan slider is in the UI and state only; apply it when Roblox exposes a pan property on Sound or via another API.
- **Asset IDs**: Use valid Roblox audio asset IDs (e.g. from the Toolbox or your own uploads). The default IDs in `App.lua` are placeholders; replace or remove as needed.

## License

Use as you like in your Roblox projects.
