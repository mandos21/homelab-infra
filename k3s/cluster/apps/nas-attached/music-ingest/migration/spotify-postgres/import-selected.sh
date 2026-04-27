#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 /path/to/spotify_clean.sqlite3 /path/to/spotify_clean_audio_features.sqlite3" >&2
  exit 1
fi

main_db="$1"
audio_db="$2"

if [[ ! -f "$main_db" ]]; then
  echo "main sqlite db not found: $main_db" >&2
  exit 1
fi

if [[ ! -f "$audio_db" ]]; then
  echo "audio-features sqlite db not found: $audio_db" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
schema_sql="$script_dir/schema.sql"

: "${POSTGRES_USER:?POSTGRES_USER is required}"
: "${POSTGRES_DB:?POSTGRES_DB is required}"
: "${PGHOST:?PGHOST is required}"
: "${PGPORT:=5432}"

main_tables=(
  artists
  artist_images
  albums
  album_images
  artist_albums
  tracks
  track_artists
)

run_psql() {
  psql \
    --set ON_ERROR_STOP=1 \
    --username "$POSTGRES_USER" \
    --dbname "$POSTGRES_DB" \
    "$@"
}

import_table() {
  local db_path="$1"
  local table_name="$2"
  echo "Importing $table_name from $(basename "$db_path")"
  sqlite3 -csv -header "$db_path" "SELECT * FROM \"$table_name\";" \
    | run_psql --command "\\copy spotify_raw.${table_name} FROM STDIN WITH (FORMAT csv, HEADER true)"
}

echo "Creating schema objects"
run_psql --file "$schema_sql"

echo "Truncating target tables"
run_psql --command "
TRUNCATE TABLE
  spotify_raw.track_audio_features,
  spotify_raw.track_artists,
  spotify_raw.tracks,
  spotify_raw.artist_albums,
  spotify_raw.album_images,
  spotify_raw.albums,
  spotify_raw.artist_images,
  spotify_raw.artists;
"

for table_name in "${main_tables[@]}"; do
  import_table "$main_db" "$table_name"
done

import_table "$audio_db" track_audio_features

echo "Import complete"
