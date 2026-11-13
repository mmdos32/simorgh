# Simorgh live ISO

A bootable installer image, like a real OS: write it to a USB stick,
boot it, and the graphical installer opens on the desktop. Click
through it — language, disk, user — and it installs Simorgh, complete.
No terminal commands. The `install.sh` script method (for people who
already have Arch) stays exactly as it is — see the main README.

## How installing works

```
Simorgh ISO (USB)  →  live Hyprland desktop, Calamares opens
       →  pick language / disk / user / password  →  Install
       →  reboot  →  SDDM login  →  Simorgh desktop, ready
```

1. **Boot the ISO.** It logs in automatically as `liveuser`
   (password `live`) and the installer window opens on the desktop.
   Connect to Wi-Fi first if you need it — press `SUPER + W`
   (opens `nmtui`). If you close the installer, press `SUPER + I`
   to reopen it.
2. **Click through Calamares:** language and timezone, keyboard,
   disk (with optional LUKS encryption — the installer asks),
   your user account and password, then a summary screen, then Install. It copies the
   system, installs the bootloader and the Simorgh packages, then
   runs the Simorgh install inside the new system (same installer
   the script method uses, in its non-interactive `--chroot` mode:
   yay + AUR packages, Maia, Sung, themes, services). The install can
   take a long time on a slow machine — Sung alone can take well over
   an hour to build (the installer allows up to 4 hours for this step),
   so leave it running.
3. **Reboot when it says so.** Log in with SDDM. The desktop is
   ready — no commands to run afterwards.

## Building the ISO

On Arch Linux, via sudo (not from a root shell — `build.sh` needs to
know your user so the AUR build can run as you, since `makepkg`
refuses to run as root). Prerequisites: `git`, `python3`,
`base-devel` (for `makepkg`), and `archiso`:

```bash
sudo pacman -S git python base-devel archiso
sudo ./iso/build.sh
```

`build.sh` regenerates the Calamares package list from
`packages/pacman.txt`, stages the repo into the live image at
`/opt/simorgh`, and runs `mkarchiso`. The ISO lands in `iso/out/`.
Write it to USB with balenaEtcher, or with `dd` (see the message
`build.sh` prints — double-check the device with `lsblk` first;
`dd` erases the target).

No Arch machine? The ISO is also built by GitHub Actions: repo →
Actions → "Build ISO" → Run workflow (manual trigger only) →
download the `simorgh-iso` artifact from the run, or the release
if the release option was ticked.

**Calamares comes from a local repo.** Calamares is not in the Arch
official repos (AUR only), so `build.sh` builds it once from the AUR
into `iso/repo/` (a local pacman repo, ~10 minutes the first time)
and points the build's `pacman.conf` at it. Later builds reuse the
cached package. The repo directory is gitignored.

## What this ISO is — and isn't

- **The full install is still unverified end-to-end.** The ISO is published
  as v1.0 (`simorgh-1.0-x86_64.iso`, ~1.5 GB, built by GitHub
  Actions) and boots to the live Hyprland desktop, with Calamares
  starting. It has been retested twice live: on 2026-11-12 the install
  failed at unpackfs, and on 2026-11-13 it got past unpackfs AND the
  bootloader before failing at `shellprocess@keyring` — but the full
  graphical install + reboot into the installed system has still not
  been verified end-to-end.
- **Disk encryption** is offered by Calamares (LUKS, optional).
- **Dual-boot is not officially supported in v1.** Calamares can
  install alongside another OS with manual partitioning, but we
  haven't tested that path.
- **Secure Boot must be off** in the BIOS (like the Arch ISO).
- **The shipped archinstall preset is interactive-only.** It has no
  `disk_config` and no user credentials by design — disk layout and the
  user account go through archinstall's own menus in the console
  fallback (`simorgh-install`). It cannot drive an unattended install.
- **Console fallback:** if the graphical session fails to start on
  some hardware, the ISO falls back to a root console (tty1,
  auto-login) where `simorgh-install` (the v1 text installer) still
  works — it installs base Arch via archinstall, then prints the one
  command to run after reboot.

## Files

```
iso/
  profiledef.sh            archiso profile (name, label, boot modes)
  pacman.conf.template     pacman config template (build.sh generates
                           pacman.conf from it, with the local repo path)
  packages.x86_64          packages in the live environment
  build.sh                 mkarchiso wrapper (run via sudo on Arch)
  gen-packages-conf.py     generates the Calamares package list
  syslinux/                BIOS boot menu (from archiso releng,
                           rebranded to Simorgh; splash.png is the
                           phoenix signature, 640x480)
  efiboot/loader/          UEFI boot entries (loader.conf)
    entries/               01-simorgh-linux.conf,
                           02-simorgh-speech-linux.conf,
                           03-simorgh-memtest86+x64.conf
  repo/                    local pacman repo (Calamares build, cached,
                           created at build time, gitignored)
  airootfs/
    opt/simorgh/           STAGED AT BUILD TIME (the repo itself)
    usr/local/bin/simorgh-install        console fallback installer
    usr/local/bin/simorgh-target-install Calamares job: installs Simorgh
                                         into the target (chroot)
    usr/local/lib/simorgh-live-setup.sh  live-session setup (live user,
                                         desktop config, autostart)
    usr/share/simorgh/archinstall-simorgh.json   archinstall preset
                                         (console fallback only)
    etc/profile.d/simorgh.sh   session PATH for the live user
    etc/calamares/
      settings.conf        module sequence + the simorgh shellprocess job
      branding/simorgh/    logo (phoenix), welcome image,
                           stylesheet.qss (light installer styling;
                           colors in branding.desc); show.qml is the
                           branded 4-slide slideshow (9 s per slide)
      modules/             welcome, locale, partition, users,
                           unpackfs, packages, bootloader,
                           displaymanager, finished, shellprocess@simorgh,
                           shellprocess@keyring (populates the target
                           keyring before the packages step)
                           (keyboard/mount/fstab use Calamares defaults)
    etc/mkinitcpio.conf.d/archiso.conf   archiso initramfs hooks
                           (from releng — without these the live ISO
                           cannot mount its own root)
    etc/locale.conf        LANG=en_US.UTF-8 (pre-set so the live boot
    etc/vconsole.conf      KEYMAP=us   does not stop at the
    etc/localtime          -> ../usr/share/zoneinfo/UTC   systemd-
                           firstboot prompt)
    etc/sddm.conf.d/autologin.conf       live session autologin
    etc/sddm.conf.d/simorgh-software-render.conf
                                         greeter software rendering
                                         (login screen renders even
                                         without 3D acceleration)
    etc/systemd/system/simorgh-live-user.service
    etc/systemd/system/display-manager.service -> sddm (symlink)
    etc/systemd/system/multi-user.target.wants/simorgh-live-user.service
                           (symlink, enables the live setup service)
    etc/systemd/system/multi-user.target.wants/NetworkManager.service
                           (symlink — the live session needs a working
                           network before Calamares runs)
    etc/motd               welcome banner on the console
    etc/issue              live-installer console banner
    etc/hostname           simorgh-live
    etc/systemd/system/getty@tty1.service.d/autologin.conf
```
