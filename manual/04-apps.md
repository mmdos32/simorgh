# Apps

## Defaults


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

