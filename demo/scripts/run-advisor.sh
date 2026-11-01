#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

# `advisor upgrade-plan get` exits 50 ("blocked upgrades") when some projects are
# held back, even though it still prints a usable plan. Treat that as success.
show_plan() {
  local status=0
  advisor upgrade-plan get || status=$?
  if [[ $status -ne 0 && $status -ne 50 ]]; then
    return "$status"
  fi
  [[ $status -eq 50 ]] && echo "Note: some upgrades are blocked (exit 50); the plan above still applies."
  return 0
}

case "${1:-}" in
  patch)
    # patch apply honours .advisor.yml ignore rules automatically.
    advisor build-config get
    advisor patch apply
    ;;
  plan)
    advisor build-config get
    show_plan
    ;;
  upgrade)
    advisor build-config get
    show_plan
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
