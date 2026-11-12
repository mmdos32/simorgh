#!/usr/bin/env bash
# Simorgh one-command installer (like Omarchy's `curl ... | bash`).
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/mmdos32/simorgh/main/bootstrap.sh | bash
# It clones Simorgh to ~/simorgh (if needed) and runs install.sh.
# Needs curl; install it first if missing: sudo pacman -S curl
#
# Trust note: piping this script straight from GitHub means trusting
# the mmdos32/simorgh repo at fetch time (TLS only — no checksum or
# signature check, the same trade-off Omarchy's installer makes).
# If that bothers you, download bootstrap.sh, read it, then run it.
set -euo pipefail

REPO_URL="https://github.com/mmdos32/simorgh"
TARGET="$HOME/simorgh"

# This installer only runs on Arch, and needs sudo for the git install
# below (and for install.sh afterwards).
[[ -f /etc/arch-release ]] || { echo "Simorgh only runs on Arch Linux." >&2; exit 1; }
command -v sudo >/dev/null || { echo "sudo is required — install it first as root: pacman -S sudo" >&2; exit 1; }

if ! command -v git >/dev/null; then
  echo "git is missing — installing it..."
  sudo pacman -Syu --noconfirm --needed git
fi

if [[ -d "$TARGET/.git" ]]; then
  echo "Simorgh already cloned at $TARGET — using it."
  # The clone is user-controlled: make sure it is actually Simorgh,
  # not some other repo that happens to sit at that path (same check
  # as simorgh-update — never execute a stranger's install.sh).
  # The origin must be github.com/mmdos32/simorgh: a bare
  # mmdos32/simorgh substring would also match an attacker's host.
  remote="$(git -C "$TARGET" remote get-url origin 2>/dev/null || true)"
  # Normalise before matching: git stores the origin verbatim, so a
  # clone made with a trailing slash (`.../simorgh/`) or a capitalised
  # host (`GitHub.com`, same host per DNS) is the same repo — strip
  # trailing slashes and compare lowercased. $remote itself is kept
  # unchanged so the error message shows the real origin.
  remote_norm="${remote,,}"
  while [[ "$remote_norm" == */ ]]; do remote_norm="${remote_norm%/}"; done
  if [[ -n "$remote_norm" && ! "$remote_norm" =~ (^|[@/])github\.com[:/]mmdos32/simorgh(\.git)?$ ]]; then
    echo "Error: $TARGET is not the Simorgh repo (origin: $remote)." >&2
    echo "Move or delete it first, then run the installer again." >&2
    exit 1
  fi
  # An ISO-installed ~/simorgh is always on a detached HEAD (the
  # installer checks out a pinned commit), and `git pull` refuses on
  # a detached HEAD — re-attach first instead of warning and then
  # running the stale clone.
  if ! git -C "$TARGET" symbolic-ref -q HEAD >/dev/null; then
    branch="$(git -C "$TARGET" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
    branch="${branch#origin/}"
    [[ -n "$branch" ]] || branch="main"
    echo "bootstrap: detached HEAD detected; checking out $branch first ..."
    git -C "$TARGET" checkout --quiet "$branch" || {
      echo "Error: could not check out $branch in $TARGET — leaving it untouched." >&2
      echo "Check with: git -C $TARGET status" >&2
      exit 1
    }
  fi
  # A transient network failure used to abort the whole install even
  # though the existing clone is usable — retry once, then warn and
  # continue with the existing checkout instead of exiting.
  pulled=0
  for attempt in 1 2; do
    if git -C "$TARGET" pull --ff-only; then pulled=1; break; fi
    echo "Update failed (attempt $attempt/2), retrying..." >&2
  done
  if [[ "$pulled" -eq 0 ]]; then
    echo "Warning: could not update the existing clone — continuing with the existing checkout in $TARGET." >&2
    echo "Check with: git -C $TARGET status" >&2
  fi
elif [[ -e "$TARGET" || -L "$TARGET" ]]; then
  # -L catches a dangling symlink: -e is false for one, so without
  # it the script fell into the clone branch and `mv` failed on the
  # symlink on every run instead of reaching this error.
  echo "Error: $TARGET already exists but is not a Simorgh git clone." >&2
  echo "Move or delete it first, then run the installer again." >&2
  exit 1
else
  # Clone to a temp dir first, then move it into place: a failed clone
  # used to leave a half-created ~/simorgh behind, and the next run
  # refused to retry until it was deleted by hand. The temp dir is
  # under $HOME so the move is an atomic rename on the same filesystem.
  tmp="$(mktemp -d "$HOME/.simorgh-clone.XXXXXX")"
  trap 'rm -rf "$tmp"' EXIT
  # Retry the clone once on a flaky network (install.sh retries its
  # clones the same way); a bare `git clone` under `set -e` aborted
  # the installer on the first failure with no second chance.
  cloned=0
  for attempt in 1 2; do
    if git clone "$REPO_URL" "$tmp/simorgh"; then cloned=1; break; fi
    echo "Clone failed (attempt $attempt/2), retrying..." >&2
    rm -rf "$tmp/simorgh"
  done
  if [[ "$cloned" -eq 0 ]]; then
    echo "Error: could not clone $REPO_URL — check your network and try again." >&2
    exit 1
  fi
  mv "$tmp/simorgh" "$TARGET"
  trap - EXIT
  rm -rf "$tmp"
fi

# Redirect stdin from the terminal: when this script is piped in via
# `curl | bash`, stdin is the pipe, and install.sh's prompts would
# read EOF. /dev/tty gives the prompts a real terminal. Without a
# controlling terminal, run without the redirect (prompts read EOF and
# fall back to defaults). Note: `[[ -c /dev/tty ]]` cannot test this —
# /dev/tty is always a char device, even with no controlling terminal
# (the `< /dev/tty` redirect then fails with ENXIO) — so test whether
# it can actually be opened instead.
if : </dev/tty 2>/dev/null; then
  exec "$TARGET/install.sh" "$@" < /dev/tty
else
  exec "$TARGET/install.sh" "$@"
fi
