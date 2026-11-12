pub mod equalizer;
pub use equalizer::{EqPreset, GraphicEqualizer, EQ_FREQUENCIES};

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ReplayGainMode {
    Off,
    Track,
    Album,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ReplayGainProcessor {
    pub mode: ReplayGainMode,
    pub preamp_db: f32,
}

impl ReplayGainProcessor {
    pub fn new(mode: ReplayGainMode) -> Self {
        Self {
            mode,
            preamp_db: 0.0,
        }
    }

    /// Calculate linear gain factor from decibels: 10^(dB / 20)
    #[inline]
    pub fn db_to_linear(db: f32) -> f32 {
        10.0_f32.powf(db / 20.0)
    }

    /// Apply gain to interleaved float PCM samples in-place
    pub fn apply_gain(
        &self,
        samples: &mut [f32],
        track_gain: Option<f32>,
        album_gain: Option<f32>,
    ) {
        let selected_gain = match self.mode {
            ReplayGainMode::Off => return,
            ReplayGainMode::Track => track_gain.unwrap_or(0.0),
            ReplayGainMode::Album => album_gain.or(track_gain).unwrap_or(0.0),
        };

        let total_gain = Self::db_to_linear(selected_gain + self.preamp_db);
        if (total_gain - 1.0).abs() < 1e-5 {
            return;
        }

        for sample in samples.iter_mut() {
            *sample *= total_gain;
        }
    }
}

