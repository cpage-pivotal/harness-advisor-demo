#!/usr/bin/env bash
set -euo pipefail

: "${BROADCOM_EMAIL:?Set BROADCOM_EMAIL first}"
: "${BROADCOM_REGISTRY_TOKEN:?Set BROADCOM_REGISTRY_TOKEN first}"

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
  </servers>
</settings>
EOF
echo "Created ${settings_file} with private permissions."
