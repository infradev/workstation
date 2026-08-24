#!/usr/bin/env bash
set -e

# This script installs Terraform and related tools

# Versions
CHECKOV_VERSION=${12:-"3.3.13"}
INFRACOST_VERSION=${11:-"0.10.45"}
TENV_VERSION=${14:-"4.15.1"}
TERRAFORM_DOCS_VERSION=${2:-"0.24.0"}
TERRAFORM_VERSION=${1:-"1.15.8"}
TERRAGRUNT_VERSION=${9:-"1.1.2"}
TERRAMATE_VERSION=${13:-"0.17.2"}
TERRASCAN_VERSION=${4:-"1.19.9"}
TERRATEST_VERSION=${10:-"1.0.1"}
TFLINT_AWS_RULESET_VERSION=${6:-"0.48.0"}
TFLINT_AZURE_RULESET_VERSION=${7:-"0.32.0"}
TFLINT_GCP_RULESET_VERSION=${8:-"0.39.0"}
TFLINT_VERSION=${5:-"0.64.0"}
TFSEC_VERSION=${3:-"1.28.14"}

# Detect target architecture so the right release asset is downloaded
# on both amd64 (x86_64) and arm64 (aarch64) hosts.
case "$(uname -m)" in
    x86_64|amd64)
        ARCH="amd64"
        TERRASCAN_ARCH="x86_64"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        TERRASCAN_ARCH="arm64"
        ;;
    *)
        echo "Unsupported architecture: $(uname -m)" >&2
        exit 1
        ;;
esac
echo "Detected architecture: ${ARCH}"

# tenv manages OpenTofu, Terraform, Terragrunt, Terramate and Atmos. It ships
# proxy binaries in /usr/bin that pick a version per project from
# .terraform-version, .tool-versions or a required_version constraint, so those
# tools must NOT also be installed into /usr/local/bin - that directory comes
# first on PATH and would shadow the proxies.
echo "Installing tenv v${TENV_VERSION}..."
curl -sSLo /tmp/tenv.deb "https://github.com/tofuutils/tenv/releases/download/v${TENV_VERSION}/tenv_v${TENV_VERSION}_${ARCH}.deb"
sudo dpkg -i /tmp/tenv.deb
rm -f /tmp/tenv.deb

# Pre-install the pinned versions so the image works without a first-run
# download, and record each as the default that the proxies fall back to when a
# project pins nothing. Set TENV_GITHUB_TOKEN if these lookups hit GitHub API
# rate limits during a build.
export TENV_ROOT=/usr/local/share/tenv
sudo mkdir -p "${TENV_ROOT}"
sudo chown -R vscode:vscode "${TENV_ROOT}"

echo "Installing Terraform v${TERRAFORM_VERSION} via tenv..."
tenv terraform install "${TERRAFORM_VERSION}"
tenv terraform use "${TERRAFORM_VERSION}"

echo "Installing terraform-docs v${TERRAFORM_DOCS_VERSION}..."
curl -sSLo /tmp/terraform-docs.tar.gz "https://github.com/terraform-docs/terraform-docs/releases/download/v${TERRAFORM_DOCS_VERSION}/terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-${ARCH}.tar.gz"
tar -xzf /tmp/terraform-docs.tar.gz -C /tmp
sudo mv /tmp/terraform-docs /usr/local/bin/
rm -f /tmp/terraform-docs.tar.gz

echo "Installing tfsec v${TFSEC_VERSION}..."
curl -sSLo /tmp/tfsec "https://github.com/aquasecurity/tfsec/releases/download/v${TFSEC_VERSION}/tfsec-linux-${ARCH}"
sudo mv /tmp/tfsec /usr/local/bin/
sudo chmod +x /usr/local/bin/tfsec

echo "Installing terrascan v${TERRASCAN_VERSION}..."
curl -sSLo /tmp/terrascan.tar.gz "https://github.com/tenable/terrascan/releases/download/v${TERRASCAN_VERSION}/terrascan_${TERRASCAN_VERSION}_Linux_${TERRASCAN_ARCH}.tar.gz"
tar -xzf /tmp/terrascan.tar.gz -C /tmp
sudo mv /tmp/terrascan /usr/local/bin/
rm -f /tmp/terrascan.tar.gz

echo "Installing tflint v${TFLINT_VERSION}..."
curl -sSLo /tmp/tflint.zip "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_${ARCH}.zip"
unzip -qq /tmp/tflint.zip -d /tmp
sudo mv /tmp/tflint /usr/local/bin/
rm -f /tmp/tflint.zip

echo "Installing TFLint AWS ruleset v${TFLINT_AWS_RULESET_VERSION}..."
mkdir -p ~/.tflint.d/plugins
curl -sSLo /tmp/tflint-aws-ruleset.zip "https://github.com/terraform-linters/tflint-ruleset-aws/releases/download/v${TFLINT_AWS_RULESET_VERSION}/tflint-ruleset-aws_linux_${ARCH}.zip"
unzip -qq /tmp/tflint-aws-ruleset.zip -d ~/.tflint.d/plugins
rm -f /tmp/tflint-aws-ruleset.zip

echo "Installing TFLint Azure ruleset v${TFLINT_AZURE_RULESET_VERSION}..."
curl -sSLo /tmp/tflint-azure-ruleset.zip "https://github.com/terraform-linters/tflint-ruleset-azurerm/releases/download/v${TFLINT_AZURE_RULESET_VERSION}/tflint-ruleset-azurerm_linux_${ARCH}.zip"
unzip -qq /tmp/tflint-azure-ruleset.zip -d ~/.tflint.d/plugins
rm -f /tmp/tflint-azure-ruleset.zip

echo "Installing TFLint GCP ruleset v${TFLINT_GCP_RULESET_VERSION}..."
curl -sSLo /tmp/tflint-gcp-ruleset.zip "https://github.com/terraform-linters/tflint-ruleset-google/releases/download/v${TFLINT_GCP_RULESET_VERSION}/tflint-ruleset-google_linux_${ARCH}.zip"
unzip -qq /tmp/tflint-gcp-ruleset.zip -d ~/.tflint.d/plugins
rm -f /tmp/tflint-gcp-ruleset.zip

echo "Installing Terragrunt v${TERRAGRUNT_VERSION} via tenv..."
tenv terragrunt install "${TERRAGRUNT_VERSION}"
tenv terragrunt use "${TERRAGRUNT_VERSION}"

echo "Installing Terratest v${TERRATEST_VERSION}..."
# Terratest is a Go library, so we'll set an environment variable to track the version
echo "export TERRATEST_VERSION=${TERRATEST_VERSION}" >> /home/vscode/.bashrc

# Install Go if not already installed
if ! command -v go &> /dev/null; then
    echo "Installing Go (required for Terratest)..."
    GO_VERSION="1.20.5"
    curl -sSLo /tmp/go.tar.gz "https://golang.org/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz"
    sudo tar -C /usr/local -xzf /tmp/go.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /home/vscode/.bashrc
    echo 'export PATH=$PATH:$HOME/go/bin' >> /home/vscode/.bashrc
    rm -f /tmp/go.tar.gz
fi

# Create a simple wrapper script for terratest
cat > /tmp/terratest << EOF
#!/bin/bash
echo "Terratest v${TERRATEST_VERSION}"
echo "Terratest is a Go library for testing infrastructure code."
echo "To use Terratest, add it to your Go project:"
echo "go get github.com/gruntwork-io/terratest@v${TERRATEST_VERSION}"
EOF
sudo mv /tmp/terratest /usr/local/bin/
sudo chmod +x /usr/local/bin/terratest

echo "Installing Infracost v${INFRACOST_VERSION}..."
curl -sSLo /tmp/infracost.tar.gz "https://github.com/infracost/infracost/releases/download/v${INFRACOST_VERSION}/infracost-linux-${ARCH}.tar.gz"
tar -xzf /tmp/infracost.tar.gz -C /tmp
sudo mv "/tmp/infracost-linux-${ARCH}" /usr/local/bin/infracost
rm -f /tmp/infracost.tar.gz

echo "Installing Checkov v${CHECKOV_VERSION}..."
# PEP 668: install into a pipx-managed venv instead of the system Python.
sudo PIPX_HOME=/usr/local/pipx PIPX_BIN_DIR=/usr/local/bin \
    pipx install "checkov==${CHECKOV_VERSION}"

echo "Installing Terramate v${TERRAMATE_VERSION} via tenv..."
tenv terramate install "${TERRAMATE_VERSION}"
tenv terramate use "${TERRAMATE_VERSION}"

# Create .tflint.hcl config file
mkdir -p /home/vscode/.tflint.d
cat > /home/vscode/.tflint.hcl << EOF
plugin "aws" {
  enabled = true
}

plugin "azurerm" {
  enabled = true
}

plugin "google" {
  enabled = true
}
EOF

# Set ownership for the config file
chown -R vscode:vscode /home/vscode/.tflint.d

# tenv needs to stay writable so auto-install can add versions at runtime
sudo chown -R vscode:vscode "${TENV_ROOT}"

echo "Terraform tools installation complete!"
