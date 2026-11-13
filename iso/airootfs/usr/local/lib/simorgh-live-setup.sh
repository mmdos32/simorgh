#!/usr/bin/env bash
# simorgh-live-setup — one-shot setup for the live session (runs at boot,
# before SDDM). Creates the live user, deploys the Simorgh desktop config
# into their home, and makes Calamares start automatically.
# Runs as root, once, from simorgh-live-user.service.
set -euo pipefail

# Visible failure path: if this script fails, SDDM still boots and the user
# would land in a session with no installer and no on-screen error (journal
# only). So every failure also writes a marker in /run (tmpfs: live-only,
# never copied into the installed system by unpackfs), and the live
# hyprland.lua built below opens that marker in a terminal at session start.
# That hyprland.lua is built FIRST, right after the config copy, so a
# failure in any later step still leaves a session that shows the marker.
# What this cannot cover: failures before the live user/home exists
# (useradd, sudoers, chpasswd) and a missing /opt/simorgh/config — those
# stay journal/TTY-only; the live session then has no config at all.
FAIL_MARKER="/run/simorgh-live-setup-failed"
# A marker left by an earlier failed attempt must not survive into a
# retry: the service may be restarted on failure, and the script can
# also be re-run by hand. Clear it BEFORE the trap is armed, so only a
# failure in THIS run is ever shown. (/run is tmpfs, so a marker never
# survives a reboot — the stale case is a restart/re-run within one boot.)
rm -f "$FAIL_MARKER"
trap 'echo "simorgh-live-setup failed: line $LINENO: $BASH_COMMAND" > "$FAIL_MARKER"' ERR
fail() { echo "simorgh-live-setup: $*" | tee "$FAIL_MARKER" >&2; exit 1; }
# Ownership safety net: everything below that creates home content runs as
# root, and the only chown is the last line of the script — so any failure
# exit before it (fallback config, strip miss, luac failure) would leave
# /home/liveuser root-owned and the live session unable to write under
# $HOME (kitty cache, theme switching, Hyprland cache). Re-own the home
# on EVERY exit, success or failure, so no exit path can leave it
# root-owned. The explicit chown at the end stays: a second recursive
# chown on the success path is harmless, and the success path keeps
# owning the home even if this trap is ever removed. Guarded on the home
# existing, so exits before it is created (useradd, missing config) fail
# cleanly instead of tripping over an unset path.
chown_live_home() { [[ -n "${USER_HOME:-}" && -n "${LIVE_USER:-}" && -d "$USER_HOME" ]] && chown -R "$LIVE_USER:$LIVE_USER" "$USER_HOME" || true; }
trap chown_live_home EXIT
# Fallback live config: if building the live hyprland.lua fails (a strip
# miss or a Lua parse error), there is no previous live file on a first
# boot, so fail()-ing with no config would leave Hyprland on its built-in
# defaults — no installer autostart, no failure-marker terminal, no
# SUPER+I/SUPER+W recovery binds. Write the fallback block (marker +
# installer + recovery binds) into place instead, keep the marker so the
# failure stays visible, and still exit non-zero (caller exits after this).
write_live_fallback() { # write_live_fallback <reason>
  echo "simorgh-live-setup: $1" | tee "$FAIL_MARKER" >&2
  {
    echo "-- Simorgh live fallback (the live hyprland.lua build failed)."
    echo "-- Marker terminal + installer only; no desktop autostart, no theme."
    cat "$block_lua"
  } > "$live_lua"
  chmod 644 "$live_lua"
  # The fallback is the last-resort config: the shared block is checked
  # on its own before assembly (see below), so reaching here means the
  # block parsed and the failure is in the assembly — but check this
  # file anyway (same luac lookup as the normal path; a missing checker
  # must never break the boot) so a broken fallback is at least
  # recorded on the marker instead of failing silently.
  fallback_luac="$(command -v luac5.4 || command -v luac || true)"
  if [[ -n "$fallback_luac" ]] && ! "$fallback_luac" -p "$live_lua"; then
    echo "simorgh-live-setup: fallback live hyprland.lua does not parse either" | tee -a "$FAIL_MARKER" >&2
  fi
}

LIVE_USER="liveuser"
REPO_DIR="/opt/simorgh"

# --- Live user ---------------------------------------------------------------
if ! id -u "$LIVE_USER" >/dev/null 2>&1; then
  useradd -m -G wheel,audio,video,network,storage -s /bin/zsh "$LIVE_USER"
fi
# Passwordless sudo in the live session (so Calamares can do its job).
# Written unconditionally: if liveuser already existed the id check above
# is skipped, and sudo -E calamares would otherwise prompt for a password
# the live account cannot give.
echo "$LIVE_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/liveuser
chmod 440 /etc/sudoers.d/liveuser
# Documented live password (liveuser:live). The graphical session runs on
# tty2 (SDDM is on tty1), so a text console is Ctrl+Alt+F3 or later —
# Ctrl+Alt+F2 just switches back to the graphical session.
echo "$LIVE_USER:live" | chpasswd
USER_HOME="/home/$LIVE_USER"

# --- Desktop config (from the repo) ------------------------------------------
# The live session uses the same configs the installed system gets.
if [[ -d "$REPO_DIR/config" ]]; then
  mkdir -p "$USER_HOME/.config" "$USER_HOME/.local/share/simorgh" "$USER_HOME/.local/bin" || echo "simorgh-live-setup: WARNING: could not create live home directories" >&2
  for cfg in hypr waybar rofi kitty swaync zsh; do
    # Copy contents (not the directory itself, as install.sh does), so a
    # re-run overwrites instead of nesting .config/hypr/hypr/… inside
    # the existing directory. (Plain `cp -rT` fails when the source path
    # is a symlink to a directory.)
    [[ -d "$REPO_DIR/config/$cfg" ]] && { mkdir -p "$USER_HOME/.config/$cfg" || echo "simorgh-live-setup: WARNING: could not create $USER_HOME/.config/$cfg" >&2; cp -r "$REPO_DIR/config/$cfg/." "$USER_HOME/.config/$cfg/" || echo "simorgh-live-setup: WARNING: $cfg config copy failed, live session may miss it" >&2; }
  done
  # Live user's own tools (same layout install.sh deploys: bin/ under
  # ~/.local/share/simorgh, symlinked into ~/.local/bin). Without this,
  # SUPER+T/K/SHIFT+E/ALT+R call commands that do not exist live.
  if [[ -d "$REPO_DIR/bin" ]]; then
    mkdir -p "$USER_HOME/.local/share/simorgh/bin"
    cp -r "$REPO_DIR/bin/." "$USER_HOME/.local/share/simorgh/bin/" || echo "simorgh-live-setup: WARNING: live tools copy failed, SUPER+T/K will not work" >&2
    for tool in simorgh-menu simorgh-theme simorgh-update simorgh-power simorgh-keybinds simorgh-record simorgh-welcome; do
      [[ -e "$USER_HOME/.local/share/simorgh/bin/$tool" ]] && ln -sf "$USER_HOME/.local/share/simorgh/bin/$tool" "$USER_HOME/.local/bin/$tool"
    done
    chmod +x "$USER_HOME/.local/share/simorgh/bin/"* || echo "simorgh-live-setup: WARNING: could not mark live tools executable" >&2
    # The keybinds guide is a static list written for the installed
    # system: drop the shortcuts that are dead live, and add the two
    # live-only recovery binds, so SUPER+K teaches SUPER+W/SUPER+I.
    kb="$USER_HOME/.local/share/simorgh/bin/simorgh-keybinds"
    if [[ -f "$kb" ]]; then
      sed -i \
        -e '/Maia file manager/d' \
        -e '/Chromium browser/d' \
        -e '/VS Code editor/d' \
        -e '/Sung music player/d' \
        -e '/Simorgh menu/d' \
        -e '/Notifications center/d' \
        -e '/Do Not Disturb/d' \
        -e '/Calculator (Rofi)/d' \
        -e '/Color picker/d' \
        -e '/Toggle screen recording/d' \
        -e '/Toggle Waybar/d' \
        -e '/Emoji picker/d' \
        -e '/Scratchpad terminal/d' \
        -e '/Exit Hyprland/d' \
        -e '/Lock + suspend/d' \
        "$kb"
      sed -i '/^SUPER + K /a SUPER + I — Reopen the installer' "$kb"
      sed -i '/^SUPER + I — Reopen the installer/a SUPER + W — Join Wi-Fi (nmtui)' "$kb"
      # The edits above fail silently if the guide's wording ever drifts
      # (a delete pattern that matches nothing, an insert anchor that is
      # gone): the live guide would then teach dead shortcuts, or never
      # mention the two recovery binds. Verify they took effect — a
      # journal warning only, the binds themselves still work.
      # The lock-screen password (liveuser: live) is documented only in
      # iso/README.md — nowhere the live session itself shows it. Annotate
      # the Lock line in the live guide, so SUPER+K teaches it.
      sed -i 's/^SUPER + L — Lock screen$/SUPER + L — Lock screen (password: live)/' "$kb"
      # The power menu lost Logout live (stripped below), so its guide
      # line must not teach it — reword the parenthetical. Suspend is
      # stripped from the live menu too, so it goes from the guide as
      # well; the final live line reads (lock/reboot/power off).
      sed -i 's/(lock\/logout\/suspend\/reboot\/power off)/(lock\/suspend\/reboot\/power off)/' "$kb"
      sed -i 's/(lock\/suspend\/reboot\/power off)/(lock\/reboot\/power off)/' "$kb"
      grep -q '^SUPER + I — Reopen the installer' "$kb" || echo "simorgh-live-setup: WARNING: live keybinds guide is missing the SUPER+I line" >&2
      grep -q '^SUPER + W — Join Wi-Fi (nmtui)' "$kb" || echo "simorgh-live-setup: WARNING: live keybinds guide is missing the SUPER+W line" >&2
      if grep -qiE 'maia|chromium|vs code|sung|simorgh menu|notifications|do not disturb|calculator|color picker|screen recording|waybar|emoji picker|scratchpad|logout|suspend' "$kb"; then
        echo "simorgh-live-setup: WARNING: live keybinds guide still lists a dead-live shortcut" >&2
      fi
    fi
    # Live-only: drop Logout and Suspend from the power menu
    # (SUPER+SHIFT+E). Logout exits Hyprland mid-install, killing
    # Calamares, and SDDM autologins straight back into the
    # installer-only session; Suspend would suspend it mid-install.
    # The installed system keeps both entries — this only edits the
    # live copy.
    pw="$USER_HOME/.local/share/simorgh/bin/simorgh-power"
    if [[ -f "$pw" ]]; then
      sed -i 's/\\nLogout//' "$pw"
      sed -i '/^  "Logout")/d' "$pw"
      # Suspend too: same mid-install hazard as Logout (and the
      # SUPER+SHIFT+L bind is already stubbed live for the same
      # reason). Same pattern as the Logout strip above.
      sed -i 's/\\nSuspend//' "$pw"
      sed -i '/^  "Suspend")/d' "$pw"
      # The header comment still lists the stripped entries — reword
      # it to the live menu, same as the keybinds guide above.
      sed -i 's/lock, logout, suspend, reboot, power off/lock, reboot, power off/' "$pw"
      grep -q 'Logout' "$pw" && echo "simorgh-live-setup: WARNING: live power menu still lists Logout" >&2 || true
      # 'Suspend' bare would false-positive on the hyprlock notify
      # ("Lock and Suspend will not lock the screen"), so check the
      # menu entry itself: the case line and the rofi list item.
      if grep -qF '"Suspend")' "$pw" || grep -qF '\nSuspend' "$pw"; then
        echo "simorgh-live-setup: WARNING: live power menu still lists Suspend" >&2
      fi
    fi
  fi
  [[ -f "$REPO_DIR/config/starship.toml" ]] && { cp "$REPO_DIR/config/starship.toml" "$USER_HOME/.config/starship.toml" || echo "simorgh-live-setup: WARNING: starship.toml copy failed" >&2; }
  [[ -e "$USER_HOME/.zshrc" ]] || ln -sf "$USER_HOME/.config/zsh/.zshrc" "$USER_HOME/.zshrc"
  mkdir -p "$USER_HOME/.local/share/simorgh/themes" "$USER_HOME/.local/share/simorgh/wallpapers"
  # These two copies used to fail silently (2>/dev/null + || true): theme
  # switching / the live wallpaper then broke with no trace anywhere.
  # Warn loudly instead and keep going — the session still boots, and
  # the wallpaper step below already handles a missing file.
  cp -r "$REPO_DIR/themes/." "$USER_HOME/.local/share/simorgh/themes/" || echo "simorgh-live-setup: WARNING: themes copy failed, live theme switching will not work" >&2
  cp -r "$REPO_DIR/wallpapers/." "$USER_HOME/.local/share/simorgh/wallpapers/" || echo "simorgh-live-setup: WARNING: wallpapers copy failed, live wallpaper falls back" >&2
  # Skip the first-boot welcome in the live session.
  touch "$USER_HOME/.local/share/simorgh/.first-run-done"
  # Default theme files (hyprland.lua loads themes/active.lua via require).
  mkdir -p "$USER_HOME/.config/hypr/themes"
  if [[ -f "$REPO_DIR/config/hypr/themes/active.lua" ]]; then
    cp "$REPO_DIR/config/hypr/themes/active.lua" "$USER_HOME/.config/hypr/themes/active.lua" || echo "simorgh-live-setup: WARNING: repo hypr theme active.lua copy failed, live session keeps teal defaults" >&2
  else
    # Was silently skipped: the live hyprland.lua ends with
    # require("themes.active"), so a missing file would fail at session
    # start with no trace in this script. Warn loudly; the session still
    # boots on the teal defaults in hyprland.lua.
    echo "simorgh-live-setup: WARNING: repo hypr theme active.lua missing, live session keeps teal defaults" >&2
  fi
  echo "teal-glass" > "$USER_HOME/.config/hypr/themes/current"
  # --- Live hyprland.lua (built FIRST, before the fallible steps below) ---
  # The marker check must already be in place before the wallpaper, theme
  # and profile steps run: if any of those fails, the session still starts
  # with a hyprland.lua that shows the failure marker. (Failures before
  # this point — user creation, sudoers, chpasswd, or a missing config
  # dir — have no liveuser home to write to, so they stay journal/TTY-only.)
  # Built atomically: strip/stub/append happen on a temp file in the same
  # directory, which is syntax-checked and then moved into place, so a
  # re-run never nests configs and a kill mid-write never leaves a
  # truncated hyprland.lua behind. Rebuilt from the repo source on every
  # run, so no append guard (and no partial block) can accumulate.
  live_lua="$USER_HOME/.config/hypr/hyprland.lua"
  tmp_lua="$USER_HOME/.config/hypr/.hyprland.lua.tmp"
  block_lua="$USER_HOME/.config/hypr/.live-block.tmp"
  mkdir -p "$USER_HOME/.config/hypr"
  rm -f "$tmp_lua" "$block_lua"
  # Shared live block (marker + installer + recovery binds), written once
  # and reused by both the normal and the fallback path below.
  # Start Calamares instead of the welcome screen when Hyprland starts.
  # Via sudo (the live user has NOPASSWD sudo): running it as root
  # directly avoids Calamares' pkexec password prompt, which the live
  # session has no way to answer.
  # In Lua this is a second hyprland.start handler appended to hyprland.lua
  # (the main handler in the file already runs the other autostart apps).
  # Calamares launch lock: the autostart loop and the SUPER+I bind both
  # launch Calamares, guarded by flock on this file. It must already
  # exist, owned by the live user — /run is root-owned, so liveuser
  # could not create it at launch time.
  touch /run/simorgh-calamares.lock
  chown "$LIVE_USER:$LIVE_USER" /run/simorgh-calamares.lock
  cat > "$block_lua" <<'EOF'

-- Live installer: open Calamares automatically (removed on installed system).
-- If Calamares crashes (non-zero exit) it is relaunched, up to 3 times; a
-- clean exit (install finished, or closed on purpose) does not relaunch.
-- If it never stays up, a terminal explains how to retry (SUPER+I).
-- Both launch paths (this loop and SUPER+I) take the same lockfile,
-- so a retry and a SUPER+I press can never start two copies at once.
-- SUPER+I reopens the installer at any time; SUPER+W joins Wi-Fi (nmtui).
hl.on("hyprland.start", function()
    hl.exec_cmd("bash -c 'test -f /run/simorgh-live-setup-failed && kitty -e less /run/simorgh-live-setup-failed'")
    hl.exec_cmd("pgrep -x nm-applet || nm-applet")
    hl.exec_cmd("bash -c 'sleep 1; ok=0; for i in 1 2 3; do pgrep -x calamares >/dev/null || flock -n /run/simorgh-calamares.lock sudo -E calamares; [ $? -eq 0 ] && { ok=1; break; }; sleep 2; done; [ $ok -eq 1 ] || kitty -e bash -c \"echo The installer failed to start.; echo Press SUPER+I to retry, or Ctrl+Alt+F3 for a text console.; echo Text console login is liveuser / live.; echo Press any key to close this window.; read -n1 -s -r\"'")
end)
hl.bind("SUPER + I", hl.dsp.exec_cmd("pgrep -x calamares || flock -n /run/simorgh-calamares.lock sudo -E calamares"))
-- SUPER+W opens nmtui in a terminal (live-only Wi-Fi path: with no tray
-- in the installer-only session, nm-applet alone is not usable).
hl.bind("SUPER + W", hl.dsp.exec_cmd("kitty nmtui"))
EOF
  # The shared block is reused by both the normal and the fallback path:
  # if the block itself is broken, the fallback is broken too and
  # Hyprland loads no config at all, so the marker terminal (which only
  # exists inside a working config) never opens and the failure stays
  # journal-only. Check the block on its own before assembling anything
  # (same luac lookup as the normal path; a missing checker must never
  # break the boot). On failure, write a minimal marker-only config
  # straight into place — one autostart command opening the marker in a
  # terminal — so the failure is visible instead of journal-only.
  block_luac="$(command -v luac5.4 || command -v luac || true)"
  if [[ -n "$block_luac" ]] && ! "$block_luac" -p "$block_lua"; then
    echo "simorgh-live-setup: shared live block does not parse" | tee "$FAIL_MARKER" >&2
    {
      echo "-- Simorgh live fallback (the shared live block did not parse)."
      echo "hl.on(\"hyprland.start\", function()"
      echo "    hl.exec_cmd(\"kitty -e less $FAIL_MARKER\")"
      echo "end)"
    } > "$tmp_lua"
    chmod 644 "$tmp_lua"
    # The minimal config above is three lines, but check it anyway: if
    # even this does not parse, record it on the marker (nothing more
    # can be shown — there is no working config left to show it with).
    "$block_luac" -p "$tmp_lua" || echo "simorgh-live-setup: minimal marker-only config does not parse either" | tee -a "$FAIL_MARKER" >&2
    mv "$tmp_lua" "$live_lua"
    rm -f "$block_lua"
    exit 1
  fi
  if [[ -f "$REPO_DIR/config/hypr/hyprland.lua" ]]; then
    cp "$REPO_DIR/config/hypr/hyprland.lua" "$tmp_lua" || { write_live_fallback "live hyprland.lua copy failed"; exit 1; }
    # Installer-only session: strip the desktop autostart lines, one exact
    # line each. (The old `grep -v simorgh-welcome` also deleted the
    # welcome window-rule's name/match lines, leaving a rule with no
    # match; these patterns only match the exec_cmd lines.)
    sed -i \
      -e '/hl\.exec_cmd("waybar")/d' \
      -e '/hl\.exec_cmd("swaync")/d' \
      -e '/hl\.exec_cmd("hyprpaper")/d' \
      -e '/hl\.exec_cmd("hypridle")/d' \
      -e '/hl\.exec_cmd("\/usr\/lib\/hyprpolkitagent\/hyprpolkitagent")/d' \
      -e '/hl\.exec_cmd("wl-paste --watch cliphist store 2>\/dev\/null || true")/d' \
      -e '/hl\.exec_cmd("simorgh-welcome")/d' \
      -e '/hl\.exec_cmd("kitty --class scratchpad")/d' \
      "$tmp_lua"
    # If a future reformat changes any of these lines, the strip above
    # silently misses and the desktop autostarts live — write the fallback
    # live config instead (see write_live_fallback).
    # The check is spacing-tolerant on purpose: it looks for the app name
    # inside any exec_cmd(...), so it still catches a line the exact-match
    # sed above missed (checking for the exact string would be circular —
    # it could only ever match lines sed would already have deleted).
    for stripped in waybar swaync hyprpaper hypridle "/usr/lib/hyprpolkitagent/hyprpolkitagent" simorgh-welcome "kitty --class scratchpad"; do
      if grep -qE "exec_cmd\\(.*\"$stripped\"" "$tmp_lua"; then
        write_live_fallback "live strip missed an exec_cmd for $stripped in hyprland.lua"
        exit 1
      fi
    done
    # wl-paste's line carries trailing args (2>/dev/null || true), so
    # the quoted-name check above cannot match it — check its prefix.
    if grep -qE 'exec_cmd\(.*"wl-paste' "$tmp_lua"; then
      write_live_fallback "live strip missed an exec_cmd for wl-paste in hyprland.lua"
      exit 1
    fi
    # The list above only catches lines it names: a future autostart
    # line the strip missed would sail through. Also check the
    # autostart handler itself — after the strip it must hold no
    # exec_cmd at all (the live block, with its own exec_cmd lines, is
    # only appended below, so anything left here is a strip miss).
    if sed -n '/hl\.on("hyprland\.start", function()/,/^end)/p' "$tmp_lua" | grep -q 'hl\.exec_cmd('; then
      write_live_fallback "live strip missed an exec_cmd in the autostart handler of hyprland.lua"
      exit 1
    fi
    # Stub keybinds whose apps are not in the live image (the installed
    # system keeps them — this only touches the live copy). maia, sung,
    # chromium and VS Code are installed into the target by Calamares,
    # not shipped in the ISO; swaync, rofi-calc, rofi-emoji, hyprpicker
    # and wf-recorder are absent too, and waybar + the scratchpad are
    # not started in the installer-only session, so their toggles are dead.
    # SUPER+SHIFT+Q (exit) and SUPER+SHIFT+L (lock + suspend) are stubbed
    # too: either kills or suspends Hyprland mid-install, and SDDM
    # autologins straight back into the installer-only session.
    # SUPER+M is stubbed too: simorgh-menu's yay-install rescue cannot
    # work live (no yay/toolchain in the live image), so the menu is
    # unreachable live instead of guarded inside the menu.
    sed -i \
      -e '/hl\.dsp\.exec_cmd("maia")/d' \
      -e '/hl\.dsp\.exec_cmd("chromium")/d' \
      -e '/hl\.dsp\.exec_cmd("code")/d' \
      -e '/hl\.dsp\.exec_cmd("sung")/d' \
      -e '/hl\.dsp\.exec_cmd("simorgh-menu")/d' \
      -e '/swaync-client/d' \
      -e '/hl\.dsp\.exec_cmd("rofi -show calc")/d' \
      -e '/hyprpicker/d' \
      -e '/hl\.dsp\.exec_cmd("rofi -show emoji")/d' \
      -e '/hl\.dsp\.exec_cmd("simorgh-record")/d' \
      -e '/pkill -SIGUSR1 waybar/d' \
      -e '/toggle_special("scratchpad")/d' \
      -e '/hl\.dsp\.exit()/d' \
      -e '/systemctl suspend/d' \
      "$tmp_lua"
    # The stub seds above fail silently if a bind line's format ever
    # drifts: a dead-live bind would stay in the session with no trace.
    # Verify they all took effect — a journal warning only, like the
    # guide check above; the session still boots with one dead bind.
    # The patterns are spacing-tolerant on purpose (like the autostart
    # check above): they look for the command name inside any exec_cmd
    # or dsp call, so they still catch a line the exact-match sed above
    # missed — checking for the exact string would be circular.
    for stubbed in 'exec_cmd\(.*"maia"' 'exec_cmd\(.*"chromium"' 'exec_cmd\(.*"code"' 'exec_cmd\(.*"sung"' 'exec_cmd\(.*"simorgh-menu"' 'swaync-client' 'exec_cmd\(.*calc' 'hyprpicker' 'exec_cmd\(.*emoji' 'simorgh-record' 'pkill -SIGUSR1 waybar' 'toggle_special.*scratchpad' 'dsp\.exit' 'systemctl suspend'; do
      if grep -qE "$stubbed" "$tmp_lua"; then
        echo "simorgh-live-setup: WARNING: live keybind stub missed $stubbed in hyprland.lua" >&2
      fi
    done
    cat "$block_lua" >> "$tmp_lua"
  else
    # No hyprland.lua to copy (repo hypr dir or file missing): minimal
    # fallback so the session still shows the marker, the installer, and
    # the two recovery keybinds. No theme require() here — the fallback
    # must stand alone.
    echo "simorgh-live-setup: repo hyprland.lua missing at boot" | tee "$FAIL_MARKER" >&2
    {
      echo "-- Simorgh live fallback (the repo hyprland.lua was missing at boot)."
      echo "-- Marker terminal + installer only; no desktop autostart, no theme."
      cat "$block_lua"
    } > "$tmp_lua"
  fi
  # Syntax-check the generated file before it goes live. luac is the Arch
  # name, luac5.4 the Debian name; either may be absent from the live
  # image, so a missing checker must never break the boot.
  # A parse failure writes the fallback live config instead of fail()-ing
  # with no config (see write_live_fallback); the block is only removed
  # after the move, so it is still available for that fallback.
  luac_bin="$(command -v luac5.4 || command -v luac || true)"
  if [[ -n "$luac_bin" ]]; then
    "$luac_bin" -p "$tmp_lua" || { write_live_fallback "generated live hyprland.lua does not parse"; exit 1; }
  fi
  chmod 644 "$tmp_lua"
  mv "$tmp_lua" "$live_lua"
  rm -f "$block_lua"
  # Wallpaper for the live session (phoenix signature). If the signature
  # copy is missing for any reason, fall back to the theme gradient so
  # hyprpaper always has a valid file, and say so on stderr.
  wallpaper_src="$USER_HOME/.local/share/simorgh/wallpapers/simorgh-signature.png"
  [[ -f "$wallpaper_src" ]] || wallpaper_src="$USER_HOME/.local/share/simorgh/wallpapers/teal-glass.png"
  if [[ -f "$wallpaper_src" ]]; then
    cp "$wallpaper_src" "$USER_HOME/.config/hypr/wallpaper.png"
    # Block form: the flat preload/wallpaper=/splash/ipc form is dead in
    # the shipped hyprpaper 0.8.5-3. (hyprpaper is not autostarted in the
    # installer-only live session; this file just has to be correct if
    # it is ever used.)
    cat > "$USER_HOME/.config/hypr/hyprpaper.conf" <<EOF
# splash/ipc are valid top-level options in hyprpaper 0.8 — keep the
# splash text off and IPC on, as the shipped config always had.
splash = false
ipc = on
wallpaper {
    monitor = ;
    path = $USER_HOME/.config/hypr/wallpaper.png;
    fit_mode = cover;
}
EOF
  else
    echo "simorgh-live-setup: no wallpaper file found, hyprpaper left as shipped" >&2
  fi
  # Session PATH for the live user (same file the installed system gets).
  [[ -f "$REPO_DIR/config/profile" ]] && cp "$REPO_DIR/config/profile" "$USER_HOME/.profile"
else
  # No config dir at all: there is no home config to attach a marker check
  # to, so this stays journal/TTY-only by design (see header comment).
  fail "$REPO_DIR/config missing, cannot build the live session"
fi
chown -R "$LIVE_USER:$LIVE_USER" "$USER_HOME"
