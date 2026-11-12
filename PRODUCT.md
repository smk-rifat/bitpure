# PRODUCT.md

# Audiophile Music Player

## Product Vision
A precision, distraction-free desktop music player tailored specifically for audiophiles and local lossless music collectors. The player prioritizes bit-perfect signal fidelity, verifiable audio chain transparency, and album-centric browsing over streaming-app aesthetics, visual clutter, and unnecessary telemetry. It integrates seamlessly with custom Linux environments (supporting terminal/Neovim aesthetic palettes like Omarchy themes) while retaining full architectural flexibility to adapt to future systems and cross-platform backends.

## Target User
- **Audiophiles & High-End Headphone/DAC Owners**: Users with dedicated external DAC/amp hardware who demand verification that audio reaches hardware at native bit-depth and sample rate without OS resampling or unwanted digital attenuation.
- **Local Lossless Library Collectors**: Users who curate large collections of FLAC, ALAC, WAV, AIFF, and DSD/DSF files across local and external drives, valuing metadata consistency, album coherence, and fast indexing.
- **Minimalist Power Users**: Listeners who prefer high-density, keyboard-friendly, quiet interfaces inspired by terminal/Neovim aesthetics (e.g., Gruvbox Material, Everforest, Tokyo Night) over corporate streaming-app layouts.

## Core Principles
1. **Signal Path Transparency & Bit-Perfect Integrity**: The player explicitly distinguishes between bit-perfect pure mode (unaltered 0 dB, zero DSP) and audited DSP mode, showing real-time format details and hardware output negotiation.
2. **Album-First, Folder-Agnostic Browsing**: Music is organized and displayed by musical metadata (albums, artists, discs) rather than forcing raw filesystem navigation, while robustly respecting filesystem storage sources.
3. **Quiet, Information-Dense Aesthetic**: Terminal-inspired, high-contrast, clean UI devoid of heavy gradients, giant promo cards, or visual noise.
4. **Resilience & Self-Healing**: Automated file monitoring, graceful background scanning, online metadata repair with user confirmation, and non-blocking crash recovery.
5. **Decoupled Architecture & Headroom**: Audio engine, library storage, metadata indexing, and UI presentation are strictly decoupled behind clean abstract interfaces to allow future OS backend migrations (PipeWire, WASAPI, CoreAudio) or UI engine replacements without rewriting business logic.

---

# Feature & Requirements Hierarchy

## P0 — Absolutely Required for MVP

### P0-01: Bit-Perfect Pure Mode & ALSA Direct Output
- **Purpose**: Deliver pristine, unadulterated audio streams directly to the DAC.
- **User Value**: Confirms the external DAC receives exact file sample rates and bit depths without OS mixer resampling or intermediate gain staging.
- **Functional Requirements**:
  - Direct hardware access via ALSA (`hw:X,Y`) bypassing desktop sound servers.
  - Automatic fallback to default system output when external DAC is disconnected.
  - Dedicated "Bit-Perfect Pure Mode" toggle in settings and status bar: enforces fixed 0 dB gain, disables software volume, bypasses all DSP and ReplayGain.
  - Query negotiated ALSA hardware parameters (actual format, channels, sample rate) to verify the output stage.
- **Technical Implications**: Audio thread requires real-time priority (`nice`/`RLIMIT_RTPRIO`); output abstraction must handle device locking and release.
- **Dependencies**: ALSA development libraries (`libasound2` / `alsa-sys`).
- **Acceptance Criteria**: External DAC indicator matches file sample rate (e.g., 96 kHz). Volume slider disabled in Pure Mode. Output verified bit-for-bit against source PCM.

### P0-02: Native Hardware Clock Rate Switching
- **Purpose**: Prevent software resampling artifacts across tracks with varying sample rates.
- **User Value**: Pure audiophile reproduction matching original studio master files.
- **Functional Requirements**:
  - Always reconfigure the hardware device clock rate when switching between tracks with differing sample rates (e.g., 44.1 kHz $\to$ 96 kHz $\to$ 192 kHz).
  - Provide a micro-mute/pause window (50–150ms) during clock re-lock to absorb DAC relay clicks and transient pops.
- **Technical Implications**: Device renegotiation must be cleanly executed on the audio output thread without tearing or thread panics.
- **Dependencies**: P0-01 (Audio Engine).
- **Acceptance Criteria**: Mixed-rate queue changes DAC clock mode accurately on each track without audio stream stutter or lingering driver locks.

### P0-03: Now Playing Signal-Path & Format Telemetry
- **Purpose**: Provide at-a-glance visibility into the active playback stream.
- **User Value**: Eliminates guesswork about audio resolution and active processing.
- **Functional Requirements**:
  - Display container, bit depth, sample rate, channels (e.g., `FLAC | 24-bit | 96 kHz | Stereo`).
  - Display active output mode indicator: `[Bit-Perfect Direct: hw:DAC]` vs `[DSP Active]`.
  - Cooldown/throttled UI update policy to eliminate flicker and redundant redraws.
- **Technical Implications**: Lightweight message passing from audio engine to UI layer upon track initialization or device re-negotiation.
- **Dependencies**: P0-01, UI layer.
- **Acceptance Criteria**: Format badge renders cleanly under the title; updates immediately on track change; stays static during playback.

### P0-04: Multi-Root Library Scanning & Lossless Format Parsing
- **Purpose**: Scan and index local music libraries from multiple locations.
- **User Value**: Unifies tracks stored across internal SSDs, external USB drives, and mount points.
- **Functional Requirements**:
  - User can configure multiple directory roots in Settings.
  - Recursive, parallel background indexing of lossless audio formats: FLAC, ALAC, WAV, AIFF, DSD/DSF.
  - Extract embedded metadata tags: Album, Artist, Album Artist, Track Number, Disc Number, Year, Genre.
  - When duplicate tracks exist in multiple formats, automatically designate the highest-fidelity lossless version as preferred.
- **Technical Implications**: Thread-pool filesystem traversal; cancellation token support; background DB indexing in SQLite.
- **Dependencies**: File metadata parser (`lofty` / `symphonia`), SQLite database.
- **Acceptance Criteria**: Adding 10,000 tracks indexes in under 30 seconds with negligible UI lag.

### P0-05: Real-Time In-Place Filesystem Monitoring
- **Purpose**: Keep the library synchronized without requiring manual rebuilds.
- **User Value**: Downloaded or moved albums immediately reflect in the player.
- **Functional Requirements**:
  - File watcher (`inotify`) on all active library root paths.
  - Debounce rapid filesystem bursts (e.g., folder copy operations) by 300ms before triggering incremental index updates.
  - Handle `IN_Q_OVERFLOW` by triggering an orderly root reconciliation scan.
- **Technical Implications**: Watcher service decoupled from UI; batched incremental DB upserts and removals.
- **Dependencies**: `notify` crate / OS event watcher, P0-04.
- **Acceptance Criteria**: Dropping a new FLAC album into a watched folder adds the album to the browser within 1 second.

### P0-06: Metadata-Driven Album Browser & Folder-Free View
- **Purpose**: Present library organized by musical albums rather than raw disk directories.
- **User Value**: Cohesive, immersive album collection view.
- **Functional Requirements**:
  - Grid and list browsing modes grouped by Album metadata (Album Artist + Album Title).
  - Multi-disc releases collapsed into a single album entity with sub-disc track listings.
  - Instant client-side search filtering across artists, albums, and tracks.
- **Technical Implications**: Virtualized rendering for large libraries (100k+ tracks); indexed queries in SQLite.
- **Dependencies**: P0-04.
- **Acceptance Criteria**: Multi-disc album displays as one item with disc-separated track numbering (e.g., 1-01, 2-01).

### P0-07: Flexible Library Sorting & "Dopamine Hits" Smart Sorting
- **Purpose**: Provide versatile discovery and sorting orders for track and album views.
- **User Value**: Quick filtering by conventional metrics or intelligent listening habits.
- **Functional Requirements**:
  - Sort "All Songs" and album views by: Alphabetical (A-Z / Z-A), Genre, Song Type/Format, File Size, Date Added.
  - **Dopamine Hits Smart Sorting**: Composite score calculated as:
    $$\text{Score} = \text{PlayCount} \times W_{\text{freq}} + \frac{1}{\Delta t_{\text{last\_played}} + 1} \times W_{\text{recency}} - \text{SkipCount} \times W_{\text{skip}}$$
  - Sorting preference remembered per view.
- **Technical Implications**: SQLite indices on sorting fields; play-history telemetry table.
- **Dependencies**: SQLite, P0-04.
- **Acceptance Criteria**: Selecting "Dopamine Hits" ranks frequently and recently enjoyed tracks at the top of the collection.

### P0-08: Core Playback Engine & Resilient Buffering
- **Purpose**: Deliver rock-solid, jitter-free playback with millisecond seeking.
- **User Value**: Snappy track starts, zero stutter, and smooth manual seeking.
- **Functional Requirements**:
  - Play, pause, stop, previous, next, seek bar with millisecond resolution.
  - Pre-buffering: 2-second audio ring-buffer loaded in RAM to guarantee instantaneous playback and seek responsiveness without unbounded memory consumption.
  - Playback error recovery: On corrupt file or decode failure, pop a desktop notification and auto-skip smoothly to the next track.
- **Technical Implications**: Lock-free single-producer single-consumer (SPSC) ring buffer connecting the decoder thread and the audio output thread.
- **Dependencies**: P0-01.
- **Acceptance Criteria**: Seeking within a 24/96 FLAC file initiates playback in < 50ms without audio pops or underruns.

### P0-09: ReplayGain Support (Track & Album Modes)
- **Purpose**: Prevent jarring volume variations across different albums and eras.
- **User Value**: Consistent perceptual volume during mixed-track playback while preserving original dynamics when desired.
- **Functional Requirements**:
  - Read standard ReplayGain Vorbis tags (`REPLAYGAIN_TRACK_GAIN`, `REPLAYGAIN_ALBUM_GAIN`).
  - Toggle between Track Gain, Album Gain, or Off.
  - Automatically disabled and bypassed when "Bit-Perfect Pure Mode" is engaged.
- **Technical Implications**: Floating-point DSP volume multiplication step before PCM integer conversion in non-pure mode.
- **Dependencies**: P0-01, P0-08.
- **Acceptance Criteria**: Enabling ReplayGain attenuates loud modern tracks; switching to Pure Mode instantly restores native 0 dB bitstream.

### P0-10: Persistent Local Playlists
- **Purpose**: Curate custom track sequences stored internally within the application.
- **User Value**: Organizes listening sessions without polluting source music folders.
- **Functional Requirements**:
  - Create, rename, reorder, and delete playlists.
  - Drag-and-drop or context-menu track addition.
  - Stored directly in the local SQLite database.
- **Technical Implications**: Relational table with indexed track ordering.
- **Dependencies**: P0-04, SQLite.
- **Acceptance Criteria**: Playlists retain custom order and track availability across application restarts.

### P0-11: Online Metadata & Album Art Repair with User Confirmation
- **Purpose**: Resolve missing metadata tags, artwork, and release info.
- **User Value**: Clean, visually complete music collection without manual tag editor toil.
- **Functional Requirements**:
  - Scan for missing album art or core tags (artist, album, track name).
  - Query upstream services: MusicBrainz, Discogs, iTunes API, and fallback image search.
  - Cache results locally (`~/.cache/audioplayer/art/`).
  - **Confirmation Gate**: Present suggested corrections to the user before writing changes back to audio files.
  - In-app tag editor allowing manual tag corrections.
- **Technical Implications**: Asynchronous background network worker; rate limiting; file tag rewrite safety checks.
- **Dependencies**: HTTP client (`reqwest`), tag writer (`lofty`).
- **Acceptance Criteria**: An untagged album finds its cover art online; user clicks "Confirm"; art is cached and rendered immediately.

### P0-12: Non-Library Smart Recommendations Pane
- **Purpose**: Broaden musical discovery based on actual listening preferences.
- **User Value**: Contextual suggestions for new music that fits the user's taste.
- **Functional Requirements**:
  - Analyze top played artists, genres, and recent history.
  - Query external recommendation APIs (e.g., ListenBrainz / Last.fm).
  - Display up to 5 suggested tracks/albums not in the local library in a dedicated "Discover" drawer.
  - Clicking an item opens the external release page or provides an "Add Placeholder to Playlist" action.
- **Technical Implications**: Read-only background task; isolated from core playback.
- **Dependencies**: SQLite play-history data, network client.
- **Acceptance Criteria**: Listening to classic jazz populates the panel with related artist releases outside the local library.

### P0-13: Terminal-Style Minimalist UI & Omarchy Theme Integration
- **Purpose**: Deliver a lightweight, distraction-free aesthetic matching developer environments.
- **User Value**: Cohesive desktop look, high contrast, zero bloat, instant startup.
- **Functional Requirements**:
  - UI styled with a Neovim/terminal minimalist aesthetic (crisp borders, monospace options, high information density).
  - Direct integration with Omarchy theme definitions (e.g., Gruvbox Material Dark/Medium/Soft, Everforest, Tokyo Night) read dynamically from `~/.config/omarchy/` or built-in fallbacks.
  - Keyboard-friendly navigation with default shortcut map and future customization.
- **Technical Implications**: CSS variable system powered by theme JSON/palette definitions.
- **Dependencies**: UI framework.
- **Acceptance Criteria**: Changing system Omarchy theme re-skins the player instantly without restart.

---

## P1 — Important Post-MVP Additions

- **P1-01: 10-Band Graphic Equalizer with DAC/Amp Compensation**
  - High-precision IIR biquad filter bank with presets: Balanced, Bass Boost, Bass Reduced, Treble Reduced, Neutral, Smooth Warm Neutral. Works with external DACs when Pure Mode is disabled.
- **P1-02: Optional Cross-Fade**
  - User-configurable overlap-add transition (0.5s – 5s) for continuous background listening. Automatically disabled in Pure Mode.
- **P1-03: Synchronized & Plain Lyrics Cache**
  - Automatic lookup (Genius / Musixmatch) and local caching of synced (.lrc) or plain text lyrics.
- **P1-04: Software Resampling Engine (SoXR / Rubato)**
  - For users who prefer seamless cross-rate transitions without audible DAC hardware relay lock clicks.
- **P1-05: AI-Driven Playlist Extensions**
  - Smart playlist assistant suggesting tracks from the existing library matching acoustic features and mood of the playlist.
- **P1-06: Crash Recovery & Playback Position Persistence**
  - Atomic state writes periodically recording track ID and millisecond offset to resume effortlessly after an unexpected reboot.

---

## P2 — Future & Experimental Scope

- **P2-01: Cross-Platform Output Backends (macOS CoreAudio Exclusive, Windows WASAPI Exclusive)**
- **P2-02: Bit-Perfect PipeWire Native Client (Direct ALSA mode / Pro-Audio profile)**
- **P2-03: DSD Native Direct Stream & DoP (DSD over PCM) Passthrough**
- **P2-04: Parametric EQ & Convolution Engine for Headphone/Room Impulse Responses (AutoEQ integration)**
- **P2-05: UPnP/DLNA & Bit-Perfect Network Streaming Bridge**
- **P2-06: Hardware Controller Protocol (MIDI, HID Knobs, MPRIS D-Bus interface)**

---

# Non-Functional Requirements & System Constraints

| Category | Requirement Target |
| :--- | :--- |
| **Startup Time** | Cold boot to ready UI in $< 1.5$ seconds on standard SSD. |
| **Idle Resource Usage** | $\le 80$ MB RAM, $\le 0.5\%$ CPU usage when idling with library loaded. |
| **Active Playback Overhead** | $\le 120$ MB RAM, $\le 2.0\%$ CPU on modern x86_64 during 24/192 FLAC playback in Pure Mode. |
| **Audio Thread Safety** | Audio playback thread must be $100\%$ lock-free, zero heap allocation during streaming, and zero syscalls in the hot path. |
| **Library Scale** | Seamlessly handle libraries of up to 250,000 tracks without UI freezing or SQLite query bottlenecks. |
| **Storage Architecture** | Adherence to XDG Base Directory specification (`~/.config/audioplayer`, `~/.local/share/audioplayer`, `~/.cache/audioplayer`). |

