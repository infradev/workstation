#!/usr/bin/env bash
# Shared helpers for the workstation checks.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANSIBLE="${ROOT}/ansible/workstation"
DEBIAN_VARS="${ANSIBLE}/roles/debian/vars/main.yml"
BASE_VARS="${ANSIBLE}/roles/base/vars/main.yml"
MACOS_VARS="${ANSIBLE}/roles/macos/vars/main.yml"
BASH_PROFILE="${ANSIBLE}/roles/base/templates/bash_profile.j2"
FINALIZE="${ANSIBLE}/roles/base/tasks/finalize.yml"
DEVCONTAINER="${ROOT}/.devcontainer"
FAILURES=""

fail() {
  FAILURES="${FAILURES}"$'\n'"$*"
}

finish() {
  if [[ -n "${FAILURES}" ]]; then
    printf '%s\n' "${FAILURES#?}" >&2
    exit 1
  fi
  printf '%s\n' "$1"
}

env_value() {
  local file="$1" key="$2" line
  line="$(grep -E "^${key}=" "${file}" | head -n 1 || true)"
  printf '%s' "${line#*=}"
}

run_capture() {
  set +e
  RUN_OUT="$(timeout 20 "$@" 2>&1)"
  RUN_RC=$?
  set +e
}

command_exists() {
  if command -v "$1" >/dev/null 2>&1; then
    return 0
  fi
  fail "missing command $1"
  return 1
}

dpkg_installed() {
  local status
  status="$(dpkg-query -W -f '${db:Status-Status}' "$1" 2>/dev/null || true)"
  [[ "${status}" == "installed" ]]
}

package_installed() {
  local output
  dpkg_installed "$1" && return 0
  output="$(apt-get -s install "$1" 2>&1 || true)"
  [[ "${output}" == *"0 newly installed"* ]]
}

reports_pin() {
  local binary="$1" pin="$2" flags
  local attempts=("--version" "version --client --short" "version" "-v")
  for flags in "${attempts[@]}"; do
    # shellcheck disable=SC2086
    run_capture "${binary}" ${flags}
    if [[ "${RUN_OUT}" == *"${pin}"* ]]; then
      return 0
    fi
  done
  fail "${binary} did not report ${pin}"
  return 1
}

require_yq() {
  command -v yq >/dev/null 2>&1 && return 0
  local arch version
  arch="$(dpkg --print-architecture)"
  version="$(awk '/^  yq:/ { gsub(/"/, "", $2); print $2; exit }' "${DEBIAN_VARS}")"
  sudo curl -fsSL -o /usr/local/bin/yq \
    "https://github.com/mikefarah/yq/releases/download/v${version}/yq_linux_${arch}"
  sudo chmod +x /usr/local/bin/yq
}

yaml() {
  yq -r "$2" "$1"
}

render() {
  local text="$1" home="$2" key value
  text="${text//\{\{ local_home \}\}/${home}}"
  text="${text//\{\{local_home\}\}/${home}}"
  while [[ "${text}" =~ \{\{[[:space:]]*tool_versions\.([A-Za-z0-9_]+)[[:space:]]*\}\} ]]; do
    key="${BASH_REMATCH[1]}"
    value="$(yaml "${DEBIAN_VARS}" ".tool_versions.${key}")"
    text="$(printf '%s' "${text}" | sed -E "s/\{\{[[:space:]]*tool_versions\.${key}[[:space:]]*\}\}/${value}/")"
  done
  printf '%s' "${text}"
}

linux_exports() {
  awk '
    /\{\%-?[[:space:]]*if ansible_facts\[[^]]*\] == "Darwin"/ { darwin=1; keep=0; next }
    darwin && /\{\%-?[[:space:]]*else/ { keep=1; next }
    darwin && /\{\%-?[[:space:]]*endif/ { darwin=0; keep=0; next }
    darwin && !keep { next }
    { print }
  ' "${BASH_PROFILE}" | sed -nE 's/^export ([A-Za-z_][A-Za-z0-9_]*)=(.*)$/\1 \2/p'
}

gh_extension_repos() {
  grep -oE 'gh extension install [^[:space:]]+' "${FINALIZE}" | awk '{print $4}'
}

extension_command() {
  local name="${1##*/}"
  printf '%s' "${name#gh-}"
}

json_value() {
  local file="$1" key="$2"
  grep -E "^[[:space:]]*\"${key}\"[[:space:]]*:" "${file}" \
    | head -n 1 \
    | sed -E 's/^[^:]*:[[:space:]]*"([^"]*)".*/\1/'
}

assert_sorted() {
  local label="$1"
  shift
  local actual sorted
  actual="$(printf '%s\n' "$@")"
  sorted="$(printf '%s\n' "$@" | sort -f)"
  if [[ "${actual}" != "${sorted}" ]]; then
    fail "${label} is not sorted"
  fi
}

list_has() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ "${item}" == "${needle}" ]] && return 0
  done
  return 1
}

read_lines() {
  local array_name="$1"
  local line
  eval "${array_name}=()"
  while IFS= read -r line; do
    [[ -n "${line}" && "${line}" != "null" ]] || continue
    eval "${array_name}+=(\"\${line}\")"
  done
}
