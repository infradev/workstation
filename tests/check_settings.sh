#!/usr/bin/env bash
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
require_yq

dockerfile="${DEVCONTAINER}/Dockerfile"
devcontainer_json="${DEVCONTAINER}/devcontainer.json"
env_file="${DEVCONTAINER}/.env"
user="$(json_value "${devcontainer_json}" remoteUser)"
home="/home/${user}"

while IFS= read -r arg; do
  [[ -n "${arg}" ]] || continue
  [[ -n "$(env_value "${env_file}" "${arg}")" ]] || fail ".env missing ${arg}"
done < <(sed -nE 's/^ARG[[:space:]]+([A-Z0-9_]+).*/\1/p' "${dockerfile}")

while IFS= read -r key; do
  [[ -n "${key}" ]] || continue
  case "${key}" in
    *_VERSION|*TOKEN*|*SECRET*) fail ".env has version or secret key ${key}" ;;
  esac
done < <(sed -nE 's/^([A-Z0-9_]+)=.*/\1/p' "${env_file}")

grep -q "USER ${user}" "${dockerfile}" || fail "Dockerfile USER is not remoteUser ${user}"

copied=" "
while IFS= read -r dest; do
  [[ -n "${dest}" ]] || continue
  copied+="${dest##*/} "
done < <(sed -nE 's/^COPY[[:space:]]+[^[:space:]]+[[:space:]]+([^[:space:]]+).*/\1/p' "${dockerfile}")

for key in postCreateCommand postStartCommand; do
  command_name="$(json_value "${devcontainer_json}" "${key}")"
  [[ "${copied}" == *" ${command_name} "* ]] || fail "${key} ${command_name} is not installed by the Dockerfile"
done

while read -r name value; do
  [[ -n "${name}" ]] || continue
  value="${value%\"}"
  value="${value#\"}"
  value="${value%\'}"
  value="${value#\'}"
  case "${name}" in
    TENV_*|TF_*) ;;
    *) continue ;;
  esac
  expected="${value//\$HOME/${home}}"
  actual="$(json_value "${devcontainer_json}" "${name}")"
  [[ "${actual}" == "${expected}" ]] || fail "containerEnv ${name}=${actual}, ansible template has ${expected}"
done < <(linux_exports)

claude_path="$(yaml "${BASE_VARS}" '.files[] | select(.path | test("CLAUDE.md$")) | select(.os_family == null or .os_family == "Debian") | .path' | head -n 1)"
if [[ -n "${claude_path}" ]] && grep -q '"CLAUDE_CONFIG_DIR"' "${devcontainer_json}"; then
  expected="${home}/${claude_path%/*}"
  actual="$(json_value "${devcontainer_json}" CLAUDE_CONFIG_DIR)"
  [[ "${actual}" == "${expected}" ]] || fail "CLAUDE_CONFIG_DIR=${actual}"
fi

finish "devcontainer settings ok"
