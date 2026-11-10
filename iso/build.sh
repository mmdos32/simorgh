#!/usr/bin/env bash
# Build the Simorgh live ISO (archiso).
# Run on Arch Linux, as root:  sudo ./iso/build.sh
# Output: iso/out/simorgh-<date>-x86_64.iso
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run as root: sudo ./iso/build.sh" >&2; exit 1; }
[[ -f /etc/arch-release ]] || { echo "Build on Arch Linux." >&2; exit 1; }
command -v mkarchiso >/dev/null || { echo "archiso is required: sudo pacman -S archiso" >&2; exit 1; }

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT/iso"
[[ -f profiledef.sh && -f packages.x86_64 && -f pacman.conf.template ]] || { echo "Run from the simorgh repo (iso/ is missing files)." >&2; exit 1; }

# The Calamares package list is generated from packages/pacman.txt so
# the installed system always gets the same packages as the script method.
python3 "$REPO_ROOT/iso/gen-packages-conf.py"

# --- Local repo: Calamares is AUR-only ---------------------------------------
# Calamares is not in the Arch official repos, so mkarchiso cannot install
# it from [core]/[extra]. Build it once from the AUR into iso/repo/ (a
# local pacman repo) and point pacman.conf at it. Cached: a later build
# reuses the package instead of rebuilding (a clean build takes ~10 min).
# makepkg refuses to run as root, so the AUR build runs as the user who
# invoked sudo.
LOCAL_REPO="$REPO_ROOT/iso/repo"
mkdir -p "$LOCAL_REPO"
command -v repo-add >/dev/null || pacman -S --noconfirm pacman-contrib
if ! ls "$LOCAL_REPO"/calamares-*.pkg.tar.zst >/dev/null 2>&1; then
  BUILD_USER="${SUDO_USER:-}"
  [[ -n "$BUILD_USER" ]] || { echo "Run via sudo (not as root directly) so the AUR build can run as your user." >&2; exit 1; }
  command -v git >/dev/null || { echo "git is required to build calamares." >&2; exit 1; }
  echo "Building calamares from the AUR (one-time, ~10 min)..."
  chown "$BUILD_USER:$BUILD_USER" "$LOCAL_REPO"
  sudo -u "$BUILD_USER" -- bash -c '
    set -euo pipefail
    tmp="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/calamares.git "$tmp/calamares"
    (cd "$tmp/calamares" && makepkg -s --noconfirm)
    cp "$tmp"/calamares-*.pkg.tar.zst "$1/"
    rm -rf "$tmp"
  ' _ "$LOCAL_REPO"
  (cd "$LOCAL_REPO" && sudo -u "$BUILD_USER" -- repo-add simorgh.db.tar.gz calamares-*.pkg.tar.zst)
else
  echo "Using cached calamares package in iso/repo/."
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
tar --exclude=.git --exclude=iso/work --exclude=iso/out \
    --exclude=iso/airootfs/opt/simorgh \
    -cf - -C "$REPO_ROOT" . | tar -xf - -C airootfs/opt/simorgh

rm -rf work out
mkarchiso -v -w work -o out .
iso_file="$(ls out/*.iso | head -n 1)"
echo
echo "ISO built: $iso_file"
echo "Write it to a USB stick (example):"
echo "  sudo dd if=$iso_file of=/dev/sdX bs=4M status=progress oflag=sync"
echo "Replace /dev/sdX with your actual USB device (check with lsblk first)."
