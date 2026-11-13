#!/usr/bin/env bash
# Simorgh installer — Arch Linux + Hyprland, minimal and modern with glassy themes.
# Run on a fresh stock Arch install:  ./install.sh
# Or, from the ISO installer (Calamares), inside the target:
#   ./install.sh --chroot --user <name> [--locale <locale>]
# Idempotent where reasonable: package installs use --needed, edited
# configs are left in place (only ~/.zshrc and ~/.profile are backed
# up before being replaced), and services are enabled (not blindly
# restarted).
set -euo pipefail

# Usage:
#   ./install.sh [--reconfigure] [--help]
#   ./install.sh --chroot --user <name> [--locale <locale>]
#
# --chroot runs the install inside a Calamares target (as root, for a
# specific user, non-interactively). Normal users never need it.
CHROOT_MODE=0
RECONFIGURE=0
TARGET_USER=""
LOCALE_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --reconfigure) RECONFIGURE=1; shift ;;
    --chroot) CHROOT_MODE=1; shift ;;
    --user) [[ $# -ge 2 ]] || { echo "--user needs a value" >&2; exit 1; }; TARGET_USER="$2"; shift 2 ;;
    --locale) [[ $# -ge 2 ]] || { echo "--locale needs a value" >&2; exit 1; }; LOCALE_OVERRIDE="$2"; shift 2 ;;
    --help|-h)
      cat <<'EOF'
Usage: ./install.sh [--reconfigure] [--help]
       ./install.sh --chroot --user <name> [--locale <locale>]

  --reconfigure   ask for the language again (otherwise the saved one is reused)
  --chroot        install into a Calamares target: run as root, for --user,
                  non-interactively (used by the ISO installer only)
  --user <name>   with --chroot: the user the desktop is installed for
  --locale <loc>  with --chroot: skip the language menu (e.g. en_US.UTF-8)
  --help          show this help and exit
EOF
      exit 0 ;;
    *) echo "Unknown option: $1 (run ./install.sh --help)" >&2; exit 1 ;;
  esac
done
[[ $CHROOT_MODE -eq 0 || -n "$TARGET_USER" ]] || { echo "--chroot needs --user <name>" >&2; exit 1; }
if [[ $CHROOT_MODE -eq 0 && ( -n "$TARGET_USER" || -n "$LOCALE_OVERRIDE" ) ]]; then
  echo "--user and --locale only work with --chroot" >&2; exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ $CHROOT_MODE -eq 1 ]]; then
  id -u "$TARGET_USER" >/dev/null 2>&1 || { echo "User not found: $TARGET_USER" >&2; exit 1; }
  export HOME="/home/$TARGET_USER"
fi
SHARE_DIR="$HOME/.local/share/simorgh"
BIN_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
DEFAULT_THEME="teal-glass"

info()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
error() { printf '\033[1;31m[✗]\033[0m %s\n' "$*" >&2; exit 1; }

# --- Cleanup + helpers -------------------------------------------------------
# Runs on any exit (success, error, INT, TERM): removes the temporary
# chroot sudoers drop-in and stops the sudo keep-alive loop, so a failed
# install never leaves passwordless sudo behind. SIGKILL cannot be
# trapped — a SIGKILLed install can still leave the drop-in behind;
# simorgh-target-install removes it as well when it cleans the target.
# INT/TERM exit 130 after cleanup: a bare `trap cleanup INT TERM` ran
# cleanup and then let the install carry on to "Simorgh is installed".
KEEPALIVE_PID=""
# Temp dirs/files created by mktemp during the install: registered
# here and removed by the EXIT trap (cleanup below), so an abort
# between mktemp and the trailing rm -rf never leaks /tmp dirs
# (incl. a yay clone).
TEMP_DIRS=()
register_tmp() { TEMP_DIRS+=("$1"); }
cleanup() {
  if [[ -n "${KEEPALIVE_PID:-}" ]]; then kill "$KEEPALIVE_PID" 2>/dev/null || true; fi
  [[ "${CHROOT_MODE:-0}" -eq 1 ]] && rm -f /etc/sudoers.d/simorgh-chroot
  if [[ ${#TEMP_DIRS[@]} -gt 0 ]]; then rm -rf "${TEMP_DIRS[@]}" 2>/dev/null || true; fi
  return 0
}
trap cleanup EXIT
trap 'cleanup; exit 130' INT TERM

# pacman_retry <pacman args...> — retry once, then fail.
# Returns non-zero when pacman fails twice: the call site decides
# what that means — abort for steps the install cannot continue
# without (official packages), warn-and-continue for optional ones
# (NVIDIA driver, laptop power management). It used to always
# return 0, so a failed package step silently reported success
# and the install finished with no desktop.
pacman_retry() {
  local attempt
  for attempt in 1 2; do
    if $SUDO pacman "$@"; then return 0; fi
    warn "pacman $* failed (attempt $attempt/2)."
    sleep 2
  done
  warn "pacman $* failed twice."
  return 1
}

# --- Preconditions -----------------------------------------------------------
if [[ $CHROOT_MODE -eq 0 ]]; then
  [[ $EUID -ne 0 ]] || error "Do not run as root — run as your normal user (sudo is used where needed)."
  command -v sudo >/dev/null || error "sudo is required — install it first as root: pacman -S sudo (and add your user to the wheel group)."
  sudo -v || error "sudo authentication failed."
  # Keep sudo alive for the whole install: sudo's timestamp times out
  # after 5 min, but the install runs for hours (the Sung build alone
  # takes ~1.5h under emulation). Re-auth every 4 min; the loop exits
  # on its own if the installer dies, and the EXIT trap kills it.
  ( while sleep 240; do kill -0 "$PPID" 2>/dev/null || exit 0; sudo -v || exit 0; done ) &
  KEEPALIVE_PID=$!
else
  [[ $EUID -eq 0 ]] || error "--chroot runs as root (inside the Calamares target)."
  command -v sudo >/dev/null || error "sudo is required in the target (for the yay step)."
  command -v runuser >/dev/null || error "runuser is required for --chroot."
fi
[[ -f /etc/arch-release ]] || error "This installer only runs on Arch Linux."

# In chroot mode we run as root by design; user-level steps run as the
# target user via runuser. sudo is not used (SUDO=""). yay builds as the
# user but installs via sudo, so the target user gets temporary
# passwordless sudo, removed when we exit (cleanup trap above).
if [[ $CHROOT_MODE -eq 1 ]]; then
  SUDO=""
  echo "$TARGET_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/simorgh-chroot
  chmod 440 /etc/sudoers.d/simorgh-chroot
  command -v visudo >/dev/null && visudo -cf /etc/sudoers.d/simorgh-chroot >/dev/null || true
  # Removed by the cleanup() EXIT trap above (and by
  # simorgh-target-install when it cleans the target).
else
  SUDO="sudo"
fi
# At least ~5 GB free is needed (packages + Sung build + caches).
FREE_GB="$(df --output=avail -BG / 2>/dev/null | tail -1 | tr -dc '0-9')"
if [[ -n "$FREE_GB" && "$FREE_GB" -lt 5 ]]; then
  warn "Less than 5 GB free on / ($FREE_GB GB). The install may run out of space."
fi

# --- Language ----------------------------------------------------------------
# Simorgh is multilingual with English as the default. Pick a locale and we
# enable it in /etc/locale.gen and set it as the system locale.
# Re-runs (e.g. via simorgh-update) reuse the saved locale from
# $SHARE_DIR/locale instead of asking again, unless --reconfigure is passed.
mkdir -p "$SHARE_DIR" || warn "Could not create $SHARE_DIR; later steps may fail — fix the permissions on $HOME/.local and re-run ./install.sh."
if [[ $CHROOT_MODE -eq 1 ]]; then
  # The mkdir above ran as root, so $HOME/.local (and the share dir
  # under it) is root-owned — but Sung and Maia run as the target user
  # via runuser, ~400 lines before the end-of-install ownership fix,
  # and both mkdir under $HOME/.local. Hand it back now or both steps
  # fail and only warn, leaving the installed system without its
  # default music player and file manager.
  chown -R "$TARGET_USER:$TARGET_USER" "$HOME/.local" || warn "Could not hand ownership of $HOME/.local to $TARGET_USER; Sung and Maia may fail to install."
fi
if [[ $CHROOT_MODE -eq 1 ]]; then
  # Non-interactive: the locale comes from the ISO installer (or English).
  LOCALE="${LOCALE_OVERRIDE:-en_US.UTF-8}"
elif [[ $RECONFIGURE -eq 0 && -f "$SHARE_DIR/locale" ]]; then
  LOCALE="$(cat "$SHARE_DIR/locale")"
  info "Reusing saved locale: $LOCALE (run ./install.sh --reconfigure to change it)"
else
  info "Choose your language (default: English):"
  LOCALES=(
    "en_US.UTF-8|English (default)"
    "fa_IR.UTF-8|Persian (فارسی)"
    "de_DE.UTF-8|German (Deutsch)"
    "fr_FR.UTF-8|French (Français)"
    "es_ES.UTF-8|Spanish (Español)"
    "ar_SA.UTF-8|Arabic (العربية)"
    "tr_TR.UTF-8|Turkish (Türkçe)"
    "ru_RU.UTF-8|Russian (Русский)"
    "zh_CN.UTF-8|Chinese (中文)"
    "ja_JP.UTF-8|Japanese (日本語)"
    "pt_BR.UTF-8|Portuguese (Português)"
  )
  for i in "${!LOCALES[@]}"; do
    printf '  %2d) %s\n' "$((i + 1))" "${LOCALES[$i]#*|}"
  done
  # `|| true`: with stdin closed/EOF, read fails — under `set -e`
  # that used to abort the install instead of falling back to the
  # default (choice is empty below, so it becomes 1 anyway).
  read -rp "Language [1]: " choice || true
  choice="${choice:-1}"
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#LOCALES[@]} )); then
    warn "Invalid choice, falling back to English."
    choice=1
  fi
  LOCALE="${LOCALES[$((choice - 1))]%%|*}"
fi
# The saved locale is user-controlled file content: validate it before
# interpolating it into the sed pattern below, or a crafted value could
# break (or rewrite) /etc/locale.gen. Fall back to English.
if ! [[ "$LOCALE" =~ ^[a-z]{2}_[A-Z]{2}\.UTF-8$ ]]; then
  warn "Saved locale '$LOCALE' is not a valid locale name; falling back to en_US.UTF-8."
  LOCALE="en_US.UTF-8"
fi
info "Locale: $LOCALE"
$SUDO sed -i "s/^#\(${LOCALE} UTF-8\)/\1/" /etc/locale.gen || warn "Could not enable $LOCALE in /etc/locale.gen; continuing with the default locale — run 'sudo locale-gen' after fixing it."
# Tolerated: a locale-gen failure (bad mirrors, missing locale data)
# used to abort the whole install under `set -e` before any package
# was installed — warn and continue instead; the desktop still
# installs, and the locale can be fixed afterwards.
$SUDO locale-gen || warn "locale-gen failed for $LOCALE; continuing with the default locale — run 'sudo locale-gen' after fixing your mirrors."
# Update just the LANG line, preserving any other settings in
# /etc/locale.conf — a plain `tee` truncated the whole file.
if [[ -f /etc/locale.conf ]] && grep -q '^LANG=' /etc/locale.conf; then
  $SUDO sed -i "s/^LANG=.*/LANG=$LOCALE/" /etc/locale.conf || warn "Could not update LANG in /etc/locale.conf; continuing — set it later with 'localectl set-locale LANG=$LOCALE'."
else
  echo "LANG=$LOCALE" | $SUDO tee -a /etc/locale.conf >/dev/null || warn "Could not write LANG=$LOCALE to /etc/locale.conf; continuing — set it later with 'localectl set-locale LANG=$LOCALE'."
fi
# Remember the locale and this repo's location for simorgh-update.
# Guarded: if an earlier failed run left $SHARE_DIR root-owned (the
# chown at the end of install.sh heals it only then), a permission-
# denied redirect here must not abort the install under `set -e`
# before it can heal.
echo "$LOCALE" > "$SHARE_DIR/locale" || warn "Could not write the locale to $SHARE_DIR/locale; simorgh-update may ask for the locale again."
echo "$REPO_DIR" > "$SHARE_DIR/repo-path" || warn "Could not write the repo path to $SHARE_DIR/repo-path; simorgh-update may not find the repo — fix the permissions on $SHARE_DIR and re-run ./install.sh."

# --- Base tools (needed to build yay) ----------------------------------------
# yay is built with makepkg (base-devel) from a git clone — both must
# exist before the AUR helper step below, not after it. curl is needed
# by the yay release-binary fallback below, so it is installed here too
# (the fallback used to run before any curl install existed).
info "Installing base tools (base-devel, git, curl)..."
# Tolerated: without these, yay/AUR/Colloid/Sung/Maia degrade with
# their own warnings, but the desktop itself (below) can still
# install. A failed -Syu here usually means the official package
# step below fails too — and that one aborts.
pacman_retry -Syu --noconfirm --needed base-devel git curl || warn "Base tools install failed; yay, AUR packages, Colloid, Sung and Maia will be skipped or degraded — fix your network/mirrors and re-run ./install.sh."

# --- makepkg: disable debug symbols ----------------------------------------
# Disable `debug` in makepkg's OPTIONS if it is enabled: with it on,
# makepkg copies debug sources for every file — the colloid build hung
# at 100% CPU for 18+ min on it (VM test). (Stock /etc/makepkg.conf
# already ships !debug; this only changes installs that enabled it.)
# The match is a standalone `debug` word on the OPTIONS line, whatever
# its position — not an exact token order.
if grep -E '^OPTIONS=' /etc/makepkg.conf 2>/dev/null | grep -Eq '(^|[^![:alnum:]_])debug([^[:alnum:]_]|$)'; then
  info "Disabling makepkg debug symbols (speeds up AUR builds)..."
  # `|| true`: this is an optional speed-up — a failing sed must not
  # abort the install under `set -e`; the grep check below reports it.
  $SUDO sed -i -E '/^OPTIONS=/ s/(^|[^!])debug([^[:alnum:]_]|$)/\1!debug\2/' /etc/makepkg.conf || true
  if grep -E '^OPTIONS=' /etc/makepkg.conf | grep -q '!debug'; then
    info "makepkg debug symbols disabled."
  else
    warn "Could not disable makepkg debug symbols; AUR builds may be slow."
  fi
fi

# --- AUR helper --------------------------------------------------------------
# yay is built with makepkg (base-devel) from a git clone. The clone can
# fail on a flaky network; under `set -e` that used to abort the whole
# install (VM test, run 1). So: retry the clone once, then fall back to
# yay's GitHub release binary, and if that fails too, warn and continue —
# the AUR step below already degrades gracefully without yay.
if ! command -v yay >/dev/null; then
  info "Installing yay (AUR helper)..."
  tmp="$(mktemp -d)"
  register_tmp "$tmp"
  # mktemp -d is already 700; in chroot mode the build runs as the
  # target user, so hand the directory to them instead of opening it up.
  if [[ $CHROOT_MODE -eq 1 ]]; then chown "$TARGET_USER" "$tmp"; fi
  yay_ok=0
  for attempt in 1 2; do
    if [[ $CHROOT_MODE -eq 1 ]]; then
      # makepkg refuses to run as root: build as the target user.
      if runuser -u "$TARGET_USER" -- env HOME="$HOME" USER="$TARGET_USER" LOGNAME="$TARGET_USER" bash -c "git clone --depth 1 https://aur.archlinux.org/yay.git \"$tmp/yay\" && (cd \"$tmp/yay\" && makepkg -si --noconfirm)"; then yay_ok=1; break; fi
    else
      if git clone --depth 1 https://aur.archlinux.org/yay.git "$tmp/yay" && (cd "$tmp/yay" && makepkg -si --noconfirm); then yay_ok=1; break; fi
    fi
    warn "yay clone/build failed (attempt $attempt/2), retrying..."
    rm -rf "$tmp/yay"
  done
  # makepkg -si exiting 0 does not by itself prove the yay command
  # works — verify before trusting it, or a half-installed yay would
  # claim success here and skip the release-binary fallback below.
  # yay refuses to run as root ("Avoid running yay as root/sudo.", rc 1),
  # and --chroot mode runs as root — so verify as the target user there,
  # with the same runuser/env pattern the build step above uses.
  if [[ $CHROOT_MODE -eq 1 ]]; then
    yay_check=(runuser -u "$TARGET_USER" -- env HOME="$HOME" USER="$TARGET_USER" LOGNAME="$TARGET_USER" yay --version)
  else
    yay_check=(yay --version)
  fi
  if [[ $yay_ok -eq 1 ]] && ! "${yay_check[@]}" >/dev/null 2>&1; then
    warn "yay built but 'yay --version' fails; trying the yay release binary..."
    yay_ok=0
  fi
  if [[ $yay_ok -eq 0 ]]; then
    warn "yay clone failed twice; trying the yay release binary..."
    # The release binary is x86_64-only. yay publishes no checksums or
    # signature file for v13.1.0 (verified 2026-11-11: the release has
    # only the three tarballs), so the tarball is fetched over TLS from
    # the official release and smoke-tested with yay --version after
    # installing; an unverified (or failing-smoke-test) download is
    # never installed.
    # Same root refusal as the post-build check above: smoke-test the
    # release binary as the target user in chroot mode.
    if [[ $CHROOT_MODE -eq 1 ]]; then
      yay_smoke=(runuser -u "$TARGET_USER" -- env HOME="$HOME" USER="$TARGET_USER" LOGNAME="$TARGET_USER" /usr/local/bin/yay --version)
    else
      yay_smoke=(/usr/local/bin/yay --version)
    fi
    if [[ "$(uname -m)" == "x86_64" ]] && (cd "$tmp" && curl -fsSL -o yay.tar.gz https://github.com/Jguer/yay/releases/download/v13.1.0/yay_13.1.0_x86_64.tar.gz && tar -xzf yay.tar.gz && $SUDO install -m 755 yay_13.1.0_x86_64/yay /usr/local/bin/yay && "${yay_smoke[@]}" >/dev/null); then
      yay_ok=1
    else
      warn "yay release binary failed (download, extract, or smoke test)."
    fi
  fi
  rm -rf "$tmp"
  [[ $yay_ok -eq 1 ]] || warn "Could not install yay; AUR packages will be skipped (install them later from the menu)."
else
  info "yay already installed."
fi

# --- Multilib (needed for Steam, installed later via the menu) --------------
# Enable [multilib] and its Include line independently: a half-enabled
# section (header uncommented, Include still commented) used to pass
# the grep check below and leave pacman with a repo that has no mirrors.
multilib_enabled() {
  grep -q '^\[multilib\]' /etc/pacman.conf && awk '/^\[multilib\]/{f=1;next} /^\[/{f=0} f && /^Include = \/etc\/pacman.d\/mirrorlist/{ok=1} END{exit !ok}' /etc/pacman.conf
}
if ! multilib_enabled; then
  info "Enabling the multilib repository (needed for Steam)..."
  $SUDO sed -i 's/^#\[multilib\]/[multilib]/' /etc/pacman.conf || warn "Could not enable [multilib] in /etc/pacman.conf; Steam and 32-bit packages will fail to install."
  # Uncomment the first Include line inside the [multilib] section,
  # however many blank/comment lines sit between the header and it —
  # the old sed `{n;...}` only handled an Include directly under the
  # header, and any other layout silently left multilib half-enabled.
  # awk cannot edit in place, so write to a temp file and copy back
  # (cp keeps /etc/pacman.conf's permissions).
  tmp="$(mktemp)"
  register_tmp "$tmp"
  if awk '/^\[multilib\]/{f=1} /^\[/{if (!/^\[multilib\]/) f=0} f && !done && /^#Include = \/etc\/pacman.d\/mirrorlist/{sub(/^#/,""); done=1} {print}' /etc/pacman.conf > "$tmp"; then
    $SUDO cp "$tmp" /etc/pacman.conf || warn "Could not update /etc/pacman.conf to enable multilib; Steam and 32-bit packages will fail to install."
  else
    warn "Could not edit /etc/pacman.conf to enable multilib."
  fi
  rm -f "$tmp"
  # Re-check right after editing, before the refresh below: a failed
  # edit must be reported now, not after a pointless database sync.
  multilib_enabled || warn "Multilib still looks disabled in /etc/pacman.conf — Steam and 32-bit packages will fail to install."
  # Tolerated: the official package step below re-syncs with -Syu
  # anyway, so a failed refresh here is not fatal by itself.
  pacman_retry -Sy --noconfirm || warn "Could not refresh package databases after enabling multilib."
fi

# --- Packages ----------------------------------------------------------------
# Prints the package list, one line per package collapsed to spaces.
# Fails (non-zero) if the file is missing or the list is empty: without
# this, a missing file silently ran a bare `pacman -Syu` with no package
# arguments (the grep pipeline still exits 0).
read_list() {
  [[ -f "$1" ]] || { echo "Package list missing: $1" >&2; return 1; }
  local list
  list="$(grep -v '^\s*#' "$1" | grep -v '^\s*$' | tr '\n' ' ')"
  [[ -n "${list// /}" ]] || { echo "Package list empty: $1" >&2; return 1; }
  printf '%s' "$list"
}

info "Installing official packages..."
PACMAN_PKGS="$(read_list "$REPO_DIR/packages/pacman.txt")" || error "Cannot install official packages without $REPO_DIR/packages/pacman.txt."
# shellcheck disable=SC2086
# Must not continue on failure: without the official packages there
# is no desktop, and silently "succeeding" anyway was the bug.
pacman_retry -Syu --noconfirm --needed $PACMAN_PKGS || error "Official package install failed — the desktop is not installed. Fix your network/mirrors and re-run ./install.sh."

info "Installing AUR packages..."
# Like Maia/Sung, a failed AUR install must not kill the whole install
# (VS Code / the GTK and SDDM themes can be installed later from the menu).
# --answerdiff/--answerclean/--answeredit None: the cleanBuild/diff prompts
# can appear stuck on a serial console (VM test), so answer them explicitly.
AUR_PKGS="$(read_list "$REPO_DIR/packages/aur.txt")" || warn "Cannot install AUR packages without $REPO_DIR/packages/aur.txt — skipping AUR packages; install VS Code, the GTK theme and the SDDM theme later from the menu."
if [[ -n "${AUR_PKGS:-}" ]]; then
  if [[ $CHROOT_MODE -eq 1 ]]; then
    # shellcheck disable=SC2086
    runuser -u "$TARGET_USER" -- env HOME="$HOME" USER="$TARGET_USER" LOGNAME="$TARGET_USER" yay -S --noconfirm --answerdiff None --answerclean None --answeredit None --needed $AUR_PKGS || warn "AUR install failed (network/AUR issue); install VS Code, the GTK theme and the SDDM theme later from the menu."
  else
    # shellcheck disable=SC2086
    yay -S --noconfirm --answerdiff None --answerclean None --answeredit None --needed $AUR_PKGS || warn "AUR install failed (network/AUR issue); install VS Code, the GTK theme and the SDDM theme later from the menu."
  fi
fi

# --- Colloid GTK theme (upstream installer, not the AUR split) ---------------
# The colloid-gtk-theme-git PKGBUILD defines 6 split packages, but Simorgh
# needs only the default theme. Building it with makepkg wastes ~60 min on
# the other 5 splits, and `makepkg --pkg` (the single-split shortcut) does
# not exist in pacman 7 — it was removed in makepkg 7.0, and VM test 2
# proved the step fails on current Arch. So instead, clone the upstream
# theme repo and run its own install.sh for exactly the variant Simorgh
# uses: default + dark (= Colloid-Dark, the gtk-theme-name in
# config/gtk-3.0/settings.ini). Needs sassc (in pacman.txt). Installs
# system-wide to /usr/share/themes, like the AUR package did. The clone
# is retried once on flaky networks. Never fail the whole install if
# this step fails.
if [[ -d /usr/share/themes/Colloid-Dark ]]; then
  info "Colloid-Dark already installed — skipping."
else
info "Installing the Colloid GTK theme (Colloid-Dark, from upstream)..."
colloid_tmp="$(mktemp -d)"
register_tmp "$colloid_tmp"
colloid_ok=0
for attempt in 1 2; do
  if git clone --depth 1 https://github.com/vinceliuice/Colloid-gtk-theme.git "$colloid_tmp/colloid" 2>/dev/null; then
    if (cd "$colloid_tmp/colloid" && $SUDO ./install.sh -t default -c dark -d /usr/share/themes); then
      colloid_ok=1; break
    fi
    warn "Colloid install.sh failed (attempt $attempt/2)."
  else
    warn "Colloid clone failed (attempt $attempt/2)."
  fi
  rm -rf "$colloid_tmp/colloid"
done
rm -rf "$colloid_tmp"
if [[ $colloid_ok -eq 1 ]] && [[ -d /usr/share/themes/Colloid-Dark ]]; then
  info "Colloid-Dark installed."
else
  warn "Colloid theme install failed; install it later from the menu."
fi
fi

# --- NVIDIA GPU (auto-detect) ------------------------------------------------
# NVIDIA cards get the proprietary driver (DKMS, so it survives kernel
# updates) + the 32-bit libs Steam needs, and DRM modesetting in GRUB
# when GRUB is present (backed up first). AMD/Intel need nothing extra.
# Detect via /sys first (works even in a chroot), falling back to lspci.
HAS_NVIDIA=0
for vendor in /sys/bus/pci/devices/*/vendor; do
  [[ "$(cat "$vendor" 2>/dev/null)" == "0x10de" ]] && HAS_NVIDIA=1 && break
done
if [[ $HAS_NVIDIA -eq 0 ]] && command -v lspci >/dev/null && lspci 2>/dev/null | grep -qi 'nvidia'; then
  HAS_NVIDIA=1
fi
if [[ $HAS_NVIDIA -eq 1 ]]; then
  info "NVIDIA GPU detected — installing the proprietary driver..."
  # DKMS needs the headers matching the installed kernel. In chroot mode
  # the target kernel is the stock linux kernel (ISO preset). Otherwise
  # derive the headers from the installed kernel package: every Arch
  # kernel ships a matching <kernel>-headers package, so any kernel
  # works — linux-cachyos, linux-xanmod and friends included — not
  # just the handful a case list knows about. `uname -r` is only used
  # to prefer the running kernel when several are installed, never to
  # guess the package name. When no kernel package is found, skip the
  # driver instead of installing the wrong headers (which broke the
  # DKMS build).
  KERNEL_HEADERS=""
  if [[ $CHROOT_MODE -eq 1 ]]; then
    KERNEL_HEADERS="linux-headers"
  else
    KERNEL_PKG=""
    for cand in $(pacman -Qq 2>/dev/null | grep -E '^linux(-[a-z0-9]+)*$' | grep -vE '(-headers|-firmware|-api-headers|-docs)$' || true); do
      if pacman -Ql "$cand" 2>/dev/null | grep -qF "/usr/lib/modules/$(uname -r)/"; then
        KERNEL_PKG="$cand"
        break
      fi
      [[ -z "$KERNEL_PKG" ]] && KERNEL_PKG="$cand"
    done
    if [[ -n "$KERNEL_PKG" ]]; then
      KERNEL_HEADERS="$KERNEL_PKG-headers"
    else
      warn "Could not determine the installed kernel package; skipping the NVIDIA driver (install nvidia-dkms and the matching <kernel>-headers package manually)."
    fi
  fi
  if [[ -n "$KERNEL_HEADERS" ]]; then
    # Tolerated: the desktop works without the proprietary driver.
    pacman_retry -S --noconfirm --needed nvidia-dkms nvidia-utils lib32-nvidia-utils "$KERNEL_HEADERS" || warn "NVIDIA driver install failed; the desktop still works without it — install nvidia-dkms and $KERNEL_HEADERS manually."
  fi
  # grub-mkconfig needs the target's /boot (mounted in the Calamares
  # chroot; a mountpoint or an existing /boot/grub on a normal install).
  if [[ -f /etc/default/grub ]] && ! grep -q 'nvidia_drm.modeset=1' /etc/default/grub && { [[ -d /boot/grub ]] || mountpoint -q /boot; }; then
    $SUDO cp /etc/default/grub /etc/default/grub.simorgh-bak || warn "Could not back up /etc/default/grub; continuing without the backup."
    # `|| true`: a failing sed must not abort the install under
    # `set -e`; the grep check below reports it.
    $SUDO sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia_drm.modeset=1 /' /etc/default/grub || true
    if grep -q 'nvidia_drm.modeset=1' /etc/default/grub && $SUDO grub-mkconfig -o /boot/grub/grub.cfg; then
      info "DRM modesetting enabled — reboot to apply."
    else
      warn "Could not enable DRM modesetting; add nvidia_drm.modeset=1 to GRUB_CMDLINE_LINUX_DEFAULT manually."
    fi
  fi
else
  info "No NVIDIA GPU detected — skipping the proprietary driver."
fi

# --- Dual-boot (os-prober) ---------------------------------------------------
# GRUB only scans for other OSes when os-prober is enabled: stock Arch
# ships GRUB_DISABLE_OS_PROBER=true, and os-prober + ntfs-3g are
# installed with the official packages above, so enable it here. This
# is not NVIDIA-specific, so it runs on every install that has GRUB.
# grub.cfg is regenerated afterwards: the ISO installer's grub-mkconfig
# ran before os-prober was installed, so a grub.cfg written then lists
# no other OSes until it is regenerated with os-prober present.
if [[ -f /etc/default/grub ]]; then
  [[ -f /etc/default/grub.simorgh-bak ]] || $SUDO cp /etc/default/grub /etc/default/grub.simorgh-bak || warn "Could not back up /etc/default/grub; continuing without the backup."
  if grep -q '^GRUB_DISABLE_OS_PROBER=' /etc/default/grub; then
    $SUDO sed -i 's/^GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub || true
  else
    echo 'GRUB_DISABLE_OS_PROBER=false' | $SUDO tee -a /etc/default/grub >/dev/null || true
  fi
  if grep -q '^GRUB_DISABLE_OS_PROBER=false' /etc/default/grub; then
    # Same /boot gating as the NVIDIA block above: grub-mkconfig needs
    # the target's /boot (mounted in the Calamares chroot; a mountpoint
    # or an existing /boot/grub on a normal install).
    if [[ -d /boot/grub ]] || mountpoint -q /boot; then
      if $SUDO grub-mkconfig -o /boot/grub/grub.cfg; then
        info "GRUB os-prober enabled — other OSes will appear in the boot menu."
      else
        warn "Could not regenerate the GRUB config; other OSes may not appear in the boot menu until you run: sudo grub-mkconfig -o /boot/grub/grub.cfg"
      fi
    else
      info "GRUB os-prober enabled in /etc/default/grub (no /boot/grub found — the boot menu updates when GRUB is next configured)."
    fi
  else
    warn "Could not set GRUB_DISABLE_OS_PROBER=false in /etc/default/grub; other OSes may not appear in the boot menu."
  fi
fi

# --- Sung (default music player) ---------------------------------------------
# Sung has no AUR package and no releases: build from source, per-user
# install into ~/.local (never with sudo, never as root). The clone is
# kept under ~/.local/src/Sung so Sung can be updated later. A Sung
# failure must never fail the whole install — it can be retried from
# the menu. In --chroot mode this runs as the target user (via runuser),
# because Sung's install script is a per-user install.
install_sung() {
  if [[ -x "$HOME/.local/bin/sung" ]]; then
    info "Sung already installed."
  else
    info "Installing Sung (default music player) from source..."
    local sung_dir="$HOME/.local/src/Sung"
    mkdir -p "$HOME/.local/src"
    if [[ -d "$sung_dir/.git" ]]; then
      (cd "$sung_dir" && git pull --ff-only) || warn "Could not update the Sung checkout; continuing with the existing one."
    else
      # A failed clone leaves a half-created directory behind, and
      # `git clone` refuses to clone into a non-empty one — every
      # later re-run would fail the same way until it was deleted by
      # hand. Remove it, but only when the clone created it: a
      # directory that was already there may hold the user's files.
      local sung_had_dir=0
      [[ -e "$sung_dir" ]] && sung_had_dir=1
      git clone https://github.com/yappologistic/Sung.git "$sung_dir" || {
        warn "Could not clone Sung; install it later from the menu (simorgh-menu -> Apps -> Music)."
        [[ "$sung_had_dir" -eq 0 ]] && rm -rf "$sung_dir"
      }
    fi
    if [[ -d "$sung_dir/.git" ]]; then
      (cd "$sung_dir" && ./scripts/install.sh) || warn "Sung install script failed; install it later from the menu (simorgh-menu -> Apps -> Music)."
    fi
    # Sung's pip step (ytmusicapi, for YouTube Music) can fail on flaky
    # networks — VM test 2 lost it to pypi.org timeouts, leaving Sung
    # working but without YouTube Music support. Retry the venv
    # requirements install if ytmusicapi is missing; Sung still works
    # without it, so never fail the install over this.
    local sung_venv="$HOME/.local/lib/sung/runtime/bin/python"
    if [[ -x "$sung_venv" ]] && ! "$sung_venv" -c "import ytmusicapi" 2>/dev/null; then
      for attempt in 1 2; do
        if "$sung_venv" -m pip install --disable-pip-version-check -r "$HOME/.local/lib/sung/requirements.txt" 2>/dev/null; then break; fi
        warn "Sung ytmusicapi install retry $attempt/2 failed."
      done
    fi
  fi
  # .desktop file (the audio MIME default needs one; Sung's own install
  # may not ship it) — create it if missing, but only when the binary
  # actually exists: a failed Sung install used to leave a .desktop
  # pointing at a nonexistent Exec=sung, and mimeapps.list maps
  # audio/* to it, so double-clicking an audio file launched nothing.
  mkdir -p "$HOME/.local/share/applications" || warn "Could not create ~/.local/share/applications; the Sung desktop entry was not installed."
  if [[ -x "$HOME/.local/bin/sung" && ! -f "$HOME/.local/share/applications/sung.desktop" ]]; then
    cat > "$HOME/.local/share/applications/sung.desktop" <<'EOF' || warn "Could not write the Sung desktop entry; audio files may not open in Sung."
[Desktop Entry]
Type=Application
Name=Sung
Comment=Music player
Exec=sung
Categories=Audio;Music;Player;
StartupWMClass=sung
EOF
  fi
}
if [[ $CHROOT_MODE -eq 1 ]]; then
  export -f install_sung info warn
  # Guarded: Sung must never fail the whole install (see above), and
  # an unguarded runuser call would abort it under `set -e`.
  runuser -u "$TARGET_USER" -- env HOME="$HOME" USER="$TARGET_USER" LOGNAME="$TARGET_USER" bash -c 'install_sung' || warn "Sung install step failed; install it later from the menu (simorgh-menu -> Apps -> Music)."
else
  install_sung || warn "Sung install step failed; install it later from the menu (simorgh-menu -> Apps -> Music)."
fi

# --- Maia (default file manager) ---------------------------------------------
# Maia has no AUR package: install the official release binary.
# Never fail the whole install if the download fails. In --chroot mode
# this runs as the target user (via runuser), because Maia installs
# into ~/.local.
install_maia() {
  if [[ -x "$HOME/.local/bin/maia" ]]; then
    info "Maia already installed."
  else
    info "Installing Maia (default file manager) from its official release..."
    local tmp
    tmp="$(mktemp -d)"
    # register_tmp only works in the installer itself: in --chroot mode
    # this runs in a runuser child where it is not exported, and
    # TEMP_DIRS lives in the parent anyway. Fall back to a child-local
    # EXIT trap there (path baked in: this local is already unset by
    # the time EXIT fires).
    if command -v register_tmp >/dev/null; then
      register_tmp "$tmp"
    else
      trap "rm -rf '$tmp'" EXIT
    fi
    if curl -fsSL -o "$tmp/maia-linux-x86_64" https://github.com/yappologistic/Maia/releases/latest/download/maia-linux-x86_64; then
      chmod +x "$tmp/maia-linux-x86_64"
      "$tmp/maia-linux-x86_64" --install || warn "Maia --install failed; install it later from the menu."
      [[ -x "$HOME/.local/bin/maia" ]] && "$HOME/.local/bin/maia" --set-default || true
    else
      warn "Could not download Maia; install it later from the menu (simorgh-menu -> File Manager)."
    fi
    rm -rf "$tmp"
  fi
  # .desktop file (the folder MIME default needs one) — create it if
  # missing, but only when the binary actually exists: a failed Maia
  # download used to leave a .desktop pointing at a nonexistent
  # Exec=maia, and mimeapps.list maps inode/directory to it, so
  # opening a folder launched nothing.
  mkdir -p "$HOME/.local/share/applications" || warn "Could not create ~/.local/share/applications; the Maia desktop entry was not installed."
  if [[ -x "$HOME/.local/bin/maia" && ! -f "$HOME/.local/share/applications/maia.desktop" ]]; then
    cat > "$HOME/.local/share/applications/maia.desktop" <<'EOF' || warn "Could not write the Maia desktop entry; folders may not open in Maia."
[Desktop Entry]
Type=Application
Name=Maia
Comment=File manager
Exec=maia %U
Categories=System;FileTools;FileManager;
MimeType=inode/directory;
StartupWMClass=maia
EOF
  fi
}
if [[ $CHROOT_MODE -eq 1 ]]; then
  export -f install_maia info warn
  # Guarded: Maia must never fail the whole install (see above), and
  # an unguarded runuser call would abort it under `set -e`.
  runuser -u "$TARGET_USER" -- env HOME="$HOME" USER="$TARGET_USER" LOGNAME="$TARGET_USER" bash -c 'install_maia' || warn "Maia install step failed; install it later from the menu (simorgh-menu -> File Manager)."
else
  install_maia || warn "Maia install step failed; install it later from the menu (simorgh-menu -> File Manager)."
fi

# --- Deploy files ------------------------------------------------------------
info "Deploying Simorgh files to $SHARE_DIR ..."
# Guarded: a failing copy/link here used to abort the whole install
# under `set -e` after the ~1.5h Sung/Maia builds — warn and continue
# instead; the missing files are reported again by the checks below.
mkdir -p "$SHARE_DIR/bin" "$SHARE_DIR/themes" "$SHARE_DIR/wallpapers" "$BIN_DIR" || warn "Could not create the deploy directories under $SHARE_DIR; the Simorgh commands may be missing."
# Copy contents (not the directories themselves) so re-runs and
# simorgh-update never nest bin/ inside bin/.
cp -r "$REPO_DIR/bin/." "$SHARE_DIR/bin/" || warn "Could not deploy bin/ to $SHARE_DIR/bin; the Simorgh commands may be missing."
cp -r "$REPO_DIR/themes/." "$SHARE_DIR/themes/" || warn "Could not deploy themes/ to $SHARE_DIR/themes; theme switching may fail."
cp -r "$REPO_DIR/wallpapers/." "$SHARE_DIR/wallpapers/" || warn "Could not deploy wallpapers/ to $SHARE_DIR/wallpapers; the wallpaper may be missing."
ln -sf "$SHARE_DIR/bin/simorgh-theme" "$BIN_DIR/simorgh-theme" || warn "Could not link simorgh-theme into $BIN_DIR."
ln -sf "$SHARE_DIR/bin/simorgh-menu" "$BIN_DIR/simorgh-menu" || warn "Could not link simorgh-menu into $BIN_DIR."
ln -sf "$SHARE_DIR/bin/simorgh-update" "$BIN_DIR/simorgh-update" || warn "Could not link simorgh-update into $BIN_DIR."
ln -sf "$SHARE_DIR/bin/simorgh-power" "$BIN_DIR/simorgh-power" || warn "Could not link simorgh-power into $BIN_DIR."
ln -sf "$SHARE_DIR/bin/simorgh-keybinds" "$BIN_DIR/simorgh-keybinds" || warn "Could not link simorgh-keybinds into $BIN_DIR."
ln -sf "$SHARE_DIR/bin/simorgh-record" "$BIN_DIR/simorgh-record" || warn "Could not link simorgh-record into $BIN_DIR."
ln -sf "$SHARE_DIR/bin/simorgh-welcome" "$BIN_DIR/simorgh-welcome" || warn "Could not link simorgh-welcome into $BIN_DIR."
chmod +x "$SHARE_DIR/bin/"* || warn "Could not mark the Simorgh commands executable; run 'chmod +x $SHARE_DIR/bin/*' manually if they fail to run."

# --- Configs (edited configs are left in place) ----------------------
info "Installing configs (missing configs are installed; your edited configs are left in place; only ~/.zshrc and ~/.profile are backed up to $BACKUP_DIR)..."
mkdir -p "$BACKUP_DIR" || warn "Could not create $BACKUP_DIR; ~/.zshrc and ~/.profile will not be backed up."
# Remember the active theme so re-runs (simorgh-update) keep it instead
# of resetting to the default.
CURRENT_THEME="$DEFAULT_THEME"
if [[ -f "$CONFIG_DIR/hypr/themes/current" ]]; then
  CURRENT_THEME="$(cat "$CONFIG_DIR/hypr/themes/current")"
fi
# Only deploy a config that is missing or byte-identical to the repo
# version. Moving an edited config to a timestamped backup and copying
# the repo version over it wiped user edits on every update — an edited
# config is now left in place with a warning instead.
deploy_config() { # deploy_config <name>
  local name="$1"
  local src="$REPO_DIR/config/$name" dst="$CONFIG_DIR/$name"
  # A repo config that no longer exists must not abort the install
  # under `set -e` (a failed `cp -r` below would).
  if [[ ! -e "$src" ]]; then
    warn "Repo config missing: $src — skipping."
    return 0
  fi
  if [[ ! -e "$dst" ]]; then
    mkdir -p "$CONFIG_DIR" || warn "Could not create $CONFIG_DIR; config $name may fail to install."
    cp -r "$src" "$dst" || warn "Could not install config $name; run 'cp -r $src $dst' manually."
    return 0
  fi
  # A pre-existing but empty destination (e.g. left behind by an
  # interrupted earlier run) is not a user edit: deploy into it instead
  # of warning and leaving a fresh install with no config at all.
  if [[ -d "$dst" ]] && [[ -z "$(find "$dst" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
    cp -r "$src/." "$dst" || warn "Could not install config $name into the empty $dst; run 'cp -r $src/. $dst' manually."
    return 0
  fi
  if [[ -f "$dst" && ! -s "$dst" ]]; then
    cp "$src" "$dst" || warn "Could not install config $name; run 'cp $src $dst' manually."
    return 0
  fi
  # Theme-managed files differ by design once `simorgh-theme` has run
  # (it rewrites them on every theme switch), so they must not count
  # as user edits: without the exclusions, a pristine deploy + theme
  # apply already differs in hypr, waybar, rofi, kitty and swaync, and
  # every re-run would warn about "edited" configs nobody edited —
  # and repo updates to those five would never deploy again. The
  # excluded files are exactly the ones simorgh-theme writes:
  # active.lua / current / wallpaper.png / hyprpaper.conf /
  # hyprlock.conf (background path) in hypr, theme.css in waybar,
  # theme.rasi in rofi, theme.conf in kitty, style.css in swaync.
  # NOTE: `diff -x` matches by BASENAME at any depth, so a blanket
  # `-x style.css` also excluded waybar/style.css — a static
  # stylesheet simorgh-theme never writes — and repo updates to it
  # silently never deployed on re-runs. deploy_config runs once per
  # top-level config, so the style.css exclusion applies only when
  # deploying swaync, the one config where it is theme-managed.
  # (Residual: repo updates to hyprlock.conf / hyprpaper.conf outside
  # the theme-managed lines won't deploy either — the theme rewrites
  # those files wholesale, so they are seeds, not live configs.)
  local -a diff_excludes=(
    -x active.lua -x current -x wallpaper.png
    -x hyprpaper.conf -x hyprlock.conf
    -x theme.css -x theme.rasi -x theme.conf
  )
  if [[ "$name" == "swaync" ]]; then
    diff_excludes+=( -x style.css )
  fi
  if diff -r -q "${diff_excludes[@]}" \
      "$src" "$dst" >/dev/null 2>&1; then
    # Byte-identical (ignoring theme-managed files): nothing to deploy.
    return 0
  fi
  warn "Keeping your edited $name — not overwritten (compare with $src, or move it aside and re-run to get the repo version)."
}
for cfg in hypr waybar rofi kitty zsh swaync starship.toml fastfetch gtk-3.0 gtk-4.0 nvim; do
  # zsh config lives in ~/.config/zsh/.zshrc; link it from ~/.zshrc
  deploy_config "$cfg"
done
# Back up a real ~/.zshrc before replacing it with the link. A symlink
# (e.g. dotfiles-managed) is left alone, like ~/.profile below: `ln -sf`
# would silently replace the link itself, unlinking the user's dotfiles
# .zshrc without any backup.
if [[ -L "$HOME/.zshrc" ]]; then
  warn "~/.zshrc is a symlink to $(readlink "$HOME/.zshrc") — leaving it alone; add 'source $CONFIG_DIR/zsh/.zshrc' there yourself if you want the Simorgh shell setup."
elif [[ -e "$HOME/.zshrc" ]]; then
  if mv "$HOME/.zshrc" "$BACKUP_DIR/.zshrc"; then
    info "Backed up existing ~/.zshrc"
    ln -sf "$CONFIG_DIR/zsh/.zshrc" "$HOME/.zshrc" || warn "Could not link ~/.zshrc to the Simorgh shell setup; run 'ln -sf $CONFIG_DIR/zsh/.zshrc ~/.zshrc' manually."
  else
    warn "Could not back up ~/.zshrc; leaving it untouched."
  fi
else
  ln -sf "$CONFIG_DIR/zsh/.zshrc" "$HOME/.zshrc" || warn "Could not link ~/.zshrc to the Simorgh shell setup; run 'ln -sf $CONFIG_DIR/zsh/.zshrc ~/.zshrc' manually."
fi
# Session PATH: ~/.profile (SDDM reads it on login) + /etc/profile.d
# (system-wide). Without this, Hyprland keybinds can't find the
# ~/.local/bin commands — .zshrc only sets PATH for interactive shells,
# and the SDDM session never reads it.
if [[ -f "$REPO_DIR/config/profile" ]]; then
  if [[ -L "$HOME/.profile" ]]; then
    # A symlink (e.g. dotfiles-managed) must not be copied through:
    # plain `cp` would clobber the file the link points at. Leave the
    # link alone — /etc/profile.d/simorgh.sh below already puts
    # ~/.local/bin on the session PATH.
    warn "~/.profile is a symlink to $(readlink "$HOME/.profile") — leaving it alone; add the PATH line from $REPO_DIR/config/profile there yourself if you want it."
  else
    if [[ -e "$HOME/.profile" ]]; then
      if mv "$HOME/.profile" "$BACKUP_DIR/.profile"; then
        info "Backed up existing ~/.profile"
        cp "$REPO_DIR/config/profile" "$HOME/.profile" || warn "Could not install ~/.profile; the session PATH may miss ~/.local/bin — copy $REPO_DIR/config/profile there manually."
      else
        warn "Could not back up ~/.profile; leaving it untouched."
      fi
    else
      cp "$REPO_DIR/config/profile" "$HOME/.profile" || warn "Could not install ~/.profile; the session PATH may miss ~/.local/bin — copy $REPO_DIR/config/profile there manually."
    fi
  fi
fi
# /etc/profile.d may not exist on a minimal install — create it first,
# and warn instead of aborting: a missing PATH shim must not kill a
# nearly-complete install under `set -e`.
$SUDO mkdir -p /etc/profile.d || warn "Could not create /etc/profile.d; ~/.local/bin will not be on the login PATH."
echo 'export PATH="$HOME/.local/bin:$PATH"' | $SUDO tee /etc/profile.d/simorgh.sh >/dev/null || warn "Could not write /etc/profile.d/simorgh.sh; ~/.local/bin will not be on the login PATH."
# Default applications (browser, editor, viewer, player, archives).
# Only installed when missing — like every other config above, an
# existing mimeapps.list is the user's (their default-browser choice
# used to be overwritten on every re-run, with only a backup left
# behind to show for it).
if [[ -f "$REPO_DIR/config/mimeapps.list" ]]; then
  if [[ ! -e "$CONFIG_DIR/mimeapps.list" ]]; then
    cp "$REPO_DIR/config/mimeapps.list" "$CONFIG_DIR/mimeapps.list" || warn "Could not install the default-applications list; set your default apps manually."
    # Drop default handlers whose app failed to install: the .desktop
    # files are only written when the binary exists (see install_sung /
    # install_maia), so a mimeapps.list pointing at a missing .desktop
    # would leave double-clicking audio files or folders launching
    # nothing. Only the freshly deployed copy is pruned — an existing
    # one is the user's. Deleting lines is idempotent: a re-run finds
    # nothing left to delete.
    if [[ -f "$CONFIG_DIR/mimeapps.list" ]]; then
      # Prune on the .desktop file itself, not the binary: the .desktop
      # is what mimeapps.list points at, and its write can fail even
      # when the binary installed fine (see install_sung/install_maia).
      [[ -f "$HOME/.local/share/applications/sung.desktop" ]] || sed -i '/sung\.desktop/d' "$CONFIG_DIR/mimeapps.list" || warn "Could not remove the missing Sung handler from mimeapps.list."
      [[ -f "$HOME/.local/share/applications/maia.desktop" ]] || sed -i '/maia\.desktop/d' "$CONFIG_DIR/mimeapps.list" || warn "Could not remove the missing Maia handler from mimeapps.list."
      # code.desktop is written only by the visual-studio-code-bin AUR
      # install (/usr/share/applications/code.desktop); a `code` binary
      # on PATH without it would still leave a dangling handler.
      [[ -f /usr/share/applications/code.desktop || -f "$HOME/.local/share/applications/code.desktop" ]] || sed -i '/code\.desktop/d' "$CONFIG_DIR/mimeapps.list" || warn "Could not remove the missing VS Code handler from mimeapps.list."
    fi
  fi
fi
if command -v xdg-settings >/dev/null; then
  # Only set a default when the user has none: setting it on every
  # re-run would reset a browser choice they made afterwards (and
  # rewrite the http/https handlers in their mimeapps.list).
  if [[ -z "$(xdg-settings get default-web-browser 2>/dev/null)" ]]; then
    xdg-settings set default-web-browser chromium.desktop || true
  fi
fi
# VS Code default settings (only if the user has none yet)
if [[ -f "$REPO_DIR/config/Code/User/settings.json" ]]; then
  mkdir -p "$CONFIG_DIR/Code/User" || warn "Could not create $CONFIG_DIR/Code/User; the VS Code default settings will not be installed."
  [[ -e "$CONFIG_DIR/Code/User/settings.json" ]] || cp "$REPO_DIR/config/Code/User/settings.json" "$CONFIG_DIR/Code/User/settings.json" || warn "Could not install the VS Code default settings; copy $REPO_DIR/config/Code/User/settings.json there manually."
fi
# Coordinated GTK theme + icons + cursor (Colloid-Dark / Papirus-Dark).
# Skipped in --chroot mode: gsettings needs a D-Bus session bus, which
# does not exist inside the Calamares chroot. The settings.ini files
# below are the fallback there, and the theme still applies.
if [[ $CHROOT_MODE -eq 0 ]] && command -v gsettings >/dev/null; then
  gsettings set org.gnome.desktop.interface gtk-theme 'Colloid-Dark' || true
  gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' || true
  gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic' || true
fi
# SDDM config goes to the system directory
if [[ -f "$REPO_DIR/config/sddm/simorgh.conf" ]]; then
  $SUDO mkdir -p /etc/sddm.conf.d || warn "Could not create /etc/sddm.conf.d; the login screen keeps its default theme."
  $SUDO cp "$REPO_DIR/config/sddm/simorgh.conf" /etc/sddm.conf.d/simorgh.conf || warn "Could not install the SDDM config; the login screen keeps its default theme."
fi
# Greeter software rendering: on GPUs without 3D acceleration (the common
# "try it in a VM" case) the sugar-candy Qt Quick greeter renders black —
# X glamor fails on llvmpipe. Forcing the software Qt Quick backend makes
# the login screen always appear; on real hardware the static greeter
# renders just as well. (VM test 2 verified the workaround.)
# (the mkdir above created /etc/sddm.conf.d when simorgh.conf exists; make
# sure it exists even if that file is ever missing)
$SUDO mkdir -p /etc/sddm.conf.d || warn "Could not create /etc/sddm.conf.d; the login screen may render black on GPUs without 3D acceleration."
printf '[General]\nGreeterEnvironment=QT_QUICK_BACKEND=software\n' | $SUDO tee /etc/sddm.conf.d/simorgh-software-render.conf >/dev/null || warn "Could not write the SDDM software-render config; the login screen may render black on GPUs without 3D acceleration."
# Login screen background: the signature wallpaper, in a system path
# SDDM can read (it cannot reliably read the user's home).
SDDM_THEME_CONF="/usr/share/sddm/themes/sugar-candy/theme.conf"
if [[ -f "$SDDM_THEME_CONF" && -f "$SHARE_DIR/wallpapers/simorgh-signature.png" ]]; then
  $SUDO mkdir -p /usr/share/backgrounds || warn "Could not create /usr/share/backgrounds; the login screen keeps its default background."
  $SUDO cp "$SHARE_DIR/wallpapers/simorgh-signature.png" /usr/share/backgrounds/simorgh-signature.png || warn "Could not copy the SDDM background; the login screen keeps its default background."
  if grep -q '^Background=' "$SDDM_THEME_CONF"; then
    $SUDO sed -i 's|^Background=.*|Background=/usr/share/backgrounds/simorgh-signature.png|' "$SDDM_THEME_CONF" || warn "Could not set the SDDM background in $SDDM_THEME_CONF; the login screen keeps its default background."
  else
    echo 'Background=/usr/share/backgrounds/simorgh-signature.png' | $SUDO tee -a "$SDDM_THEME_CONF" >/dev/null || warn "Could not set the SDDM background in $SDDM_THEME_CONF; the login screen keeps its default background."
  fi
fi

# --- Shell -------------------------------------------------------------------
if [[ $CHROOT_MODE -eq 1 ]]; then
  info "Setting zsh as the default shell for $TARGET_USER..."
  chsh -s /usr/bin/zsh "$TARGET_USER" || warn "Could not change the default shell automatically."
elif [[ "${SHELL:-}" != */zsh ]]; then
  info "Setting zsh as the default shell..."
  chsh -s /usr/bin/zsh || warn "Could not change the default shell automatically. Run: chsh -s /usr/bin/zsh"
fi

# --- Services ----------------------------------------------------------------
info "Enabling services (sddm, NetworkManager, bluetooth, cups)..."
# Enable each unit separately: one missing unit file used to abort the
# whole install at the very end (after the ~1.5h Sung build).
for unit in sddm NetworkManager bluetooth cups; do
  $SUDO systemctl enable "$unit" || warn "Could not enable $unit."
done

# --- Laptop detection --------------------------------------------------------
# Laptops get power management; desktops skip it. Detected via the DMI
# chassis type (8 = portable, 9 = laptop, 10 = notebook, 14 = sub-notebook)
# or the presence of a battery.
IS_LAPTOP=0
CHASSIS="$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || echo 0)"
case "$CHASSIS" in
  8|9|10|14) IS_LAPTOP=1 ;;
esac
if compgen -G '/sys/class/power_supply/BAT*' >/dev/null; then
  IS_LAPTOP=1
fi
if [[ "$IS_LAPTOP" -eq 1 ]]; then
  info "Laptop detected — power management enabled."
  # Tolerated: power management is a nice-to-have, not the desktop.
  pacman_retry -S --noconfirm --needed power-profiles-daemon || warn "Could not install power-profiles-daemon; laptop power management is unavailable."
  $SUDO systemctl enable power-profiles-daemon || warn "Could not enable power-profiles-daemon."
else
  info "Desktop detected — skipping laptop power management."
fi

# --- Ownership (chroot only) -------------------------------------------------
# The deploy above ran as root into the user's home; hand it back to them
# before the theme step (which runs as the user and writes user files).
if [[ $CHROOT_MODE -eq 1 ]]; then
  # Guarded: a failing chown (e.g. a file the target cannot own) must
  # not abort the install this late under `set -e` — the theme step
  # below reports it if it cannot write the user's configs.
  chown -R "$TARGET_USER:$TARGET_USER" "$HOME" || warn "Could not hand ownership of $HOME to $TARGET_USER; check ownership before logging in."
fi

# --- Theme -------------------------------------------------------------------
info "Applying theme ($CURRENT_THEME)..."
if [[ $CHROOT_MODE -eq 1 ]]; then
  runuser -u "$TARGET_USER" -- env HOME="$HOME" USER="$TARGET_USER" LOGNAME="$TARGET_USER" "$BIN_DIR/simorgh-theme" "$CURRENT_THEME" || warn "Theme apply reported an issue; run 'simorgh-theme $CURRENT_THEME' later."
else
  "$BIN_DIR/simorgh-theme" "$CURRENT_THEME" || warn "Theme apply reported an issue; run 'simorgh-theme $CURRENT_THEME' later."
fi

# --- Done --------------------------------------------------------------------
cat <<EOF

  ╔═╗╦╔╦╗╔═╗╦═╗╔═╗╦ ╦
  ╚═╗║║║║║ ║╠╦╝║ ╦╠═╣
  ╚═╝╩╩ ╩╚═╝╩╚═╝╚╝╩ ╩

  Simorgh is installed.

  Next steps:
    1. Reboot, then log in with SDDM. Hyprland starts automatically.
    2. SUPER + Return  — open Kitty
       SUPER + D       — open Rofi (app launcher)
       SUPER + E       — open Maia (file manager)
       SUPER + B       — open Chromium
       SUPER + T       — switch theme (6 glassy themes)
       SUPER + M       — open the Simorgh menu (apps, gaming, updates)
       SUPER + N       — notifications center
       SUPER + K       — keyboard shortcuts guide
       SUPER + \`      — scratchpad terminal
       SUPER + SHIFT+E — power menu (lock/logout/suspend/reboot/power off)
       Alt + Shift     — switch keyboard layout (us/ir)
    3. Run 'simorgh-menu' any time to install alternative browsers,
       terminals, editors, dev tools, or gaming tools (Steam, Heroic,
       Lutris...). Run 'simorgh-update' to update Simorgh itself.

  Your previous ~/.zshrc and ~/.profile (if any) are in: $BACKUP_DIR
  Simorgh files live in: $SHARE_DIR

EOF
