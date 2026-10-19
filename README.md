# workstation

Ansible playbook and Dev Container that install one infrastructure toolchain on a Mac, an Ubuntu host, and a Linux container. The playbook is the list of tools. The container runs that playbook on create and keeps cloud logins in the project, separate from the laptop.

## Contents

- [Requirements](#requirements)
- [Provision this machine](#provision-this-machine)
- [Provision a remote Ubuntu host](#provision-a-remote-ubuntu-host)
- [Open the Dev Container](#open-the-dev-container)
- [Layout](#layout)
- [What the playbook installs](#what-the-playbook-installs)
- [Shell, git, and editor](#shell-git-and-editor)
- [Dev Container credentials](#dev-container-credentials)
- [Optional Compose services](#optional-compose-services)
- [Claude Code plugins](#claude-code-plugins)
- [Extending a copy of the Dev Container](#extending-a-copy-of-the-dev-container)
- [Checks](#checks)
- [Changing the toolchain](#changing-the-toolchain)

## Requirements

| Surface | Needs |
| --- | --- |
| macOS | Homebrew, then `brew install ansible`. Apple silicon and Intel are both supported. |
| Ubuntu host | 24.04 or 26.04, `x86_64` or `aarch64`, with `sudo apt-get install -y ansible-core`. Apt repos for those four combinations live in `ansible/workstation/roles/debian/vars/`. |
| Dev Container | Docker, and Cursor or VS Code with Dev Containers. The image is `mcr.microsoft.com/devcontainers/base`. `VARIANT` in `.devcontainer/.env` selects the tag (`ubuntu26.04`). |

The account that runs the playbook must already be able to `sudo`. `make run` refreshes the sudo timestamp once (`sudo -v`) and then relies on that cache for every `become` task.

## Provision this machine

```sh
cd ansible/workstation
make install
make run
```

`make install` installs the `community.general` Ansible collection.

`make run` runs `ansible-playbook -i inventory ansible.yml` on localhost. The playbook gathers facts, applies `base`, then `debian` or `macos` from `ansible_os_family`, then `roles/base/tasks/finalize.yml`. Finalize installs Claude Code plugins, the `gh act` extension, Krew plugins, and on macOS the Cursor marketplaces.

## Provision a remote Ubuntu host

Cloud images usually accept SSH as `ubuntu`. Create the workstation user before the playbook runs:

```sh
cd ansible/workstation
make bootstrap-user HOST=1.2.3.4
```

`REMOTE_USER` defaults to `ubuntu`. The command creates `alex` when that account is missing, copies `authorized_keys` from the user you SSH in as, locks the password with `passwd -l`, and writes a `NOPASSWD` sudoers drop-in. Connect with Cursor Remote SSH as `alex@HOST`, clone this repo under that home directory, then run `make install` and `make run` there.

## Open the Dev Container

1. Open this repository in Cursor or VS Code.
2. Reopen in Container. Compose starts the `workstation` service from `.devcontainer/compose.yaml`. The container name and hostname follow the project directory.
3. `initializeCommand` sets `.devcontainer/.creds/ssh` to mode `700`.
4. `postCreateCommand` (`post-create`) runs the playbook with `--skip-tags host` when `ansible/workstation/ansible.yml` is in the workspace.
5. `postStartCommand` (`post-start`) prints installed versions and the sign-in steps still pending.

The `host` tag is the full apt upgrade plus `host_packages` (OpenSSH, certbot, Docker CE). Docker inside the container comes from the Docker-in-Docker feature (`ghcr.io/devcontainers/features/docker-in-docker`), which is the one piece the playbook does not install.

The image carries Ansible so that create step can run. Package and binary pins are applied by the Debian role, from `tool_versions` in `ansible/workstation/roles/debian/vars/main.yml`. A workspace without `ansible/workstation` skips the playbook and stays on the base image plus Ansible.

The container user is `alex`, renamed from the base image user `vscode` with the same uid, gid, and group memberships. The workspace is bind-mounted, so git is configured with `safe.directory` for `/workspaces/*`.

## Layout

```text
ansible/workstation/     playbook, local inventory, Makefile
  ansible.yml            base, then debian or macos, then finalize
  roles/base/            home layout, shell, git, editor, plugins
  roles/debian/          apt repos, packages, GitHub binaries, tenv
  roles/macos/           Homebrew formulae, casks, Cursor extensions
.devcontainer/           image, Compose, lifecycle and auth scripts
tests/                   var, settings, image, and provision checks
.github/workflows/workstation.yml
```

## What the playbook installs

Role vars are the lists. The playbook and `tests/verify_provision.sh` read them, so a pin changed only in the README would be wrong. Edit the file in this table.

| Concern | File |
| --- | --- |
| Home directories, shell templates, git repos to clone, editor settings, Claude marketplaces and plugins, Krew plugins | `ansible/workstation/roles/base/vars/main.yml` |
| Ubuntu packages, `.deb` downloads, GitHub release binaries, pipx packages, tenv installs, `tool_versions` | `ansible/workstation/roles/debian/vars/main.yml` |
| Apt repositories for one architecture and Ubuntu major version | `ansible/workstation/roles/debian/vars/<arch>-<major>.yml` |
| Homebrew formulae, casks, and macOS-only editor extensions | `ansible/workstation/roles/macos/vars/main.yml` |

On Ubuntu the Debian role installs the cloud CLIs (AWS, Azure, gcloud, GitHub, GitLab, Session Manager), Kubernetes tools (kubectl, Helm, helmfile, kind, k9s, Krew, kubectx, stern, Argo CD, aws-iam-authenticator), Terraform tools (tenv with pinned Terraform, Terragrunt, and Terramate; tflint plus the AWS, Azure, and GCP rulesets; terraform-docs, infracost, checkov, tfsec, terrascan, sops), and the shell utilities (direnv, nvm, uv, yq, hadolint, trivy, pre-commit, jq). tenv comes from the tofuutils Cloudsmith apt repo at the version in `tool_versions.tenv`.

On macOS the Homebrew lists cover the same CLI surface, plus casks for Docker Desktop, Cursor, Claude, gcloud, and the desktop apps in `homebrew_cask`. Cursor extensions are `vscode.extensions.common` plus `client_extensions` (Remote SSH and Dev Containers). The Debian host does not run `cursor --install-extension`; the Dev Container installs its extension set from `customizations.vscode` in `.devcontainer/devcontainer.json`.

`host_packages` (OpenSSH, certbot, Docker CE and its plugins) install on an Ubuntu machine. The Dev Container skips that tag.

Krew plugins (`ctx`, `get-all`, `ns`, `resource-capacity`) install in finalize, after the OS role. The Dev Container does not install them again on start.

## Shell, git, and editor

The `base` role writes these under `$HOME`:

- `.bash_profile` and `.bash_aliases`, both sourced from `.bashrc`
- `.config/direnv/direnvrc` and `projects/.envrc.example`
- `home.code-workspace`, with folders `.` and `projects` and the settings block for the current OS. Open that file in Cursor, locally or over Remote SSH, for one workspace over the home directory and `~/projects`.
- `.claude/CLAUDE.md` with `force: false`. A later tool may append to it; a second playbook run leaves the file in place.
- On macOS, `.cursor/rules/workstation.mdc` with `alwaysApply: true` and the same instructions. Cursor loads that file.

Git commits use `Alexandre Souza` / `alexandre@infradev.com.br`. The base role writes that into `~/.gitconfig`. The image build writes it again from `.devcontainer/.env`. Change both places together. The role also sets `core.editor` to `vim` and clones `https://github.com/infradev/workstation.git` into `~/projects/infradev/workstation` (`update: no`, errors ignored). A copied devcontainer downloads that same public `main` tree in `post-create` when the project does not contain the playbook, then removes `.git`.

Finalize in the base role turns off agent signatures in the user config, on the host and in the container. `~/.claude/settings.json` gets `includeCoAuthoredBy` set to false. `~/.cursor/cli-config.json` gets `attributeCommitsToAgent` and `attributePRsToAgent` set to false. Other keys in those files stay.

The playbook cannot turn off attribution in the Cursor IDE. Open Cursor Settings, then Source Control, then Attribution. Turn off Commit Attribution and PR Attribution. Commit Attribution is the switch described as Mark Agent commits as 'Made with Cursor'. The playbook prints this reminder on the console.

These variables are set in `.bash_profile` and, in the container, in `containerEnv`:

| Variable | Value |
| --- | --- |
| `TENV_ROOT` | `~/.local/share/tenv` (`/home/alex/.local/share/tenv` in the container) |
| `TENV_AUTO_INSTALL` | `true` |
| `TF_PLUGIN_CACHE_DIR` | `~/.terraform.d/plugin-cache` |
| `TENV_GITHUB_TOKEN` | Optional. The container reads `${localEnv:TENV_GITHUB_TOKEN}` from the host. The Debian role forwards it into `tenv` when it is set. An empty value leaves tenv on unauthenticated GitHub lookups. |
| `CLAUDE_CONFIG_DIR` | `/home/alex/.claude` in the Dev Container, matching the project credential mount. A machine provisioned by Ansible uses `~/.claude` with no override. |

## Dev Container credentials

Logins are bind-mounted from `.devcontainer/.creds/<name>` in the workspace. The directories are in git as empty `.gitkeep` skeletons. Everything inside them is gitignored. The ignore rules are in `.devcontainer/.gitignore`. A subtree checkout uses that file. Each project has its own AWS, Azure, gcloud, SSH, kubeconfig, Terraform (`terraform.d`, including the plugin cache volume nested under it), GitLab CLI, and Claude config.

The mounts start empty. Sign in inside the container and the files stay in that project's `.creds` directory:

| System | Command |
| --- | --- |
| AWS | `.devcontainer/scripts/aws-auth.sh`, or `aws sso login` / `aws configure` |
| Azure | `.devcontainer/scripts/azure-auth.sh`, or `az login` |
| GCP | `.devcontainer/scripts/gcp-auth.sh`, or `gcloud auth login` |
| GitHub | `gh auth login` |
| GitLab | `glab auth login`. Add the project SSH key on GitLab when clones use SSH. |
| Terraform Cloud | `terraform login`, or set `TF_TOKEN_app_terraform_io` |
| Claude Code | Sign in once in that project. The session is the one stored under `.creds/claude`. |
| SSH | Copy the private key into `.devcontainer/.creds/ssh/` and `chmod 600` it. |

`terraform login` rewrites `credentials.tfrc.json` by rename, so the whole `.terraform.d` directory is mounted. A single-file bind would reject that rename.

## Reuse with git subtree

Put this `.devcontainer` directory into another repository with `git subtree`. Each checkout keeps its own `.creds` files. Those files stay untracked, so `git push` does not send them. A later pull does not change untracked files in `.creds`.

Publish the directory from this repository after you commit the `.devcontainer` changes:

1. Run `git subtree push --prefix=.devcontainer origin devcontainer`.

In the other repository, for a first add:

1. If the directory is not a Git repository yet, run `git init -b main`.
2. If you ran that command, run `git commit --allow-empty -m "chore: initial commit"`. `git subtree add` needs a commit on the branch.
3. Run `git subtree add --prefix=.devcontainer --squash git@github.com:infradev/workstation.git devcontainer`.
4. Sign in inside the container. Git stores the login files only in that project's `.devcontainer/.creds` directory.

To bring in later changes:

1. Run `git subtree pull --prefix=.devcontainer --squash git@github.com:infradev/workstation.git devcontainer`.

If that repository already contains a `.devcontainer` directory:

1. Copy `.devcontainer/.creds` to a path outside the repository.
2. Remove `.devcontainer` with `git rm -r .devcontainer`.
3. Commit that removal.
4. Run the `git subtree add` command above.
5. Copy the saved `.creds` directory back to `.devcontainer/.creds`.

Do not run `git add -f` on `.creds`. That command tracks the login files. A later push then sends them.

## Optional Compose services

Compose starts `workstation` only. `.devcontainer/compose.yaml` has commented examples for Postgres 17, MySQL 8.4, Floci on port 4566 (AWS endpoint `http://floci:4566`), and floci-gcp on port 4588. Uncomment the services that project needs and rebuild the container.

kind runs as a CLI in the dev container. `kind create cluster` uses the Docker daemon from Docker-in-Docker.

## Claude Code plugins

`roles/base/tasks/finalize.yml` registers every repo in `ai.marketplaces` and installs every id in `ai.plugins` (`roles/base/vars/main.yml`). It also adds or updates `anthropics/claude-plugins-official` before the official plugin installs. On macOS the same marketplace repos are registered with `cursor-agent`. Those tasks ignore errors, so a missing `claude` login does not fail the rest of the run.

Add a plugin by appending the marketplace repo (skip this for `claude-plugins-official`) and the `plugin@marketplace` id, then run the playbook again. The marketplace key is the `name` in that repo's `.claude-plugin/marketplace.json`, which can differ from the GitHub repo name.

Skills that ship as a `SKILL.md` directory, with no marketplace manifest, are `ai.manual_skills` in `roles/base/vars/main.yml`. Finalize clones each one into `~/.claude/skills/` (a sparse checkout when `subpath` is set), links that directory into `~/.cursor/skills/`, and runs `npx apex-skills`. A skill directory that already exists is left in place.

## Extending a copy of the Dev Container

`post-start` sources `/home/alex/.devcontainer/scripts/extended.sh` when that file exists. The image copies `.devcontainer/scripts` to that path at build time. An `extended.sh` in a project can append to the `pending` array printed under "Next Steps" (private marketplaces, named SSO sessions, internal setup). Keep that file in the checkout that needs it.

## Checks

`.github/workflows/workstation.yml` runs on push, pull request, and `workflow_dispatch`. The three jobs start together.

| Job | What it runs |
| --- | --- |
| `ansible` | `ansible-playbook --syntax-check`, `--list-tasks`, and `tests/check_ansible_vars.sh` |
| `settings` | `tests/check_settings.sh`, which checks that the Dockerfile, `devcontainer.json`, and `.env` agree. `.env` holds `VARIANT` and the git identity. |
| `devcontainer` | `docker build` of `.devcontainer`, then `tests/verify_image.sh`, then `post-create` and `tests/verify_provision.sh` inside the image |

`verify_provision.sh` checks packages, pinned binaries, host packages absent after `--skip-tags host`, Krew plugins, and the tenv-managed tools. The provision job passes `GH_TOKEN` from `secrets.GITHUB_TOKEN` so `gh extension install` can reach GitHub.

Run the same workflow locally with [act](https://github.com/nektos/act). `.actrc` selects the runner image:

```sh
gh act -s GITHUB_TOKEN="$(gh auth token)"
```

`tests/lib.sh` downloads `yq` at the pinned version when it is missing. On GitHub the jobs check out the repo. Under act the workspace is already mounted, and those jobs skip `actions/checkout` (`env.ACT != 'true'`).

## Changing the toolchain

| Change | Edit |
| --- | --- |
| Ubuntu package or pinned binary | `roles/debian/vars/main.yml` (`packages`, `remote_executables`, `remote_packages`, `tool_versions`) |
| Apt repository or a new Ubuntu release | a new or existing `roles/debian/vars/<arch>-<major>.yml` |
| macOS formula, cask, or client extension | `roles/macos/vars/main.yml` |
| Shared editor extension or setting | `roles/base/vars/main.yml` (`vscode`) and `.devcontainer/devcontainer.json` (`customizations.vscode`) |
| Claude marketplace or plugin | `roles/base/vars/main.yml` (`ai.marketplaces`, `ai.plugins`) |
| Manual-install skill | `roles/base/vars/main.yml` (`ai.manual_skills`) |
| Krew plugin | `roles/base/vars/main.yml` (`krew_plugins`) |
| Image tag | `VARIANT` in `.devcontainer/.env` |
| Git identity | `.devcontainer/.env` and the `git_config` tasks in `roles/base/tasks/main.yml` |
| Container environment variable | `containerEnv` in `devcontainer.json` and `roles/base/templates/bash_profile.j2` |
