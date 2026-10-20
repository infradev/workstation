#!/usr/bin/env bash
set -e

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# Make scripts executable
chmod +x /home/alex/.devcontainer/scripts/*.sh

# Seed an empty Claude Code config on first use of this project's creds dir
[ -f "${CLAUDE_CONFIG_DIR:-/home/alex/.claude}/.claude.json" ] || \
    echo '{}' > "${CLAUDE_CONFIG_DIR:-/home/alex/.claude}/.claude.json"

# Make krew and nvm available in this non-interactive shell (they are only
# wired into PATH via .bashrc, which isn't sourced by postStartCommand)
export KREW_ROOT="/home/alex/.krew"
export PATH="${KREW_ROOT}/bin:${PATH}"
export NVM_DIR="/home/alex/.nvm"
# shellcheck disable=SC1091
[ -s "${NVM_DIR}/nvm.sh" ] && \. "${NVM_DIR}/nvm.sh"

# Display welcome message
clear
printf '\e[0;32mTerraform Development Environment: %s\e[0m\n\n' "$(basename "${PWD}")"

# Display installed tools and versions
echo "=== Installed Tools ==="
echo "AWS CLI: $(aws --version)"
echo "Azure CLI: $(az --version | head -n 1)"
echo "Checkov: $(checkov --version)"
echo "GitHub CLI: $(gh --version | head -n 1)"
echo "gh act: $(gh act --version)"
echo "GitLab CLI: $(glab --version | head -n 1)"
echo "Google Cloud SDK: $(gcloud --version | head -n 1)"
echo "jq: $(jq --version)"
echo "Pre-commit: $(pre-commit --version)"
echo "Terraform: $(terraform --version | head -n 1)"
echo "Terraform Docs: $(terraform-docs --version)"
echo "Terragrunt: $(terragrunt --version)"
echo "Terramate: $(terramate --version)"
echo "Terrascan: $(terrascan version)"
echo "Terratest: v$(terratest | head -n 1 | cut -d 'v' -f 2)"
echo "TFLint: $(tflint --version)"
echo "TFSec: $(tfsec --version)"
echo "uv: $(uv --version)"
echo "Vim: $(vim --version | head -n 1)"
echo "yq: $(yq --version)"
echo ""

echo "=== Kubernetes Tools ==="
echo "argocd: $(argocd version --client --short 2>/dev/null)"
echo "aws-iam-authenticator: $(aws-iam-authenticator version 2>&1)"
echo "Docker: $(docker --version)"
echo "Helm: $(helm version --short)"
echo "k9s: $(k9s version | head -n 2 | tr '\n' ' ')"
echo "kind: $(kind --version)"
echo "krew: $(kubectl krew version 2>/dev/null | grep GitTag || echo 'installed')"
echo "kubectx: $(kubectx --version 2>/dev/null || echo 'installed')"
echo "kubectl: $(kubectl version --client 2>/dev/null | head -n 1)"
echo "Session Manager plugin: $(session-manager-plugin --version)"
echo "stern: $(stern --version | head -n 1)"
echo ""

echo "=== Security & Utility Tools ==="
echo "Hadolint: $(hadolint --version)"
echo "MySQL Client: $(mysql --version)"
echo "nvm: v$(nvm --version 2>/dev/null || echo 'installed')"
echo "PostgreSQL Client: $(psql --version)"
echo "pv: $(pv --version | head -n 1)"
echo "Sops: $(sops --version)"
echo "Trivy: $(trivy --version | head -n 1)"
echo ""

# Display environment information
echo "=== Environment Information ==="
echo "Working Directory: $(pwd)"
echo "User: $(whoami)"
echo ""

# Display authentication status
echo "=== Authentication Status ==="
echo "AWS: Run '.devcontainer/scripts/aws-auth.sh' to authenticate"
echo "Azure: Run '.devcontainer/scripts/azure-auth.sh' to authenticate"
echo "GCP: Run '.devcontainer/scripts/gcp-auth.sh' to authenticate"
echo ""

# Display helpful commands
echo "=== Helpful Commands ==="
echo "terraform init - Initialize a Terraform working directory"
echo "terraform plan - Generate and show an execution plan"
echo "terraform apply - Builds or changes infrastructure"
echo "terraform validate - Validates the Terraform files"
echo "terraform fmt - Rewrites config files to canonical format"
echo "pre-commit run --all-files - Run pre-commit hooks on all files"
echo ""

# Display container information if available
if command -v devcontainer-info &> /dev/null; then
    devcontainer-info
fi

# Onboarding: list only the steps still pending, so the section disappears
# once everything is set up. Keep this list generic - org/team-specific
# checks belong in the optional extended.sh hook below, not here.
pending=()
pending+=("Sign in to AWS: .devcontainer/scripts/aws-auth.sh")
pending+=("Sign in to Azure: .devcontainer/scripts/azure-auth.sh")
pending+=("Sign in to GCP: .devcontainer/scripts/gcp-auth.sh")

# Optional, org/team-specific additions (marketplace installs, internal SSO
# sessions, etc.) are not part of this generic devcontainer. Drop a file at
# .devcontainer/scripts/extended.sh to append more pending items - it is
# sourced here (so it shares the `pending` array) if present, and skipped
# otherwise.
EXTENDED_SCRIPT="/home/alex/.devcontainer/scripts/extended.sh"
if [ -f "${EXTENDED_SCRIPT}" ]; then
    # shellcheck disable=SC1090
    . "${EXTENDED_SCRIPT}"
fi

echo ""
printf "\e[0;33m=== Next Steps ===\e[0m\n"
i=1
for step in "${pending[@]}"; do
    echo "${i}. ${step}"
    i=$((i + 1))
done
