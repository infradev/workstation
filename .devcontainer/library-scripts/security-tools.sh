#!/usr/bin/env bash
set -e

# This script installs security and linting tools: Trivy and Hadolint

# Versions
TRIVY_VERSION=${1:-"0.73.0"}
HADOLINT_VERSION=${2:-"2.15.1"}

# Detect target architecture so the right release asset is downloaded
# on both amd64 (x86_64) and arm64 (aarch64) hosts.
case "$(uname -m)" in
    x86_64|amd64)
        TRIVY_ARCH="64bit"
        HADOLINT_ARCH="x86_64"
        ;;
    aarch64|arm64)
        TRIVY_ARCH="ARM64"
        HADOLINT_ARCH="arm64"
        ;;
    *)
        echo "Unsupported architecture: $(uname -m)" >&2
        exit 1
        ;;
esac
echo "Detected architecture: Trivy=${TRIVY_ARCH} Hadolint=${HADOLINT_ARCH}"

echo "Installing Trivy v${TRIVY_VERSION}..."
curl -sSLo /tmp/trivy.tar.gz "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${TRIVY_ARCH}.tar.gz"
tar -xzf /tmp/trivy.tar.gz -C /tmp trivy
sudo mv /tmp/trivy /usr/local/bin/
sudo chmod +x /usr/local/bin/trivy
rm -f /tmp/trivy.tar.gz

echo "Installing Hadolint v${HADOLINT_VERSION}..."
curl -sSLo /tmp/hadolint "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-linux-${HADOLINT_ARCH}"
sudo mv /tmp/hadolint /usr/local/bin/
sudo chmod +x /usr/local/bin/hadolint

echo "Security tools installation complete!"
