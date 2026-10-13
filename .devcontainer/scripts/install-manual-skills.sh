#!/usr/bin/env bash
# Installs the manual-install Claude Code skills documented in CLAUDE.md's
# "Manual-install skills" section - these ship as bare SKILL.md folders (no
# .claude-plugin/marketplace.json), so `claude plugin install` can't reach
# them; they're cloned straight into ~/.claude/skills/<name>/ instead.
# Idempotent - re-running pulls/refreshes each one in place. Not wired into
# post-start.sh: run it by hand when you want these, so container start
# doesn't always pay for ~30 clones.
set -uo pipefail

SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
mkdir -p "$SKILLS_DIR"

SKILLS_FILE="${CLAUDE_MANUAL_SKILLS_FILE:-$(dirname "$0")/../config/claude-manual-skills.txt}"
mapfile -t SKILLS < "$SKILLS_FILE"

failures=()

install_whole_repo() {
  local name="$1" repo="$2" dest="$SKILLS_DIR/$1"
  if [ -d "$dest/.git" ]; then
    git -C "$dest" pull --ff-only --quiet || failures+=("$name: pull failed")
  elif git clone --depth 1 --quiet "https://github.com/${repo}.git" "$dest"; then
    :
  else
    failures+=("$name: clone failed")
  fi
}

install_subpath() {
  local name="$1" repo="$2" subpath="$3" dest="$SKILLS_DIR/$1" tmp
  tmp="$(mktemp -d)"
  if git clone --depth 1 --quiet --filter=blob:none --sparse "https://github.com/${repo}.git" "$tmp" >/dev/null 2>&1 \
      && git -C "$tmp" sparse-checkout set --quiet "$subpath" \
      && [ -d "$tmp/$subpath" ]; then
    rm -rf "$dest"
    mv "$tmp/$subpath" "$dest"
  else
    failures+=("$name: sparse clone of ${repo}#${subpath} failed")
  fi
  rm -rf "$tmp"
}

for entry in "${SKILLS[@]}"; do
  read -r name repo subpath <<< "$entry"
  if [ -z "$subpath" ]; then
    install_whole_repo "$name" "$repo"
  else
    install_subpath "$name" "$repo" "$subpath"
  fi
done

# sample-apex-skills ships its own installer (not a single SKILL.md folder) -
# run it instead of hand-rolling a clone for its multi-skill layout.
if command -v npx >/dev/null 2>&1; then
  npx --yes apex-skills || failures+=("apex-skills: npx apex-skills failed")
else
  failures+=("apex-skills: npx not found, run 'npx apex-skills' manually")
fi

total=$(( ${#SKILLS[@]} + 1 ))
echo "Installed $(( total - ${#failures[@]} ))/${total} manual-install skills into ${SKILLS_DIR} (+ apex-skills via npx)"
if [ "${#failures[@]}" -gt 0 ]; then
  echo "Failures:"
  printf '  %s\n' "${failures[@]}"
  exit 1
fi
