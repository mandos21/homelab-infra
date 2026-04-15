FROM lscr.io/linuxserver/beets:latest

RUN apk add --no-cache \
    chromaprint \
    ffmpeg \
    fish \
    flac \
    py3-pip \
  && pip3 install --no-cache-dir \
    "beets[fetchart]" \
    "beets[chroma]" \
    "beets[lastgenre]" \
    "beets[scrub]" \
    discogs-client \
    pylast \
  && mkdir -p /root/.config/fish/conf.d

COPY beets-admin.fish /root/.config/fish/conf.d/beets-admin.fish
