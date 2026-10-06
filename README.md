# iac

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
| **superpowers** | official (`anthropics/claude-plugins-official`) | `/plugin install superpowers@claude-plugins-official` (marketplace already registered by default) |
| **humanizer** | `blader/humanizer` | `/plugin marketplace add blader/humanizer` then `/plugin install humanizer@humanizer` |
| **andrej-karpathy-skills** | `forrestchang/andrej-karpathy-skills` | `/plugin marketplace add forrestchang/andrej-karpathy-skills` then `/plugin install andrej-karpathy-skills@karpathy-skills` |
| **ECC** | `affaan-m/ECC` | `/plugin marketplace add affaan-m/ECC` then `/plugin install ecc@ecc` |
| **AWS skills** (general) | official | `/plugin install aws-core@claude-plugins-official` |
| **agent-toolkit-for-aws** | official (`aws-agents` plugin) | `/plugin install aws-agents@claude-plugins-official` |
| **cloudflare security** | official (`cloudflare` plugin, includes Cloudflare One / Zero Trust skill) | `/plugin install cloudflare@claude-plugins-official` |
| **recommended aws security skills** | official (`aws-agents-for-devsecops` plugin) | `/plugin install aws-agents-for-devsecops@claude-plugins-official` |

### New marketplaces (not yet registered anywhere)

| Skill | Repo | Commands |
| --- | --- | --- |
| **i-have-adhd** | `ayghri/i-have-adhd` | `/plugin marketplace add ayghri/i-have-adhd`, then `/plugin` → Install plugin, pick it from the list (marketplace key unconfirmed — use the UI, not a guessed CLI name) |
| **no-ai-slop** | `petergyang/no-ai-slop` | `/plugin marketplace add petergyang/no-ai-slop`, then `/plugin` → Install plugin |
| **ponytail** | `dietrichgebert/ponytail` | `/plugin marketplace add dietrichgebert/ponytail`, then `/plugin` → Install plugin |
| **find-skills** | `vercel/find-skills` | `/plugin marketplace add vercel/find-skills`, then `/plugin` → Install plugin |
| **security-audit-skill** | `cloudflare/security-audit-skill` | `/plugin marketplace add cloudflare/security-audit-skill`, then `/plugin` → Install plugin |

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
- `ecc` — pull specific skills: `security-review`, `security-scan`, `kubernetes-patterns`, `docker-patterns`, `architecture-decision-records`, `github-ops`, `git-workflow`, `production-audit`, `cost-tracking`, `network-config-validation`. Plugin is huge — use `/find-skills` later to mine more.
- `find-skills` — meta-skill, keeps discovery going as needs shift.
- `security-audit-skill` (`cloudflare/security-audit-skill`) — dedicated security-audit skill, direct hit for devsecops.

**Tier 2 — worth it:**

- `cloudflare` — mainly for the `cloudflare-one` (Zero Trust) skill, if Cloudflare is in the stack.
- `superpowers` — `systematic-debugging`, `verification-before-completion`, `writing-plans`. Process discipline, not domain-specific.

**Skip / optional, not devsecops-relevant:**

- `aws-agents` (agent-toolkit-for-aws) — only if building AI agents on AWS, not infra work itself.
- `andrej-karpathy-skills` — ML-training focused, off-target.
- `i-have-adhd`, `no-ai-slop`, `ponytail` — personal/writing style, optional.
- `caveman`, `humanizer` — personal style preferences, not role-specific.

### Install + configure snippet

```text
# --- install ---
/plugin install aws-agents-for-devsecops@claude-plugins-official
/plugin install aws-core@claude-plugins-official
/plugin install superpowers@claude-plugins-official
/plugin install cloudflare@claude-plugins-official

/plugin marketplace add affaan-m/ECC
/plugin install ecc@ecc

/plugin marketplace add vercel/find-skills
/plugin install find-skills@find-skills

/plugin marketplace add cloudflare/security-audit-skill
/plugin install security-audit-skill@security-audit-skill
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
    "find-skills": { "source": { "source": "github", "repo": "vercel/find-skills" } },
    "security-audit-skill": { "source": { "source": "github", "repo": "cloudflare/security-audit-skill" } }
  },
  "enabledPlugins": {
    "aws-agents-for-devsecops@claude-plugins-official": true,
    "aws-core@claude-plugins-official": true,
    "superpowers@claude-plugins-official": true,
    "cloudflare@claude-plugins-official": true,
    "ecc@ecc": true,
    "find-skills@find-skills": true,
    "security-audit-skill@security-audit-skill": true
  }
}
```
