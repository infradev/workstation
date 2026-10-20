#!/usr/bin/env bash
set -uo pipefail
# shellcheck source=tests/lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
require_yq

HOME="${HOME:-/home/alex}"
export PATH="${HOME}/.local/bin:${HOME}/.krew/bin:/usr/local/bin:/usr/bin:/bin:${PATH}"
export TENV_ROOT="${TENV_ROOT:-${HOME}/.local/share/tenv}"
export KREW_ROOT="${KREW_ROOT:-${HOME}/.krew}"

while IFS= read -r package; do
  [[ -n "${package}" ]] || continue
  rendered="$(render "${package}" "${HOME}")"
  name="${rendered%%=*}"
  if [[ "${rendered}" == *"="* ]]; then
    pin="${rendered#*=}"
  else
    pin=""
  fi
  if ! package_installed "${name}"; then
    fail "package ${name} is not installed"
  elif [[ -n "${pin}" ]]; then
    version="$(dpkg-query -W -f '${Version}' "${name}" 2>/dev/null || true)"
    [[ "${version}" == "${pin}"* ]] || fail "package ${name} version is not ${pin}"
  fi
done < <(yaml "${DEBIAN_VARS}" '.packages[]')

if grep -q -- '--skip-tags host' "${DEVCONTAINER}/post-create.sh"; then
  while IFS= read -r package; do
    [[ -n "${package}" ]] || continue
    dpkg_installed "${package}" && fail "host package ${package} is installed"
  done < <(yaml "${DEBIAN_VARS}" '.host_packages[]')
fi

count="$(yaml "${DEBIAN_VARS}" '.remote_executables | length')"
for ((i = 0; i < count; i++)); do
  item_name="$(yaml "${DEBIAN_VARS}" ".remote_executables[${i}].name")"
  pin="$(yaml "${DEBIAN_VARS}" ".tool_versions.\"${item_name//-/_}\"" 2>/dev/null || true)"
  [[ "${pin}" == "null" ]] && pin=""
  names="$(yaml "${DEBIAN_VARS}" ".remote_executables[${i}].binaries[]?.dest" 2>/dev/null || true)"
  [[ -n "${names}" ]] || names="${item_name}"
  while IFS= read -r binary; do
    [[ -n "${binary}" && "${binary}" != "null" ]] || continue
    if command_exists "${binary}" && [[ -n "${pin}" ]]; then
      reports_pin "${binary}" "${pin}" || true
    fi
  done <<<"${names}"
done

while IFS=$'\t' read -r cmd creates; do
  [[ -n "${cmd}" ]] || continue
  cmd="$(render "${cmd}" "${HOME}")"
  if [[ -n "${creates}" && "${creates}" != "null" ]]; then
    creates="$(render "${creates}" "${HOME}")"
    [[ -e "${creates}" ]] || fail "missing ${creates}"
  fi
  if [[ "${cmd}" =~ tenv[[:space:]]+([^[:space:]]+)[[:space:]]+install[[:space:]]+([^[:space:]]+) ]]; then
    if command_exists "${BASH_REMATCH[1]}"; then
      reports_pin "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" || true
    fi
  fi
  if [[ "${cmd}" == *"aws/install"* ]]; then
    command_exists aws || true
  fi
done < <(yaml "${DEBIAN_VARS}" '.commands[] | [.cmd, (.creates // "")] | @tsv')

while IFS= read -r creates; do
  [[ -n "${creates}" ]] || continue
  creates="$(render "${creates}" "${HOME}")"
  [[ -e "${creates}" ]] || fail "missing ${creates}"
  base="$(basename "${creates}")"
  if [[ "${base}" == "nvm.sh" ]]; then
    output="$(bash -c ". \"${creates}\" && nvm --version" 2>&1 || true)"
    pin="$(yaml "${DEBIAN_VARS}" '.tool_versions.nvm')"
    [[ "${output}" == *"${pin}"* ]] || fail "nvm did not report ${pin}"
  fi
  if [[ "${base}" == "kubectl-krew" ]] && command_exists kubectl; then
    output="$(kubectl krew version 2>&1 || true)"
    pin="$(yaml "${DEBIAN_VARS}" '.tool_versions.krew')"
    [[ "${output}" == *"${pin}"* ]] || fail "krew did not report ${pin}"
  fi
done < <(yaml "${DEBIAN_VARS}" '.archives[].creates')

krew_list="$(kubectl krew list 2>&1 || true)"
while IFS= read -r plugin; do
  [[ -n "${plugin}" ]] || continue
  [[ "${krew_list}" == *"${plugin}"* ]] || fail "krew plugin ${plugin} is not installed"
done < <(yaml "${BASE_VARS}" '.krew_plugins[]')

while IFS= read -r spec; do
  [[ -n "${spec}" ]] || continue
  spec="$(render "${spec}" "${HOME}")"
  name="${spec%%==*}"
  pin=""
  [[ "${spec}" == *"=="* ]] && pin="${spec#*==}"
  if command_exists "${name}" && [[ -n "${pin}" ]]; then
    reports_pin "${name}" "${pin}" || true
  fi
done < <(yaml "${DEBIAN_VARS}" '.pipx_packages // [] | .[]')

while IFS= read -r url; do
  [[ -n "${url}" ]] || continue
  url="$(render "${url}" "${HOME}")"
  filename="${url##*/}"
  name="${filename%%_*}"
  name="${name%.deb}"
  command_exists "${name}" || continue
  pin_key="${name//-/_}"
  pin="$(yaml "${DEBIAN_VARS}" ".tool_versions.\"${pin_key}\"" 2>/dev/null || true)"
  [[ "${pin}" == "null" ]] && pin=""
  if [[ -n "${pin}" && "${url}" == *"${pin}"* ]]; then
    reports_pin "${name}" "${pin}" || true
  fi
done < <(yaml "${DEBIAN_VARS}" '.remote_packages // [] | .[]')

while IFS= read -r repo; do
  [[ -n "${repo}" ]] || continue
  command_name="$(extension_command "${repo}")"
  output="$(gh extension list 2>&1 || true)"
  if [[ "${output}" != *"${repo}"* ]]; then
    fail "gh extension ${repo} is not installed"
  elif ! gh "${command_name}" --version >/dev/null 2>&1; then
    fail "gh ${command_name} --version failed"
  fi
done < <(gh_extension_repos)

while IFS= read -r path; do
  [[ -n "${path}" ]] || continue
  [[ -f "${HOME}/${path}" ]] || fail "missing ${HOME}/${path}"
done < <(yaml "${BASE_VARS}" '.files[] | select(.os_family == null or .os_family == "Debian") | .path')

while IFS= read -r path; do
  [[ -n "${path}" ]] || continue
  [[ -d "${HOME}/${path}" ]] || fail "missing directory ${path}"
done < <(yaml "${BASE_VARS}" '.directories[] | select(tag == "!!str" or .os_family == null or .os_family == "Debian") | (.path // .)')

if yaml "${DEBIAN_VARS}" 'has("directories")' | grep -qx true; then
  while IFS= read -r path; do
    [[ -n "${path}" ]] || continue
    path="$(render "${path}" "${HOME}")"
    [[ -d "${path}" ]] || fail "missing directory ${path}"
  done < <(yaml "${DEBIAN_VARS}" '.directories[] | (.path // .)')
fi

bashrc=""
[[ -f "${HOME}/.bashrc" ]] && bashrc="$(cat "${HOME}/.bashrc")"
while IFS= read -r line; do
  [[ -n "${line}" ]] || continue
  [[ "${bashrc}" == *"${line}"* ]] || fail ".bashrc missing ${line}"
done < <(yaml "${BASE_VARS}" '.bashrc_includes[]')

profile=""
[[ -f "${HOME}/.bash_profile" ]] && profile="$(cat "${HOME}/.bash_profile")"
while read -r name _value; do
  [[ -n "${name}" && "${name}" != "PATH" ]] || continue
  [[ "${profile}" == *"${name}="* ]] || fail ".bash_profile missing ${name}"
done < <(linux_exports)

if yaml "${DEBIAN_VARS}" '.tflint_plugins | length' | grep -qxv 0; then
  hcl=""
  [[ -f "${HOME}/.tflint.hcl" ]] && hcl="$(cat "${HOME}/.tflint.hcl")"
  [[ -n "${hcl}" ]] || fail "missing .tflint.hcl"
  while IFS= read -r plugin; do
    [[ -n "${plugin}" ]] || continue
    [[ "${hcl}" == *"plugin \"${plugin}\""* ]] || fail ".tflint.hcl missing ${plugin}"
  done < <(yaml "${DEBIAN_VARS}" '.tflint_plugins[].plugin')
fi

git_name="$(git config --global user.name || true)"
git_email="$(git config --global user.email || true)"
[[ "${git_name}" == "$(env_value "${DEVCONTAINER}/.env" GIT_USER_NAME)" ]] || fail "git user.name is ${git_name}"
[[ "${git_email}" == "$(env_value "${DEVCONTAINER}/.env" GIT_USER_EMAIL)" ]] || fail "git user.email is ${git_email}"

groups="$(id -nG "${USER:-alex}" 2>/dev/null || true)"
while IFS= read -r group; do
  [[ -n "${group}" ]] || continue
  [[ " ${groups} " == *" ${group} "* ]] || fail "user is not in group ${group}"
done < <(yaml "${DEBIAN_VARS}" '.user_groups[]')

if [[ -n "${FAILURES}" ]]; then
  count="$(printf '%s\n' "${FAILURES#?}" | wc -l | tr -d ' ')"
  printf '%s provision check(s) failed:\n%s\n' "${count}" "${FAILURES#?}" >&2
  exit 1
fi
printf '%s\n' "provisioned tools and settings ok"
