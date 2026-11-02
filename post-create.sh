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
