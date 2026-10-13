#!/usr/bin/env bash
set -e

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# Load environment variables
if [ -f "/home/alex/.devcontainer/config/terraform.env" ]; then
    echo "Loading Terraform environment variables..."
    set -a
    source "/home/alex/.devcontainer/config/terraform.env"
    set +a
fi

# Make scripts executable
chmod +x /home/alex/.devcontainer/scripts/*.sh

# Seed an empty Claude Code config on first use of this project's creds dir
[ -f "${CLAUDE_CONFIG_DIR:-/home/alex/.claude}/.claude.json" ] || \
    echo '{}' > "${CLAUDE_CONFIG_DIR:-/home/alex/.claude}/.claude.json"

# Install the Claude Code plugins/marketplaces documented in README.md's
# install snippet. roles/base/vars/main.yml's claude.marketplaces+
# claude.plugins is the canonical list - read straight from it (via yq) when
# this workspace actually carries that ansible source (i.e. this devcontainer
# template opened on the workstation repo itself; the path is relative to
# the workspace root so it doesn't depend on the repo's folder name).
# Otherwise fall back to the static one-per-line mirror in
# .devcontainer/config/claude-{marketplaces,plugins}.txt, kept in sync by
# hand for projects (like most real usages of this template) that don't
# carry the ansible source. Idempotent; failures (e.g. an unconfirmed Tier 3
# marketplace key) are tolerated, not fatal.
if command -v claude >/dev/null 2>&1; then
    # /home/alex/.claude/plugins/cache can be root-owned (seeded at image
    # build time by the claude-code devcontainer Feature) while alex clones
    # into it at runtime - git's ownership check then refuses every clone
    # with "detected dubious ownership". Trust it once; this is a
    # single-user devcontainer, not a shared multi-tenant git host.
    git config --global --get-all safe.directory 2>/dev/null | grep -qx '\*' || \
        git config --global --add safe.directory '*'

    # Clear scratch clones left behind by runs that failed before the
    # safe.directory fix above - a half-written temp clone can leave a
    # corrupted local git config ("unknown error... reading the
    # configuration files") that keeps failing even after the real cause
    # is fixed, since retries reuse the same broken directory.
    rm -rf /home/alex/.claude/plugins/cache/temp_*

    ANSIBLE_CLAUDE_VARS="ansible/workstation/roles/base/vars/main.yml"
    if [ -f "$ANSIBLE_CLAUDE_VARS" ] && command -v yq >/dev/null 2>&1; then
        mapfile -t claude_marketplaces < <(yq -r '.claude.marketplaces[]' "$ANSIBLE_CLAUDE_VARS")
        mapfile -t claude_plugins < <(yq -r '.claude.plugins[]' "$ANSIBLE_CLAUDE_VARS")
    else
        mapfile -t claude_marketplaces < /home/alex/.devcontainer/config/claude-marketplaces.txt
        mapfile -t claude_plugins < /home/alex/.devcontainer/config/claude-plugins.txt
    fi

    claude_marketplace_failures=()
    claude_plugin_failures=()
    for mp in "${claude_marketplaces[@]}"; do
        if ! out=$(claude plugin marketplace add "$mp" 2>&1); then
            claude_marketplace_failures+=("${mp}: ${out}")
        fi
    done

    # claude-plugins-official ships built into the CLI, so it's never in the
    # marketplaces list above - but a fresh, project-scoped .claude dir (this
    # devcontainer's per-project credential isolation) has no local cache of
    # its catalog yet, and every @claude-plugins-official install 404s with
    # "local copy may be out of date" until it's seeded/refreshed once.
    claude plugin marketplace add anthropics/claude-plugins-official >/dev/null 2>&1 || \
        claude plugin marketplace update claude-plugins-official >/dev/null 2>&1 || true

    for p in "${claude_plugins[@]}"; do
        if ! out=$(claude plugin install "$p" 2>&1); then
            claude_plugin_failures+=("${p}: ${out}")
        fi
    done
fi

# Make krew and nvm available in this non-interactive shell (they are only
# wired into PATH via .bashrc, which isn't sourced by postStartCommand)
export KREW_ROOT="/home/alex/.krew"
export PATH="${KREW_ROOT}/bin:${PATH}"
export NVM_DIR="/home/alex/.nvm"
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

if [ "${#claude_marketplace_failures[@]}" -gt 0 ] || [ "${#claude_plugin_failures[@]}" -gt 0 ]; then
    echo ""
    printf "\e[0;31m=== Claude plugin/marketplace install failures ===\e[0m\n"
    for f in "${claude_marketplace_failures[@]}"; do
        echo "marketplace: ${f}"
    done
    for f in "${claude_plugin_failures[@]}"; do
        echo "plugin: ${f}"
    done
    echo "(a failure can be expected noise - e.g. already registered/installed - or a real issue; re-run '.devcontainer/post-start.sh' after fixing to retry)"
fi

echo ""
printf "\e[0;33m=== Next Steps ===\e[0m\n"
i=1
for step in "${pending[@]}"; do
    echo "${i}. ${step}"
    i=$((i + 1))
done
