FROM lscr.io/linuxserver/beets:latest

RUN apk add --no-cache     chromaprint     ffmpeg     py3-pip  && pip3 install --no-cache-dir     "beets[fetchart]"     "beets[chroma]"     "beets[scrub]"     discogs-client     pylast
