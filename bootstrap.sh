#!/usr/bin/env bash
# Simorgh one-command installer (like Omarchy's `curl ... | bash`).
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/mmdos32/simorgh/main/bootstrap.sh | bash
# It clones Simorgh to ~/simorgh (if needed) and runs install.sh.
# Needs curl; install it first if missing: sudo pacman -S curl
set -euo pipefail

REPO_URL="https://github.com/mmdos32/simorgh"
TARGET="$HOME/simorgh"

if ! command -v git >/dev/null; then
  echo "git is missing — installing it..."
  sudo pacman -Syu --noconfirm --needed git
fi

if [[ -d "$TARGET/.git" ]]; then
  echo "Simorgh already cloned at $TARGET — using it."
elif [[ -e "$TARGET" ]]; then
  echo "Error: $TARGET already exists but is not a Simorgh git clone." >&2
  echo "Move or delete it first, then run the installer again." >&2
  exit 1
else
  git clone "$REPO_URL" "$TARGET"
fi

# Redirect stdin from the terminal: when this script is piped in via
# `curl | bash`, stdin is the pipe, and install.sh's prompts would
# read EOF. /dev/tty gives the prompts a real terminal. Without a
# controlling terminal, run without the redirect (prompts read EOF and
# fall back to defaults).
if [[ -c /dev/tty ]]; then
  exec "$TARGET/install.sh" "$@" < /dev/tty
else
  exec "$TARGET/install.sh" "$@"
fi
