# Base image tag. Tool version pins are installed by the Debian Ansible role
# at postCreate, not in this image.
ARG VARIANT
FROM mcr.microsoft.com/devcontainers/base:${VARIANT}

# The base image's default non-root user is "vscode" (created at its own
# build time); rename it to alex before any later step assumes that username.
# usermod -m moves the home directory contents; UID/GID and group memberships
# (sudo, docker) carry over unchanged, so alex keeps every capability vscode had.
USER root
RUN usermod -l alex -m -d /home/alex vscode \
    && groupmod -n alex vscode \
    && if [ -f /etc/sudoers.d/vscode ]; then \
      sed -i 's/\bvscode\b/alex/g' /etc/sudoers.d/vscode \
      && mv /etc/sudoers.d/vscode /etc/sudoers.d/alex; \
    fi

# Git identity used for commits made inside the container. Ansible's base
# role sets the same values again when postCreate runs the playbook.
ARG GIT_USER_EMAIL
ARG GIT_USER_NAME

# Copy scripts
COPY scripts /home/alex/.devcontainer/scripts
RUN chmod +x /home/alex/.devcontainer/scripts/*.sh
RUN chown -R alex:alex /home/alex/.devcontainer

# direnv itself is installed by the Debian role, which also writes
# ~/.config/direnv/direnvrc. The hook is a no-op until both exist.
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

# Ansible installs the toolchain, Azure CLI, Session Manager plugin, and
# pre-commit at postCreate. The binary has to be in the image so that can run.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ansible-core \
    && ansible-galaxy collection install -p /usr/share/ansible/collections community.general \
    && rm -rf /root/.ansible /root/.cache \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Copy lifecycle scripts
COPY post-start.sh /usr/local/bin/post-start
COPY post-create.sh /usr/local/bin/post-create
RUN chmod +x /usr/local/bin/post-start /usr/local/bin/post-create

# Switch back to the non-root alex user
USER alex

# Bind-mounted trees are usually owned by a different uid than the container
# user. Trust every repository under these directories so git does not refuse
# with "detected dubious ownership". The Claude directory includes the
# temporary clones created by `claude plugin install`.
RUN git config --global --add safe.directory "/workspaces/*" \
    && git config --global --add safe.directory "/home/alex/.claude/*" \
    && git config --global user.name "${GIT_USER_NAME}" \
    && git config --global user.email "${GIT_USER_EMAIL}"
