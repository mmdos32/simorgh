# Simorgh

**Simorgh** is a minimal, modern Arch Linux desktop setup built on
[Hyprland](https://hyprland.org) — glassy, keyboard-driven, and ready for
programming, gaming, and daily use.

> Simorgh (سیمرغ) is the mythical phoenix of Persian literature.
> The name is a nod to the project author's roots — the desktop itself
> is multilingual, with English as the default.

## What it is

Simorgh is a complete Arch + Hyprland desktop — minimal, modern, with
glassy details — available both as a bootable installer ISO and as an
install script plus dotfiles that turn a fresh stock Arch install into
the same desktop. In the spirit of Omarchy, with its own taste.

## Features

- **Hyprland** with smooth animations, dwindle tiling, and glassy blur
- **Six glassy themes** (all with blur, transparency, and rounded
  corners), switchable in one keystroke — `SUPER + T`
- **Waybar** (glassy top bar), **Rofi** (glassy app launcher),
  **SwayNC** (notifications), **hyprlock** + **hypridle**
- **zsh** with autosuggestions, syntax highlighting, and a
  [Starship](https://starship.rs) prompt
- **SDDM** graphical login with the sugar-candy theme
- **Maia** file manager (fast, keyboard-first, Rust) — `SUPER + E`
- **Coordinated GTK look**: Colloid-Dark theme, Papirus-Dark icons,
  Bibata cursor — GTK apps match the glassy themes
- **Multilingual**: pick your language at install time (English default;
  Persian, German, French, Spanish, Arabic, Turkish, Russian, Chinese,
  Japanese, Portuguese also offered)
- **Programming-first, gaming-ready**: dev tools one click away in the
  menu (nothing preinstalled), and Steam / Heroic / Lutris one click
  away too
- **Self-updating**: `simorgh-update` pulls the latest Simorgh and
  re-runs the installer
- **Signature wallpaper**: the default theme ships a glass-teal Simorgh
  phoenix wallpaper made for this project

## Defaults (and their alternatives)

| Role           | Default                              | Quick-install alternatives (via `simorgh-menu`) |
|----------------|--------------------------------------|--------------------------------------------------|
| Browser        | Chromium                             | Firefox, Brave, Zen Browser                      |
| Terminal       | Kitty                                | Alacritty, Ghostty, Foot                         |
| Editor         | VS Code                              | Neovim, Zed, VSCodium                            |
| File manager   | Maia                                 | Dolphin, Thunar, Nautilus                        |
| Music          | Sung (YouTube Music + local files + synced lyrics) | Spotify, SoundCloud (Chromium web app), Amberol, Rhythmbox |
| Video          | VLC                                  | mpv, Celluloid, Haruna                           |
| PDF            | Evince                               | Okular, Zathura                                  |
| Image viewer   | Loupe                                | Eye of GNOME, imv                                |
| System monitor | btop                                 | Mission Center                                   |
| Archive        | File Roller                          | —                                                |
| Gaming         | —                                    | Steam, Heroic, Lutris, ProtonUp-Qt, MangoHud, GameMode |
| Dev tools      | — (none preinstalled)                | C/C++ toolchain, Python, Node.js, Rust, Go, Docker, lazygit, GitHub CLI |

## Install

There are two ways to install Simorgh. The ISO is the real-OS way;
the script is for people who already have Arch.

### From the ISO (recommended)

1. Build the ISO (on Arch Linux) or download it when a release is
   published: `sudo ./iso/build.sh` — see `iso/README.md` for the
   details. Write it to a USB stick with balenaEtcher or `dd`.
2. Boot the USB stick. It logs in automatically and the graphical
   installer opens on the desktop.
3. Click through it — language, disk, user — and install. Reboot,
   log in with SDDM, and the Simorgh desktop is ready. No terminal
   commands anywhere.

> The ISO is new and **has not been built or booted yet** — this
> machine has no Arch to build it on. Everything is validated by
> reading only (see `iso/README.md`).

### On an existing Arch install

Install stock Arch Linux first — the `archinstall` script on the Arch
ISO does it in a few minutes (base system + network + a user with sudo).
Then, on that fresh install:

```bash
sudo pacman -S git
git clone https://github.com/mmdos32/simorgh
cd simorgh
./install.sh
```

Or in one command (needs `curl` — install it first if missing with
`sudo pacman -S curl`):

```bash
curl -fsSL https://raw.githubusercontent.com/mmdos32/simorgh/main/bootstrap.sh | bash
```

The installer will:

1. Ask for your language (default: English; saved for later re-runs)
2. Install base tools (`base-devel`, `git`), then `yay` if it is missing
3. Install the packages from `packages/pacman.txt` and `packages/aur.txt`
4. Detect an NVIDIA GPU and install its driver + DRM modesetting
   (AMD/Intel need nothing extra)
5. Install Sung (default music player) from source and Maia (default
   file manager) from its official GitHub release
6. Deploy the configs to `~/.config` (existing configs are backed up
   to `~/.config-backup-<date>`)
7. Set zsh as your default shell and enable SDDM, NetworkManager,
   Bluetooth, and printing (CUPS)
8. Detect a laptop automatically (DMI chassis type or a battery) and,
   only then, install and enable power management
   (`power-profiles-daemon`)
9. Apply your theme (the default `teal-glass` on first install; your
   current theme on re-runs)

Then reboot and log in — Hyprland starts automatically.

## Keybinds

| Keys | Action |
|------|--------|
| `SUPER + Return` | Kitty terminal |
| `SUPER + D` | Rofi app launcher |
| `SUPER + E` | Maia file manager |
| `SUPER + B` | Chromium browser |
| `SUPER + C` | VS Code editor |
| `SUPER + U` | Sung music player |
| `SUPER + M` | Simorgh menu (apps, gaming, updates) |
| `SUPER + T` | Switch theme |
| `SUPER + N` | Notifications center (swaync) |
| `SUPER + SHIFT + N` | Do Not Disturb on/off |
| `SUPER + K` | This shortcuts guide |
| SUPER + ` (grave key) | Scratchpad terminal |
| `SUPER + SHIFT + E` | Power menu (lock/logout/suspend/reboot/power off) |
| `SUPER + Q` | Close window |
| `SUPER + SHIFT + Q` | Exit Hyprland |
| `SUPER + Tab` / `SUPER + SHIFT + Tab` | Switch to next / previous window |
| `SUPER + F` | Fullscreen |
| `SUPER + V` | Toggle floating |
| `SUPER + P` | Pseudo-tiling |
| `SUPER + J` | Toggle split direction |
| `SUPER + R` | Resize mode (arrows to resize, Esc to exit) |
| `SUPER + SHIFT + R` | Reload Hyprland config |
| `SUPER + L` | Lock screen |
| `SUPER + arrows` | Move focus |
| `SUPER + CTRL + arrows` | Focus monitor (multi-monitor) |
| `SUPER + SHIFT + arrows` | Move window |
| `SUPER + 1..0` | Switch workspace |
| `SUPER + SHIFT + 1..0` | Move window to workspace |
| `SUPER + SHIFT + V` | Clipboard history (cliphist + Rofi) |
| `SUPER + ALT + C` | Calculator (Rofi) |
| `SUPER + ALT + P` | Color picker (copies hex) |
| `SUPER + ALT + R` | Toggle screen recording |
| `SUPER + ALT + B` | Toggle Waybar |
| `SUPER + .` | Emoji picker |
| `SUPER + CTRL + 1..0` | Move window to workspace silently |
| `SUPER + Z` | Previous workspace |
| `SUPER + SHIFT + L` | Lock + suspend |
| `Print` | Full-screen screenshot to `~/Pictures/Screenshots` |
| `SUPER + SHIFT + S` | Region screenshot to `~/Pictures/Screenshots` |
| `SUPER + SHIFT + C` | Region screenshot to clipboard |
| `Alt + Shift` | Switch keyboard layout (us / ir) |
| `XF86AudioRaiseVolume` / `LowerVolume` / `Mute` | Volume |
| `XF86AudioMicMute` | Mute microphone |
| `XF86MonBrightnessUp` / `Down` | Brightness |
| `XF86AudioPlay` / `Next` / `Prev` | Media playback |
| `SUPER + mouse drag` | Move / resize window |
| `SUPER + mouse wheel` | Switch workspace |

Press `SUPER + K` any time for the searchable shortcuts guide (`simorgh-keybinds`, also in the Simorgh menu under Keybinds).

## Themes

Six glassy themes, every one of them covering Hyprland, Waybar, Rofi,
Kitty, and the wallpaper:

- **teal-glass** — dark teal (default, the most crowd-pleasing)
- **violet-glass** — purple
- **forest-glass** — green
- **ocean-glass** — blue
- **rose-glass** — pink
- **ember-glass** — warm orange

Switch with `SUPER + T`, with `simorgh-theme` (Rofi menu), or directly:
`simorgh-theme violet-glass`. Theme files live in `themes/<name>/`;
wallpapers are generated by `wallpapers/generate.py`. The default
teal-glass theme uses the signature wallpaper
(`wallpapers/simorgh-signature.png`) — a glass-teal Simorgh phoenix
made for this project; the other themes use their own gradient
wallpapers. Each theme's `colors` file can point at a different
wallpaper via its `wallpaper=` line.

## Maia

The default file manager is [Maia](https://github.com/yappologistic/Maia):
fast, keyboard-first, written in Rust, a single small binary with split
panels, tabs, and live filtering. Maia has no AUR package, so the
installer downloads its official GitHub release and runs
`maia --install` (into `~/.local/bin`) and `maia --set-default`.
Dolphin, Thunar, and Nautilus stay one click away in the menu
(`simorgh-menu` → Install File Manager).

## Sung

The default music player is [Sung](https://github.com/yappologistic/Sung):
a native Material 3 player for Linux with YouTube Music, local audio
files, synchronized lyrics, and optional Navidrome / Jellyfin and
Apple Music (via Cider) support. Sung has no AUR package and no
releases, so the installer builds it from source: it clones Sung into
`~/.local/src/Sung` and runs its `./scripts/install.sh` as a per-user
install into `~/.local` (never with sudo). The clone is kept so Sung
can be updated later; if the build ever fails during install, retry it
from the menu (`simorgh-menu` → Install Apps → Music → Sung).
**The build is slow:** it is a Qt6 C++ build, and on a 2–4 core machine
it can take well over an hour (in a VM test it compiled at roughly one
step a minute). Let it run; the build directory is kept, so an
interrupted build resumes where it left off.
Spotify is one click away in the same menu, and so is SoundCloud —
there is no official SoundCloud Linux app, so Simorgh adds it as a
Chromium web app on demand instead of preinstalling it.

## Coordinated GTK theme

The glassy look is not limited to Hyprland: GTK apps use the
Colloid-Dark theme with Papirus-Dark icons and the Bibata cursor, set
both in `config/gtk-3.0/settings.ini` / `config/gtk-4.0/settings.ini`
and via `gsettings` at install time.

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

## Updating Simorgh

`simorgh-update` updates Simorgh itself: it finds the git clone
(`$SIMORGH_REPO`, `~/simorgh`, or the path recorded at install time),
runs `git pull --ff-only`, then re-runs `install.sh` — reusing the
saved language instead of asking again (pass `--reconfigure` to
`install.sh` to change it). It is also in the menu under
"Update Simorgh".

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

## Layout

```
install.sh              installer (Arch only, idempotent where reasonable)
bootstrap.sh            one-command installer: clones the repo, runs install.sh
iso/                    bootable installer ISO (Calamares, archiso)
  build.sh              builds the ISO (on Arch, as root)
  profiledef.sh         archiso profile
  pacman.conf.template  pacman config for the build (generates pacman.conf)
  packages.x86_64       packages in the live environment
  gen-packages-conf.py  generates the Calamares package list
  airootfs/             files overlaid into the live image
packages/
  pacman.txt            official repo packages
  aur.txt               AUR packages (yay)
  gaming.txt            gaming packages (menu only)
  alternatives.txt      alternative apps (menu only)
  apps.txt              everyday apps + dev tools (menu only)
config/                 dotfiles, deployed to ~/.config
  hypr/                 hyprland.lua, hyprlock.conf, hypridle.conf, hyprpaper.conf
  waybar/               config.jsonc, style.css, theme.css
  rofi/                 config.rasi, theme.rasi
  kitty/                kitty.conf, theme.conf
  zsh/                  .zshrc
  swaync/               config.json, style.css
  gtk-3.0/ + gtk-4.0/   settings.ini (Colloid-Dark / Papirus-Dark)
  sddm/                 simorgh.conf (sugar-candy theme)
  nvim/                 init.lua (minimal, no plugins)
  Code/User/            settings.json (VS Code defaults)
  mimeapps.list         default applications
  profile               session environment (~/.profile, session PATH)
  starship.toml
  fastfetch/
themes/<name>/          colors, hyprland.lua, waybar.css, rofi.rasi, kitty.conf, swaync.css
bin/
  simorgh-theme         theme switcher (Rofi menu or direct)
  simorgh-menu          app / dev tools / gaming / update menu
  simorgh-update        pull the latest Simorgh and re-run the installer
  simorgh-power         Rofi power menu
  simorgh-keybinds      searchable shortcuts guide (SUPER + K)
  simorgh-record        toggle screen recording
  simorgh-welcome       first-boot welcome screen (once)
wallpapers/             one 1920x1080 PNG per theme (+ generate.py)
                        + simorgh-signature.png (signature phoenix art)
CONTRIBUTING.md         how to contribute (themes, code, bug reports)
LICENSE                 MIT
.github/                issue templates (bug report, feature request)
```

## Known limits

- **Not tested on real Arch yet** — the installer has never actually
  run here (no Arch/pacman on this machine); validation so far is
  syntax, JSON, and smoke tests. A real Arch install (VM or hardware)
  is the biggest remaining step.
- **No README screenshots yet** — they need a live session.
- **The ISO is unbuilt and untested.** `iso/` has the archiso
  profile, the Calamares graphical installer, and the `simorgh-install`
  console fallback, but no Arch machine has built or booted it yet.
  The script method stays fully supported.
- **No light theme** — all six themes are dark and glassy.
- CJK (Chinese/Japanese/Korean) fonts are not preinstalled; install
  `noto-fonts-cjk` from the menu if you need them.

## License

MIT — see [LICENSE](LICENSE).
