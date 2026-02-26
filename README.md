# RoAudio

A Roblox experience that plays multiple audio files with a clean UI. Uses the **new Roblox Audio API** (**AudioPlayer**, **Wire**, **AudioDeviceOutput**, **AudioAnalyzer**) for playback and real level metering, and the official **React Lua** ([jsdotlua/react-lua](https://github.com/Roblox/react-lua)) for the interface. Synced to Roblox Studio via **Rojo**. Package management via **Wally**.

## Features

- **Multiple tracks** – Add and remove tracks by Roblox audio asset ID
- **Playback region** – Waveform-style display with draggable start/end handles (region via `AudioPlayer.PlaybackRegion`)
- **Playhead** – White line on the waveform shows current playback position when playing
- **Level meter** – Per-channel vertical VU meter driven by **AudioAnalyzer.PeakLevel** (real-time)
- **Loop** – Per-track loop toggle (`AudioPlayer.Looping`)
- **Level** – Per-track volume (0–200%) (`AudioPlayer.Volume`)
- **EQ / Compression** – UI sliders kept; new API does not expose Equalizer/Compressor in the same way; state is stored for future use
- **Pan** – Per-track pan slider (stored in state; not yet exposed in this API path)

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
- `src/Client/` – StarterPlayerScripts: `main.client.lua` (entry), `App.lua`, `components/` (TrackCard, Slider, WaveformRegion, LevelMeter).
- `assets/` – Logo image (`roaudio_logo.jpg`); used via asset ID (see Logo below).

## Logo (top-right of UI)

The logo lives in `assets/roaudio_logo.jpg`. **Rojo does not sync image file contents** into Roblox, so the game cannot load it from the folder alone. To show it:

1. **Upload the image** in Roblox: [Creator Hub](https://create.roblox.com/dashboard/creations) → **Development Items** → **Images** → **Add Image**, upload `assets/roaudio_logo.jpg`, then copy the new **asset ID** (numbers only).
2. In **`src/Client/App.lua`**, set:  
   `local LOGO_ASSET_ID = "YOUR_ASSET_ID"`  
   (replace `YOUR_ASSET_ID` with the ID you copied; replace `"0"` if it’s already there).
3. Save, re-sync with Rojo if needed, and run the experience. The logo will appear in the top-right.

## Notes

- **Waveform**: Roblox does not expose a full-file waveform. The **Sound** API has no amplitude/spectrum data. The **new Audio API**’s **AudioAnalyzer.GetSpectrum()** returns per-buffer frequency data (live only), so you could draw a live spectrum while playing, but there is no API that returns the waveform for the whole file. The UI uses a placeholder bar whose width scales with duration; use it to set the playback region via `Sound.PlaybackRegion`.
- **Level meter**: Vertical VU-style meter driven by **AudioAnalyzer.PeakLevel** (new Audio API).
- **Asset metadata**: Each track fetches metadata via **MarketplaceService:GetProductInfoAsync** (Name, Description, Creator) and displays it with Asset ID and duration.
- **Pan**: The pan slider is in the UI and state only; apply it when Roblox exposes a pan property on Sound or via another API.
- **Asset IDs**: The app starts with no default tracks so nothing fails to load (external IDs often 403). Add tracks with the Add box using asset IDs from Toolbox → Audio or your own uploaded sounds.

## License

Use as you like in your Roblox projects.
