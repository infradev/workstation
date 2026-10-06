#!/usr/bin/env bash
set -e

# This script installs Kubernetes CLI tools not covered by devcontainer
# features: aws-iam-authenticator, krew (+ plugins), k9s, stern, kubectx/kubens
# and argocd.
# kubectl and Helm are installed via the "kubectl-helm-minikube" devcontainer feature.

# Versions
AWS_IAM_AUTHENTICATOR_VERSION=${1:-"0.7.20"}
KREW_VERSION=${2:-"0.5.0"}
K9S_VERSION=${3:-"0.51.0"}
STERN_VERSION=${4:-"1.34.0"}
KUBECTX_VERSION=${5:-"0.11.0"}
ARGOCD_VERSION=${6:-"3.5.3"}

# Detect target architecture so the right release asset is downloaded
# on both amd64 (x86_64) and arm64 (aarch64) hosts.
case "$(uname -m)" in
    x86_64|amd64)
        ARCH="amd64"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        ;;
    *)
        echo "Unsupported architecture: $(uname -m)" >&2
        exit 1
        ;;
esac
echo "Detected architecture: ${ARCH}"

echo "Installing aws-iam-authenticator v${AWS_IAM_AUTHENTICATOR_VERSION}..."
curl -sSLo /tmp/aws-iam-authenticator "https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v${AWS_IAM_AUTHENTICATOR_VERSION}/aws-iam-authenticator_${AWS_IAM_AUTHENTICATOR_VERSION}_linux_${ARCH}"
sudo mv /tmp/aws-iam-authenticator /usr/local/bin/
sudo chmod +x /usr/local/bin/aws-iam-authenticator

echo "Installing krew v${KREW_VERSION}..."
export KREW_ROOT="/home/vscode/.krew"
mkdir -p /tmp/krew-extract
curl -sSLo /tmp/krew.tar.gz "https://github.com/kubernetes-sigs/krew/releases/download/v${KREW_VERSION}/krew-linux_${ARCH}.tar.gz"
tar -xzf /tmp/krew.tar.gz -C /tmp/krew-extract
"/tmp/krew-extract/krew-linux_${ARCH}" install krew
rm -rf /tmp/krew.tar.gz /tmp/krew-extract

echo "Installing krew plugins: ctx, ns, get-all, resource-capacity..."
"${KREW_ROOT}/bin/kubectl-krew" install ctx ns get-all resource-capacity

{
    echo 'export KREW_ROOT="/home/vscode/.krew"'
    echo 'export PATH="${KREW_ROOT}/bin:${PATH}"'
} >> /home/vscode/.bashrc
chown -R vscode:vscode "${KREW_ROOT}"

echo "Installing k9s v${K9S_VERSION}..."
curl -sSLo /tmp/k9s.tar.gz "https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_Linux_${ARCH}.tar.gz"
tar -xzf /tmp/k9s.tar.gz -C /tmp k9s
sudo mv /tmp/k9s /usr/local/bin/
sudo chmod +x /usr/local/bin/k9s
rm -f /tmp/k9s.tar.gz

echo "Installing stern v${STERN_VERSION}..."
curl -sSLo /tmp/stern.tar.gz "https://github.com/stern/stern/releases/download/v${STERN_VERSION}/stern_${STERN_VERSION}_linux_${ARCH}.tar.gz"
tar -xzf /tmp/stern.tar.gz -C /tmp stern
sudo mv /tmp/stern /usr/local/bin/
sudo chmod +x /usr/local/bin/stern
rm -f /tmp/stern.tar.gz

# kubectx/kubens publish x86_64 rather than amd64 asset names. The standalone
# binaries sit alongside the krew ctx/ns plugins because the eks-onboard audit
# looks for the kubectx and kubens commands.
echo "Installing kubectx and kubens v${KUBECTX_VERSION}..."
KUBECTX_ARCH="${ARCH/amd64/x86_64}"
for tool in kubectx kubens; do
    curl -sSLo "/tmp/${tool}.tar.gz" "https://github.com/ahmetb/kubectx/releases/download/v${KUBECTX_VERSION}/${tool}_v${KUBECTX_VERSION}_linux_${KUBECTX_ARCH}.tar.gz"
    tar -xzf "/tmp/${tool}.tar.gz" -C /tmp "${tool}"
    sudo mv "/tmp/${tool}" /usr/local/bin/
    sudo chmod +x "/usr/local/bin/${tool}"
    rm -f "/tmp/${tool}.tar.gz"
done

echo "Installing argocd v${ARGOCD_VERSION}..."
curl -sSLo /tmp/argocd "https://github.com/argoproj/argo-cd/releases/download/v${ARGOCD_VERSION}/argocd-linux-${ARCH}"
sudo mv /tmp/argocd /usr/local/bin/
sudo chmod +x /usr/local/bin/argocd

echo "Kubernetes tools installation complete!"
