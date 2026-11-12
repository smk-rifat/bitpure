use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use uuid::Uuid;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct TrackId(pub Uuid);

impl TrackId {
    pub fn new() -> Self {
        Self(Uuid::new_v4())
    }
}

impl Default for TrackId {
    fn default() -> Self {
        Self::new()
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct AlbumId(pub Uuid);

impl AlbumId {
    pub fn new() -> Self {
        Self(Uuid::new_v4())
    }
}

impl Default for AlbumId {
    fn default() -> Self {
        Self::new()
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct PlaylistId(pub Uuid);

impl PlaylistId {
    pub fn new() -> Self {
        Self(Uuid::new_v4())
    }
}

impl Default for PlaylistId {
    fn default() -> Self {
        Self::new()
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum AudioCodec {
    Flac,
    Alac,
    Wav,
    Aiff,
    Dsd,
    Dsf,
    Unknown,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum BitDepth {
    Bits16,
    Bits24,
    Bits32,
    Float32,
    Unknown,
}

impl BitDepth {
    pub fn as_u16(&self) -> u16 {
        match self {
            Self::Bits16 => 16,
            Self::Bits24 => 24,
            Self::Bits32 | Self::Float32 => 32,
            Self::Unknown => 0,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct AudioFormat {
    pub codec: AudioCodec,
    pub bit_depth: BitDepth,
    pub sample_rate: u32,
    pub channels: u16,
}

impl std::fmt::Display for AudioFormat {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{:?} | {} | {} Hz | {}ch",
            self.codec,
            match self.bit_depth {
                BitDepth::Bits16 => "16-bit",
                BitDepth::Bits24 => "24-bit",
                BitDepth::Bits32 => "32-bit",
                BitDepth::Float32 => "32-bit float",
                BitDepth::Unknown => "Unknown-bit",
            },
            self.sample_rate,
            self.channels
        )
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SignalPathInfo {
    pub source_format: AudioFormat,
    pub is_bit_perfect_pure: bool,
    pub active_dsp_description: Option<String>,
    pub output_device_name: String,
    pub negotiated_hardware_format: AudioFormat,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Track {
    pub id: TrackId,
    pub album_id: AlbumId,
    pub file_path: PathBuf,
    pub file_size: u64,
    pub title: String,
    pub track_artist: String,
    pub track_number: u32,
    pub disc_number: u32,
    pub duration_ms: u64,
    pub format: AudioFormat,
    pub replaygain_track_gain: Option<f32>,
    pub replaygain_track_peak: Option<f32>,
    pub replaygain_album_gain: Option<f32>,
    pub replaygain_album_peak: Option<f32>,
    pub is_preferred: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Album {
    pub id: AlbumId,
    pub title: String,
    pub album_artist: String,
    pub year: Option<u32>,
    pub genre: Option<String>,
    pub disc_count: u32,
    pub cover_art_path: Option<PathBuf>,
    pub track_count: usize,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum SortCriteria {
    AlphabeticalAsc,
    AlphabeticalDesc,
    Genre,
    SongType,
    FileSize,
    DateAdded,
    DopamineHits,
}

