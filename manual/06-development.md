# Development

## Layout


```
install.sh              installer (Arch only, idempotent where reasonable)
bootstrap.sh            one-command installer: clones the repo, runs install.sh
iso/                    bootable installer ISO (Calamares, archiso)
  build.sh              builds the ISO (on Arch, via sudo — not from
                        a root shell, so the AUR build can run as your user)
  profiledef.sh         archiso profile
  pacman.conf.template  pacman config for the build (generates pacman.conf)
  packages.x86_64       packages in the live environment
  gen-packages-conf.py  generates the Calamares package list
  airootfs/             files overlaid into the live image
packages/
  pacman.txt            official repo packages
  aur.txt               AUR packages (yay)
  gaming.txt            gaming packages (reference only — nothing
                        reads it; the menu hardcodes its own list)
  alternatives.txt      alternative apps (reference only — nothing
                        reads it; the menu hardcodes its own list)
  apps.txt              everyday apps + dev tools (reference only —
                        nothing reads it; the menu hardcodes its own list)
config/                 dotfiles, deployed to ~/.config
  hypr/                 hyprland.lua, hyprlock.conf, hypridle.conf, hyprpaper.conf
                        themes/ (active.lua, current — managed by simorgh-theme)
  waybar/               config.jsonc, style.css, theme.css
  rofi/                 config.rasi, theme.rasi
  kitty/                kitty.conf, theme.conf
  zsh/                  .zshrc
  swaync/               config.json, style.css
  gtk-3.0/ + gtk-4.0/   settings.ini (Colloid-Dark / Papirus-Dark)
  sddm/                 simorgh.conf (sugar-candy theme), README.md
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
                        + GitHub Actions workflows (ISO build, release publish)
```


See [CONTRIBUTING.md](../CONTRIBUTING.md) for how to contribute (themes, code, bug reports).
