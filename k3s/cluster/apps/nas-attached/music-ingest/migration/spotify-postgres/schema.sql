CREATE SCHEMA IF NOT EXISTS spotify_raw;

CREATE TABLE IF NOT EXISTS spotify_raw.artists (
    rowid BIGINT PRIMARY KEY,
    id TEXT NOT NULL,
    fetched_at BIGINT NOT NULL,
    name TEXT NOT NULL,
    followers_total BIGINT NOT NULL,
    popularity INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS spotify_raw.artist_images (
    artist_rowid BIGINT NOT NULL,
    width INTEGER NOT NULL,
    height INTEGER NOT NULL,
    url TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS spotify_raw.albums (
    rowid BIGINT PRIMARY KEY,
    id TEXT NOT NULL,
    fetched_at BIGINT NOT NULL,
    name TEXT NOT NULL,
    album_type TEXT NOT NULL,
    available_markets_rowid BIGINT NOT NULL,
    external_id_upc TEXT,
    copyright_c TEXT,
    copyright_p TEXT,
    label TEXT NOT NULL,
    popularity INTEGER NOT NULL,
    release_date TEXT NOT NULL,
    release_date_precision TEXT NOT NULL,
    total_tracks INTEGER NOT NULL,
    external_id_amgid TEXT
);

CREATE TABLE IF NOT EXISTS spotify_raw.album_images (
    album_rowid BIGINT NOT NULL,
    width INTEGER NOT NULL,
    height INTEGER NOT NULL,
    url TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS spotify_raw.artist_albums (
    artist_rowid BIGINT NOT NULL,
    album_rowid BIGINT NOT NULL,
    is_appears_on INTEGER NOT NULL,
    is_implicit_appears_on INTEGER NOT NULL,
    index_in_album INTEGER
);

CREATE TABLE IF NOT EXISTS spotify_raw.tracks (
    rowid BIGINT PRIMARY KEY,
    id TEXT NOT NULL,
    fetched_at BIGINT NOT NULL,
    name TEXT NOT NULL,
    preview_url TEXT,
    album_rowid BIGINT NOT NULL,
    track_number INTEGER NOT NULL,
    external_id_isrc TEXT,
    popularity INTEGER NOT NULL,
    available_markets_rowid BIGINT NOT NULL,
    disc_number INTEGER NOT NULL,
    duration_ms INTEGER NOT NULL,
    explicit INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS spotify_raw.track_artists (
    track_rowid BIGINT NOT NULL,
    artist_rowid BIGINT NOT NULL
);

CREATE TABLE IF NOT EXISTS spotify_raw.track_audio_features (
    rowid BIGINT PRIMARY KEY,
    track_id TEXT NOT NULL,
    fetched_at BIGINT NOT NULL,
    null_response INTEGER NOT NULL,
    duration_ms INTEGER,
    time_signature INTEGER,
    tempo INTEGER,
    key INTEGER,
    mode INTEGER,
    danceability REAL,
    energy REAL,
    loudness REAL,
    speechiness REAL,
    acousticness REAL,
    instrumentalness REAL,
    liveness REAL,
    valence REAL
);

CREATE UNIQUE INDEX IF NOT EXISTS artists_id_unique
    ON spotify_raw.artists (id);
CREATE INDEX IF NOT EXISTS artists_name
    ON spotify_raw.artists (name);
CREATE INDEX IF NOT EXISTS artists_popularity
    ON spotify_raw.artists (popularity);
CREATE INDEX IF NOT EXISTS artists_followers_total
    ON spotify_raw.artists (followers_total);

CREATE INDEX IF NOT EXISTS artist_images_artist_rowid
    ON spotify_raw.artist_images (artist_rowid);

CREATE UNIQUE INDEX IF NOT EXISTS albums_id_unique
    ON spotify_raw.albums (id);
CREATE INDEX IF NOT EXISTS albums_name
    ON spotify_raw.albums (name);
CREATE INDEX IF NOT EXISTS albums_popularity
    ON spotify_raw.albums (popularity);
CREATE INDEX IF NOT EXISTS albums_available_markets_rowid
    ON spotify_raw.albums (available_markets_rowid);

CREATE INDEX IF NOT EXISTS album_images_album_rowid
    ON spotify_raw.album_images (album_rowid);

CREATE INDEX IF NOT EXISTS artist_albums_artist_rowid
    ON spotify_raw.artist_albums (artist_rowid);
CREATE INDEX IF NOT EXISTS artist_albums_album_rowid
    ON spotify_raw.artist_albums (album_rowid);

CREATE UNIQUE INDEX IF NOT EXISTS tracks_id_unique
    ON spotify_raw.tracks (id);
CREATE INDEX IF NOT EXISTS tracks_popularity
    ON spotify_raw.tracks (popularity);
CREATE INDEX IF NOT EXISTS tracks_album_rowid
    ON spotify_raw.tracks (album_rowid);
CREATE INDEX IF NOT EXISTS tracks_external_id_isrc
    ON spotify_raw.tracks (external_id_isrc);

CREATE INDEX IF NOT EXISTS track_artists_track_rowid
    ON spotify_raw.track_artists (track_rowid);
CREATE INDEX IF NOT EXISTS track_artists_artist_rowid
    ON spotify_raw.track_artists (artist_rowid);

CREATE UNIQUE INDEX IF NOT EXISTS track_audio_features_track_id_unique
    ON spotify_raw.track_audio_features (track_id);
