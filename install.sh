#!/usr/bin/env bash
# NewsSpinner — one-liner installer
# Usage: curl -fsSL https://raw.githubusercontent.com/Taichi-Ibi/NewsSpinner/main/install.sh | bash
set -euo pipefail

REPO="Taichi-Ibi/NewsSpinner"
BRANCH="main"

echo "=== NewsSpinner Installer ==="

# 1. Check dependencies
missing=()
for cmd in jq curl; do
  command -v "$cmd" > /dev/null 2>&1 || missing+=("$cmd")
done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "Error: missing required dependencies: ${missing[*]}" >&2
  echo "Install them and retry (e.g. brew install jq curl)" >&2
  exit 1
fi
echo "[1/4] Dependencies OK (jq, curl)"

# 2. Check if in a project with .claude/
if [ ! -d ".claude" ]; then
  echo "Error: .claude/ directory not found" >&2
  echo ""
  echo "This installer expects to run in a project directory with .claude/" >&2
  echo "You can either:"
  echo "  1. Clone the repo first:"
  echo "       git clone https://github.com/${REPO}.git"
  echo "       cd NewsSpinner"
  echo "       bash install.sh"
  echo ""
  echo "  2. Initialize .claude/ in your current project:"
  echo "       mkdir -p .claude"
  echo "       curl -fsSL https://raw.githubusercontent.com/${REPO}/raw/${BRANCH}/install.sh | bash"
  echo ""
  exit 1
fi
echo "[2/4] Found .claude/ directory"

# 3. Download repo and extract skills
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "[3/4] Downloading skills from GitHub..."
curl -fsSL "https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz" \
  | tar xz -C "$TMP" --strip-components=1

# 4. Copy .claude/skills/ to ./.claude/skills/
mkdir -p ".claude/skills"
cp -r "$TMP/.claude/skills/." ".claude/skills/"
echo "       Skills installed to ./.claude/skills/"

# 5. Run skill installer(s)
for install_sh in ".claude/skills"/*/bin/install.sh; do
  [ -f "$install_sh" ] || continue
  bash "$install_sh"
done

echo ""
echo "=== Installation complete! ==="
echo "Restart Claude Code to activate the hook."
echo ""
echo "Quick start in Claude Code:"
echo "  /news-fetch add AI      # add a feed"
echo "  /news-fetch fetch       # fetch headlines"
echo ""
