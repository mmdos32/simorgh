# Simorgh

**Simorgh** is a minimal, modern Arch Linux desktop setup built on
[Hyprland](https://hyprland.org) — glassy, keyboard-driven, and ready for
programming, gaming, and daily use.

> Simorgh (سیمرغ) is the mythical phoenix of Persian literature.
> The name is a nod to the project author's roots — the desktop itself
> is multilingual, with English as the default.

## Download

Get the latest release — **v1.0** — from the
[Releases page](https://github.com/mmdos32/simorgh/releases):

[simorgh-1.0-x86_64.iso](https://github.com/mmdos32/simorgh/releases/download/v1.0/simorgh-1.0-x86_64.iso) (~1.48 GB)

## Install

**From the ISO (recommended):** download the ISO above, write it to a USB
stick with balenaEtcher or `dd`, boot it, and the graphical installer
opens on the desktop. See [the full install guide](manual/01-install.md)
and [`iso/README.md`](iso/README.md).

**On an existing Arch install:**

```bash
sudo pacman -S git
git clone https://github.com/mmdos32/simorgh
cd simorgh
./install.sh
```

Or in one command (needs `curl` — install it first with `sudo pacman -S curl` if missing):

```bash
curl -fsSL https://raw.githubusercontent.com/mmdos32/simorgh/main/bootstrap.sh | bash
```

> Installing from the ISO is not fully tested yet — it boots to the
> live desktop, but the complete graphical install + reboot into the
> installed system has not been verified end-to-end.

## The Simorgh Manual

The manual lives in [`manual/`](manual/), which is its authoritative source.

- [Install](manual/01-install.md) — ISO and script install, in full
- [Keybinds](manual/02-keybinds.md) — every shortcut
- [Themes](manual/03-themes.md) — the six glassy themes
- [Apps](manual/04-apps.md) — defaults, Maia, Sung, GTK
- [Desktop](manual/05-desktop.md) — behavior, the menu, updating
- [Development](manual/06-development.md) — repository layout

## Features

- **Hyprland** with smooth animations, dwindle tiling, and glassy blur
- **Six glassy themes**, switchable in one keystroke — `SUPER + T`
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

## Known limits

- **Not tested on real hardware yet** — the installer was tested in
  Arch VMs (including a successful SDDM login), but no real machine
  has run it yet; the Waybar/wallpaper rendering still needs
  real-hardware confirmation.
- **No README screenshots yet** — they need a live session.
- **Installing from the ISO is untested.** The ISO is published
  (v1.0) and boots to the live desktop, but the full graphical
  install + reboot into the installed system has not been verified
  end-to-end. The script method stays fully supported.
- **No light theme** — all six themes are dark and glassy.
- CJK (Chinese/Japanese/Korean) fonts are not preinstalled; install
  `noto-fonts-cjk` from the menu if you need them.

## License

MIT — see [LICENSE](LICENSE).
