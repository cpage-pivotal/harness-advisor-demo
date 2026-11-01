#!/usr/bin/env bash
# Create ~/.m2/settings.xml for a disposable environment such as a CI container.
#
# Two modes:
#   - Artifactory: set ARTIFACTORY_URL and ARTIFACTORY_PASSWORD (ARTIFACTORY_USERNAME
#     defaults to admin). Maven reaches Broadcom's Spring Enterprise repository only
#     through the Artifactory remote, so no Broadcom credentials are needed here.
#   - Direct: set BROADCOM_EMAIL and BROADCOM_REGISTRY_TOKEN.
set -euo pipefail

if [[ -n "${ARTIFACTORY_URL:-}" ]]; then
  : "${ARTIFACTORY_PASSWORD:?Set ARTIFACTORY_PASSWORD when ARTIFACTORY_URL is set}"
  ARTIFACTORY_USERNAME="${ARTIFACTORY_USERNAME:-admin}"
else
  : "${BROADCOM_EMAIL:?Set BROADCOM_EMAIL, or set ARTIFACTORY_URL to use the Artifactory mirror}"
  : "${BROADCOM_REGISTRY_TOKEN:?Set BROADCOM_REGISTRY_TOKEN, or set ARTIFACTORY_URL to use the Artifactory mirror}"
fi

settings_dir="${HOME}/.m2"
settings_file="${settings_dir}/settings.xml"
mkdir -p "$settings_dir"
if [[ -e "$settings_file" ]]; then
  echo "${settings_file} already exists. Configure its Spring Enterprise server manually." >&2
  exit 1
fi

umask 077
{
  echo '<settings>'
  echo '  <servers>'
  if [[ -n "${ARTIFACTORY_URL:-}" ]]; then
    cat <<EOF
    <server>
      <id>spring-enterprise-remote</id>
      <username>${ARTIFACTORY_USERNAME}</username>
      <password>${ARTIFACTORY_PASSWORD}</password>
    </server>
EOF
  else
    cat <<EOF
    <server>
      <id>spring-enterprise-subscription</id>
      <username>${BROADCOM_EMAIL}</username>
      <password>${BROADCOM_REGISTRY_TOKEN}</password>
    </server>
EOF
  fi
  echo '  </servers>'
  if [[ -n "${ARTIFACTORY_URL:-}" ]]; then
    cat <<EOF
  <mirrors>
    <mirror>
      <id>spring-enterprise-remote</id>
      <mirrorOf>spring-enterprise-subscription</mirrorOf>
      <url>${ARTIFACTORY_URL}</url>
    </mirror>
  </mirrors>
EOF
  fi
  echo '</settings>'
} > "$settings_file"

if [[ -n "${ARTIFACTORY_URL:-}" ]]; then
  echo "Created ${settings_file}: Spring Enterprise artifacts resolve through ${ARTIFACTORY_URL}."
else
  echo "Created ${settings_file}: Spring Enterprise artifacts resolve directly from Broadcom."
fi
