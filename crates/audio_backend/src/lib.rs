use common_types::{AudioFormat, BitDepth};
use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Error, Debug)]
pub enum AudioBackendError {
    #[error("ALSA driver error: {0}")]
    Alsa(#[from] alsa::Error),
    #[error("Device not found: {0}")]
    DeviceNotFound(String),
    #[error("Exclusive lock acquisition failed: {0}")]
    ExclusiveLockFailed(String),
    #[error("Unsupported hardware format: {0}")]
    UnsupportedFormat(String),
    #[error("Buffer underrun (XRUN)")]
    BufferUnderrun,
    #[error("Stream inactive")]
    StreamInactive,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceDescriptor {
    pub id: String,
    pub name: String,
    pub card: i32,
    pub device: i32,
    pub is_default: bool,
}

pub trait AudioOutputBackend: Send {
    fn enumerate_devices(&self) -> Result<Vec<DeviceDescriptor>, AudioBackendError>;
    fn open_exclusive(&mut self, device_id: &str, format: AudioFormat) -> Result<AudioFormat, AudioBackendError>;
    fn write_interleaved_f32(&mut self, samples: &[f32]) -> Result<usize, AudioBackendError>;
    fn pause(&mut self) -> Result<(), AudioBackendError>;
    fn resume(&mut self) -> Result<(), AudioBackendError>;
    fn stop(&mut self) -> Result<(), AudioBackendError>;
}

pub struct AlsaDirectBackend {
    pcm: Option<alsa::PCM>,
    active_format: Option<AudioFormat>,
    channels: u16,
}

impl AlsaDirectBackend {
    pub fn new() -> Self {
        Self {
            pcm: None,
            active_format: None,
            channels: 2,
        }
    }
}

impl Default for AlsaDirectBackend {
    fn default() -> Self {
        Self::new()
    }
}

// In alsa-rs, PCM contains raw pointers and a Cell, but is thread-bound to the audio thread
unsafe impl Send for AlsaDirectBackend {}

impl AudioOutputBackend for AlsaDirectBackend {
    fn enumerate_devices(&self) -> Result<Vec<DeviceDescriptor>, AudioBackendError> {
        let mut devices = Vec::new();
        let mut card_idx = -1;

        while let Ok(Some(next_card)) = alsa::card::Iter::new().next().transpose() {
            let _ = next_card; // card iterator available
            break;
        }

        // Direct hardware card inspection via standard indexing (0..8)
        for c in 0..8 {
            let card = alsa::Card::new(c);
            if let Ok(card_name) = card.get_name() {
                let card_longname = card.get_longname().unwrap_or_else(|_| card_name.clone());

                let dev_id = format!("hw:{},0", c);
                let is_default = card_name.contains("MAX") || card_name.contains("USB") || c == 1;

                devices.push(DeviceDescriptor {
                    id: dev_id,
                    name: format!("{} ({})", card_name, card_longname),
                    card: c,
                    device: 0,
                    is_default,
                });
            }
        }

        Ok(devices)
    }

    fn open_exclusive(&mut self, device_id: &str, requested_format: AudioFormat) -> Result<AudioFormat, AudioBackendError> {
        let pcm = alsa::PCM::new(device_id, alsa::Direction::Playback, false)?;

        let alsa_fmt = match requested_format.bit_depth {
            BitDepth::Bits16 => alsa::pcm::Format::s16(),
            BitDepth::Bits24 => alsa::pcm::Format::s24(),
            BitDepth::Bits32 => alsa::pcm::Format::s32(),
            BitDepth::Float32 => alsa::pcm::Format::float(),
            BitDepth::Unknown => alsa::pcm::Format::s16(),
        };

        let mut actual_rate = requested_format.sample_rate;
        let mut actual_channels = requested_format.channels as u32;

        {
            let hwp = alsa::pcm::HwParams::any(&pcm)?;
            hwp.set_access(alsa::pcm::Access::RWInterleaved)?;

            if hwp.set_format(alsa_fmt).is_err() {
                // If requested hardware bit depth cannot be negotiated, fallback gracefully
                hwp.set_format(alsa::pcm::Format::float())
                    .or_else(|_| hwp.set_format(alsa::pcm::Format::s32()))
                    .or_else(|_| hwp.set_format(alsa::pcm::Format::s16()))?;
            }

            hwp.set_channels(actual_channels)?;
            hwp.set_rate_near(actual_rate, alsa::ValueOr::Nearest)?;

            let buffer_frames = (requested_format.sample_rate as i64) / 2; // ~500ms
            let period_frames = (requested_format.sample_rate as i64) / 16;
            let _ = hwp.set_buffer_size_near(buffer_frames);
            let _ = hwp.set_period_size_near(period_frames, alsa::ValueOr::Nearest);

            pcm.hw_params(&hwp)?;

            // Re-read actual parameters
            actual_rate = hwp.get_rate().unwrap_or(actual_rate);
            actual_channels = hwp.get_channels().unwrap_or(actual_channels);
        }

        let verified_format = AudioFormat {
            codec: requested_format.codec,
            bit_depth: requested_format.bit_depth,
            sample_rate: actual_rate,
            channels: actual_channels as u16,
        };

        self.pcm = Some(pcm);
        self.active_format = Some(verified_format);
        self.channels = verified_format.channels;

        Ok(verified_format)
    }

    fn write_interleaved_f32(&mut self, samples: &[f32]) -> Result<usize, AudioBackendError> {
        let pcm = self.pcm.as_ref().ok_or(AudioBackendError::StreamInactive)?;
        let io = pcm.io_f32()?;

        match io.writei(samples) {
            Ok(frames) => Ok(frames),
            Err(e) => {
                // 32 is EPIPE in Linux (underrun)
                if e.errno() == 32 {
                    let _ = pcm.prepare();
                    Ok(0)
                } else {
                    Err(AudioBackendError::Alsa(e))
                }
            }
        }
    }

    fn pause(&mut self) -> Result<(), AudioBackendError> {
        if let Some(pcm) = self.pcm.as_ref() {
            pcm.pause(true)?;
        }
        Ok(())
    }

    fn resume(&mut self) -> Result<(), AudioBackendError> {
        if let Some(pcm) = self.pcm.as_ref() {
            pcm.pause(false)?;
        }
        Ok(())
    }

    fn stop(&mut self) -> Result<(), AudioBackendError> {
        if let Some(pcm) = self.pcm.take() {
            let _ = pcm.drop();
        }
        self.active_format = None;
        Ok(())
    }
}
