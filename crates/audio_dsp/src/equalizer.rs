use std::f32::consts::PI;

pub const EQ_FREQUENCIES: [f32; 10] = [
    31.25, 62.5, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0,
];

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum EqPreset {
    Flat,
    Balanced,
    BassBoost,
    BassReduced,
    TrebleReduced,
    Neutral,
    SmoothWarmNeutral,
}

#[derive(Debug, Clone)]
pub struct BiquadFilter {
    b0: f32,
    b1: f32,
    b2: f32,
    a1: f32,
    a2: f32,
    // Per-channel state memory (up to 2 channels stereo)
    x1: [f32; 2],
    x2: [f32; 2],
    y1: [f32; 2],
    y2: [f32; 2],
}

impl BiquadFilter {
    pub fn new_peaking_eq(sample_rate: f32, freq: f32, q: f32, gain_db: f32) -> Self {
        if gain_db.abs() < 1e-4 {
            return Self::identity();
        }

        let a = 10.0_f32.powf(gain_db / 40.0);
        let w0 = 2.0 * PI * (freq / sample_rate).min(0.49);
        let alpha = w0.sin() / (2.0 * q);
        let cos_w0 = w0.cos();

        let b0 = 1.0 + alpha * a;
        let b1 = -2.0 * cos_w0;
        let b2 = 1.0 - alpha * a;
        let a0 = 1.0 + alpha / a;
        let a1 = -2.0 * cos_w0;
        let a2 = 1.0 - alpha / a;

        Self {
            b0: b0 / a0,
            b1: b1 / a0,
            b2: b2 / a0,
            a1: a1 / a0,
            a2: a2 / a0,
            x1: [0.0; 2],
            x2: [0.0; 2],
            y1: [0.0; 2],
            y2: [0.0; 2],
        }
    }

    pub fn identity() -> Self {
        Self {
            b0: 1.0,
            b1: 0.0,
            b2: 0.0,
            a1: 0.0,
            a2: 0.0,
            x1: [0.0; 2],
            x2: [0.0; 2],
            y1: [0.0; 2],
            y2: [0.0; 2],
        }
    }

    #[inline]
    pub fn process_sample(&mut self, ch: usize, x: f32) -> f32 {
        let ch_idx = ch % 2;
        let y = self.b0 * x + self.b1 * self.x1[ch_idx] + self.b2 * self.x2[ch_idx]
            - self.a1 * self.y1[ch_idx]
            - self.a2 * self.y2[ch_idx];

        self.x2[ch_idx] = self.x1[ch_idx];
        self.x1[ch_idx] = x;
        self.y2[ch_idx] = self.y1[ch_idx];
        self.y1[ch_idx] = y;

        y
    }
}

pub struct GraphicEqualizer {
    pub enabled: bool,
    pub gains_db: [f32; 10],
    filters: Vec<BiquadFilter>,
    sample_rate: f32,
}

impl GraphicEqualizer {
    pub fn new(sample_rate: f32) -> Self {
        let gains_db = [0.0; 10];
        let mut eq = Self {
            enabled: false,
            gains_db,
            filters: Vec::new(),
            sample_rate,
        };
        eq.recalculate();
        eq
    }

    pub fn set_preset(&mut self, preset: EqPreset) {
        self.gains_db = match preset {
            EqPreset::Flat => [0.0; 10],
            EqPreset::Balanced => [1.5, 1.0, 0.5, 0.0, 0.0, 0.5, 1.0, 1.5, 2.0, 1.5],
            EqPreset::BassBoost => [5.0, 4.0, 3.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
            EqPreset::BassReduced => [-4.0, -3.5, -2.5, -1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
            EqPreset::TrebleReduced => [0.0, 0.0, 0.0, 0.0, 0.0, -1.0, -2.0, -3.0, -4.0, -5.0],
            EqPreset::Neutral => [0.0; 10],
            EqPreset::SmoothWarmNeutral => [2.0, 1.8, 1.2, 0.5, 0.0, -0.5, -0.8, -1.0, -1.5, -2.0],
        };
        self.enabled = preset != EqPreset::Flat && preset != EqPreset::Neutral;
        self.recalculate();
    }

    pub fn set_band_gain(&mut self, band: usize, db: f32) {
        if band < 10 {
            self.gains_db[band] = db.clamp(-12.0, 12.0);
            self.recalculate();
        }
    }

    pub fn recalculate(&mut self) {
        self.filters.clear();
        for (i, &freq) in EQ_FREQUENCIES.iter().enumerate() {
            let gain = self.gains_db[i];
            let filter = BiquadFilter::new_peaking_eq(self.sample_rate, freq, 1.414, gain);
            self.filters.push(filter);
        }
    }

    pub fn process_interleaved(&mut self, samples: &mut [f32], channels: usize) {
        if !self.enabled {
            return;
        }

        for (i, sample) in samples.iter_mut().enumerate() {
            let ch = i % channels;
            let mut s = *sample;
            for filter in self.filters.iter_mut() {
                s = filter.process_sample(ch, s);
            }
            *sample = s;
        }
    }
}

