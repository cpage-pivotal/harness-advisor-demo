#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if [[ "$(git branch --show-current)" != "demo" ]]; then
  echo "Reset must be run on the demo branch." >&2
  exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree has changes. Commit or discard them before resetting." >&2
  exit 1
fi
git rev-parse -q --verify refs/tags/demo-baseline >/dev/null || {
  echo "Missing demo-baseline tag." >&2
  exit 1
}

git restore --source=demo-baseline --staged --worktree -- .
if git diff --cached --quiet; then
  echo "The demo branch is already at the baseline content."
  exit 0
fi
boot_version="$(git show demo-baseline:pom.xml | grep -A3 '<artifactId>spring-boot-starter-parent</artifactId>' \
  | grep -m1 -o '<version>[^<]*' | sed 's/<version>//')"
git commit -m "demo: restore Spring Boot ${boot_version:-baseline} baseline"
echo "Baseline restored in a new commit. Push with: git push origin demo"
