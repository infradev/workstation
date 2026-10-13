ARG VARIANT="resolute"
FROM mcr.microsoft.com/devcontainers/base:${VARIANT}

# The base image's default non-root user is "vscode" (created at its own
# build time); rename it to alex before any later step - including
# library-scripts/*.sh - assumes that username. usermod -m moves the home
# directory contents; UID/GID and group memberships (sudo, docker) carry
# over unchanged, so alex keeps every capability vscode had.
USER root
RUN usermod -l alex -m -d /home/alex vscode \
    && groupmod -n alex vscode

# Set versions as arguments
ARG ARGOCD_VERSION="3.5.3"
ARG AWS_IAM_AUTHENTICATOR_VERSION="0.7.19"
ARG CHECKOV_VERSION="3.3.13"
ARG GLAB_VERSION="1.121.0"
ARG HADOLINT_VERSION="2.15.1"
ARG INFRACOST_VERSION="0.10.45"
ARG K9S_VERSION="0.51.0"
ARG KREW_VERSION="0.5.0"
ARG KUBECTX_VERSION="0.11.0"
ARG NVM_VERSION="0.40.7"
ARG RTK_VERSION="0.51.0"
ARG STERN_VERSION="1.34.0"
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
ARG UV_VERSION="0.12.23"
ARG YQ_VERSION="4.54.1"

# Git identity used for commits made inside the container
ARG GIT_USER_EMAIL="alexandre@infradev.com.br"
ARG GIT_USER_NAME="Alexandre Souza"

# Copy library scripts
COPY library-scripts/*.sh /tmp/library-scripts/
RUN chmod +x /tmp/library-scripts/*.sh

# Install common utilities and dependencies
USER root
RUN /tmp/library-scripts/common-utils.sh \
    "${NVM_VERSION}" \
    "${RTK_VERSION}" \
    "${YQ_VERSION}" \
    "${GLAB_VERSION}" \
    "${UV_VERSION}"

# Install cloud CLI tools
RUN /tmp/library-scripts/cloud-cli-tools.sh

# Install Terraform and related tools.
# tenv resolves Terragrunt/Terramate/OpenTofu versions through the GitHub API,
# which rate-limits unauthenticated builds. TENV_GITHUB_TOKEN is set via
# containerEnv (devcontainer.json) for the running container, not available
# at this build step - an absent/unset token here just falls back to
# unauthenticated lookups.
RUN /tmp/library-scripts/terraform-tools.sh \
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

# Install Kubernetes CLI tools (aws-iam-authenticator, krew + plugins, k9s,
# stern, kubectx/kubens, argocd)
RUN /tmp/library-scripts/kubernetes-tools.sh \
    "${AWS_IAM_AUTHENTICATOR_VERSION}" \
    "${KREW_VERSION}" \
    "${K9S_VERSION}" \
    "${STERN_VERSION}" \
    "${KUBECTX_VERSION}" \
    "${ARGOCD_VERSION}"

# Install security and linting tools (Trivy, Hadolint)
RUN /tmp/library-scripts/security-tools.sh \
    "${TRIVY_VERSION}" \
    "${HADOLINT_VERSION}"

# Copy scripts and configuration
COPY scripts /home/alex/.devcontainer/scripts
COPY config /home/alex/.devcontainer/config
RUN chmod +x /home/alex/.devcontainer/scripts/*.sh
RUN chown -R alex:alex /home/alex/.devcontainer

# direnv global config (mirrors ansible/workstation's direnvrc.j2). The
# direnv binary itself comes from the apt-packages feature, applied after
# this Dockerfile builds - the bash hook below is a runtime guard, so it's a
# harmless no-op until then.
COPY --chown=alex:alex config/direnvrc /home/alex/.config/direnv/direnvrc
RUN echo 'command -v direnv >/dev/null 2>&1 && eval "$(direnv hook bash)"' >> /home/alex/.bashrc

# Set up Terraform plugin cache directory
RUN mkdir -p /home/alex/.terraform.d/plugin-cache \
    && chown -R alex:alex /home/alex/.terraform.d

# Set up credential directories
RUN mkdir -p /home/alex/.aws \
    && mkdir -p /home/alex/.azure \
    && mkdir -p /home/alex/.config/gcloud \
    && mkdir -p /home/alex/.ssh \
    && chown -R alex:alex /home/alex/.aws \
    && chown -R alex:alex /home/alex/.azure \
    && chown -R alex:alex /home/alex/.config \
    && chown -R alex:alex /home/alex/.ssh \
    && chmod 700 /home/alex/.ssh

# Clean up
RUN apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/library-scripts

# Copy post-start script
COPY post-start.sh /usr/local/bin/post-start
RUN chmod +x /usr/local/bin/post-start

# Switch back to the non-root alex user
USER alex

# The workspace is bind-mounted from the host, so its files are usually owned by
# a different uid than the container user. Trust every repository under
# /workspaces so git does not refuse with "detected dubious ownership".
RUN git config --global --add safe.directory "/workspaces/*" \
    && git config --global user.name "${GIT_USER_NAME}" \
    && git config --global user.email "${GIT_USER_EMAIL}"
