#!/usr/bin/env bash
set -euo pipefail

# Once per container create. Applies the Linux Ansible playbook, skipping
# tasks tagged host (full apt upgrade, OpenSSH, certbot, Docker CE).
# Docker-in-Docker already provides the engine. A copied devcontainer does
# not contain the playbook, so this clones the public workstation repo.
if [ -f "${PWD}/ansible/workstation/ansible.yml" ]; then
  PLAYBOOK_DIR="${PWD}/ansible/workstation"
elif [ -f /workspaces/project/ansible/workstation/ansible.yml ]; then
  PLAYBOOK_DIR=/workspaces/project/ansible/workstation
else
  clone="${HOME:-/home/alex}/.local/src/workstation"
  if [ ! -f "${clone}/ansible/workstation/ansible.yml" ]; then
    mkdir -p "$(dirname "${clone}")"
    git clone --depth 1 --single-branch --branch main https://github.com/infradev/workstation.git "${clone}"
    rm -rf "${clone}/.git"
  fi
  PLAYBOOK_DIR="${clone}/ansible/workstation"
fi

cd "${PLAYBOOK_DIR}"
ansible-playbook -i inventory ansible.yml --skip-tags host

# Shared editor config (also read by the Ansible base role). The settings go
# to the machine-scope file of each server flavor; extensions go through the
# server CLI, which exists once the editor has attached. Missing CLI is not
# fatal: the extensions can be installed from the editor later.
vscode_dir="${PLAYBOOK_DIR}/roles/base/files/vscode"
for server in .vscode-server .cursor-server; do
  install -D -m 0644 "${vscode_dir}/settings.jsonc" "${HOME}/${server}/data/Machine/settings.json"
done

cli="$(command -v code || command -v cursor || find "${HOME}/.vscode-server" "${HOME}/.cursor-server" -path '*/bin/remote-cli/*' \( -name code -o -name cursor \) -print -quit 2>/dev/null || true)"
if [ -n "${cli}" ]; then
  jq -r '.[]' "${vscode_dir}/extensions.json" | while read -r extension; do
    "${cli}" --install-extension "${extension}" || echo "warning: ${extension} not installed" >&2
  done
else
  echo "warning: no editor CLI found, skipping extension install" >&2
fi
