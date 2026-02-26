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

1. **Install the Rojo CLI** (needed for `rojo serve`):
   - **Option A – Aftman (recommended)**  
     Install [Aftman](https://github.com/LPGhatguy/aftman) (download from [Releases](https://github.com/LPGhatguy/aftman/releases), then run `./aftman self-install`).  
     Then in the project folder:
     ```bash
     aftman install
     ```
     This installs Rojo and Wally for this project (see `aftman.toml`).
   - **Option B – Homebrew**  
     `brew install rojo` (macOS/Linux).
   - **Option C – Direct download**  
     [Rojo releases](https://github.com/rojo-rbx/rojo/releases) – download the binary for your OS and put it on your PATH.

2. **Install Wally packages** (React, ReactRoblox):
   ```bash
   wally install
   ```
   This creates a `Packages` folder.

3. **Install the Rojo plugin in Roblox Studio**  
   Either run `rojo plugin install` (with Rojo on your PATH) or install the plugin from the [Rojo page](https://rojo.space/) / Studio toolbox.

4. **Start Rojo and connect Studio**:
   - In the project folder: `rojo serve`
   - In Roblox Studio: **Plugins → Rojo → Connect** (default: localhost:34872)
   - Press **Play** to run the game and see the RoAudio UI.

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
