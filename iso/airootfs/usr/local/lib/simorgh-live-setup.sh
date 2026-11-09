#!/usr/bin/env bash
# simorgh-live-setup — one-shot setup for the live session (runs at boot,
# before SDDM). Creates the live user, deploys the Simorgh desktop config
# into their home, and makes Calamares start automatically.
# Runs as root, once, from simorgh-live-user.service.
set -euo pipefail

LIVE_USER="liveuser"
REPO_DIR="/opt/simorgh"

# --- Live user ---------------------------------------------------------------
if ! id -u "$LIVE_USER" >/dev/null 2>&1; then
  useradd -m -G wheel,audio,video,network,storage -s /bin/zsh "$LIVE_USER"
  # Passwordless sudo in the live session (so Calamares can do its job).
  echo "$LIVE_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/liveuser
  chmod 440 /etc/sudoers.d/liveuser
fi
USER_HOME="/home/$LIVE_USER"

# --- Desktop config (from the repo) ------------------------------------------
# The live session uses the same configs the installed system gets.
if [[ -d "$REPO_DIR/config" ]]; then
  mkdir -p "$USER_HOME/.config" "$USER_HOME/.local/share/simorgh"
  for cfg in hypr waybar rofi kitty swaync zsh; do
    [[ -d "$REPO_DIR/config/$cfg" ]] && cp -r "$REPO_DIR/config/$cfg" "$USER_HOME/.config/$cfg"
  done
  [[ -f "$REPO_DIR/config/starship.toml" ]] && cp "$REPO_DIR/config/starship.toml" "$USER_HOME/.config/starship.toml"
  [[ -e "$USER_HOME/.zshrc" ]] || ln -sf "$USER_HOME/.config/zsh/.zshrc" "$USER_HOME/.zshrc"
  cp -r "$REPO_DIR/themes" "$USER_HOME/.local/share/simorgh/themes" 2>/dev/null || true
  cp -r "$REPO_DIR/wallpapers" "$USER_HOME/.local/share/simorgh/wallpapers" 2>/dev/null || true
  # Skip the first-boot welcome in the live session.
  touch "$USER_HOME/.local/share/simorgh/.first-run-done"
  # Default theme files (hyprland.lua loads themes/active.lua via require).
  mkdir -p "$USER_HOME/.config/hypr/themes"
  [[ -f "$REPO_DIR/config/hypr/themes/active.lua" ]] && cp "$REPO_DIR/config/hypr/themes/active.lua" "$USER_HOME/.config/hypr/themes/active.lua"
  echo "teal-glass" > "$USER_HOME/.config/hypr/themes/current"
  # Wallpaper for the live session.
  if [[ -f "$USER_HOME/.local/share/simorgh/wallpapers/simorgh-signature.png" ]]; then
    cp "$USER_HOME/.local/share/simorgh/wallpapers/simorgh-signature.png" "$USER_HOME/.config/hypr/wallpaper.png"
    cat > "$USER_HOME/.config/hypr/hyprpaper.conf" <<EOF
preload = $USER_HOME/.config/hypr/wallpaper.png
wallpaper = ,$USER_HOME/.config/hypr/wallpaper.png
splash = false
ipc = on
EOF
  fi
  # Start Calamares instead of the welcome screen when Hyprland starts.
  # Via sudo (the live user has NOPASSWD sudo): running it as root
  # directly avoids Calamares' pkexec password prompt, which the live
  # session has no way to answer.
  # In Lua this is a second hyprland.start handler appended to hyprland.lua
  # (the main handler in the file already runs the other autostart apps).
  if [[ -f "$USER_HOME/.config/hypr/hyprland.lua" ]]; then
    grep -v 'simorgh-welcome' "$USER_HOME/.config/hypr/hyprland.lua" > "$USER_HOME/.config/hypr/hyprland.lua.tmp"
    mv "$USER_HOME/.config/hypr/hyprland.lua.tmp" "$USER_HOME/.config/hypr/hyprland.lua"
    if ! grep -q 'sudo -E calamares' "$USER_HOME/.config/hypr/hyprland.lua"; then
      cat >> "$USER_HOME/.config/hypr/hyprland.lua" <<'EOF'

-- Live installer: open Calamares automatically (removed on installed system).
hl.on("hyprland.start", function()
    hl.exec_cmd("sudo -E calamares")
end)
EOF
    fi
  fi
  # Session PATH for the live user (same file the installed system gets).
  [[ -f "$REPO_DIR/config/profile" ]] && cp "$REPO_DIR/config/profile" "$USER_HOME/.profile"
fi
chown -R "$LIVE_USER:$LIVE_USER" "$USER_HOME"
