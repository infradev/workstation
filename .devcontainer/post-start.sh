#!/usr/bin/env bash
set -e

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# Load environment variables
if [ -f "/home/vscode/.devcontainer/config/terraform.env" ]; then
    echo "Loading Terraform environment variables..."
    set -a
    source "/home/vscode/.devcontainer/config/terraform.env"
    set +a
fi

# Make scripts executable
chmod +x /home/vscode/.devcontainer/scripts/*.sh

# Make krew and nvm available in this non-interactive shell (they are only
# wired into PATH via .bashrc, which isn't sourced by postStartCommand)
export KREW_ROOT="/home/vscode/.krew"
export PATH="${KREW_ROOT}/bin:${PATH}"
export NVM_DIR="/home/vscode/.nvm"
# shellcheck disable=SC1091
[ -s "${NVM_DIR}/nvm.sh" ] && \. "${NVM_DIR}/nvm.sh"

# Display welcome message
clear
printf "\e[0;32mTerraform Development Environment: $(basename $PWD)\e[0m\n\n"

# Display installed tools and versions
echo "=== Installed Tools ==="
echo "Terraform: $(terraform --version | head -n 1)"
echo "AWS CLI: $(aws --version)"
echo "Azure CLI: $(az --version | head -n 1)"
echo "Google Cloud SDK: $(gcloud --version | head -n 1)"
echo "Terraform Docs: $(terraform-docs --version)"
echo "TFLint: $(tflint --version)"
echo "TFSec: $(tfsec --version)"
echo "Terrascan: $(terrascan version)"
echo "Terragrunt: $(terragrunt --version)"
echo "Terratest: v$(terratest | head -n 1 | cut -d 'v' -f 2)"
echo "Checkov: $(checkov --version)"
echo "Terramate: $(terramate --version)"
echo "Pre-commit: $(pre-commit --version)"
echo "GitHub CLI: $(gh --version | head -n 1)"
echo "GitLab CLI: $(glab --version | head -n 1)"
echo "jq: $(jq --version)"
echo "yq: $(yq --version)"
echo "uv: $(uv --version)"
echo "Vim: $(vim --version | head -n 1)"
echo ""

echo "=== Kubernetes Tools ==="
echo "kubectl: $(kubectl version --client 2>/dev/null | head -n 1)"
echo "Helm: $(helm version --short)"
echo "aws-iam-authenticator: $(aws-iam-authenticator version 2>&1)"
echo "krew: $(kubectl krew version 2>/dev/null | grep GitTag || echo 'installed')"
echo "k9s: $(k9s version | head -n 2 | tr '\n' ' ')"
echo "Docker: $(docker --version)"
echo "kind: $(kind --version)"
echo "stern: $(stern --version | head -n 1)"
echo "kubectx: $(kubectx --version 2>/dev/null || echo 'installed')"
echo "argocd: $(argocd version --client --short 2>/dev/null)"
echo "Session Manager plugin: $(session-manager-plugin --version)"
echo ""

echo "=== Security & Utility Tools ==="
echo "Trivy: $(trivy --version | head -n 1)"
echo "Hadolint: $(hadolint --version)"
echo "Sops: $(sops --version)"
echo "Act: $(act --version)"
echo "MySQL Client: $(mysql --version)"
echo "PostgreSQL Client: $(psql --version)"
echo "nvm: v$(nvm --version 2>/dev/null || echo 'installed')"
echo "pv: $(pv --version | head -n 1)"
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

# Career Certified DevOps onboarding: list only the steps still pending, so
# the section disappears once everything is set up.
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-/home/vscode/.claude}"
pending=()
[ -n "${GITLAB_TOKEN}" ] || \
    pending+=("Export GITLAB_TOKEN (GitLab PAT, read_api scope) in the host shell, then rebuild")
ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -T git@gitlab.com 2>&1 | grep -q "Welcome to GitLab" || \
    pending+=("Add ~/.ssh/id_rsa.pub to your GitLab account (ssh -T git@gitlab.com must greet you); the marketplace is cloned over SSH")
[ -n "$(glab config get token --host gitlab.com 2>/dev/null)" ] || \
    pending+=("glab auth login")
{ [ -n "${TF_TOKEN_app_terraform_io}" ] || grep -qs app.terraform.io /home/vscode/.terraform.d/credentials.tfrc.json; } || \
    pending+=("terraform login")
grep -qs plat-claude-marketplace "${CLAUDE_DIR}/plugins/known_marketplaces.json" || \
    pending+=("In Claude Code: install plat-claude-marketplace and the DevOps plugins, then /plat-context:setup --team devops")
grep -qs '^\[sso-session plat-investigator\]' /home/vscode/.aws/config || \
    pending+=("Run the EKS onboarding audit: ask Claude to \"onboard me to EKS\" (writes the plat-investigator SSO session, profiles and kube contexts)")
pending+=("Sign in to AWS: aws sso login --sso-session plat-investigator --use-device-code")

echo ""
printf "\e[0;33m=== Next Steps (DevOps onboarding) ===\e[0m\n"
i=1
for step in "${pending[@]}"; do
    echo "${i}. ${step}"
    i=$((i + 1))
done
