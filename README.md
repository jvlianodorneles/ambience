# Ambience Studio for Omarchy 🌧️🎧

Offline ambient soundscapes, procedural noise generator, and focus sound studio for [Omarchy](https://omarchy.org/).

---

## ✨ Features

- **⚡ 100% Offline & Ultra-Lightweight**: Generates soundscapes in real-time via mathematical DSP synthesis (~0.2% CPU), with zero internet connection required and zero trackers.
- **🎧 8 Built-in Soundscapes**:
  - 🌧️ **Rain Shower**: Soothing rainfall with stochastic droplet impacts.
  - 🌊 **Ocean Waves**: Deep oceanic surf with 11-second natural wave cycles.
  - 🔥 **Campfire**: Cozy wood fire with warm pops and crackles.
  - 🟫 **Brown Noise**: Deep Brownian rumble (ideal for deep focus, office masking, and ADHD).
  - 🌸 **Pink Noise**: Balanced 1/f soothing natural spectrum.
  - ⚪ **White Noise**: Crisp static noise for total frequency masking.
  - 🧠 **Binaural Beats (Alpha 10Hz)**: Stereo-separated frequencies (200Hz left / 210Hz right) to induce focus.
  - ☕ **Café Ambience**: Warm coffee shop acoustic resonance.
- **📁 Custom Audio Loops**: Drop your own `.ogg`, `.mp3`, or `.wav` files into `sounds/` to play personal tracks seamlessly.
- **🖱️ Intuitive Bar Controls**:
  - **Left-Click**: Play / Pause toggle.
  - **Mouse Wheel**: Smooth volume adjustment up / down (+/- 5%).
  - **Middle-Click**: Quick-cycle to the next sound preset.
  - **Right-Click**: Opens the **Ambience Studio** visual popup card.
- **🎚️ Ambience Studio Popup**:
  - 2-column Soundscape selection cards.
  - Fluid volume slider (0% - 100%).
  - **Sleep Timer**: Auto-off countdown (Off, 15m, 30m, 45m, 60m).
- **🎨 Omarchy Theme Integration**: Seamlessly follows system colors (`bar.urgent`, `bar.foreground`, `bar.fontFamily`).

---

## 📋 Requirements & Dependencies

- **PipeWire / ALSA**: `aplay` or `pw-play` (pre-installed on Omarchy/Arch).
- **Python 3**: (pre-installed) for real-time DSP mathematical audio synthesis.
- **mpv**: (optional) used for playing custom `.ogg`/`.mp3` files if placed in `sounds/`.
- **Nerd Fonts**: (pre-installed) for status bar icons.

---

## 📦 Installation

Install directly using the Omarchy CLI:

```bash
omarchy plugin add https://github.com/jvlianodorneles/ambience.git --enable --yes
```

Or clone manually into your plugins folder:

```bash
git clone https://github.com/jvlianodorneles/ambience.git ~/.config/omarchy/plugins/dorneles.ambience
omarchy-shell shell rescanPlugins
omarchy plugin enable dorneles.ambience
```

---

## 🗑️ Removal / Uninstallation

To disable or remove the plugin from Omarchy:

```bash
# Disable from the status bar
omarchy plugin disable dorneles.ambience

# Or completely remove the plugin
omarchy plugin remove dorneles.ambience --yes
```

If installed manually:
```bash
omarchy plugin disable dorneles.ambience
rm -rf ~/.config/omarchy/plugins/dorneles.ambience
omarchy-shell shell rescanPlugins
```

---

## 🎮 Usage & Controls

| Action | Control | Description |
|---|---|---|
| **Play / Pause** | Left-Click | Toggles sound playback |
| **Volume Up / Down** | Scroll Wheel on Bar | Changes volume by 5% |
| **Next Sound** | Middle-Click on Bar | Advances to the next soundscape preset |
| **Open Studio** | Right-Click on Bar | Opens the visual Ambience Studio popup card |

---

## ⚙️ Configuration (`~/.config/omarchy/shell.json`)

Configure default startup settings in `~/.config/omarchy/shell.json`:

```json
{
  "id": "dorneles.ambience",
  "defaultPreset": "rain",
  "defaultVolume": 60,
  "showLabel": true
}
```

### Options Reference

| Option | Type | Options / Values | Default | Description |
|---|---|---|---|---|
| `defaultPreset` | `enum` | `"rain"`, `"waves"`, `"campfire"`, `"brown"`, `"pink"`, `"white"`, `"binaural"`, `"cafe"` | `"rain"` | Default soundscape to start. |
| `defaultVolume` | `integer` | `0` - `100` | `60` | Default volume percentage. |
| `showLabel` | `boolean` | `true`, `false` | `true` | Show sound name on horizontal bars. |

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
