#!/usr/bin/env bash
set -e

# This script installs common utilities and dependencies

# Versions
NVM_VERSION=${1:-"0.40.6"}

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
    software-properties-common \
    unzip \
    vim \
    wget \
    zip

# Install pre-commit
echo "Installing pre-commit..."
pip3 install pre-commit

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

# Create directory for Terraform plugin cache
mkdir -p /home/vscode/.terraform.d/plugin-cache
chown -R vscode:vscode /home/vscode/.terraform.d

# Create SSH directory
mkdir -p /home/vscode/.ssh
chown -R vscode:vscode /home/vscode/.ssh
chmod 700 /home/vscode/.ssh

echo "Common utilities installation complete!"