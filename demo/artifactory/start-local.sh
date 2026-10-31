#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
env_file="$here/.env"
if [[ ! -f "$env_file" ]]; then
  umask 077
  python3 - "$env_file" <<'PY'
from pathlib import Path
import secrets
import sys
Path(sys.argv[1]).write_text(
    'POSTGRES_PASSWORD=' + secrets.token_urlsafe(32) + '\n'
    'ARTIFACTORY_ADMIN_PASSWORD=' + secrets.token_urlsafe(32) + '\n'
)
PY
fi

docker compose --env-file "$env_file" -f "$here/compose.yaml" up -d
echo "Artifactory is starting at http://localhost:8082/ui/"
