# Install

Simorgh is available both as a bootable installer ISO and as an install script plus dotfiles that turn a fresh stock Arch install into the same desktop. In the spirit of Omarchy, with its own taste.


There are two ways to install Simorgh. The ISO is the real-OS way;
the script is for people who already have Arch.

### From the ISO (recommended)

1. Download the ISO from the [v1.0 release](https://github.com/mmdos32/simorgh/releases/download/v1.0/simorgh-1.0-x86_64.iso)
   (~1.48 GB) — or build it yourself on Arch Linux with
   `sudo ./iso/build.sh` (see `iso/README.md` for the details).
   Write it to a USB stick with balenaEtcher or `dd`.
2. Boot the USB stick. It logs in automatically and the graphical
   installer opens on the desktop.
3. Click through it — language, disk, user — and install. Reboot,
   log in with SDDM, and the Simorgh desktop is ready. No terminal
   commands anywhere.

> The ISO is published, but **installing from it is not fully
> tested yet** — it boots to the live desktop, but the complete
> graphical install + reboot into the installed system has not
> been verified end-to-end (see `iso/README.md`).

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

## Updating Simorgh


`simorgh-update` updates Simorgh itself: it finds the git clone
(`$SIMORGH_REPO`, `~/simorgh`, or the path recorded at install time),
runs `git pull --ff-only`, then re-runs `install.sh` — reusing the
saved language instead of asking again (pass `--reconfigure` to
`install.sh` to change it). It is also in the menu under
"Update Simorgh".

