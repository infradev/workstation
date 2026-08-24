ARG VARIANT="resolute"
FROM mcr.microsoft.com/devcontainers/base:${VARIANT}

# Set versions as arguments
ARG ACT_VERSION="0.2.89"
ARG AWS_IAM_AUTHENTICATOR_VERSION="0.7.19"
ARG CHECKOV_VERSION="3.3.13"
ARG HADOLINT_VERSION="2.15.1"
ARG INFRACOST_VERSION="0.10.45"
ARG K9S_VERSION="0.51.0"
ARG KREW_VERSION="0.5.0"
ARG NVM_VERSION="0.40.7"
ARG TENV_VERSION="4.15.1"
ARG TERRAFORM_DOCS_VERSION="0.24.0"
ARG TERRAFORM_VERSION="1.15.9"
ARG TERRAGRUNT_VERSION="1.1.3"
ARG TERRAMATE_VERSION="0.17.2"
ARG TERRASCAN_VERSION="1.19.9"
ARG TERRATEST_VERSION="1.0.1"
ARG TFLINT_AWS_RULESET_VERSION="0.48.0"
ARG TFLINT_AZURE_RULESET_VERSION="0.32.0"
ARG TFLINT_GCP_RULESET_VERSION="0.39.0"
ARG TFLINT_VERSION="0.64.0"
ARG TFSEC_VERSION="1.28.14"
ARG TRIVY_VERSION="0.74.0"

# Git identity used for commits made inside the container
ARG GIT_USER_EMAIL="alexandre@infradev.com.br"
ARG GIT_USER_NAME="Alexandre Souza"

# Copy library scripts
COPY library-scripts/*.sh /tmp/library-scripts/
RUN chmod +x /tmp/library-scripts/*.sh

# Install common utilities and dependencies
USER root
RUN /tmp/library-scripts/common-utils.sh "${NVM_VERSION}"

# Install cloud CLI tools
RUN /tmp/library-scripts/cloud-cli-tools.sh

# Install Terraform and related tools.
# tenv resolves Terragrunt/Terramate/OpenTofu versions through the GitHub API,
# which rate-limits unauthenticated builds. The token is mounted as a BuildKit
# secret so it never lands in an image layer; an absent secret just falls back
# to unauthenticated lookups.
RUN --mount=type=secret,id=tenv_github_token \
    export TENV_GITHUB_TOKEN="$(cat /run/secrets/tenv_github_token 2>/dev/null || true)" \
    && /tmp/library-scripts/terraform-tools.sh \
    "${TERRAFORM_VERSION}" \
    "${TERRAFORM_DOCS_VERSION}" \
    "${TFSEC_VERSION}" \
    "${TERRASCAN_VERSION}" \
    "${TFLINT_VERSION}" \
    "${TFLINT_AWS_RULESET_VERSION}" \
    "${TFLINT_AZURE_RULESET_VERSION}" \
    "${TFLINT_GCP_RULESET_VERSION}" \
    "${TERRAGRUNT_VERSION}" \
    "${TERRATEST_VERSION}" \
    "${INFRACOST_VERSION}" \
    "${CHECKOV_VERSION}" \
    "${TERRAMATE_VERSION}" \
    "${TENV_VERSION}"

# Install Kubernetes CLI tools (aws-iam-authenticator, krew + plugins, k9s)
RUN /tmp/library-scripts/kubernetes-tools.sh \
    "${AWS_IAM_AUTHENTICATOR_VERSION}" \
    "${KREW_VERSION}" \
    "${K9S_VERSION}"

# Install security and linting tools (Trivy, Hadolint)
RUN /tmp/library-scripts/security-tools.sh \
    "${TRIVY_VERSION}" \
    "${HADOLINT_VERSION}"

# Copy scripts and configuration
COPY scripts /home/vscode/.devcontainer/scripts
COPY config /home/vscode/.devcontainer/config
RUN chmod +x /home/vscode/.devcontainer/scripts/*.sh
RUN chown -R vscode:vscode /home/vscode/.devcontainer

# Set up Terraform plugin cache directory
RUN mkdir -p /home/vscode/.terraform.d/plugin-cache \
    && chown -R vscode:vscode /home/vscode/.terraform.d

# Set up credential directories
RUN mkdir -p /home/vscode/.aws \
    && mkdir -p /home/vscode/.azure \
    && mkdir -p /home/vscode/.config/gcloud \
    && mkdir -p /home/vscode/.ssh \
    && chown -R vscode:vscode /home/vscode/.aws \
    && chown -R vscode:vscode /home/vscode/.azure \
    && chown -R vscode:vscode /home/vscode/.config \
    && chown -R vscode:vscode /home/vscode/.ssh \
    && chmod 700 /home/vscode/.ssh

# Clean up
RUN apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/library-scripts

# Copy post-start script
COPY post-start.sh /usr/local/bin/post-start
RUN chmod +x /usr/local/bin/post-start

# Switch back to vscode user
USER vscode

# The workspace is bind-mounted from the host, so its files are usually owned by
# a different uid than the container user. Trust every repository under
# /workspaces so git does not refuse with "detected dubious ownership".
RUN git config --global --add safe.directory "/workspaces/*" \
    && git config --global user.name "${GIT_USER_NAME}" \
    && git config --global user.email "${GIT_USER_EMAIL}"
