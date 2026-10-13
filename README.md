# iac

Infra bootstrap tooling: an Ansible-based workstation setup (`ansible/workstation`) covering both the local macOS dev machine and remote Debian/Ubuntu boxes, plus a generic Terraform/Kubernetes devcontainer (`.devcontainer`).

## Project layout

- `ansible/workstation/` - playbook (`ansible.yml`) with three roles:
  - `base` - OS-agnostic. `directories`/`files` are plain lists of paths relative to `local_home` (an `ansible_env.HOME` fact, falling back to a `lookup('env', 'HOME')`); two generic tasks join `local_home` on and create them, rendering a `template` via Jinja when a `files` entry declares one (covers `.bash_profile`/`.bash_aliases`, `~/home.code-workspace`, and `~/.claude/CLAUDE.md` - the latter is `force: false` so a tool like `plat-context:setup` can safely append a managed block later without it ever being clobbered on rerun). Also owns `vscode` (a tree: `extensions.common`/`extensions.client_only`, plus a JSONC `settings` block with one OS-conditional bit) and `claude` (`marketplaces`/`plugins`), both branched by `ansible_facts['os_family']`. A second pass (`tasks_from: finalize`, after debian/macos install the `claude-code` binary) installs all the Claude Code plugins/marketplaces from `claude.marketplaces`/`claude.plugins` (every tier below that's `/plugin`-installable - see "Manual-install skills" for the ones that aren't).
  - `debian` - packages, apt repos (keyring-based signing, not the deprecated `apt_key`), per-arch/per-release tool versions (`vars/<arch>-<major>.yml`, currently Ubuntu 24.04/26.04 on x86_64/aarch64) - for a headless SSH remote target, so no GUI-requiring packages are installed.
  - `macos` - Homebrew packages/casks (GUI apps included - this is the local client machine) and Cursor extensions.
- `.devcontainer/` - a generic, org-agnostic devcontainer. Anything team/org-specific (internal marketplaces, named SSO sessions, etc.) does **not** live here - see "Extending the devcontainer" below.

## Running the Ansible playbook

```sh
cd ansible/workstation
make install   # one-time: ansible-galaxy collection install community.general
make run       # sudo -v (asks for your password once), then ansible-playbook -i inventory ansible.yml
```

Runs against localhost, picking the `debian` or `macos` role by `ansible_os_family`. `make run` only asks for your sudo password once, at the top (`sudo -v`), relying on sudo's own timestamp cache for every `become:` task after that - not Ansible's separate `--ask-become-pass` prompt.

### Bootstrapping a fresh remote box for Cursor Remote-SSH

Cloud VMs usually ship with a default `ubuntu` user. Before `make run` can target a dedicated user:

```sh
make bootstrap-user HOST=1.2.3.4 [REMOTE_USER=ubuntu]
```

Creates a passwordless (`passwd -l`, locked - not `passwd -d`, which would leave an exploitable empty password field), NOPASSWD-sudo `alex` user, copying `ubuntu`'s `~/.ssh/authorized_keys` so Cursor can connect as `alex@HOST` right away - password auth stays disabled, only the existing SSH key works.

## home.code-workspace

The `base` role writes `~/home.code-workspace` with two folders (`.` and `projects`) plus the OS-appropriate `vscode` settings block, so opening that file in Cursor (locally or over Remote-SSH) gives one workspace covering the home directory and `~/projects`.

## Generic post-install checklist

A few things ansible and the devcontainer deliberately can't do for you (interactive logins to external accounts):

- **AWS**: `aws sso login` or `aws configure` (or `.devcontainer/scripts/aws-auth.sh` inside the devcontainer)
- **Azure**: `az login` (or `.devcontainer/scripts/azure-auth.sh` inside the devcontainer)
- **GCP**: `gcloud auth login` (or `.devcontainer/scripts/gcp-auth.sh`)
- **GitHub**: `gh auth login`
- **GitLab**: `glab auth login`, and add your SSH key to GitLab if repos are cloned over SSH
- **Terraform Cloud**: `terraform login` (or set `TF_TOKEN_app_terraform_io`)

## Devcontainer: user and credential isolation

The devcontainer's remote user is `alex` (renamed from the base image's default `vscode` in the Dockerfile's first `RUN`, before anything else depends on the username - same UID/GID and group memberships, so it keeps every capability `vscode` had).

Cloud/tool credentials - AWS, Azure, GCP, SSH, kube, Terraform Cloud (via `.terraform.d`), GitLab CLI, and Claude Code's own login/settings - are bind-mounted from `${localWorkspaceFolder}/.devcontainer/.creds/<name>` (gitignored), **not** the host's global `~/.aws` etc. Each project/client gets its own isolated set of logins instead of every devcontainer on the laptop sharing - and being able to see - the same credentials. First time opening a project's devcontainer, these start empty:

- Run the usual auth commands inside the container (`aws sso login`, `az login`, `gcloud auth login`, `glab auth login`, `terraform login`) - they'll persist into that project's own `.devcontainer/.creds/`.
- Claude Code needs its own login the first time too (separate session per project, by design).
- SSH: copy/symlink the key you want this project to use into `.devcontainer/.creds/ssh/` yourself (`chmod 600` the private key) - there's no automatic per-project SSH identity to provision.

## Extending the devcontainer

`.devcontainer/post-start.sh` sources `.devcontainer/scripts/extended.sh` if present, appending to the same `pending` onboarding-reminders array it builds. Anything org/team-specific (private marketplaces, named SSO sessions, internal setup commands) goes in that optional file in your own project checkout - it is never part of this repo's `.devcontainer`.

## Adding Claude Code skills

Skills ship inside **plugins**, plugins come from **marketplaces** (git repos). Prefer the `/plugin` command over editing config by hand.

### Fastest path: interactive UI

```text
/plugin
```

Opens a menu: `Marketplaces` → `Add marketplace` (paste `owner/repo` or full URL) → back to main menu → `Install plugin` → pick marketplace → pick plugin. Works for any repo, no need to know the internal marketplace name in advance.

### CLI equivalent

```text
/plugin marketplace add <owner/repo>
/plugin install <plugin-name>@<marketplace-name>
```

`marketplace-name` is whatever name the repo's `.claude-plugin/marketplace.json` declares — not always the same as the repo name. If unsure after `add`, run `/plugin` and install from the UI instead of guessing the CLI form.

### Already-known marketplaces → plugin, one-liners

| Skill | Marketplace source | Commands |
| --- | --- | --- |
| **caveman** | `JuliusBrussee/caveman` | `/plugin marketplace add JuliusBrussee/caveman` then `/plugin install caveman@caveman` |
| **superpowers** | official (`anthropics/claude-plugins-official`) | `/plugin install superpowers@claude-plugins-official` (marketplace already registered by default on a normal host install; a fresh, project-scoped `.claude` dir - like the devcontainer's - has no local catalog cache yet, so the first `@claude-plugins-official` install 404s until `claude plugin marketplace add anthropics/claude-plugins-official` runs once - `post-start.sh` does this automatically) |
| **humanizer** | `blader/humanizer` | `/plugin marketplace add blader/humanizer` then `/plugin install humanizer@humanizer` |
| **andrej-karpathy-skills** | `forrestchang/andrej-karpathy-skills` | `/plugin marketplace add forrestchang/andrej-karpathy-skills` then `/plugin install andrej-karpathy-skills@karpathy-skills` |
| **ECC** | `affaan-m/ECC` | `/plugin marketplace add affaan-m/ECC` then `/plugin install ecc@ecc` |
| **AWS skills** (general) | official | `/plugin install aws-core@claude-plugins-official` |
| **agent-toolkit-for-aws** | official (`aws-agents` plugin) | `/plugin install aws-agents@claude-plugins-official` |
| **cloudflare security** | official (`cloudflare` plugin, includes Cloudflare One / Zero Trust skill) | `/plugin install cloudflare@claude-plugins-official` |
| **recommended aws security skills** | official (`aws-agents-for-devsecops` plugin) | `/plugin install aws-agents-for-devsecops@claude-plugins-official` |
| **security-guidance** | official | `/plugin install security-guidance@claude-plugins-official` |
| **claude-security** | official | `/plugin install claude-security@claude-plugins-official` |

### New marketplaces (not yet registered anywhere)

| Skill | Repo | Commands |
| --- | --- | --- |
| **i-have-adhd** | `ayghri/i-have-adhd` | `/plugin marketplace add ayghri/i-have-adhd`, then `/plugin` → Install plugin, pick it from the list (marketplace key unconfirmed — use the UI, not a guessed CLI name) |
| **ponytail** | `dietrichgebert/ponytail` | `/plugin marketplace add dietrichgebert/ponytail`, then `/plugin` → Install plugin |

### Config: where it lands

`/plugin` writes to `~/.claude/settings.json`:

```jsonc
{
  "extraKnownMarketplaces": {
    "caveman": { "source": { "source": "github", "repo": "JuliusBrussee/caveman" } }
  },
  "enabledPlugins": {
    "caveman@caveman": true
  }
}
```

- `extraKnownMarketplaces`: registered marketplace sources (skip for the built-in `claude-plugins-official` one).
- `enabledPlugins`: `"<plugin>@<marketplace>": true|false` — toggle a plugin off without uninstalling by flipping to `false`, or do it via `/plugin` → Manage plugins → disable.

Edit this file directly only for bulk changes; for single installs, `/plugin` is less error-prone (auto-fills the correct marketplace key for you).

## Recommended picks for devsecops / platform engineering

Scoped to the marketplaces listed above only.

**Tier 1 — install now:**

- `aws-agents-for-devsecops` — security scanning, incident investigation, threat modeling, pentesting, release-readiness. Direct hit for the role.
- `aws-core` — IAM, Secrets Manager, CloudFormation/CDK, containers, observability, serverless. Foundation for the Atlas ECS/Lambda/RDS/CloudFront stack.
- `ecc` — pull specific skills: `security-review`, `security-scan`, `kubernetes-patterns`, `docker-patterns`, `architecture-decision-records`, `github-ops`, `git-workflow`, `production-audit`, `cost-tracking`, `network-config-validation`. Plugin is huge.
- `security-guidance` — official security best-practices skill, direct hit for the role.
- `claude-security` — official security-focused skill, direct hit for the role.
- `code-review`, `code-simplifier`, `pr-review-toolkit` — code quality/review tooling, requested.
- `github`, `commit-commands` — git/GitHub workflow, requested.
- `context7` — up-to-date library/API docs lookup, requested.
- `atlassian`, `slack` — Jira/Confluence and Slack integration, requested.
- `remember` — cross-session memory, requested.
- `terraform` — generic Terraform MCP server (plan/state/drift, module docs). No plugin is literally named "aws-terraform"; this is the closest match.
- `databases-on-aws`, `supabase`, `pagerduty`, `vanta` — AWS database, Supabase, PagerDuty, and Vanta integrations, requested.

**Tier 2 — worth it:**

- `cloudflare` — mainly for the `cloudflare-one` (Zero Trust) skill, if Cloudflare is in the stack.
- `superpowers` — `systematic-debugging`, `verification-before-completion`, `writing-plans`. Process discipline, not domain-specific.

**Tier 3 — personal/style, installed per request:**

- `i-have-adhd` (`ayghri/i-have-adhd`), `ponytail` (`dietrichgebert/ponytail`) — not devsecops-specific, but requested. **Marketplace key unconfirmed for both** (the repo's `.claude-plugin/marketplace.json` may declare a different name than the repo itself) - the install snippet's guesses may need correcting via `/plugin` → Install plugin → pick from list.
- `caveman` (`JuliusBrussee/caveman`), `humanizer` (`blader/humanizer`) — personal style preferences, not role-specific, but already in active use (caveman mode, and `humanizer` is required by this user's own `~/.claude/CLAUDE.md` for Slack messages).
- `andrej-karpathy-skills` (`forrestchang/andrej-karpathy-skills`) — ML-training focused, off-target for this role, but requested. Marketplace key confirmed: `karpathy-skills`.
- `ste-writing` (`thought-stuff/claude-ste`) — ASD-STE100 Simplified Technical English discipline plus a machine-checkable anti-slop linter, for plans/reports/user-facing messages. Marketplace key confirmed: `thought-stuff`.
- `terragrunt-skill` (`jfr992/terragrunt-skill`) — Terragrunt stacks/units/catalog patterns, CI/CD pipelines, AWS/GCP OIDC, multi-account deployments. Direct hit for the role. Marketplace key confirmed: `jfr992`.
- `devops-skills` (`akin-ozer/cc-devops-skills`) — bundles 30 generate/validate skills across Ansible, Azure Pipelines, Bash, Dockerfile, Fluent Bit, GitHub Actions, GitLab CI, Helm, Jenkinsfile, Kubernetes YAML + `k8s-debug`, LogQL, Loki config, Makefile, PromQL, Terraform, and Terragrunt. Direct hit for the role — see "DevOps skills" below for when to use each. Marketplace key confirmed: `akin-ozer`.
- `kubernetes-skill` (`LukasNiessen/kubernetes-skill`) — security/reliability-focused Kubernetes manifest generation and review; diagnoses failure modes (insecure defaults, resource starvation, network exposure, privilege sprawl, fragile rollouts, API drift) before writing YAML. Marketplace key confirmed: `kubernetes-skill`.
- `grill-with-docs` (`mattpocock/skills`, specifically `skills/engineering/grill-with-docs/SKILL.md`) — requested. Confirmed via the repo's `.claude-plugin/marketplace.json`: the marketplace key is `mattpocock` (not the repo name `skills`), and the whole monorepo installs as one bundled plugin, `mattpocock-skills` - not a separate plugin per skill subfolder.

**Skip / optional, not devsecops-relevant:**

- `aws-agents` (agent-toolkit-for-aws) — only if building AI agents on AWS, not infra work itself.

**Manual-install skills (not covered by the snippet/ansible/devcontainer automation below):**

A handful of skills ship as bare `SKILL.md` folders, not `.claude-plugin/marketplace.json` marketplaces — `aws-samples/sample-eks-operation-review-skill`, `aws-samples/sample-eks-upgrade-skill`, `aws-samples/sample-apex-skills`, `aws-samples/sample-aws-resilience-skill` (8 skills), `foxj77/claude-code-skills` (18 skills), `cloudflare/security-audit-skill`, and `petergyang/no-ai-slop` (the latter's `.codex-plugin` wrapper is for Codex, not Claude Code - only its `skills/no-ai-slop/SKILL.md` is usable here). Install by cloning into `~/.claude/skills/<name>/`, not `/plugin install` - see the "Manual-install skills" section of `CLAUDE.md` for what each does and when to use it.

`.devcontainer/scripts/install-manual-skills.sh` clones/sparse-checkouts all of the above (30 skills via git, plus `sample-apex-skills` via its own `npx apex-skills` installer) into `~/.claude/skills/`. Idempotent - re-running updates each one in place. Not wired into `post-start.sh`, so a container start doesn't always pay for ~30 clones; run it by hand when you want them.

**Dropped:** `vercel/find-skills` was removed from this list - the repo doesn't exist (confirmed 404 via `gh api repos/vercel/find-skills`), so it was a dead reference with no working install path.

### Install + configure snippet

```text
# --- install ---
/plugin install aws-agents-for-devsecops@claude-plugins-official
/plugin install aws-core@claude-plugins-official
/plugin install superpowers@claude-plugins-official
/plugin install cloudflare@claude-plugins-official
/plugin install security-guidance@claude-plugins-official
/plugin install claude-security@claude-plugins-official
/plugin install code-review@claude-plugins-official
/plugin install code-simplifier@claude-plugins-official
/plugin install pr-review-toolkit@claude-plugins-official
/plugin install github@claude-plugins-official
/plugin install commit-commands@claude-plugins-official
/plugin install context7@claude-plugins-official
/plugin install atlassian@claude-plugins-official
/plugin install slack@claude-plugins-official
/plugin install remember@claude-plugins-official
/plugin install terraform@claude-plugins-official
/plugin install databases-on-aws@claude-plugins-official
/plugin install supabase@claude-plugins-official
/plugin install pagerduty@claude-plugins-official
/plugin install vanta@claude-plugins-official

/plugin marketplace add affaan-m/ECC
/plugin install ecc@ecc

# Tier 3 (personal/style) - marketplace key unconfirmed for both, installs below are best guesses
/plugin marketplace add ayghri/i-have-adhd
/plugin install i-have-adhd@i-have-adhd

/plugin marketplace add dietrichgebert/ponytail
/plugin install ponytail@ponytail

/plugin marketplace add JuliusBrussee/caveman
/plugin install caveman@caveman

/plugin marketplace add blader/humanizer
/plugin install humanizer@humanizer

/plugin marketplace add forrestchang/andrej-karpathy-skills
/plugin install andrej-karpathy-skills@karpathy-skills

# Monorepo of skills (grill-with-docs and others), installs as one bundled plugin
/plugin marketplace add mattpocock/skills
/plugin install mattpocock-skills@mattpocock

/plugin marketplace add thought-stuff/claude-ste
/plugin install ste-writing@thought-stuff

/plugin marketplace add jfr992/terragrunt-skill
/plugin install terragrunt-skill@jfr992

/plugin marketplace add akin-ozer/cc-devops-skills
/plugin install devops-skills@akin-ozer

/plugin marketplace add LukasNiessen/kubernetes-skill
/plugin install kubernetes-skill@kubernetes-skill
# if CLI install name unconfirmed, fall back: /plugin → Install plugin → pick from list

# --- configure (post-install, needed for these two) ---
/aws-agents-for-devsecops:setup          # wires DevOps Agent + Security Agent MCP connections
# cloudflare: auth happens on first tool call (cloudflare-api / cloudflare-one authenticate) — just invoke a cloudflare skill, it'll prompt
```

Resulting `~/.claude/settings.json` state (reference, `/plugin` writes this for you):

```jsonc
{
  "extraKnownMarketplaces": {
    "ecc": { "source": { "source": "git", "url": "https://github.com/affaan-m/ECC.git" } },
    "i-have-adhd": { "source": { "source": "github", "repo": "ayghri/i-have-adhd" } },
    "ponytail": { "source": { "source": "github", "repo": "dietrichgebert/ponytail" } },
    "caveman": { "source": { "source": "github", "repo": "JuliusBrussee/caveman" } },
    "humanizer": { "source": { "source": "github", "repo": "blader/humanizer" } },
    "karpathy-skills": { "source": { "source": "github", "repo": "forrestchang/andrej-karpathy-skills" } },
    "mattpocock": { "source": { "source": "github", "repo": "mattpocock/skills" } },
    "thought-stuff": { "source": { "source": "github", "repo": "thought-stuff/claude-ste" } },
    "jfr992": { "source": { "source": "github", "repo": "jfr992/terragrunt-skill" } },
    "akin-ozer": { "source": { "source": "github", "repo": "akin-ozer/cc-devops-skills" } },
    "kubernetes-skill": { "source": { "source": "github", "repo": "LukasNiessen/kubernetes-skill" } }
  },
  "enabledPlugins": {
    "aws-agents-for-devsecops@claude-plugins-official": true,
    "aws-core@claude-plugins-official": true,
    "superpowers@claude-plugins-official": true,
    "cloudflare@claude-plugins-official": true,
    "security-guidance@claude-plugins-official": true,
    "claude-security@claude-plugins-official": true,
    "code-review@claude-plugins-official": true,
    "code-simplifier@claude-plugins-official": true,
    "pr-review-toolkit@claude-plugins-official": true,
    "github@claude-plugins-official": true,
    "commit-commands@claude-plugins-official": true,
    "context7@claude-plugins-official": true,
    "atlassian@claude-plugins-official": true,
    "slack@claude-plugins-official": true,
    "remember@claude-plugins-official": true,
    "terraform@claude-plugins-official": true,
    "databases-on-aws@claude-plugins-official": true,
    "supabase@claude-plugins-official": true,
    "pagerduty@claude-plugins-official": true,
    "vanta@claude-plugins-official": true,
    "ecc@ecc": true,
    "i-have-adhd@i-have-adhd": true,
    "ponytail@ponytail": true,
    "caveman@caveman": true,
    "humanizer@humanizer": true,
    "andrej-karpathy-skills@karpathy-skills": true,
    "mattpocock-skills@mattpocock": true,
    "ste-writing@thought-stuff": true,
    "terragrunt-skill@jfr992": true,
    "devops-skills@akin-ozer": true,
    "kubernetes-skill@kubernetes-skill": true
  }
}
```
