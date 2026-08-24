#!/usr/bin/env bash
set -e

# This script installs common utilities and dependencies

# Versions
NVM_VERSION=${1:-"0.40.7"}
RTK_VERSION=${2:-"0.45.0"}

# Install common packages
echo "Installing common utilities and dependencies..."
apt-get update
export DEBIAN_FRONTEND=noninteractive
apt-get -y install --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    curl \
    git \
    gnupg \
    jq \
    lsb-release \
    make \
    python3 \
    python3-pip \
    pipx \
    software-properties-common \
    unzip \
    vim \
    wget \
    zip

# Install pre-commit
# Ubuntu 26.04 ships an externally managed Python (PEP 668), so plain
# "pip3 install" is refused. pipx installs each CLI in its own venv; pointing
# PIPX_HOME/PIPX_BIN_DIR at /usr/local makes the tools available to all users.
echo "Installing pre-commit..."
export PIPX_HOME=/usr/local/pipx
export PIPX_BIN_DIR=/usr/local/bin
pipx install pre-commit

# Install nvm (Node Version Manager) for the vscode user
echo "Installing nvm v${NVM_VERSION}..."
export NVM_DIR="/home/vscode/.nvm"
mkdir -p "${NVM_DIR}"
curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh" | PROFILE=/dev/null bash
{
    echo 'export NVM_DIR="/home/vscode/.nvm"'
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'
} >> /home/vscode/.bashrc
chown -R vscode:vscode "${NVM_DIR}"

# Install rtk (Rust Token Killer). The Claude Code hook in ~/.claude/settings.json
# (bind-mounted from the host) shells out to "rtk hook claude" on every Bash
# call, so its absence here breaks that hook inside the container even though
# the host has its own rtk install.
echo "Installing rtk v${RTK_VERSION}..."
case "$(uname -m)" in
    x86_64) RTK_TARGET="x86_64-unknown-linux-musl" ;;
    aarch64) RTK_TARGET="aarch64-unknown-linux-gnu" ;;
    *) echo "Unsupported architecture for rtk: $(uname -m)"; exit 1 ;;
esac
curl -fsSL "https://github.com/rtk-ai/rtk/releases/download/v${RTK_VERSION}/rtk-${RTK_TARGET}.tar.gz" \
    | tar -xz -C /usr/local/bin rtk
chmod +x /usr/local/bin/rtk

# Create directory for Terraform plugin cache
mkdir -p /home/vscode/.terraform.d/plugin-cache
chown -R vscode:vscode /home/vscode/.terraform.d

# Create SSH directory
mkdir -p /home/vscode/.ssh
chown -R vscode:vscode /home/vscode/.ssh
chmod 700 /home/vscode/.ssh

echo "Common utilities installation complete!"