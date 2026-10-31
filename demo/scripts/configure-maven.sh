#!/usr/bin/env bash
set -euo pipefail

: "${BROADCOM_EMAIL:?Set BROADCOM_EMAIL first}"
: "${BROADCOM_REGISTRY_TOKEN:?Set BROADCOM_REGISTRY_TOKEN first}"
if [[ -n "${ARTIFACTORY_URL:-}" ]]; then
  : "${ARTIFACTORY_PASSWORD:?Set ARTIFACTORY_PASSWORD when ARTIFACTORY_URL is set}"
  ARTIFACTORY_USERNAME="${ARTIFACTORY_USERNAME:-admin}"
fi

settings_dir="${HOME}/.m2"
settings_file="${settings_dir}/settings.xml"
mkdir -p "$settings_dir"
if [[ -e "$settings_file" ]]; then
  echo "${settings_file} already exists. Configure its spring-enterprise-subscription server manually." >&2
  exit 1
fi

umask 077
cat > "$settings_file" <<EOF
<settings>
  <servers>
    <server>
      <id>spring-enterprise-subscription</id>
      <username>${BROADCOM_EMAIL}</username>
      <password>${BROADCOM_REGISTRY_TOKEN}</password>
    </server>
EOF
if [[ -n "${ARTIFACTORY_URL:-}" ]]; then
  cat >> "$settings_file" <<EOF
    <server>
      <id>spring-enterprise-remote</id>
      <username>${ARTIFACTORY_USERNAME}</username>
      <password>${ARTIFACTORY_PASSWORD}</password>
    </server>
EOF
fi
cat >> "$settings_file" <<EOF
  </servers>
EOF
if [[ -n "${ARTIFACTORY_URL:-}" ]]; then
  cat >> "$settings_file" <<EOF
  <mirrors>
    <mirror>
      <id>spring-enterprise-remote</id>
      <mirrorOf>spring-enterprise-subscription</mirrorOf>
      <url>${ARTIFACTORY_URL}</url>
    </mirror>
  </mirrors>
EOF
fi
cat >> "$settings_file" <<EOF
</settings>
EOF
echo "Created ${settings_file} with private permissions."
