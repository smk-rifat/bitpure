# ARCHITECTURE.md

# Audiophile Music Player — Technical Architecture

This document specifies the software architecture for the high-fidelity desktop audiophile music player. The architecture is engineered around the principle of **systemic headroom**: strict isolation of the core domain logic, an audio pipeline with zero-allocation real-time guarantees, and pluggable abstraction layers for audio output, library storage, metadata providers, and UI presentation.

---

## 1. System Architecture & High-Level Topology

```
                  ┌──────────────────────────────────────────────┐
                  │                   UI Layer                   │
                  │   Tauri + TypeScript + Solid/Vue (Frontend)  │
                  │   Terminal-Style / Neovim Theme Engine       │
                  └──────────────────────┬───────────────────────┘
                                         │
                               IPC Commands & Events
                           (Strongly-Typed JSON-RPC)
                                         │
                  ┌──────────────────────▼───────────────────────┐
                  │           Application Core / Orchestrator    │
                  │            Rust Workspace Crate (core)       │
                  └──────────────┬───────────────┬───────────────┘
                                 │               │
         ┌───────────────────────┼───────────────┼────────────────────────┐
         │                       │               │                        │
┌────────▼────────┐     ┌────────▼──────┐ ┌──────▼────────┐     ┌─────────▼────────┐
│  Audio Engine   │     │Library Engine │ │Metadata Engine│     │  Config & State  │
│(audio_engine)   │     │(library_index)│ │(metadata_svc) │     │  (storage_mgr)   │
└────────┬────────┘     └────────┬──────┘ └──────┬────────┘     └─────────┬────────┘
         │                       │               │                        │
┌────────▼────────┐     ┌────────▼──────┐ ┌──────▼────────┐     ┌─────────▼────────┐
│ Hardware Output │     │ SQLite Index  │ │Online Providers│    │ ~/.config & XDG  │
│ ALSA (hw:X,Y)   │     │ & inotify     │ │MB, Discogs,   │     │ SQLite / JSON    │
│ (Future: WASAPI,│     │ File Watcher  │ │iTunes, Genius │     │                  │
│ PipeWire, Core) │     │               │ │               │     │                  │
└────────┬────────┘     └───────────────┘ └───────────────┘     └──────────────────┘
         │
    External DAC / Amp
```

### Architectural Headroom & Extensibility Guarantees
- **Backend Swappability**: Audio output backends implement the `AudioOutputBackend` trait. Swapping Linux ALSA for Windows WASAPI Exclusive, macOS CoreAudio, or native PipeWire Pro-Audio requires implementing this trait without touching decoding, ring buffering, or playlist logic.
- **Frontend Agility**: The UI communicates across a structured IPC boundary using protocol-defined payloads. The UI layer can be completely replaced (e.g., from Webview to native Slint, Qt/QML, or Ratatui terminal TUI) without altering backend crates.
- **Database Decoupling**: The library repository exposes a repository trait (`LibraryRepository`), isolating SQLite specifics from catalog and sorting business rules.

---

## 2. Module Boundaries & Crate Organization

The project is structured as a Cargo workspace with distinct crate boundaries:

```
music_player/
├── Cargo.toml                  # Workspace definition
├── crates/
│   ├── app_core/               # Application state orchestration, commands, IPC bridge
│   ├── audio_engine/           # Zero-allocation playback pipeline, decoders, ring-buffers
│   ├── audio_backend/          # OS-specific hardware drivers (ALSA, mock, future WASAPI)
│   ├── audio_dsp/              # ReplayGain, 10-band IIR filters, resamplers, crossfade
│   ├── library_index/          # File scanning, inotify watching, SQLite schema & queries
│   ├── metadata_svc/           # Tag extraction (lofty), online repair, image/lyrics caching
│   └── common_types/           # Shared domain entities (Track, Album, Format, StreamInfo)
└── src-ui/                     # Frontend source (TypeScript, CSS, Components)
```

### Boundary Responsibilities:
1. `common_types`: Pure value objects and domain contracts (`TrackId`, `AlbumId`, `AudioFormat`, `SignalPathInfo`). Zero heavy dependencies.
2. `audio_engine`: Manages stream lifecycle, decoder state, and real-time ring buffering. Depends only on `common_types` and `audio_dsp`. Has no knowledge of SQLite or UI.
3. `audio_backend`: Encapsulates OS hardware APIs (`alsa-sys`, `libasound2`). Provides concrete stream sinks.
4. `library_index`: Owns the local catalog, sorting algorithms (including "Dopamine Hits"), and directory tree traversal.
5. `metadata_svc`: Manages network requests, image caching on disk, and ID3/Vorbis tag updates.
6. `app_core`: Glues events between audio playback, database updates, and UI notifications.

---

## 3. Audio-Engine Architecture

### Zero-Allocation Real-Time Pipeline

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            DECODER / WORKER THREAD                          │
│                                                                             │
│  [Source File] ──► [Symphonia Decoder] ──► [Decoded PCM (f32/i32)]          │
│                                                       │                     │
│                                              [Pure Mode Active?]            │
│                                              ├── Yes ──► (Bypass DSP) ──┐   │
│                                              └── No  ──► [ReplayGain]   │   │
│                                                               │         │   │
│                                                          [10-Band EQ]   │   │
│                                                               │         │   │
│                                                               ├─────────┘   │
│                                                               ▼             │
│                                                  [Pre-Roll SPSC Ring Buffer]│
└───────────────────────────────────────────────────────────────┬─────────────┘
                                                                │ Atomic Read
                                                                │ (Zero Alloc)
┌───────────────────────────────────────────────────────────────▼─────────────┐
│                         REAL-TIME AUDIO OUTPUT THREAD                       │
│                                                                             │
│  [SPSC Ring Buffer] ──► [ALSA Direct Buffer] ──► [/dev/snd/pcmC* (hw:X,Y)]  │
│                                                                             │
│  * Strict RT Constraints: No Mutex, No Allocations, No Syscalls, No I/O     │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Audio Pipeline Deep Dives:

#### 1. Audio-Thread Safety & Lock-Free Design
- The real-time playback thread is bounded by hard deadlines. Missing a deadline produces an audible glitch/underrun.
- Communication between the Decoder Thread and the Audio Output Thread uses a lock-free, single-producer single-consumer (SPSC) circular ring buffer (`rtrb` crate).
- The audio callback thread never allocates memory (`malloc`/`free`), never locks standard OS primitives (`std::sync::Mutex`), and performs no disk or network I/O.
- Commands from the application core (Play, Pause, Seek, Stop) are delivered via bounded lock-free atomic command rings (`crossbeam_channel`).

#### 2. Buffering & Pre-Buffering Strategy
- **Pre-Roll Buffer**: The engine buffers up to 2.0 seconds of decoded PCM samples in RAM before opening the output sink or releasing stream pause.
- This guarantees instantaneous seek responses ($\le 30$ms) and completely isolates playback from bursty filesystem or I/O latency.
- Memory envelope: 2.0 seconds of uncompressed stereo 24-bit/192kHz PCM requires:
  $$\text{RAM} = 2.0\text{ s} \times 192,000\text{ samples/s} \times 2\text{ channels} \times 4\text{ bytes/sample} \approx 3.07\text{ MB}$$
  This is negligible on modern hardware while providing massive safety margin.

#### 3. Native Sample-Rate Handling & Clock Negotiation
- When a track begins, the engine compares the track's native `sample_rate` and `format` with the active device state.
- If a rate difference exists:
  1. The output stream initiates a micro-mute (50ms).
  2. The output handle releases the current hardware lock.
  3. `snd_pcm_hw_params_set_rate_near()` and `snd_pcm_hw_params_set_format()` reconfigure the hardware PLL clock natively on the DAC.
  4. Once hardware negotiation returns success, the stream unmutes and streams the pre-buffered frames.
- This guarantees genuine bit-perfect delivery for 44.1k, 48k, 88.2k, 96k, 176.4k, and 192k audio.

#### 4. Signal Path Transparency Verification
- The engine creates a `SignalPathInfo` telemetry record whenever a track opens:
  - **Source File**: Codec (e.g., FLAC), Container Bit Depth (24-bit), Sample Rate (96,000 Hz), Channels (2).
  - **DSP Stage**: `Bypassed (Bit-Perfect Pure Mode)` vs `Active (ReplayGain: -3.2 dB, EQ: Balanced)`.
  - **Hardware Output**: Confirmed ALSA parameters read back from the driver (`SND_PCM_FORMAT_S24_3LE`, `96000 Hz`, `hw:1,0`).
- Discrepancies (e.g., device downmixing or unsupported clock forcing fallback) are surfaced explicitly to the UI.

#### 5. Output-Device Changes & USB Hot-Plugging
- A background device discovery worker monitors `/dev/snd` via `udev` events.
- When an external USB DAC is plugged in: The engine automatically queries its capabilities. If configured for auto-switch, it smoothly migrates the playback pipeline to the newly discovered DAC.
- When an active DAC is unplugged: ALSA calls return `-ENODEV` or `-EIO`. The engine catches the driver error, pauses stream time, surfaces a desktop notification, and cleanly falls back to the default system audio sink.

---

## 4. Library Architecture & Scanning

```
                        ┌───────────────────────────────┐
                        │   Configured Root Folders     │
                        │ [/mnt/music, /home/user/flac] │
                        └───────────────┬───────────────┘
                                        │
                         ┌──────────────┴──────────────┐
                         ▼                             ▼
               ┌───────────────────┐         ┌───────────────────┐
               │  Initial / Rescan │         │ Inotify Watcher   │
               │ (Rayon Threadpool)│         │(Real-Time Changes)│
               └─────────┬─────────┘         └─────────┬─────────┘
                         │                             │
                         │ Batched Parsed Records      │ Debounced (300ms)
                         │ (Lofty Tag Parser)          │ FS Events
                         │                             │
                         └──────────────┬──────────────┘
                                        ▼
                      ┌──────────────────────────────────┐
                      │    Library Batch Ingestion       │
                      │  - Duplicate format resolution   │
                      │  - Multi-disc album unification  │
                      │  - Transactional SQLite Upsert   │
                      └─────────────────┬────────────────┘
                                        ▼
                              ┌──────────────────┐
                              │    library.db    │
                              │ (SQLite WAL Mode)│
                              └──────────────────┘
```

### Key Library Mechanisms:
1. **Parallel Multi-Root Traverser**: Directories are walked using `walkdir` and parallelized with `rayon`. File headers are probed via magic bytes (avoiding slow extension-only guessing).
2. **Duplicate Format Preference**: If multiple files share the identical `Album` + `Title` + `TrackNumber` (or MusicBrainz Track ID), the indexer computes a fidelity score:
   $$\text{Rank}: \text{DSD/DSF (600)} > \text{FLAC (500)} > \text{ALAC (400)} > \text{WAV (300)} > \text{AIFF (200)}$$
   The highest-fidelity copy is marked `is_preferred = 1`. In the UI, the album displays clean singular tracks, while providing an inspector view of alternative encodings.
3. **Multi-Disc Unification**: Folders named `CD1`, `Disc 2`, `Part 1` are detected both structurally and via tags (`DISCNUMBER`). They are unified under one `Album` entity with sorted track numbers (`disc_number`, `track_number`).
4. **Large Library Scalability**: SQLite runs in `WAL` (Write-Ahead Logging) mode with `PRAGMA synchronous = NORMAL` and `PRAGMA cache_size = -64000` (64 MB in-memory cache). Queries use covered indexes on `(album_id, disc_number, track_number)` ensuring sub-5ms query times across 250,000 tracks.

---

## 5. Metadata Architecture & Repair Pipeline

```
                         [Track Lacks Cover / Tags]
                                     │
                                     ▼
                      ┌─────────────────────────────┐
                      │ Metadata Worker Task Queue  │
                      │  (Rate-Limited Async Pool)  │
                      └──────────────┬──────────────┘
                                     │
           ┌─────────────────────────┼─────────────────────────┐
           ▼                         ▼                         ▼
  ┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
  │  MusicBrainz    │       │     Discogs     │       │   iTunes API    │
  │  (AcoustID &    │       │ (Search API &   │       │(High-Res Covers)│
  │  Metadata Tags) │       │ Release Art)    │       │                 │
  └────────┬────────┘       └────────┬────────┘       └────────┬────────┘
           │                         │                         │
           └─────────────────────────┼─────────────────────────┘
                                     ▼
                       ┌────────────────────────────┐
                       │ Result Staging & Cache     │
                       │ ~/.cache/audioplayer/art/  │
                       └─────────────┬──────────────┘
                                     │
                                     ▼
                       ┌────────────────────────────┐
                       │ User Confirmation Dialog   │
                       │ "Review Tag Corrections"   │
                       └─────────────┬──────────────┘
                                     │ User Confirms
                                     ▼
                       ┌────────────────────────────┐
                       │ Atomic Tag Writer (Lofty)  │
                       │ Safe In-Place File Update  │
                       └────────────────────────────┘
```

### Safety & Resilience Strategy:
- **Zero Involuntary File Writes**: Fetched tags and images are never written to source audio files without explicit user consent. Until confirmed, fetched metadata exists purely in the local cache database (`metadata_cache`).
- **Corruption-Proof Tag Writing**: When the user approves tag updates, `metadata_svc` writes to a temporary sibling file (`file.flac.tmp`) and executes an atomic POSIX rename (`renameat2`), preventing file corruption in the event of power loss or disk detachment.
- **Embedded vs External Artwork Priority**:
  1. High-resolution local sidecar files (`cover.jpg`, `folder.png`).
  2. Embedded ID3/Vorbis picture frames.
  3. Cached online-retrieved artwork.

---

## 6. Persistence Model

The persistence layer is partitioned into structured databases, configuration manifests, and disposable caches following the XDG specification:

### 1. Relational Database: `~/.local/share/audioplayer/library.db` (SQLite 3)
```sql
CREATE TABLE albums (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    album_artist TEXT NOT NULL,
    year INTEGER,
    genre TEXT,
    disc_count INTEGER DEFAULT 1,
    cover_art_uri TEXT,
    created_at INTEGER NOT NULL
);

CREATE TABLE tracks (
    id TEXT PRIMARY KEY,
    album_id TEXT NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
    file_path TEXT UNIQUE NOT NULL,
    file_size INTEGER NOT NULL,
    mtime INTEGER NOT NULL,
    title TEXT NOT NULL,
    track_artist TEXT NOT NULL,
    track_number INTEGER NOT NULL,
    disc_number INTEGER DEFAULT 1,
    duration_ms INTEGER NOT NULL,
    format TEXT NOT NULL,
    bit_depth INTEGER NOT NULL,
    sample_rate INTEGER NOT NULL,
    channels INTEGER NOT NULL,
    replaygain_track_gain REAL,
    replaygain_track_peak REAL,
    replaygain_album_gain REAL,
    replaygain_album_peak REAL,
    is_preferred INTEGER DEFAULT 1,
    FOREIGN KEY(album_id) REFERENCES albums(id)
);

CREATE TABLE play_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    track_id TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
    played_at INTEGER NOT NULL,
    duration_played_ms INTEGER NOT NULL,
    completed INTEGER NOT NULL
);

CREATE TABLE playlists (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

CREATE TABLE playlist_entries (
    playlist_id TEXT NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
    track_id TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
    position INTEGER NOT NULL,
    PRIMARY KEY(playlist_id, position)
);

CREATE INDEX idx_tracks_album ON tracks(album_id, disc_number, track_number);
CREATE INDEX idx_tracks_lookup ON tracks(title, track_artist);
CREATE INDEX idx_history_track ON play_history(track_id, played_at);
```

### 2. User Configuration: `~/.config/audioplayer/settings.json`
- Stores user-defined library roots, bit-perfect toggle states, theme name, audio device identifiers, and 10-band EQ configuration.
- Serialized atomically using temporary file swap.

### 3. Disposable Cache: `~/.cache/audioplayer/`
- Directory tree storing scaled album cover thumbnails, lyrics blobs, and online metadata response caches. Can be safely wiped at any time without database corruption.

---

## 7. UI Architecture & Theme Engine

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Tauri Frontend Application                      │
│                                                                        │
│  ┌───────────────────────┐  ┌───────────────────────────────────────┐  │
│  │   Navigation Pane     │  │       Album Browser / All Songs       │  │
│  │   - Albums (Grid)     │  │   (Virtualized Dynamic Grid / List)   │  │
│  │   - Playlists         │  │                                       │  │
│  │   - Settings          │  │   [Filter: Search] [Sort: Dopamine ▾] │  │
│  │   - Recommendations   │  └───────────────────────────────────────┘  │
│  └───────────────────────┘  ┌───────────────────────────────────────┐  │
│                             │       Now Playing Telemetry Bar       │  │
│                             │ [Track Title - Artist]                │  │
│                             │ FLAC · 24-bit · 96 kHz · hw:DAC · 0dB │  │
│                             └───────────────────────────────────────┘  │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │
                          Omarchy Theme Reader
                                     │
           ┌─────────────────────────┴─────────────────────────┐
           ▼                                                   ▼
┌──────────────────────────────┐              ┌──────────────────────────────┐
│  ~/.config/omarchy/theme/    │              │   Internal Palette Fallback  │
│  Reads colors, fonts, borders│              │  Gruvbox, Everforest, TokyoN │
└──────────────────────────────┘              └──────────────────────────────┘
```

### Principles & Features:
- **Neovim/Terminal Minimalist Design**:
  - High information density, crisp 1px borders, square edges, monospace tabular numbers for times and frequencies.
  - No bloated cover art reflections, zero gradients, no distracting blur filters.
- **Dynamic Omarchy Theme Sync**:
  - Reads active Omarchy configuration or system theme files directly.
  - Automatically maps hex palettes into reactive CSS variables (`--bg`, `--fg`, `--border`, `--accent`, `--status-pure`).
- **Throttled Telemetry Updates**:
  - Format badges and playback timers update via requestAnimationFrame / 100ms throttle to prevent UI bus contention.

---

## 8. Threading & Concurrency Model

```
Thread Name              Priority       Role / Constraints
──────────────────────────────────────────────────────────────────────────────────────
Main / UI Thread         Normal         Tauri webview event loop, user input handling
Core Dispatcher Thread   Normal         IPC router, coordinates commands between engines
Audio Decoder Thread     Above Normal   Decodes lossless files, pre-fills ring buffer
Audio Output Thread      Real-Time      Writes to ALSA PCM; lock-free, zero allocation
FS Watcher Thread        Low            Listens for inotify events, debounces file additions
Background Worker Pool   Low            Parallel directory scanning, SQLite batch writes
Metadata Network Pool    Low            Async HTTP requests (MusicBrainz, Discogs, iTunes)
```

- **Deadlock Avoidance**: Lock hierarchy is strictly ordered. `audio_engine` never takes locks on `library_index`. Communication is strictly message-based across bounded channels.

---

## 9. Error-Handling Strategy & Crash Recovery

| Subsystem | Failure Scenario | Detection | Recovery Action |
| :--- | :--- | :--- | :--- |
| **Audio** | Corrupt FLAC frame or unreadable file | Symphonia decode error `FormatError` | Immediately pop desktop notification; smoothly advance queue to next track without crashing output thread. |
| **Audio** | DAC unplugged mid-playback | ALSA write returns `-ENODEV` or `-EPIPE` | Stop stream; set UI state to Paused; notify user; fallback to default system audio sink. |
| **Audio** | Buffer underrun (XRUN) | ALSA `-EPIPE` | Invoke `snd_pcm_prepare()`; refill 2s pre-roll buffer before resuming stream. |
| **Library** | Inotify event queue saturation | `IN_Q_OVERFLOW` | Log warning; flag library dirty; trigger a low-priority full reconciliation pass. |
| **Database** | Sudden crash / power cutoff | SQLite recovery | WAL file ensures automatic roll-forward/rollback on startup; integrity check run on boot (`PRAGMA integrity_check`). |
| **Application** | Panic in background worker | Rust `std::panic::catch_unwind` | Isolate panic to the specific worker thread; restart thread pool; persist error details to `crash.log`. |

---

## 10. Testing Strategy

```
Level               Target & Tools                                 Coverage Goal
──────────────────────────────────────────────────────────────────────────────────
Unit Tests          Audio ring-buffers, decoders, tag parsers      $\ge 85\%$
                    Tools: `cargo test`, `rtrb`, `symphonia` mocks
Integration Tests   Full playback pipeline: Decode $\to$ RingBuf   $\ge 80\%$
                    $\to$ ALSA Loopback device (`snd-aloop`)
Database Tests      SQLite migrations, duplicate resolution,       $100\%$ schema
                    Dopamine Hits sorting calculations
UI / End-to-End     Tauri IPC commands, theme switching,          Core user journeys
                    virtualized list scrolling via `Playwright`
Fuzz Testing        Tag extraction on corrupted/malformed files    Zero unhandled
                    Tools: `cargo fuzz` on Lofty parser            panics
```

---

## 11. Packaging & Distribution Strategy

1. **Arch Linux (PKGBUILD / AUR)**:
   - Primary distribution mechanism. Native compilation against system `libasound.so.2`.
   - Desktop entry with proper audio categories (`AudioVideo;Audio;Player;`).
   - Permissions: Automatically installs udev rules or setcap documentation (`setcap cap_sys_nice+ep`) for unprivileged real-time thread priority.
2. **Universal Flatpak (`org.audioplayer.MusicPlayer`)**:
   - Sandboxed build with access to `--filesystem=host:ro` and `--socket=pulseaudio` / `--device=all` for direct ALSA device passthrough.
3. **Standalone AppImage**:
   - Self-contained binary bundling all shared dependencies for instant execution across any Linux distribution.

