#!/bin/sh
set -eu
mkdir -p /state /music /uploads/incoming /uploads/review /uploads/rejected /uploads/logs /uploads/tmp
python3 - <<'PY'
from pathlib import Path
import os

template = Path('/config-src/config.yaml.tmpl').read_text()
for key in ('BEETS_DISCOGS_TOKEN', 'BEETS_ACOUSTID_APIKEY'):
    template = template.replace('${%s}' % key, os.environ.get(key, ''))
Path('/state/config.yaml').write_text(template)
PY
if command -v fish >/dev/null 2>&1; then
  mkdir -p /root/.config/fish/completions /root/.config/fish/conf.d
  cat >/root/.config/fish/conf.d/beets-admin.fish <<'FISH_EOF'
function beet --wraps beet
    command beet -c /state/config.yaml $argv
end
function b --wraps beet
    command beet -c /state/config.yaml $argv
end
function bl --wraps beet
    command beet -c /state/config.yaml ls $argv
end
function bi --wraps beet
    command beet -c /state/config.yaml import $argv
end
function bb --wraps beet
    command beet -c /state/config.yaml bad $argv
end
function bdup --wraps beet
    command beet -c /state/config.yaml duplicates $argv
end
if status --is-interactive; and test "$PWD" = /
    cd /uploads
end
FISH_EOF
  HOME=/root beet -c /state/config.yaml fish >/dev/null 2>&1 || true
fi
