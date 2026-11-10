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
  workspace.
- **Waybar** shows the currently playing track (MPRIS — Sung,
  Spotify, …) next to the clock, the weather (wttr.in, refreshed
  every 30 minutes), and a pending-updates counter — click it to
  update the system.
- **Rofi** stays a centered list, glassy like the rest.
- **NVIDIA GPUs are auto-detected** at install time and get the
  proprietary driver (DKMS) + 32-bit libs + DRM modesetting in GRUB.
  AMD/Intel need nothing extra; Mesa/Vulkan drivers come with the
  gaming set from the menu. If you boot with systemd-boot instead of
  GRUB, add `nvidia_drm.modeset=1` to your kernel command line
  manually.
- **Default apps are set up:** Chromium for the web, VS Code for
  text/code, Loupe for images, Evince for PDF, VLC for video, Sung
  for audio, Maia for folders (`config/mimeapps.list`).
- **VS Code ships sane defaults** (JetBrains Mono, format on save,
  dark theme) and **Neovim ships a minimal config** (`config/nvim/init.lua`)
  — only if you have no settings yet.
- **Modern CLI tools** are preinstalled: fzf, ripgrep, eza, bat,
  zoxide (wired into `.zshrc` with guarded aliases).
- **Flatpak** is not preinstalled — install it from the menu
  (`simorgh-menu` → Install Flatpak), which also adds Flathub.
- **Printing** works out of the box: CUPS is installed and enabled.
- **Idle:** the screen locks after 5 minutes, turns off after 6,
  and the system suspends after 15. Change the numbers (in seconds)
  in `config/hypr/hypridle.conf`, then run `hyprctl reload`.
- **Multi-monitor** is automatic; `SUPER + CTRL + arrows` moves
  focus between monitors.
- Deliberately **not** included, following Omarchy's defaults: no
  night light, no firewall, no system snapshots, no boot splash.

## The menu


`simorgh-menu` (or `SUPER + M`) opens a Rofi menu:

- **Install Browser / Terminal / Editor / File Manager** — one-click
  alternatives (Maia, Dolphin, Thunar, Nautilus for files)
- **Install Apps** — Music (Spotify, SoundCloud web app, Amberol,
  Rhythmbox), Video (mpv, Celluloid, Haruna), PDF (Okular, Zathura), Image Viewer (Eye of GNOME, imv),
  Image Editor (GIMP), System Monitor (Mission Center), Office (LibreOffice), Messenger
  (Telegram Desktop, Vesktop), Email (Thunderbird), Recording (OBS Studio), Passwords
  (KeePassXC), Bluetooth (Blueman), Calculator, Terminal Multiplexer
  (tmux)
- **Dev Tools** — C/C++ toolchain, Python, Node.js, Rust, Go, Docker,
  lazygit, GitHub CLI (none preinstalled, by design)
- **Gaming** — Steam, Heroic, Lutris, ProtonUp-Qt, MangoHud, GameMode
  (not installed by default, on purpose) — plus Mesa/Vulkan drivers
  and 32-bit libs for Steam/Proton
- **Themes** — switch between the six glassy themes
- **Keybinds** — the searchable shortcuts guide (`SUPER + K`)
- **Install Flatpak** — Flatpak + Flathub, on demand (not preinstalled)
- **Update Simorgh** — pull the latest Simorgh and re-run the installer
- **Update System** — `yay -Syu`

