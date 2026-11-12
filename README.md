# BitPure

**BitPure** is an audiophile music player desktop application for Arch Linux (Hyprland / Wayland) designed for local lossless music library listening, direct hardware USB DAC integration, and terminal TUI aesthetics.

![Theme](https://img.shields.io/badge/Themes-Everforest%20%7C%20Gruvbox%20%7C%20Nord-green)
![Audio Engine](https://img.shields.io/badge/Audio-Direct%20ALSA%20%2F%20PipeWire%20%2F%20MPV-blue)
![Architecture](https://img.shields.io/badge/Core-Rust%20%2B%20Qt6%20QML-orange)

---

## Highlights

- **Bit-Perfect 0 dB Line-Out**: Direct hardware DAC passthrough (`hw:X,Y`) with zero software resampling or digital attenuation when Pure Mode is engaged.
- **Audited DSP Mode**: Optional 10-band equalizer (Flat, Balanced, Bass+, Warm) and software volume control when not in Pure Mode.
- **TUI & Neovim Aesthetic**: Inspired by terminal players (`rmpc`), featuring authentic Everforest, Gruvbox, and Nord palettes, 1px bordered boxes, and Vim statusline badges (`[ NORMAL ]` / `[ PLAYING ]`).
- **Interactive Controls**:
  - Click & drag timeline / seek bar for instant seeking.
  - Hover & mouse-wheel scroll on the volume panel for smooth audio adjustment.
  - Keyboard shortcuts (`[zxcv]` for playback and volume control).
- **Fast Lossless Library**: Scans local FLAC/WAV libraries, populates tracks, artists, albums, and recommendations instantly.

---

## Architecture

- **Core & Metadata**: High-performance Rust crates (`app_core`, `audio_backend`, `audio_dsp`, `audio_engine`, `library_index`, `metadata_svc`).
- **Playback Engine**: `mpv` background daemon with IPC socket control (`QLocalSocket`).
- **User Interface**: Qt 6 Quick / QML with native C++ backend bindings (`Backend` and `Theme` QObject controllers).

---

## Building and Running

### Prerequisites

- Arch Linux (or modern Linux distribution)
- `rust` and `cargo`
- `qt6-base`, `qt6-declarative`
- `alsa-lib`, `mpv`

### Build

```bash
# 1. Build Rust core libraries
cargo build

# 2. Build Qt6 GUI frontend
cd ui
mkdir -p build && cd build
qmake6 ../audioplayer.pro
make -j$(nproc)
```

### Launch

```bash
/home/smk/Music_Player/bin/bitpure
```

---

## License

MIT
