use common_types::{Album, AlbumId, AudioCodec, AudioFormat, BitDepth, SortCriteria, Track, TrackId};
use rusqlite::{params, Connection};
use std::path::{Path, PathBuf};
use thiserror::Error;
use uuid::Uuid;

#[derive(Error, Debug)]
pub enum LibraryError {
    #[error("Database error: {0}")]
    Database(#[from] rusqlite::Error),
    #[error("Filesystem IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("Metadata parse error: {0}")]
    Metadata(String),
}

pub struct SqliteLibrary {
    conn: Connection,
}

impl SqliteLibrary {
    pub fn new<P: AsRef<Path>>(db_path: P) -> Result<Self, LibraryError> {
        let conn = Connection::open(db_path)?;
        let lib = Self { conn };
        lib.initialize_schema()?;
        Ok(lib)
    }

    pub fn in_memory() -> Result<Self, LibraryError> {
        let conn = Connection::open_in_memory()?;
        let lib = Self { conn };
        lib.initialize_schema()?;
        Ok(lib)
    }

    pub fn initialize_schema(&self) -> Result<(), LibraryError> {
        self.conn.execute_batch(
            "
            PRAGMA journal_mode = WAL;
            PRAGMA synchronous = NORMAL;

            CREATE TABLE IF NOT EXISTS albums (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                album_artist TEXT NOT NULL,
                year INTEGER,
                genre TEXT,
                disc_count INTEGER DEFAULT 1,
                cover_art_path TEXT,
                track_count INTEGER DEFAULT 0
            );

            CREATE TABLE IF NOT EXISTS tracks (
                id TEXT PRIMARY KEY,
                album_id TEXT NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
                file_path TEXT UNIQUE NOT NULL,
                file_size INTEGER NOT NULL,
                title TEXT NOT NULL,
                track_artist TEXT NOT NULL,
                track_number INTEGER NOT NULL,
                disc_number INTEGER DEFAULT 1,
                duration_ms INTEGER NOT NULL,
                codec TEXT NOT NULL,
                bit_depth INTEGER NOT NULL,
                sample_rate INTEGER NOT NULL,
                channels INTEGER NOT NULL,
                replaygain_track_gain REAL,
                replaygain_track_peak REAL,
                replaygain_album_gain REAL,
                replaygain_album_peak REAL,
                is_preferred INTEGER DEFAULT 1,
                play_count INTEGER DEFAULT 0,
                last_played_at INTEGER DEFAULT 0,
                added_at INTEGER NOT NULL
            );

            CREATE TABLE IF NOT EXISTS playlists (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                created_at INTEGER NOT NULL
            );

            CREATE TABLE IF NOT EXISTS playlist_entries (
                playlist_id TEXT NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
                track_id TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
                position INTEGER NOT NULL,
                PRIMARY KEY(playlist_id, position)
            );

            CREATE INDEX IF NOT EXISTS idx_tracks_album ON tracks(album_id, disc_number, track_number);
            CREATE INDEX IF NOT EXISTS idx_tracks_title ON tracks(title);
            CREATE INDEX IF NOT EXISTS idx_tracks_artist ON tracks(track_artist);
            CREATE INDEX IF NOT EXISTS idx_tracks_play_count ON tracks(play_count, last_played_at);
            "
        )?;
        Ok(())
    }

    pub fn upsert_album(&self, album: &Album) -> Result<(), LibraryError> {
        self.conn.execute(
            "INSERT INTO albums (id, title, album_artist, year, genre, disc_count, cover_art_path, track_count)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
             ON CONFLICT(id) DO UPDATE SET
                title=excluded.title,
                album_artist=excluded.album_artist,
                year=excluded.year,
                genre=excluded.genre,
                disc_count=excluded.disc_count,
                cover_art_path=excluded.cover_art_path,
                track_count=excluded.track_count",
            params![
                album.id.0.to_string(),
                album.title,
                album.album_artist,
                album.year,
                album.genre,
                album.disc_count,
                album.cover_art_path.as_ref().map(|p| p.to_string_lossy().to_string()),
                album.track_count as i64,
            ],
        )?;
        Ok(())
    }

    pub fn find_or_create_album(
        &self,
        title: &str,
        artist: &str,
        year: Option<u32>,
        genre: Option<String>,
    ) -> Result<AlbumId, LibraryError> {
        let mut stmt = self.conn.prepare("SELECT id, track_count FROM albums WHERE title = ?1 AND album_artist = ?2")?;
        let mut rows = stmt.query(params![title, artist])?;
        if let Some(row) = rows.next()? {
            let id_str: String = row.get(0)?;
            let count: i64 = row.get(1)?;
            let id = AlbumId(Uuid::parse_str(&id_str).unwrap_or_else(|_| Uuid::new_v4()));
            let _ = self.conn.execute("UPDATE albums SET track_count = ?1 WHERE id = ?2", params![count + 1, id_str]);
            return Ok(id);
        }

        let new_id = AlbumId::new();
        let album = Album {
            id: new_id,
            title: title.to_string(),
            album_artist: artist.to_string(),
            year,
            genre,
            disc_count: 1,
            cover_art_path: None,
            track_count: 1,
        };
        self.upsert_album(&album)?;
        Ok(new_id)
    }

    pub fn upsert_track(&self, track: &Track) -> Result<(), LibraryError> {
        let codec_str = format!("{:?}", track.format.codec);
        let bit_depth_val = track.format.bit_depth.as_u16();
        let now = chrono::Utc::now().timestamp();

        self.conn.execute(
            "INSERT INTO tracks (
                id, album_id, file_path, file_size, title, track_artist,
                track_number, disc_number, duration_ms, codec, bit_depth,
                sample_rate, channels, replaygain_track_gain, replaygain_track_peak,
                replaygain_album_gain, replaygain_album_peak, is_preferred, added_at
             ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19)
             ON CONFLICT(file_path) DO UPDATE SET
                title=excluded.title,
                track_artist=excluded.track_artist,
                track_number=excluded.track_number,
                disc_number=excluded.disc_number,
                duration_ms=excluded.duration_ms,
                codec=excluded.codec,
                bit_depth=excluded.bit_depth,
                sample_rate=excluded.sample_rate,
                channels=excluded.channels,
                replaygain_track_gain=excluded.replaygain_track_gain,
                replaygain_album_gain=excluded.replaygain_album_gain,
                is_preferred=excluded.is_preferred",
            params![
                track.id.0.to_string(),
                track.album_id.0.to_string(),
                track.file_path.to_string_lossy().to_string(),
                track.file_size as i64,
                track.title,
                track.track_artist,
                track.track_number as i64,
                track.disc_number as i64,
                track.duration_ms as i64,
                codec_str,
                bit_depth_val,
                track.format.sample_rate as i64,
                track.format.channels as i64,
                track.replaygain_track_gain,
                track.replaygain_track_peak,
                track.replaygain_album_gain,
                track.replaygain_album_peak,
                if track.is_preferred { 1 } else { 0 },
                now
            ],
        )?;
        Ok(())
    }

    pub fn record_play_event(&self, track_id: TrackId) -> Result<(), LibraryError> {
        let now = chrono::Utc::now().timestamp();
        self.conn.execute(
            "UPDATE tracks SET play_count = play_count + 1, last_played_at = ?1 WHERE id = ?2",
            params![now, track_id.0.to_string()],
        )?;
        Ok(())
    }

    pub fn list_albums(&self, sort: SortCriteria) -> Result<Vec<Album>, LibraryError> {
        let order_clause = match sort {
            SortCriteria::AlphabeticalAsc => "ORDER BY title ASC",
            SortCriteria::AlphabeticalDesc => "ORDER BY title DESC",
            SortCriteria::Genre => "ORDER BY genre ASC, title ASC",
            _ => "ORDER BY title ASC",
        };

        let sql = format!("SELECT id, title, album_artist, year, genre, disc_count, cover_art_path, track_count FROM albums {}", order_clause);
        let mut stmt = self.conn.prepare(&sql)?;

        let rows = stmt.query_map([], |row| {
            let id_str: String = row.get(0)?;
            let cover_str: Option<String> = row.get(6)?;
            let t_count: i64 = row.get(7)?;

            Ok(Album {
                id: AlbumId(Uuid::parse_str(&id_str).unwrap_or_else(|_| Uuid::new_v4())),
                title: row.get(1)?,
                album_artist: row.get(2)?,
                year: row.get(3)?,
                genre: row.get(4)?,
                disc_count: row.get::<_, i64>(5)? as u32,
                cover_art_path: cover_str.map(PathBuf::from),
                track_count: t_count as usize,
            })
        })?;

        let mut albums = Vec::new();
        for r in rows {
            albums.push(r?);
        }
        Ok(albums)
    }

    pub fn list_tracks(&self, sort: SortCriteria) -> Result<Vec<Track>, LibraryError> {
        let now = chrono::Utc::now().timestamp();
        let order_clause = match sort {
            SortCriteria::AlphabeticalAsc => "ORDER BY title ASC",
            SortCriteria::AlphabeticalDesc => "ORDER BY title DESC",
            SortCriteria::Genre => "ORDER BY album_id, disc_number, track_number",
            SortCriteria::SongType => "ORDER BY codec ASC, sample_rate DESC",
            SortCriteria::FileSize => "ORDER BY file_size DESC",
            SortCriteria::DateAdded => "ORDER BY added_at DESC",
            SortCriteria::DopamineHits => {
                // Dopamine Hits scoring: play_count * 100 + recency bonus
                "ORDER BY (play_count * 100 + (100000.0 / ((?1 - last_played_at) / 3600 + 1.0))) DESC"
            }
        };

        let sql = format!(
            "SELECT id, album_id, file_path, file_size, title, track_artist, track_number,
                    disc_number, duration_ms, codec, bit_depth, sample_rate, channels,
                    replaygain_track_gain, replaygain_track_peak, replaygain_album_gain,
                    replaygain_album_peak, is_preferred
             FROM tracks {}",
            order_clause
        );

        let mut stmt = self.conn.prepare(&sql)?;
        let mut tracks = Vec::new();

        if matches!(sort, SortCriteria::DopamineHits) {
            let rows = stmt.query_map(params![now], |row| self.row_to_track(row))?;
            for r in rows {
                tracks.push(r?);
            }
        } else {
            let rows = stmt.query_map([], |row| self.row_to_track(row))?;
            for r in rows {
                tracks.push(r?);
            }
        };

        Ok(tracks)
    }

    fn row_to_track(&self, row: &rusqlite::Row) -> rusqlite::Result<Track> {
        let id_str: String = row.get(0)?;
        let album_id_str: String = row.get(1)?;
        let path_str: String = row.get(2)?;
        let f_size: i64 = row.get(3)?;
        let t_num: i64 = row.get(6)?;
        let d_num: i64 = row.get(7)?;
        let dur: i64 = row.get(8)?;
        let s_rate: i64 = row.get(11)?;
        let ch: i64 = row.get(12)?;
        let pref: i64 = row.get(17)?;

        let bit_d: i64 = row.get(10)?;
        let bit_depth = match bit_d {
            16 => BitDepth::Bits16,
            24 => BitDepth::Bits24,
            32 => BitDepth::Bits32,
            _ => BitDepth::Bits16,
        };

        let format = AudioFormat {
            codec: AudioCodec::Flac,
            bit_depth,
            sample_rate: s_rate as u32,
            channels: ch as u16,
        };

        Ok(Track {
            id: TrackId(Uuid::parse_str(&id_str).unwrap_or_else(|_| Uuid::new_v4())),
            album_id: AlbumId(Uuid::parse_str(&album_id_str).unwrap_or_else(|_| Uuid::new_v4())),
            file_path: PathBuf::from(path_str),
            file_size: f_size as u64,
            title: row.get(4)?,
            track_artist: row.get(5)?,
            track_number: t_num as u32,
            disc_number: d_num as u32,
            duration_ms: dur as u64,
            format,
            replaygain_track_gain: row.get(13)?,
            replaygain_track_peak: row.get(14)?,
            replaygain_album_gain: row.get(15)?,
            replaygain_album_peak: row.get(16)?,
            is_preferred: pref == 1,
        })
    }
}
