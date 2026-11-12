use lofty::file::{AudioFile, TaggedFileExt};
use lofty::probe::Probe;
use lofty::tag::Accessor;
use serde::{Deserialize, Serialize};
use std::path::Path;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum MetadataError {
    #[error("Lofty tag inspection error: {0}")]
    Lofty(#[from] lofty::error::LoftyError),
    #[error("Network query failed: {0}")]
    Network(#[from] reqwest::Error),
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParsedTrackMetadata {
    pub title: String,
    pub artist: String,
    pub album: String,
    pub year: Option<u32>,
    pub track_number: Option<u32>,
    pub disc_number: Option<u32>,
    pub genre: Option<String>,
    pub duration_ms: u64,
    pub bit_depth: Option<u8>,
    pub sample_rate: Option<u32>,
    pub channels: Option<u8>,
    pub has_embedded_cover: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExternalRecommendation {
    pub title: String,
    pub artist: String,
    pub release_title: String,
    pub info_url: String,
}

pub struct MetadataInspector;

impl MetadataInspector {
    pub fn parse_file<P: AsRef<Path>>(path: P) -> Result<ParsedTrackMetadata, MetadataError> {
        let tagged_file = Probe::open(path.as_ref())?.read()?;
        let properties = tagged_file.properties();

        let tag = tagged_file.primary_tag().or_else(|| tagged_file.first_tag());

        let title = tag
            .and_then(|t| t.title().map(|s| s.to_string()))
            .unwrap_or_else(|| {
                path.as_ref()
                    .file_stem()
                    .map(|s| s.to_string_lossy().to_string())
                    .unwrap_or_else(|| "Unknown Title".to_string())
            });

        let artist = tag
            .and_then(|t| t.artist().map(|s| s.to_string()))
            .unwrap_or_else(|| "Unknown Artist".to_string());

        let album = tag
            .and_then(|t| t.album().map(|s| s.to_string()))
            .unwrap_or_else(|| {
                path.as_ref()
                    .parent()
                    .and_then(|p| p.file_name())
                    .map(|s| s.to_string_lossy().to_string())
                    .unwrap_or_else(|| "Unknown Album".to_string())
            });

        let year = tag.and_then(|t| t.year());
        let track_number = tag.and_then(|t| t.track());
        let disc_number = tag.and_then(|t| t.disk());
        let genre = tag.and_then(|t| t.genre().map(|s| s.to_string()));

        let has_embedded_cover = tag.map(|t| !t.pictures().is_empty()).unwrap_or(false);
        let duration_ms = properties.duration().as_millis() as u64;

        Ok(ParsedTrackMetadata {
            title,
            artist,
            album,
            year,
            track_number,
            disc_number,
            genre,
            duration_ms,
            bit_depth: properties.bit_depth(),
            sample_rate: properties.sample_rate(),
            channels: properties.channels(),
            has_embedded_cover,
        })
    }

    /// Query external public recommendations (ListenBrainz / MusicBrainz fallback)
    pub async fn fetch_recommendations(artist: &str) -> Vec<ExternalRecommendation> {
        let mut recs = Vec::new();
        let client = reqwest::Client::builder()
            .user_agent("AudiophileMusicPlayer/0.1.0")
            .timeout(std::time::Duration::from_secs(3))
            .build();

        if let Ok(client) = client {
            let url = format!(
                "https://musicbrainz.org/ws/2/release?query=artist:{}&fmt=json&limit=5",
                urlencoding::encode(artist)
            );

            if let Ok(resp) = client.get(&url).send().await {
                if let Ok(json) = resp.json::<serde_json::Value>().await {
                    if let Some(releases) = json.get("releases").and_then(|r| r.as_array()) {
                        for rel in releases.iter().take(5) {
                            let title = rel["title"].as_str().unwrap_or("Featured Track").to_string();
                            let rel_id = rel["id"].as_str().unwrap_or("");
                            recs.push(ExternalRecommendation {
                                title: format!("Featured: {}", title),
                                artist: artist.to_string(),
                                release_title: title,
                                info_url: format!("https://musicbrainz.org/release/{}", rel_id),
                            });
                        }
                    }
                }
            }
        }

        if recs.is_empty() {
            // High-fidelity fallback recommendations
            recs.push(ExternalRecommendation {
                title: "Kind of Blue (Master Edition)".to_string(),
                artist: "Miles Davis".to_string(),
                release_title: "Kind of Blue".to_string(),
                info_url: "https://musicbrainz.org/release/b8b4b248-183d-4952-b7b5-2d93e157790b".to_string(),
            });
            recs.push(ExternalRecommendation {
                title: "A Love Supreme (Acoustic Master)".to_string(),
                artist: "John Coltrane".to_string(),
                release_title: "A Love Supreme".to_string(),
                info_url: "https://musicbrainz.org/release/55d94726-0e31-4091-a129-873d6b0a8f89".to_string(),
            });
        }

        recs
    }
}
