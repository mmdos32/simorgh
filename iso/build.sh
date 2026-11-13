#!/usr/bin/env bash
# Build the Simorgh live ISO (archiso).
# Run on Arch Linux, via sudo:  sudo ./iso/build.sh
# Output: iso/out/simorgh-<version>-x86_64.iso (name + iso_version from profiledef.sh)
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run as root: sudo ./iso/build.sh" >&2; exit 1; }
[[ -f /etc/arch-release ]] || { echo "Build on Arch Linux." >&2; exit 1; }
command -v mkarchiso >/dev/null || { echo "archiso is required: sudo pacman -S archiso" >&2; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required (Arch package 'python'): sudo pacman -S python" >&2; exit 1; }
# Fail closed if any other tool this script invokes is missing: the
# workflow container installs only archiso, git, sudo and python, and
# the rest is assumed from the archlinux:base-devel image. (useradd is
# invoked by the workflow's container step before this script runs;
# checking it here is belt-and-braces. repo-add is not checked: it is
# self-healing via the pacman-contrib fallback below.)
for tool in useradd flock bsdtar makepkg tar sed grep mktemp chown cp mv ls head cat rm mkdir pacman sudo git dirname; do
  command -v "$tool" >/dev/null || { echo "$tool is required to build the ISO." >&2; exit 1; }
done
# grep -oP (PCRE) is used below to parse iso_version.
echo test | grep -qP 'test' >/dev/null || { echo "grep -P (PCRE) support is required." >&2; exit 1; }

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# The build runs as root (via sudo) on a checkout owned by another
# user — and in CI by the runner user — so git would refuse to run
# ("detected dubious ownership in repository") and the dirty-guard
# checks below, plus the .build-commit stamp, would fail or fall back
# to "unknown". Mark the checkout as safe before any git call.
if command -v git >/dev/null && [[ -d "$REPO_ROOT/.git" ]]; then
  git config --global --get-all safe.directory 2>/dev/null | grep -qx "$REPO_ROOT" \
    || git config --global --add safe.directory "$REPO_ROOT"
fi
cd "$REPO_ROOT/iso"
[[ -f profiledef.sh && -f packages.x86_64 && -f pacman.conf.template ]] || { echo "Run from the simorgh repo (iso/ is missing files)." >&2; exit 1; }

# Validate iso_version the same way build-iso.yml does: a malformed
# version would produce a weirdly-named ISO that the CI checksum step
# (simorgh-*.iso glob / versioned checksum filename) may not match.
ISO_VERSION="$(grep -oP 'iso_version="\K[^"]+' profiledef.sh || true)"
if [[ -z "$ISO_VERSION" || ! "$ISO_VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
  echo "Invalid iso_version in iso/profiledef.sh (got: '$ISO_VERSION'; expected e.g. 1.0 or 1.0.1)." >&2
  exit 1
fi

# One build at a time: two simultaneous runs would race on work/, out/
# and the staging dir. flock on fd 9 is held until this script exits.
LOCK_FILE="/tmp/simorgh-build.lock"
exec 9>"$LOCK_FILE"
flock -n 9 || { echo "Another build is already running (lock $LOCK_FILE)." >&2; exit 1; }

# The Calamares package list is generated from packages/pacman.txt so
# the installed system always gets the same packages as the script method.
python3 "$REPO_ROOT/iso/gen-packages-conf.py"

# --- Local repo: Calamares is AUR-only ---------------------------------------
# Calamares is not in the Arch official repos, so mkarchiso cannot install
# it from [core]/[extra]. Build it once from the AUR into iso/repo/ (a
# local pacman repo) and point pacman.conf at it. Cached: a later build
# reuses the package instead of rebuilding (a clean build takes ~10 min),
# but only if it was built from the current CALAMARES_PIN (recorded in
# iso/repo/.calamares-pin) and passes an integrity check — otherwise
# the package is rebuilt.
# makepkg refuses to run as root, so the AUR build runs as the user who
# invoked sudo.
LOCAL_REPO="$REPO_ROOT/iso/repo"
mkdir -p "$LOCAL_REPO"
command -v repo-add >/dev/null || pacman -Syu --noconfirm --needed pacman-contrib
# Pinned AUR commit for calamares (3.4.2-2 at this commit). Pinning keeps
# the installer identical across builds: a later AUR update cannot
# silently change the Calamares version or its build script. To ship a
# newer Calamares, update this hash deliberately after reviewing the diff.
CALAMARES_PIN="167151beb537c06cb75c8dbfd409799ba308bb66"
# Reuse the cached package only if it was built from the current pin
# (recorded in iso/repo/.calamares-pin when it was built), is the
# expected version (3.4.2-2) and is intact; a pin bump, a wrong-version
# package or a corrupt package forces a rebuild instead of silently
# reusing the old one.
CACHED_PKG="$(ls "$LOCAL_REPO"/calamares-[0-9]*.pkg.tar.zst 2>/dev/null | head -n 1 || true)"
if [[ -n "$CACHED_PKG" ]]; then
  if [[ "$(cat "$LOCAL_REPO/.calamares-pin" 2>/dev/null || true)" != "$CALAMARES_PIN" ]]; then
    echo "Cached calamares package was built from a different pin; rebuilding for the current pin..."
    CACHED_PKG=""
  elif ! bsdtar -tf "$CACHED_PKG" >/dev/null 2>&1 && ! pacman -Qip "$CACHED_PKG" >/dev/null 2>&1; then
    echo "Cached calamares package is corrupt or unreadable; rebuilding it..."
    CACHED_PKG=""
  elif [[ "$(pacman -Qip "$CACHED_PKG" 2>/dev/null | sed -n 's/^Version[[:space:]]*: *//p')" != "3.4.2-2" ]]; then
    echo "Cached calamares package is not version 3.4.2-2; rebuilding it..."
    CACHED_PKG=""
  fi
  if [[ -z "$CACHED_PKG" ]]; then
    rm -f "$LOCAL_REPO"/calamares-*.pkg.tar.zst "$LOCAL_REPO"/simorgh.db.tar.gz
  fi
fi
if [[ -z "$CACHED_PKG" ]]; then
  BUILD_USER="${SUDO_USER:-}"
  [[ -n "$BUILD_USER" ]] || { echo "Run via sudo (not as root directly) so the AUR build can run as your user." >&2; exit 1; }
  command -v git >/dev/null || { echo "git is required to build calamares." >&2; exit 1; }
  echo "Building calamares from the AUR (one-time, ~10 min)..."
  chown "$BUILD_USER:$BUILD_USER" "$LOCAL_REPO"
  sudo -u "$BUILD_USER" -- bash -c '
    set -euo pipefail
    tmp="$(mktemp -d)"
    git clone https://aur.archlinux.org/calamares.git "$tmp/calamares"
    (cd "$tmp/calamares" && git checkout --quiet "$2")
    # The pin is only a commit hash: verify the checked-out tree really
    # is Calamares 3.4.2-2, so a mistyped pin cannot silently ship a
    # different version.
    pkgver="$(sed -n "s/^pkgver=//p" "$tmp/calamares/PKGBUILD")"
    pkgrel="$(sed -n "s/^pkgrel=//p" "$tmp/calamares/PKGBUILD")"
    [[ "$pkgver" == "3.4.2" && "$pkgrel" == "2" ]] || { echo "Pinned calamares commit is not 3.4.2-2 (got ${pkgver}-${pkgrel}); refusing to build." >&2; exit 1; }
    (cd "$tmp/calamares" && makepkg -s --noconfirm)
    # makepkg writes the packages into the build dir ($tmp/calamares),
    # not $tmp. [0-9] skips the calamares-debug split package.
    cp "$tmp"/calamares/calamares-[0-9]*.pkg.tar.zst "$1/"
    rm -rf "$tmp"
  ' _ "$LOCAL_REPO" "$CALAMARES_PIN"
  (cd "$LOCAL_REPO" && sudo -u "$BUILD_USER" -- repo-add simorgh.db.tar.gz calamares-*.pkg.tar.zst)
  # Record which pin this cached package was built from, so a later
  # build can tell a stale cache from a current one.
  printf '%s\n' "$CALAMARES_PIN" > "$LOCAL_REPO/.calamares-pin"
else
  echo "Using cached calamares package in iso/repo/."
  # Self-healing: if the repo DB is missing or corrupt, regenerate it
  # instead of letting mkarchiso fail later with an unreadable repo.
  if [[ ! -f "$LOCAL_REPO/simorgh.db.tar.gz" ]] || ! tar -tzf "$LOCAL_REPO/simorgh.db.tar.gz" >/dev/null 2>&1; then
    echo "Local repo DB missing or corrupt; regenerating it..."
    # repo-add fails on a corrupt db file instead of replacing it,
    # so remove it first (as the pin-mismatch path above does).
    rm -f "$LOCAL_REPO/simorgh.db.tar.gz"
    BUILD_USER="${SUDO_USER:-}"
    if [[ -n "$BUILD_USER" ]]; then
      chown "$BUILD_USER:$BUILD_USER" "$LOCAL_REPO"
      (cd "$LOCAL_REPO" && sudo -u "$BUILD_USER" -- repo-add simorgh.db.tar.gz calamares-*.pkg.tar.zst)
    else
      (cd "$LOCAL_REPO" && repo-add simorgh.db.tar.gz calamares-*.pkg.tar.zst)
    fi
  fi
fi

# Generate pacman.conf from the template with the local repo's real path.
sed "s|__SIMORGH_REPO_DIR__|$LOCAL_REPO|g" "$REPO_ROOT/iso/pacman.conf.template" > "$REPO_ROOT/iso/pacman.conf"

# Stage the repo into the live image at /opt/simorgh: the live session
# reads its configs from there, and the Calamares job installs from it.
# Cleaned up afterwards so the repo stays clean.
cleanup_stage() { rm -rf airootfs/opt/simorgh; }
trap cleanup_stage EXIT
rm -rf airootfs/opt/simorgh
mkdir -p airootfs/opt/simorgh
# Stamp the exact commit this ISO was built from, so the installer can
# check out the same tree (simorgh-target-install reads this file).
# The tar below stages the *working tree*, so refuse a dirty tree: a
# build from uncommitted changes would install files newer than the
# stamped commit, and the installer's pinned checkout would downgrade
# them on re-run. Same for a HEAD that was never pushed — the installer
# clones from GitHub, so an unpushed commit falls back to the older v1.0.
# Skipped for non-git trees (tarball export): there is nothing to check.
if [[ -d "$REPO_ROOT/.git" ]] && command -v git >/dev/null; then
  if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
    echo "Refusing to build: the working tree has uncommitted changes." >&2
    echo "Commit or stash them first, so the stamped commit matches the staged tree." >&2
    exit 1
  fi
  if git -C "$REPO_ROOT" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    ahead="$(git -C "$REPO_ROOT" rev-list --count '@{u}..HEAD')"
    if [[ "$ahead" != "0" ]]; then
      echo "Refusing to build: HEAD is $ahead commit(s) ahead of its upstream (unpushed)." >&2
      echo "Push first, so the installer can check out the stamped commit." >&2
      exit 1
    fi
  else
    echo "Warning: no upstream configured; cannot verify the stamped commit is pushed (the installer clones from GitHub)." >&2
  fi
fi
{ git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo unknown; } > airootfs/opt/simorgh/.build-commit
tar --exclude=.git --exclude=iso/work --exclude=iso/out \
    --exclude=iso/out.bak --exclude=iso/__pycache__ \
    --exclude=iso/airootfs/opt/simorgh \
    --exclude=iso/repo --exclude=iso/pacman.conf --exclude=.github \
    --exclude='*.iso' --exclude='*.log' \
    -cf - -C "$REPO_ROOT" . | tar -xf - -C airootfs/opt/simorgh

# Keep the last good ISO until the new one builds: move out/ aside
# (replacing any older backup) and only drop the backup once the new
# ISO exists. If mkarchiso fails, out.bak still holds the previous
# working ISO.
[[ -d out ]] && { rm -rf out.bak; mv out out.bak; }
rm -rf work out
mkarchiso -v -w work -o out .
# Fail closed if mkarchiso did not produce exactly one ISO: the
# iso_file assignment below takes the first match, so a stray second
# ISO in out/ would otherwise be silently used. (The CI workflow has
# the same count guard; this covers manual local builds too.)
# The '|| true' keeps 'set -o pipefail' from aborting on the empty
# glob (ls exits 2 when no .iso exists) before the guard can report it.
iso_count="$(ls out/*.iso 2>/dev/null | wc -l || true)"
[[ "$iso_count" -eq 1 ]] || { echo "Expected exactly one .iso in out/, found $iso_count." >&2; exit 1; }
iso_file="$(ls out/*.iso 2>/dev/null | head -n 1 || true)"
[[ -n "$iso_file" ]] || { echo "mkarchiso finished but no ISO was produced in out/" >&2; exit 1; }
rm -rf out.bak
echo
echo "ISO built: $iso_file"
echo "Write it to a USB stick (example):"
echo "  sudo dd if=$iso_file of=/dev/sdX bs=4M status=progress oflag=sync"
echo "Replace /dev/sdX with your actual USB device (check with lsblk first)."
