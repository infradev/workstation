#!/usr/bin/env bash
set -uo pipefail
# shellcheck source=tests/lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
require_yq

debian_dir="$(dirname "${DEBIAN_VARS}")"
executables=()
read_lines executables < <(yaml "${DEBIAN_VARS}" '.remote_executables[].name')
versions=()
read_lines versions < <(yaml "${DEBIAN_VARS}" '.tool_versions | keys | .[]')
packages=()
read_lines packages < <(yaml "${DEBIAN_VARS}" '.packages[]')
host_packages=()
read_lines host_packages < <(yaml "${DEBIAN_VARS}" '.host_packages[]')
krew_plugins=()
read_lines krew_plugins < <(yaml "${BASE_VARS}" '.krew_plugins[]')
manual_skills=()
read_lines manual_skills < <(yaml "${BASE_VARS}" '.ai.manual_skills[].name')
homebrew=()
read_lines homebrew < <(yaml "${MACOS_VARS}" '.homebrew[]')

while IFS= read -r repo; do
  [[ -n "${repo}" ]] || continue
  command_name="$(extension_command "${repo}")"
  if list_has "${command_name}" "${homebrew[@]}" \
    || list_has "${command_name}" "${executables[@]}" \
    || list_has "${command_name}" "${versions[@]}"; then
    fail "${repo} is also installed as ${command_name}"
  fi
done < <(gh_extension_repos)

assert_sorted "tool_versions keys" "${versions[@]}"
assert_sorted "remote_executables" "${executables[@]}"
assert_sorted "packages" "${packages[@]}"
assert_sorted "host_packages" "${host_packages[@]}"
assert_sorted "krew_plugins" "${krew_plugins[@]}"
assert_sorted "manual_skills" "${manual_skills[@]}"
assert_sorted "homebrew" "${homebrew[@]}"

while IFS=$'\t' read -r name url; do
  [[ -n "${name}" ]] || continue
  while [[ "${url}" =~ tool_versions\.([A-Za-z0-9_]+) ]]; do
    ref="${BASH_REMATCH[1]}"
    list_has "${ref}" "${versions[@]}" || fail "${name} url uses missing tool_versions.${ref}"
    url="${url#*tool_versions."${ref}"}"
  done
done < <(yaml "${DEBIAN_VARS}" '.remote_executables[] | [.name, .url] | @tsv')

repo_names=""
for arch_file in "${debian_dir}"/*-*.yml; do
  names="$(yaml "${arch_file}" '.repositories[].name')"
  # shellcheck disable=SC2086
  assert_sorted "$(basename "${arch_file}") repositories" ${names}
  if [[ -z "${repo_names}" ]]; then
    repo_names="${names}"
  elif [[ "${names}" != "${repo_names}" ]]; then
    fail "$(basename "${arch_file}") repository names differ"
  fi
done

finish "ansible vars ok"
