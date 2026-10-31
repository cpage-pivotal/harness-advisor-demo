#!/usr/bin/env bash
set -euo pipefail

: "${BROADCOM_REGISTRY_TOKEN:?Set BROADCOM_REGISTRY_TOKEN first}"

case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) variant=macos-arm64 ;;
  Darwin-x86_64) variant=macos ;;
  Linux-x86_64) variant=linux ;;
  *) echo "This installer supports macOS ARM64/AMD64 and Linux AMD64." >&2; exit 1 ;;
esac

version="$(curl -fsS -H "Authorization: Bearer ${BROADCOM_REGISTRY_TOKEN}" \
  'https://packages.broadcom.com/artifactory/api/search/latestVersion?g=com.vmware.tanzu.spring&a=application-advisor-cli-linux&repos=spring-enterprise')"
if [[ ! "$version" =~ ^[0-9][0-9A-Za-z._-]*$ ]]; then
  echo "Broadcom did not return a valid CLI version." >&2
  exit 1
fi

install_dir="${ADVISOR_INSTALL_DIR:-$HOME/.local/bin}"
mkdir -p "$install_dir"
archive="$(mktemp)"
trap 'rm "$archive"' EXIT
curl -fsSL -H "Authorization: Bearer ${BROADCOM_REGISTRY_TOKEN}" \
  -o "$archive" \
  "https://packages.broadcom.com/artifactory/spring-enterprise/com/vmware/tanzu/spring/application-advisor-cli-${variant}/${version}/application-advisor-cli-${variant}-${version}.tar"
tar -xf "$archive" -C "$install_dir" --strip-components=1 --exclude=./META-INF
"$install_dir/advisor" --version
echo "Installed advisor at $install_dir/advisor"
