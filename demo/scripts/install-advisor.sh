#!/usr/bin/env bash
# Install the Application Advisor CLI into $ADVISOR_INSTALL_DIR (default ~/.local/bin).
#
# Download source:
#   - Artifactory: set ARTIFACTORY_URL and ARTIFACTORY_PASSWORD (ARTIFACTORY_USERNAME
#     defaults to admin). The CLI tarball is fetched through the Spring Enterprise remote.
#   - Direct: set BROADCOM_REGISTRY_TOKEN.
#
# Version: ADVISOR_VERSION (default below). Artifactory OSS cannot look up the latest
# version, and Broadcom publishes no maven-metadata.xml for the CLI, so the version is
# pinned. ADVISOR_VERSION=latest asks Broadcom directly and needs BROADCOM_REGISTRY_TOKEN.
set -euo pipefail

default_version=1.7.1
version="${ADVISOR_VERSION:-$default_version}"

if [[ -n "${ARTIFACTORY_URL:-}" ]]; then
  : "${ARTIFACTORY_PASSWORD:?Set ARTIFACTORY_PASSWORD when ARTIFACTORY_URL is set}"
  base_url="${ARTIFACTORY_URL%/}"
  auth=(-u "${ARTIFACTORY_USERNAME:-admin}:${ARTIFACTORY_PASSWORD}")
else
  : "${BROADCOM_REGISTRY_TOKEN:?Set BROADCOM_REGISTRY_TOKEN, or set ARTIFACTORY_URL to use the Artifactory mirror}"
  base_url=https://packages.broadcom.com/artifactory/spring-enterprise
  auth=(-H "Authorization: Bearer ${BROADCOM_REGISTRY_TOKEN}")
fi

case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) variant=macos-arm64 ;;
  Darwin-x86_64) variant=macos ;;
  Linux-x86_64) variant=linux ;;
  Linux-aarch64 | Linux-arm64)
    echo "Broadcom publishes no Linux ARM64 build of the advisor CLI." >&2
    echo "Run this container as linux/amd64 (for example, Linux / AMD64 in the Harness infrastructure)." >&2
    exit 1
    ;;
  *) echo "This installer supports macOS ARM64/AMD64 and Linux AMD64." >&2; exit 1 ;;
esac

if [[ "$version" == latest ]]; then
  : "${BROADCOM_REGISTRY_TOKEN:?ADVISOR_VERSION=latest needs BROADCOM_REGISTRY_TOKEN to ask Broadcom}"
  version="$(curl -fsS -H "Authorization: Bearer ${BROADCOM_REGISTRY_TOKEN}" \
    'https://packages.broadcom.com/artifactory/api/search/latestVersion?g=com.vmware.tanzu.spring&a=application-advisor-cli-linux&repos=spring-enterprise')"
fi
if [[ ! "$version" =~ ^[0-9][0-9A-Za-z._-]*$ ]]; then
  echo "Invalid advisor CLI version: ${version}" >&2
  exit 1
fi

install_dir="${ADVISOR_INSTALL_DIR:-$HOME/.local/bin}"
mkdir -p "$install_dir"
archive="$(mktemp)"
trap 'rm -f "$archive"' EXIT
artifact="application-advisor-cli-${variant}"
echo "Downloading ${artifact} ${version} from ${base_url}"
curl -fsSL "${auth[@]}" -o "$archive" \
  "${base_url}/com/vmware/tanzu/spring/${artifact}/${version}/${artifact}-${version}.tar"
tar -xf "$archive" -C "$install_dir" --strip-components=1 --exclude=./META-INF
"$install_dir/advisor" --version
echo "Installed advisor at $install_dir/advisor"
