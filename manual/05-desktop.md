# Desktop

## Desktop behavior


- **First boot:** a welcome screen opens once, with the essential
  shortcuts (`SUPER + K` shows them all). Later logins go straight
  to the desktop. (The flag lives at
  `~/.local/share/simorgh/.first-run-done` — delete it to see the
  welcome again.)
- **Workspaces** are numbered, not named.
- **Window rules:** small dialogs (volume, archives, Bluetooth,
  network settings, calculator) float; Sung opens as a small
  floating mini player (900×560, centered). No app is forced onto a
  workspace — except the scratchpad terminal, which lives on the
  special scratchpad workspace (`SUPER + \`` toggles it).
- **Waybar** shows the currently playing track (MPRIS — Sung,
  Spotify, …) next to the clock, the weather (wttr.in, refreshed
  every 30 minutes), and a pending-updates counter — click it to
  update the system.
- **Wi-Fi:** `network-manager-applet` is installed but does not
  autostart, and Waybar's network indicator is display-only (no
  click action, no tray icon), so there is no graphical Wi-Fi menu
  on the installed desktop. Connect from a terminal with `nmtui`
  (open one with `SUPER + Return`, then run `nmtui`). (`nmtui` is
  also the live installer's Wi-Fi path — `SUPER + W` there.)
- **Rofi** stays a centered list, glassy like the rest.
- **NVIDIA GPUs are auto-detected** at install time and get the
  proprietary driver (DKMS) + 32-bit libs + DRM modesetting in GRUB.
  AMD/Intel need nothing extra; Mesa/Vulkan drivers come with
  "Install all gaming packages" in the menu. If you boot with systemd-boot instead of
  GRUB, add `nvidia_drm.modeset=1` to your kernel command line
  manually.
- **Default apps are set up:** Chromium for the web, VS Code for
  text/code, Loupe for images, Evince for PDF, VLC for video, Sung
  for audio, Maia for folders (`config/mimeapps.list`).
- **VS Code ships sane defaults** (JetBrains Mono, format on save,
  dark theme) — only if you have no settings yet — and **Neovim ships
  a minimal config** (`config/nvim/init.lua`), also only when
  `~/.config/nvim` doesn't exist yet. An existing config is never
  overwritten: an edited one is left in place with a warning.
- **Modern CLI tools** are preinstalled: fzf, ripgrep, eza, bat,
  zoxide. fzf, eza, bat and zoxide are wired into `.zshrc` with
  guarded aliases; ripgrep is installed as-is.
- **Flatpak** is not preinstalled — install it from the menu
  (`simorgh-menu` → Install Flatpak), which also adds Flathub.
- **Printing** works out of the box: CUPS is installed and enabled.
- **Idle:** the screen locks after 5 minutes, turns off after 6,
  and the system suspends after 15. Change the numbers (in seconds)
  in `config/hypr/hypridle.conf`, then restart hypridle
  (`pkill hypridle; hypridle &`) — `hyprctl reload` only reloads
  Hyprland, hypridle never re-reads its config.
- **Multi-monitor** is automatic; `SUPER + CTRL + arrows`
  moves focus between monitors.
- Deliberately **not** included, following Omarchy's defaults: no
  night light, no firewall, no system snapshots, no Plymouth boot splash on the installed system (the BIOS/legacy ISO boot menu keeps the phoenix background; UEFI boot shows a plain menu).

## The menu


`simorgh-menu` (or `SUPER + M`) opens a Rofi menu:

- **Install Browser / Terminal / Editor / File Manager** — one-click
  alternatives (defaults: Chromium, Kitty, VS Code, Maia; Dolphin,
  Thunar, Nautilus for files)
- **Install Apps** — Music (Sung (default), Spotify, SoundCloud web app, Amberol,
  Rhythmbox), Video (VLC (default), mpv, Celluloid, Haruna), PDF (Evince (default), Okular, Zathura), Image Viewer (Loupe (default), Eye of GNOME (eog), imv),
  System Monitor (btop (default), Mission Center), Office (LibreOffice), Messenger
  (Telegram Desktop, Vesktop (Discord)), Email (Thunderbird), Image Editor (GIMP), Recording (OBS Studio), Passwords
  (KeePassXC), Bluetooth (Blueman (default)), Calculator (GNOME Calculator), Terminal Multiplexer
  (tmux)
- **Dev Tools** — C/C++ toolchain, Python pip, npm, Rust (rustup), Go, Docker (+ Compose),
  lazygit, GitHub CLI (gcc, make, Python and Node.js preinstalled; the rest one click away in the menu)
- **Gaming** — Steam, Heroic, Lutris, ProtonUp-Qt, MangoHud, GameMode
  (not installed by default, on purpose) — plus Mesa/Vulkan drivers
  and 32-bit libs for Steam/Proton, with "Install all gaming packages" only
- **Themes** — switch between the six glassy themes
- **Keybinds** — the searchable shortcuts guide (`SUPER + K`)
- **Install Flatpak** — Flatpak + Flathub, on demand (not preinstalled)
- **Update Simorgh** — pull the latest Simorgh and re-run the installer
- **Update System** — `yay -Syu`

