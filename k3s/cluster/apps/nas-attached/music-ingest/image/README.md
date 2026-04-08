# Music Ingest Beets Image

Build and publish this image before reconciling the service.

```bash
docker build -t ghcr.io/mandos21/music-ingest-beets:latest k3s/cluster/apps/nas-attached/music-ingest/image
docker push ghcr.io/mandos21/music-ingest-beets:latest
```
