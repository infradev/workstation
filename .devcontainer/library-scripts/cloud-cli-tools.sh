#!/usr/bin/env bash
set -e

# This script installs AWS CLI, the Session Manager plugin, Azure CLI, and
# Google Cloud SDK

# Detect target architecture so the right AWS CLI asset is downloaded
# on both amd64 (x86_64) and arm64 (aarch64) hosts.
case "$(uname -m)" in
    x86_64|amd64)
        AWS_CLI_ARCH="x86_64"
        SSM_PLUGIN_ARCH="ubuntu_64bit"
        ;;
    aarch64|arm64)
        AWS_CLI_ARCH="aarch64"
        SSM_PLUGIN_ARCH="ubuntu_arm64"
        ;;
    *)
        echo "Unsupported architecture: $(uname -m)" >&2
        exit 1
        ;;
esac

# Install AWS CLI v2
echo "Installing AWS CLI v2..."
curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_CLI_ARCH}.zip" -o /tmp/awscliv2.zip
unzip -qq /tmp/awscliv2.zip -d /tmp
sudo /tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip

# Install AWS Session Manager plugin
echo "Installing AWS Session Manager plugin..."
curl -sSL "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/${SSM_PLUGIN_ARCH}/session-manager-plugin.deb" -o /tmp/session-manager-plugin.deb
sudo apt-get install -y /tmp/session-manager-plugin.deb
rm -f /tmp/session-manager-plugin.deb

# Install Azure CLI
echo "Installing Azure CLI..."
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Google Cloud SDK
echo "Installing Google Cloud SDK..."
# apt-key was removed in Ubuntu 26.04, so dearmor the key into a keyring file
# directly and reference it from the deb line with signed-by.
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    | sudo gpg --dearmor --yes -o /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
    | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list
sudo apt-get update && sudo apt-get install -y google-cloud-cli

# Create directories for credentials
mkdir -p /home/alex/.aws
mkdir -p /home/alex/.azure
mkdir -p /home/alex/.config/gcloud

# Set proper ownership
chown -R alex:alex /home/alex/.aws
chown -R alex:alex /home/alex/.azure
chown -R alex:alex /home/alex/.config/gcloud

echo "Cloud CLI tools installation complete!"