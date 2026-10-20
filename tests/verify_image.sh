#!/usr/bin/env bash
set -uo pipefail
# shellcheck source=tests/lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

dockerfile="${DEVCONTAINER}/Dockerfile"
devcontainer_json="${DEVCONTAINER}/devcontainer.json"
env_file="${DEVCONTAINER}/.env"
user="$(json_value "${devcontainer_json}" remoteUser)"
home="/home/${user}"

actual_user="$(id -un)"
actual_group="$(id -gn)"
[[ "${actual_user}" == "${user}" ]] || fail "user is ${actual_user}, Dockerfile USER is ${user}"
[[ "${actual_group}" == "${user}" ]] || fail "group is ${actual_group}"

while IFS= read -r dest; do
  [[ -n "${dest}" ]] || continue
  name="${dest##*/}"
  if [[ "${name}" == "post-create" || "${name}" == "post-start" ]] && [[ ! -x "${dest}" ]]; then
    fail "${dest} is not executable"
  fi
done < <(sed -nE 's/^COPY[[:space:]]+[^[:space:]]+[[:space:]]+([^[:space:]]+).*/\1/p' "${dockerfile}")

command_exists ansible-playbook || true
listed="$(ansible-galaxy collection list 2>/dev/null || true)"
while IFS= read -r line; do
  [[ "${line}" == *"ansible-galaxy collection install"* ]] || continue
  for token in ${line//\\/}; do
    if [[ "${token}" == *.* && "${token}" != */* && "${token}" != -* ]]; then
      [[ "${listed}" == *"${token}"* ]] || fail "collection ${token} is missing"
    fi
  done
done < "${dockerfile}"

git_name="$(git config --global user.name || true)"
git_email="$(git config --global user.email || true)"
[[ "${git_name}" == "$(env_value "${env_file}" GIT_USER_NAME)" ]] || fail "git user.name is ${git_name}"
[[ "${git_email}" == "$(env_value "${env_file}" GIT_USER_EMAIL)" ]] || fail "git user.email is ${git_email}"
safe="$(git config --global --get-all safe.directory || true)"
while IFS= read -r directory; do
  [[ -n "${directory}" ]] || continue
  grep -qxF "${directory}" <<<"${safe}" || fail "git safe.directory missing ${directory}"
done < <(sed -nE 's/.*safe\.directory[[:space:]]+"([^"]+)".*/\1/p' "${dockerfile}")

while IFS= read -r path; do
  [[ -d "${path}" ]] || fail "missing ${path}"
done < <(sed -nE 's/.*mkdir -p[[:space:]]+([^[:space:]]+).*/\1/p' "${dockerfile}")

while read -r mode target; do
  [[ -n "${target}" ]] || continue
  actual="$(stat -c %a "${target}")"
  [[ "${actual}" == "${mode}" ]] || fail "${target} mode is ${actual}"
done < <(sed -nE 's/.*chmod[[:space:]]+([0-9]+)[[:space:]]+([^[:space:]]+).*/\1 \2/p' "${dockerfile}")

hook="$(sed -nE "s/.*echo '([^']+)' >> .*\\.bashrc.*/\\1/p" "${dockerfile}" | head -n 1)"
if [[ -n "${hook}" && -f "${home}/.bashrc" ]] && ! grep -qF "${hook}" "${home}/.bashrc"; then
  fail "bashrc is missing the Dockerfile hook"
fi

finish "image settings ok"
