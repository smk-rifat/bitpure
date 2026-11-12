use audio_backend::{AlsaDirectBackend, AudioOutputBackend, DeviceDescriptor};
use audio_dsp::{EqPreset, GraphicEqualizer, ReplayGainMode, ReplayGainProcessor};
use audio_engine::AudioEngine;
use common_types::{Album, AlbumId, AudioCodec, AudioFormat, BitDepth, SignalPathInfo, SortCriteria, Track, TrackId};
use library_index::SqliteLibrary;
use metadata_svc::{ExternalRecommendation, MetadataInspector};
use notify::{Config, Event, RecommendedWatcher, RecursiveMode, Watcher};
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::channel;
use std::sync::{Arc, Mutex};
use std::thread;

static APP_STATE: Mutex<Option<AppInstance>> = Mutex::new(None);

struct AppInstance {
    engine: AudioEngine,
    library: SqliteLibrary,
    equalizer: GraphicEqualizer,
    current_signal_path: Option<SignalPathInfo>,
    active_roots: Vec<PathBuf>,
    watcher_stop_flag: Arc<AtomicBool>,
}

#[no_mangle]
pub extern "C" fn audioplayer_init(db_path: *const c_char) -> i32 {
    let path_str = if db_path.is_null() {
        let home = std::env::var("HOME").unwrap_or_else(|_| "/home/smk".to_string());
        format!("{}/.local/share/audioplayer/library.db", home)
    } else {
        unsafe { CStr::from_ptr(db_path).to_string_lossy().to_string() }
    };

    if let Some(parent) = Path::new(&path_str).parent() {
        let _ = std::fs::create_dir_all(parent);
    }

    let library = match SqliteLibrary::new(&path_str) {
        Ok(lib) => lib,
        Err(_) => match SqliteLibrary::in_memory() {
            Ok(lib) => lib,
            Err(_) => return -1,
        },
    };

    let engine = AudioEngine::new();
    let equalizer = GraphicEqualizer::new(96000.0);

    let mut state = APP_STATE.lock().unwrap();
    *state = Some(AppInstance {
        engine,
        library,
        equalizer,
        current_signal_path: None,
        active_roots: Vec::new(),
        watcher_stop_flag: Arc::new(AtomicBool::new(false)),
    });

    0
}

#[no_mangle]
pub extern "C" fn audioplayer_get_devices_json() -> *mut c_char {
    let state = APP_STATE.lock().unwrap();
    if let Some(inst) = state.as_ref() {
        if let Ok(devs) = inst.engine.enumerate_devices() {
            let json = serde_json::to_string(&devs).unwrap_or_else(|_| "[]".to_string());
            return CString::new(json).unwrap().into_raw();
        }
    }
    CString::new("[]").unwrap().into_raw()
}

#[no_mangle]
pub extern "C" fn audioplayer_set_device(dev_id: *const c_char) {
    if dev_id.is_null() {
        return;
    }
    let id_str = unsafe { CStr::from_ptr(dev_id).to_string_lossy().to_string() };
    let mut state = APP_STATE.lock().unwrap();
    if let Some(inst) = state.as_mut() {
        inst.engine.set_output_device(&id_str);
    }
}

#[no_mangle]
pub extern "C" fn audioplayer_set_bit_perfect(enabled: i32) {
    let mut state = APP_STATE.lock().unwrap();
    if let Some(inst) = state.as_mut() {
        inst.engine.set_bit_perfect_pure_mode(enabled != 0);
        inst.equalizer.enabled = enabled == 0;
    }
}

#[no_mangle]
pub extern "C" fn audioplayer_set_eq_preset(preset_idx: i32) {
    let preset = match preset_idx {
        0 => EqPreset::Flat,
        1 => EqPreset::Balanced,
        2 => EqPreset::BassBoost,
        3 => EqPreset::BassReduced,
        4 => EqPreset::TrebleReduced,
        5 => EqPreset::Neutral,
        6 => EqPreset::SmoothWarmNeutral,
        _ => EqPreset::Flat,
    };

    let mut state = APP_STATE.lock().unwrap();
    if let Some(inst) = state.as_mut() {
        inst.equalizer.set_preset(preset);
    }
}

#[no_mangle]
pub extern "C" fn audioplayer_set_eq_band(band: i32, gain_db: f32) {
    let mut state = APP_STATE.lock().unwrap();
    if let Some(inst) = state.as_mut() {
        inst.equalizer.set_band_gain(band as usize, gain_db);
    }
}

#[no_mangle]
pub extern "C" fn audioplayer_play_file(path: *const c_char) -> *mut c_char {
    if path.is_null() {
        return std::ptr::null_mut();
    }
    let path_str = unsafe { CStr::from_ptr(path).to_string_lossy().to_string() };
    let p = PathBuf::from(path_str);

    let mut state = APP_STATE.lock().unwrap();
    if let Some(inst) = state.as_mut() {
        match inst.engine.play_file(&p, None) {
            Ok(sig) => {
                inst.current_signal_path = Some(sig.clone());
                let json = serde_json::to_string(&sig).unwrap_or_else(|_| "{}".to_string());
                return CString::new(json).unwrap().into_raw();
            }
            Err(e) => {
                let err_json = format!("{{\"error\": \"{}\"}}", e);
                return CString::new(err_json).unwrap().into_raw();
            }
        }
    }
    std::ptr::null_mut()
}

#[no_mangle]
pub extern "C" fn audioplayer_stop() {
    let mut state = APP_STATE.lock().unwrap();
    if let Some(inst) = state.as_mut() {
        inst.engine.stop();
        inst.current_signal_path = None;
    }
}

#[no_mangle]
pub extern "C" fn audioplayer_scan_directory(dir_path: *const c_char) -> i32 {
    if dir_path.is_null() {
        return -1;
    }
    let path_str = unsafe { CStr::from_ptr(dir_path).to_string_lossy().to_string() };
    let root = PathBuf::from(path_str);
    if !root.exists() {
        return -1;
    }

    let mut count = 0;
    let state = APP_STATE.lock().unwrap();
    if let Some(inst) = state.as_ref() {
        for entry in walkdir::WalkDir::new(&root).into_iter().filter_map(|e| e.ok()) {
            let p = entry.path();
            if let Some(ext) = p.extension().and_then(|s| s.to_str()) {
                let ext_l = ext.to_lowercase();
                if ext_l == "flac" || ext_l == "wav" || ext_l == "alac" || ext_l == "aiff" {
                    let file_size = entry.metadata().map(|m| m.len()).unwrap_or(0);

                    // Extract actual high-fidelity metadata using Lofty
                    let (title, artist, album_title, year, genre, s_rate, b_depth, ch, dur) =
                        if let Ok(meta) = MetadataInspector::parse_file(p) {
                            (
                                meta.title,
                                meta.artist,
                                meta.album,
                                meta.year,
                                meta.genre,
                                meta.sample_rate.unwrap_or(96000),
                                meta.bit_depth.unwrap_or(24),
                                meta.channels.unwrap_or(2),
                                meta.duration_ms,
                            )
                        } else {
                            (
                                p.file_stem().map(|s| s.to_string_lossy().to_string()).unwrap_or_else(|| "Unknown".to_string()),
                                "Audiophile Artist".to_string(),
                                "Lossless Album".to_string(),
                                None,
                                Some("Hi-Res Audio".to_string()),
                                96000,
                                24,
                                2,
                                180000,
                            )
                        };

                    let album_id = inst
                        .library
                        .find_or_create_album(&album_title, &artist, year, genre)
                        .unwrap_or_else(|_| AlbumId::new());

                    let track = Track {
                        id: TrackId::new(),
                        album_id,
                        file_path: p.to_path_buf(),
                        file_size,
                        title,
                        track_artist: artist,
                        track_number: count + 1,
                        disc_number: 1,
                        duration_ms: dur,
                        format: AudioFormat {
                            codec: match ext_l.as_str() {
                                "flac" => AudioCodec::Flac,
                                "wav" => AudioCodec::Wav,
                                "alac" => AudioCodec::Alac,
                                "aiff" => AudioCodec::Aiff,
                                _ => AudioCodec::Flac,
                            },
                            bit_depth: match b_depth {
                                16 => BitDepth::Bits16,
                                24 => BitDepth::Bits24,
                                32 => BitDepth::Bits32,
                                _ => BitDepth::Bits24,
                            },
                            sample_rate: s_rate,
                            channels: ch as u16,
                        },
                        replaygain_track_gain: None,
                        replaygain_track_peak: None,
                        replaygain_album_gain: None,
                        replaygain_album_peak: None,
                        is_preferred: true,
                    };
                    let _ = inst.library.upsert_track(&track);
                    count += 1;
                }
            }
        }
    }
    count as i32
}

#[no_mangle]
pub extern "C" fn audioplayer_watch_directory(dir_path: *const c_char) -> i32 {
    if dir_path.is_null() {
        return -1;
    }
    let path_str = unsafe { CStr::from_ptr(dir_path).to_string_lossy().to_string() };
    let root = PathBuf::from(path_str);
    if !root.exists() {
        return -1;
    }

    let mut state = APP_STATE.lock().unwrap();
    if let Some(inst) = state.as_mut() {
        inst.active_roots.push(root.clone());
        let root_clone = root.clone();

        thread::spawn(move || {
            let (tx, rx) = channel();
            if let Ok(mut watcher) = RecommendedWatcher::new(tx, Config::default()) {
                if watcher.watch(&root_clone, RecursiveMode::Recursive).is_ok() {
                    while let Ok(res) = rx.recv() {
                        if let Ok(event) = res {
                            if event.kind.is_create() || event.kind.is_modify() {
                                for path in event.paths {
                                    let c_path = CString::new(path.to_string_lossy().to_string()).unwrap();
                                    audioplayer_scan_directory(c_path.as_ptr());
                                }
                            }
                        }
                    }
                }
            }
        });
    }
    0
}

#[no_mangle]
pub extern "C" fn audioplayer_get_albums_json(sort_type: i32) -> *mut c_char {
    let sort = match sort_type {
        0 => SortCriteria::AlphabeticalAsc,
        1 => SortCriteria::AlphabeticalDesc,
        2 => SortCriteria::Genre,
        _ => SortCriteria::AlphabeticalAsc,
    };

    let state = APP_STATE.lock().unwrap();
    if let Some(inst) = state.as_ref() {
        if let Ok(albums) = inst.library.list_albums(sort) {
            let json = serde_json::to_string(&albums).unwrap_or_else(|_| "[]".to_string());
            return CString::new(json).unwrap().into_raw();
        }
    }
    CString::new("[]").unwrap().into_raw()
}

#[no_mangle]
pub extern "C" fn audioplayer_get_tracks_json(sort_type: i32) -> *mut c_char {
    let sort = match sort_type {
        0 => SortCriteria::AlphabeticalAsc,
        1 => SortCriteria::AlphabeticalDesc,
        2 => SortCriteria::Genre,
        3 => SortCriteria::SongType,
        4 => SortCriteria::FileSize,
        5 => SortCriteria::DateAdded,
        6 => SortCriteria::DopamineHits,
        _ => SortCriteria::AlphabeticalAsc,
    };

    let state = APP_STATE.lock().unwrap();
    if let Some(inst) = state.as_ref() {
        if let Ok(tracks) = inst.library.list_tracks(sort) {
            let json = serde_json::to_string(&tracks).unwrap_or_else(|_| "[]".to_string());
            return CString::new(json).unwrap().into_raw();
        }
    }
    CString::new("[]").unwrap().into_raw()
}

#[no_mangle]
pub extern "C" fn audioplayer_get_recommendations_json(artist: *const c_char) -> *mut c_char {
    let artist_str = if artist.is_null() {
        "Miles Davis".to_string()
    } else {
        unsafe { CStr::from_ptr(artist).to_string_lossy().to_string() }
    };

    let rt = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .unwrap();

    let recs = rt.block_on(MetadataInspector::fetch_recommendations(&artist_str));
    let json = serde_json::to_string(&recs).unwrap_or_else(|_| "[]".to_string());
    CString::new(json).unwrap().into_raw()
}

#[no_mangle]
pub extern "C" fn audioplayer_free_string(s: *mut c_char) {
    if !s.is_null() {
        unsafe {
            let _ = CString::from_raw(s);
        }
    }
}
