#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

case "${1:-}" in
  patch)
    advisor build-config get
    advisor patch apply --from-yml
    ;;
  plan)
    advisor build-config get
    advisor upgrade-plan get
    ;;
  upgrade)
    advisor build-config get
    advisor upgrade-plan get
    advisor upgrade-plan apply
    ;;
  *)
    echo "Usage: $0 {patch|plan|upgrade}" >&2
    exit 2
    ;;
esac

if [[ "${1}" != "plan" ]]; then
  ./mvnw -B test
fi
