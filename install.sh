#!/usr/bin/env bash
# install.sh — install add-agents and the Spec-Kit agent markdowns, then check Spec-Kit.
# Run it from the folder that holds add-agents and the agents/ folder (six agent .md files + AGENTS.md).

set -uo pipefail

# Where things get installed. AGENTS_DEST_DIR must match AGENTS_SRC_DIR in add-agents.
BIN_DIR="$HOME/.local/bin"
AGENTS_DEST_DIR="$HOME/.local/share/speckit-agents"

SCRIPT_NAME="add-agents"
AGENT_FILES=(coordinator.md planner.md developer.md verifier.md bug-fixer.md idea-assessor.md)
SHARED_FILE="AGENTS.md"   # shared rules, no frontmatter

SPECKIT_CMD="specify"
SPECKIT_INSTALL=(uv tool install specify-cli)
SPECKIT_DOCS="https://github.com/github/spec-kit.git"

die()  { echo "Error: $*" >&2; exit 1; }
warn() { echo "Warning: $*" >&2; }

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_SRC="$SRC_DIR/agents"

# --- 1. Validate everything before touching the system ---------------------
[ -n "${HOME:-}" ] && [ -d "$HOME" ] || die "HOME is not set or is not a directory"

missing=()
[ -f "$SRC_DIR/$SCRIPT_NAME" ] || missing+=("$SCRIPT_NAME")
[ -f "$AGENTS_SRC/$SHARED_FILE" ] || missing+=("agents/$SHARED_FILE")
for f in "${AGENT_FILES[@]}"; do
  [ -f "$AGENTS_SRC/$f" ] || missing+=("agents/$f")
done
[ ${#missing[@]} -eq 0 ] || die "missing in $SRC_DIR: ${missing[*]}"

for f in "${AGENT_FILES[@]}"; do
  [ -s "$AGENTS_SRC/$f" ] || die "$f is empty"
  [ "$(head -n 1 "$AGENTS_SRC/$f")" = "---" ] || die "$f has no frontmatter (is it an agent file?)"
done
[ -s "$AGENTS_SRC/$SHARED_FILE" ] || die "$SHARED_FILE is empty"
bash -n "$SRC_DIR/$SCRIPT_NAME" || die "$SCRIPT_NAME has syntax errors"

configured="$(sed -n 's/^AGENTS_SRC_DIR="\(.*\)"$/\1/p' "$SRC_DIR/$SCRIPT_NAME" | head -n 1)"
configured="${configured/\$HOME/$HOME}"
[ "$configured" = "$AGENTS_DEST_DIR" ] ||
  die "AGENTS_SRC_DIR in $SCRIPT_NAME ($configured) differs from AGENTS_DEST_DIR here ($AGENTS_DEST_DIR)"

# --- 2. Install ------------------------------------------------------------
mkdir -p "$BIN_DIR" "$AGENTS_DEST_DIR" || die "cannot create $BIN_DIR or $AGENTS_DEST_DIR"
[ -w "$BIN_DIR" ] && [ -w "$AGENTS_DEST_DIR" ] || die "no write permission on $BIN_DIR or $AGENTS_DEST_DIR"

cp "$SRC_DIR/$SCRIPT_NAME" "$BIN_DIR/$SCRIPT_NAME" || die "could not copy $SCRIPT_NAME"
chmod +x "$BIN_DIR/$SCRIPT_NAME" || die "could not make $SCRIPT_NAME executable"
for f in "${AGENT_FILES[@]}" "$SHARED_FILE"; do
  cp "$AGENTS_SRC/$f" "$AGENTS_DEST_DIR/$f" || die "could not copy $f"
done

echo "Installed $SCRIPT_NAME to $BIN_DIR"
echo "Installed ${#AGENT_FILES[@]} agent files and $SHARED_FILE to $AGENTS_DEST_DIR"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) warn "$BIN_DIR is not on your PATH. Add this line to ~/.bashrc or ~/.zshrc:"
     echo "  export PATH=\"$BIN_DIR:\$PATH\"" >&2 ;;
esac

# --- 3. Spec-Kit -----------------------------------------------------------
status=0
if command -v "$SPECKIT_CMD" >/dev/null 2>&1; then
  echo "Spec-Kit is installed: $(command -v "$SPECKIT_CMD")"
elif ! command -v uv >/dev/null 2>&1; then
  echo "Error: Spec-Kit is not installed, and uv (Python) is not installed either." >&2
  echo "       Install uv first (https://docs.astral.sh/uv/), then run: ${SPECKIT_INSTALL[*]}" >&2
  status=1
else
  echo "Spec-Kit is not installed."
  read -r -p "Install it now with '${SPECKIT_INSTALL[*]}'? [y/N] " answer || answer=""
  case "$answer" in
    y|Y|yes|YES|Yes)
      if "${SPECKIT_INSTALL[@]}"; then
        echo "Spec-Kit installed."
      else
        echo "Error: Spec-Kit installation failed." >&2
        status=1
      fi ;;
    *) echo "Skipped. Install it later with: ${SPECKIT_INSTALL[*]}" ;;
  esac
fi

echo "Spec-Kit documentation: $SPECKIT_DOCS"
[ "$status" -eq 0 ] && echo "Done. Run '$SCRIPT_NAME sdd' inside a project to add the agents."
exit "$status"
