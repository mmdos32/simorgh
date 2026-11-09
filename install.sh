#!/usr/bin/env bash
# Simorgh installer — Arch Linux + Hyprland, minimal and modern with glassy themes.
# Run on a fresh stock Arch install:  ./install.sh
# Or, from the ISO installer (Calamares), inside the target:
#   ./install.sh --chroot --user <name> [--locale <locale>]
# Idempotent where reasonable: package installs use --needed, existing
# configs are backed up before being replaced, and services are enabled
# (not blindly restarted).
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
    --user) TARGET_USER="${2:-}"; shift 2 ;;
    --locale) LOCALE_OVERRIDE="${2:-}"; shift 2 ;;
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

# --- Preconditions -----------------------------------------------------------
if [[ $CHROOT_MODE -eq 0 ]]; then
  [[ $EUID -ne 0 ]] || error "Do not run as root — run as your normal user (sudo is used where needed)."
  command -v sudo >/dev/null || error "sudo is required — install it first as root: pacman -S sudo (and add your user to the wheel group)."
  sudo -v || error "sudo authentication failed."
else
  [[ $EUID -eq 0 ]] || error "--chroot runs as root (inside the Calamares target)."
  command -v sudo >/dev/null || error "sudo is required in the target (for the yay step)."
  command -v runuser >/dev/null || error "runuser is required for --chroot."
fi
[[ -f /etc/arch-release ]] || error "This installer only runs on Arch Linux."

# In chroot mode we run as root by design; user-level steps run as the
# target user via runuser. sudo is not used (SUDO=""). yay builds as the
# user but installs via sudo, so the target user gets temporary
# passwordless sudo, removed when we exit (trap below).
if [[ $CHROOT_MODE -eq 1 ]]; then
  SUDO=""
  echo "$TARGET_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/simorgh-chroot
  chmod 440 /etc/sudoers.d/simorgh-chroot
  command -v visudo >/dev/null && visudo -cf /etc/sudoers.d/simorgh-chroot >/dev/null || true
  cleanup_chroot() { rm -f /etc/sudoers.d/simorgh-chroot; }
  trap cleanup_chroot EXIT INT TERM
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
mkdir -p "$SHARE_DIR"
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
  read -rp "Language [1]: " choice
  choice="${choice:-1}"
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#LOCALES[@]} )); then
    warn "Invalid choice, falling back to English."
    choice=1
  fi
  LOCALE="${LOCALES[$((choice - 1))]%%|*}"
fi
info "Locale: $LOCALE"
$SUDO sed -i "s/^#\(${LOCALE} UTF-8\)/\1/" /etc/locale.gen
$SUDO locale-gen
echo "LANG=$LOCALE" | $SUDO tee /etc/locale.conf >/dev/null
# Remember the locale and this repo's location for simorgh-update.
echo "$LOCALE" > "$SHARE_DIR/locale"
echo "$REPO_DIR" > "$SHARE_DIR/repo-path"

# --- Base tools (needed to build yay) ----------------------------------------
# yay is built with makepkg (base-devel) from a git clone — both must
# exist before the AUR helper step below, not after it.
info "Installing base tools (base-devel, git)..."
$SUDO pacman -Syu --noconfirm --needed base-devel git

# --- makepkg: disable debug symbols ----------------------------------------
# Arch enables `debug` in /etc/makepkg.conf by default, so makepkg copies
# debug sources for every file — the colloid build hung at 100% CPU for
# 18+ min on it (VM test). Disable it before any AUR build.
if grep -q ' purge debug ' /etc/makepkg.conf 2>/dev/null; then
  info "Disabling makepkg debug symbols (speeds up AUR builds)..."
  $SUDO sed -i 's/ purge debug lto)/ purge !debug lto)/' /etc/makepkg.conf
fi

# --- AUR helper --------------------------------------------------------------
# yay is built with makepkg (base-devel) from a git clone. The clone can
# fail on a flaky network; under `set -e` that used to abort the whole
# install (VM test, run 1). So: retry the clone once, then fall back to
# yay's GitHub release binary, and if that fails too, warn and continue —
# the AUR step below already degrades gracefully without yay.
if ! command -v yay >/dev/null; then
  info "Installing yay (AUR helper)..."
  tmp="$(mktemp -d)"; chmod 777 "$tmp"
  yay_ok=0
  for attempt in 1 2; do
    if [[ $CHROOT_MODE -eq 1 ]]; then
      # makepkg refuses to run as root: build as the target user.
      if runuser -u "$TARGET_USER" -- env HOME="$HOME" bash -c "git clone --depth 1 https://aur.archlinux.org/yay.git \"$tmp/yay\" && (cd \"$tmp/yay\" && makepkg -si --noconfirm)"; then yay_ok=1; break; fi
    else
      if git clone --depth 1 https://aur.archlinux.org/yay.git "$tmp/yay" && (cd "$tmp/yay" && makepkg -si --noconfirm); then yay_ok=1; break; fi
    fi
    warn "yay clone/build failed (attempt $attempt/2), retrying..."
    rm -rf "$tmp/yay"
  done
  if [[ $yay_ok -eq 0 ]]; then
    warn "yay clone failed twice; trying the yay release binary..."
    if (cd "$tmp" && curl -fsSL -o yay.tar.gz https://github.com/Jguer/yay/releases/download/v13.1.0/yay_13.1.0_x86_64.tar.gz && tar -xzf yay.tar.gz && $SUDO install -m 755 yay_13.1.0_x86_64/yay /usr/local/bin/yay); then
      yay_ok=1
    fi
  fi
  rm -rf "$tmp"
  [[ $yay_ok -eq 1 ]] || warn "Could not install yay; AUR packages will be skipped (install them later from the menu)."
else
  info "yay already installed."
fi

# --- Multilib (needed for Steam, installed later via the menu) --------------
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
  info "Enabling the multilib repository (needed for Steam)..."
  $SUDO sed -i -e 's/^#\[multilib\]/[multilib]/' -e '/^\[multilib\]/{n;s/^#Include = \/etc\/pacman.d\/mirrorlist/Include = \/etc\/pacman.d\/mirrorlist/}' /etc/pacman.conf
  $SUDO pacman -Sy --noconfirm
fi

# --- Packages ----------------------------------------------------------------
read_list() { grep -v '^\s*#' "$1" | grep -v '^\s*$' | tr '\n' ' '; }

info "Installing official packages..."
# shellcheck disable=SC2046
$SUDO pacman -Syu --noconfirm --needed $(read_list "$REPO_DIR/packages/pacman.txt")

info "Installing AUR packages..."
# Like Maia/Sung, a failed AUR install must not kill the whole install
# (VS Code / the GTK and SDDM themes can be installed later from the menu).
# --answerdiff/--answerclean/--answeredit None: the cleanBuild/diff prompts
# can appear stuck on a serial console (VM test), so answer them explicitly.
if [[ $CHROOT_MODE -eq 1 ]]; then
  # shellcheck disable=SC2046
  runuser -u "$TARGET_USER" -- env HOME="$HOME" yay -S --noconfirm --answerdiff None --answerclean None --answeredit None --needed $(read_list "$REPO_DIR/packages/aur.txt") || warn "AUR install failed (network/AUR issue); install VS Code, the GTK theme and the SDDM theme later from the menu."
else
  # shellcheck disable=SC2046
  yay -S --noconfirm --answerdiff None --answerclean None --answeredit None --needed $(read_list "$REPO_DIR/packages/aur.txt") || warn "AUR install failed (network/AUR issue); install VS Code, the GTK theme and the SDDM theme later from the menu."
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
info "Installing the Colloid GTK theme (Colloid-Dark, from upstream)..."
colloid_tmp="$(mktemp -d)"; chmod 777 "$colloid_tmp"
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
  # DKMS needs the headers matching the running kernel. In chroot mode
  # the target kernel is the stock linux kernel (ISO preset).
  if [[ $CHROOT_MODE -eq 1 ]]; then
    KERNEL_HEADERS="linux-headers"
  else
    case "$(uname -r)" in
      *zen*)      KERNEL_HEADERS="linux-zen-headers" ;;
      *lts*)      KERNEL_HEADERS="linux-lts-headers" ;;
      *hardened*) KERNEL_HEADERS="linux-hardened-headers" ;;
      *)          KERNEL_HEADERS="linux-headers" ;;
    esac
  fi
  $SUDO pacman -S --noconfirm --needed nvidia-dkms nvidia-utils lib32-nvidia-utils "$KERNEL_HEADERS"
  # grub-mkconfig needs the target's /boot (mounted in the Calamares
  # chroot; a mountpoint or an existing /boot/grub on a normal install).
  if [[ -f /etc/default/grub ]] && ! grep -q 'nvidia_drm.modeset=1' /etc/default/grub && { [[ -d /boot/grub ]] || mountpoint -q /boot; }; then
    $SUDO cp /etc/default/grub /etc/default/grub.simorgh-bak
    $SUDO sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia_drm.modeset=1 /' /etc/default/grub
    if grep -q 'nvidia_drm.modeset=1' /etc/default/grub && $SUDO grub-mkconfig -o /boot/grub/grub.cfg; then
      info "DRM modesetting enabled — reboot to apply."
    else
      warn "Could not enable DRM modesetting; add nvidia_drm.modeset=1 to GRUB_CMDLINE_LINUX_DEFAULT manually."
    fi
  fi
else
  info "No NVIDIA GPU detected — skipping the proprietary driver."
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
      git clone https://github.com/yappologistic/Sung.git "$sung_dir" || warn "Could not clone Sung; install it later from the menu (simorgh-menu -> Apps -> Music)."
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
  # may not ship it) — create it if missing.
  mkdir -p "$HOME/.local/share/applications"
  if [[ ! -f "$HOME/.local/share/applications/sung.desktop" ]]; then
    cat > "$HOME/.local/share/applications/sung.desktop" <<'EOF'
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
  runuser -u "$TARGET_USER" -- env HOME="$HOME" bash -c 'install_sung'
else
  install_sung
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
    if curl -fsSL -o "$tmp/maia-linux-x86_64" https://github.com/yappologistic/Maia/releases/latest/download/maia-linux-x86_64; then
      chmod +x "$tmp/maia-linux-x86_64"
      "$tmp/maia-linux-x86_64" --install || warn "Maia --install failed; install it later from the menu."
      [[ -x "$HOME/.local/bin/maia" ]] && "$HOME/.local/bin/maia" --set-default || true
    else
      warn "Could not download Maia; install it later from the menu (simorgh-menu -> File Manager)."
    fi
    rm -rf "$tmp"
  fi
  # .desktop file (the folder MIME default needs one) — create it if missing.
  mkdir -p "$HOME/.local/share/applications"
  if [[ ! -f "$HOME/.local/share/applications/maia.desktop" ]]; then
    cat > "$HOME/.local/share/applications/maia.desktop" <<'EOF'
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
  runuser -u "$TARGET_USER" -- env HOME="$HOME" bash -c 'install_maia'
else
  install_maia
fi

# --- Deploy files ------------------------------------------------------------
info "Deploying Simorgh files to $SHARE_DIR ..."
mkdir -p "$SHARE_DIR/bin" "$SHARE_DIR/themes" "$SHARE_DIR/wallpapers" "$BIN_DIR"
# Copy contents (not the directories themselves) so re-runs and
# simorgh-update never nest bin/ inside bin/.
cp -r "$REPO_DIR/bin/." "$SHARE_DIR/bin/"
cp -r "$REPO_DIR/themes/." "$SHARE_DIR/themes/"
cp -r "$REPO_DIR/wallpapers/." "$SHARE_DIR/wallpapers/"
ln -sf "$SHARE_DIR/bin/simorgh-theme" "$BIN_DIR/simorgh-theme"
ln -sf "$SHARE_DIR/bin/simorgh-menu" "$BIN_DIR/simorgh-menu"
ln -sf "$SHARE_DIR/bin/simorgh-update" "$BIN_DIR/simorgh-update"
ln -sf "$SHARE_DIR/bin/simorgh-power" "$BIN_DIR/simorgh-power"
ln -sf "$SHARE_DIR/bin/simorgh-keybinds" "$BIN_DIR/simorgh-keybinds"
ln -sf "$SHARE_DIR/bin/simorgh-record" "$BIN_DIR/simorgh-record"
ln -sf "$SHARE_DIR/bin/simorgh-welcome" "$BIN_DIR/simorgh-welcome"
chmod +x "$SHARE_DIR/bin/"*

# --- Configs (with backup) ---------------------------------------------------
info "Installing configs (existing configs backed up to $BACKUP_DIR)..."
mkdir -p "$BACKUP_DIR"
# Remember the active theme so re-runs (simorgh-update) keep it instead
# of resetting to the default.
CURRENT_THEME="$DEFAULT_THEME"
if [[ -f "$CONFIG_DIR/hypr/themes/current" ]]; then
  CURRENT_THEME="$(cat "$CONFIG_DIR/hypr/themes/current")"
fi
deploy_config() { # deploy_config <name>
  local name="$1"
  if [[ -e "$CONFIG_DIR/$name" ]]; then
    mv "$CONFIG_DIR/$name" "$BACKUP_DIR/$name"
    info "Backed up existing $name"
  fi
  mkdir -p "$CONFIG_DIR"
  cp -r "$REPO_DIR/config/$name" "$CONFIG_DIR/$name"
}
for cfg in hypr waybar rofi kitty zsh swaync starship.toml fastfetch gtk-3.0 gtk-4.0 nvim; do
  # zsh config lives in ~/.config/zsh/.zshrc; link it from ~/.zshrc
  deploy_config "$cfg"
done
# Back up a real ~/.zshrc before replacing it with the link.
if [[ -e "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
  mv "$HOME/.zshrc" "$BACKUP_DIR/.zshrc"
  info "Backed up existing ~/.zshrc"
fi
ln -sf "$CONFIG_DIR/zsh/.zshrc" "$HOME/.zshrc"
# Session PATH: ~/.profile (SDDM reads it on login) + /etc/profile.d
# (system-wide). Without this, Hyprland keybinds can't find the
# ~/.local/bin commands — .zshrc only sets PATH for interactive shells,
# and the SDDM session never reads it.
if [[ -f "$REPO_DIR/config/profile" ]]; then
  if [[ -e "$HOME/.profile" && ! -L "$HOME/.profile" ]]; then
    mv "$HOME/.profile" "$BACKUP_DIR/.profile"
    info "Backed up existing ~/.profile"
  fi
  cp "$REPO_DIR/config/profile" "$HOME/.profile"
fi
echo 'export PATH="$HOME/.local/bin:$PATH"' | $SUDO tee /etc/profile.d/simorgh.sh >/dev/null
# Default applications (browser, editor, viewer, player, archives)
if [[ -f "$REPO_DIR/config/mimeapps.list" ]]; then
  [[ -e "$CONFIG_DIR/mimeapps.list" ]] && mv "$CONFIG_DIR/mimeapps.list" "$BACKUP_DIR/mimeapps.list"
  cp "$REPO_DIR/config/mimeapps.list" "$CONFIG_DIR/mimeapps.list"
fi
if command -v xdg-settings >/dev/null; then
  xdg-settings set default-web-browser chromium.desktop || true
fi
# VS Code default settings (only if the user has none yet)
if [[ -f "$REPO_DIR/config/Code/User/settings.json" ]]; then
  mkdir -p "$CONFIG_DIR/Code/User"
  [[ -e "$CONFIG_DIR/Code/User/settings.json" ]] || cp "$REPO_DIR/config/Code/User/settings.json" "$CONFIG_DIR/Code/User/settings.json"
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
  $SUDO mkdir -p /etc/sddm.conf.d
  $SUDO cp "$REPO_DIR/config/sddm/simorgh.conf" /etc/sddm.conf.d/simorgh.conf
fi
# Greeter software rendering: on GPUs without 3D acceleration (the common
# "try it in a VM" case) the sugar-candy Qt Quick greeter renders black —
# X glamor fails on llvmpipe. Forcing the software Qt Quick backend makes
# the login screen always appear; on real hardware the static greeter
# renders just as well. (VM test 2 verified the workaround.)
# (the mkdir above created /etc/sddm.conf.d when simorgh.conf exists; make
# sure it exists even if that file is ever missing)
$SUDO mkdir -p /etc/sddm.conf.d
printf '[General]\nGreeterEnvironment=QT_QUICK_BACKEND=software\n' | $SUDO tee /etc/sddm.conf.d/simorgh-software-render.conf >/dev/null
# Login screen background: the signature wallpaper, in a system path
# SDDM can read (it cannot reliably read the user's home).
SDDM_THEME_CONF="/usr/share/sddm/themes/sugar-candy/theme.conf"
if [[ -f "$SDDM_THEME_CONF" && -f "$SHARE_DIR/wallpapers/simorgh-signature.png" ]]; then
  $SUDO mkdir -p /usr/share/backgrounds
  $SUDO cp "$SHARE_DIR/wallpapers/simorgh-signature.png" /usr/share/backgrounds/simorgh-signature.png
  if grep -q '^Background=' "$SDDM_THEME_CONF"; then
    $SUDO sed -i 's|^Background=.*|Background=/usr/share/backgrounds/simorgh-signature.png|' "$SDDM_THEME_CONF"
  else
    echo 'Background=/usr/share/backgrounds/simorgh-signature.png' | $SUDO tee -a "$SDDM_THEME_CONF" >/dev/null
  fi
fi

# --- Shell -------------------------------------------------------------------
if [[ $CHROOT_MODE -eq 1 ]]; then
  info "Setting zsh as the default shell for $TARGET_USER..."
  chsh -s /usr/bin/zsh "$TARGET_USER" || warn "Could not change the default shell automatically."
elif [[ "$SHELL" != */zsh ]]; then
  info "Setting zsh as the default shell..."
  chsh -s /usr/bin/zsh || warn "Could not change the default shell automatically. Run: chsh -s /usr/bin/zsh"
fi

# --- Services ----------------------------------------------------------------
info "Enabling services (sddm, NetworkManager, bluetooth)..."
$SUDO systemctl enable sddm NetworkManager bluetooth cups

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
  $SUDO pacman -S --noconfirm --needed power-profiles-daemon
  $SUDO systemctl enable power-profiles-daemon
else
  info "Desktop detected — skipping laptop power management."
fi

# --- Ownership (chroot only) -------------------------------------------------
# The deploy above ran as root into the user's home; hand it back to them
# before the theme step (which runs as the user and writes user files).
if [[ $CHROOT_MODE -eq 1 ]]; then
  chown -R "$TARGET_USER:$TARGET_USER" "$HOME"
fi

# --- Theme -------------------------------------------------------------------
info "Applying theme ($CURRENT_THEME)..."
if [[ $CHROOT_MODE -eq 1 ]]; then
  runuser -u "$TARGET_USER" -- env HOME="$HOME" "$BIN_DIR/simorgh-theme" "$CURRENT_THEME" || warn "Theme apply reported an issue; run 'simorgh-theme $CURRENT_THEME' later."
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

  Your previous configs (if any) are in: $BACKUP_DIR
  Simorgh files live in: $SHARE_DIR

EOF
