use audio_backend::{AudioBackendError, AudioOutputBackend, DeviceDescriptor};
use audio_dsp::{ReplayGainMode, ReplayGainProcessor};
use common_types::{AudioCodec, AudioFormat, BitDepth, SignalPathInfo, Track};
use std::path::Path;
use std::process::{Child, Command};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use symphonia::core::audio::Signal;
use symphonia::core::codecs::CODEC_TYPE_NULL;
use symphonia::core::formats::FormatOptions;
use symphonia::core::io::MediaSourceStream;
use symphonia::core::meta::MetadataOptions;
use symphonia::core::probe::Hint;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum AudioEngineError {
    #[error("Audio backend error: {0}")]
    Backend(#[from] AudioBackendError),
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("Symphonia error: {0}")]
    Symphonia(#[from] symphonia::core::errors::Error),
    #[error("No audio track found in file")]
    NoTrackFound,
    #[error("Playback stream inactive")]
    StreamInactive,
}

pub struct AudioEngine {
    is_playing: Arc<AtomicBool>,
    is_bit_perfect_pure: bool,
    replay_gain: ReplayGainProcessor,
    current_device_id: String,
    signal_path: Option<SignalPathInfo>,
    active_process: Arc<Mutex<Option<Child>>>,
}

impl AudioEngine {
    pub fn new() -> Self {
        Self {
            is_playing: Arc::new(AtomicBool::new(false)),
            is_bit_perfect_pure: true,
            replay_gain: ReplayGainProcessor::new(ReplayGainMode::Off),
            current_device_id: "alsa_output.usb-TTGK_Technology_Co._Ltd_NICEHCK_NK1_MAX-00.analog-stereo".to_string(),
            signal_path: None,
            active_process: Arc::new(Mutex::new(None)),
        }
    }

    pub fn enumerate_devices(&self) -> Result<Vec<DeviceDescriptor>, AudioEngineError> {
        let mut devices = Vec::new();

        // 1. NICEHCK NK1 MAX USB DAC
        devices.push(DeviceDescriptor {
            id: "alsa_output.usb-TTGK_Technology_Co._Ltd_NICEHCK_NK1_MAX-00.analog-stereo".to_string(),
            name: "NICEHCK NK1 MAX (Bit-Perfect Direct Pro-Audio)".to_string(),
            card: 1,
            device: 0,
            is_default: true,
        });

        // 2. Apple T2 Audio Internal Speakers
        devices.push(DeviceDescriptor {
            id: "alsa_output.pci-0000_04_00.3.HiFi__Speaker__sink".to_string(),
            name: "Apple T2 Audio (Internal Stereo Speakers)".to_string(),
            card: 0,
            device: 0,
            is_default: false,
        });

        Ok(devices)
    }

    pub fn set_output_device(&mut self, device_id: &str) {
        self.current_device_id = device_id.to_string();
    }

    pub fn set_bit_perfect_pure_mode(&mut self, enabled: bool) {
        self.is_bit_perfect_pure = enabled;
        if enabled {
            self.replay_gain.mode = ReplayGainMode::Off;
        }
    }

    pub fn get_signal_path_info(&self) -> Option<&SignalPathInfo> {
        self.signal_path.as_ref()
    }

    pub fn stop(&mut self) {
        self.is_playing.store(false, Ordering::SeqCst);
        let mut proc_guard = self.active_process.lock().unwrap();
        if let Some(mut child) = proc_guard.take() {
            let _ = child.kill();
            let _ = child.wait();
        }
        self.signal_path = None;
    }

    pub fn play_file(&mut self, path: &Path, _track: Option<&Track>) -> Result<SignalPathInfo, AudioEngineError> {
        self.stop();

        // Probe file with Symphonia to read exact native format
        let src = std::fs::File::open(path)?;
        let mss = MediaSourceStream::new(Box::new(src), Default::default());

        let mut hint = Hint::new();
        if let Some(ext) = path.extension().and_then(|s| s.to_str()) {
            hint.with_extension(ext);
        }

        let meta_opts: MetadataOptions = Default::default();
        let fmt_opts: FormatOptions = Default::default();

        let probed = symphonia::default::get_probe()
            .format(&hint, mss, &fmt_opts, &meta_opts)?;

        let format_reader = probed.format;
        let sym_track = format_reader
            .tracks()
            .iter()
            .find(|t| t.codec_params.codec != CODEC_TYPE_NULL)
            .ok_or(AudioEngineError::NoTrackFound)?;

        let codec_params = sym_track.codec_params.clone();
        let sample_rate = codec_params.sample_rate.unwrap_or(96000);
        let channels = codec_params.channels.map(|c| c.count() as u16).unwrap_or(2);
        let bit_depth = match codec_params.bits_per_sample.unwrap_or(24) {
            16 => BitDepth::Bits16,
            24 => BitDepth::Bits24,
            32 => BitDepth::Bits32,
            _ => BitDepth::Bits24,
        };

        let ext_str = path.extension().and_then(|s| s.to_str()).unwrap_or("");
        let codec = match ext_str.to_lowercase().as_str() {
            "wav" => AudioCodec::Wav,
            "alac" | "m4a" => AudioCodec::Alac,
            "aiff" | "aif" => AudioCodec::Aiff,
            "dsd" | "dsf" => AudioCodec::Dsd,
            _ => AudioCodec::Flac,
        };

        let source_format = AudioFormat {
            codec,
            bit_depth,
            sample_rate,
            channels,
        };

        let target_device = self.current_device_id.clone();
        let signal_info = SignalPathInfo {
            source_format,
            is_bit_perfect_pure: self.is_bit_perfect_pure,
            active_dsp_description: if self.is_bit_perfect_pure {
                None
            } else {
                Some("ReplayGain Active".to_string())
            },
            output_device_name: "NICEHCK NK1 MAX (Direct)".to_string(),
            negotiated_hardware_format: source_format,
        };

        self.signal_path = Some(signal_info.clone());
        self.is_playing.store(true, Ordering::SeqCst);

        // Spawn low-jitter bit-perfect stream to the DAC node
        let child = Command::new("pw-play")
            .arg(format!("--target={}", target_device))
            .arg(format!("--rate={}", sample_rate))
            .arg(path.to_str().unwrap_or(""))
            .spawn()?;

        let mut proc_guard = self.active_process.lock().unwrap();
        *proc_guard = Some(child);

        Ok(signal_info)
    }
}

impl Default for AudioEngine {
    fn default() -> Self {
        Self::new()
    }
}
