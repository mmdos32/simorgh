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

1. **Boot the ISO.** It logs in automatically and the installer
   window opens on the desktop. Connect to WiFi first if you need it
   (the network icon in the bar, or `nmtui` in a terminal).
2. **Click through Calamares:** language and timezone, keyboard,
   disk (with optional LUKS encryption — the installer asks),
   your user account and password, then Install. It copies the
   system, installs the bootloader and the Simorgh packages, then
   runs the Simorgh install inside the new system (same installer
   the script method uses, in its non-interactive `--chroot` mode:
   yay + AUR packages, Maia, Sung, themes, services).
3. **Reboot when it says so.** Log in with SDDM. The desktop is
   ready — no commands to run afterwards.

## Building the ISO

On Arch Linux, as root:

```bash
sudo pacman -S archiso
sudo ./iso/build.sh
```

`build.sh` regenerates the Calamares package list from
`packages/pacman.txt`, stages the repo into the live image at
`/opt/simorgh`, and runs `mkarchiso`. The ISO lands in `iso/out/`.
Write it to USB with balenaEtcher, or with `dd` (see the message
`build.sh` prints — double-check the device with `lsblk` first;
`dd` erases the target).

**Calamares comes from a local repo.** Calamares is not in the Arch
official repos (AUR only), so `build.sh` builds it once from the AUR
into `iso/repo/` (a local pacman repo, ~10 minutes the first time)
and points the build's `pacman.conf` at it. Later builds reuse the
cached package. The repo directory is gitignored.

## What this ISO is — and isn't

- **It has been built and booted (test 7, 2026-11-09).** The ISO
  builds (`simorgh-2026.11.09-x86_64.iso`, ~1.7 GB) and boots to
  the live Hyprland desktop; Calamares starts after the `slideshow`
  fix below. The full graphical install + reboot into the installed
  system is still unverified — the test VM's keyboard/display froze
  under load before the install could be driven. See the test-7
  report for the full story.
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
  some hardware, the ISO also boots to a console where
  `simorgh-install` (the v1 text installer) still works — it
  installs base Arch via archinstall, then prints the one command
  to run after reboot.

## Files

```
iso/
  profiledef.sh            archiso profile (name, label, boot modes)
  pacman.conf.template     pacman config template (build.sh generates
                           pacman.conf from it, with the local repo path)
  packages.x86_64          packages in the live environment
  build.sh                 mkarchiso wrapper (run as root on Arch)
  gen-packages-conf.py     generates the Calamares package list
  syslinux/                BIOS boot menu (from archiso releng,
                           rebranded to Simorgh; splash.png is the
                           phoenix signature, 640x480)
  efiboot/loader/          UEFI boot entries (loader.conf +
                           01/02/03-simorgh-*.conf)
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
      branding/simorgh/    logo, welcome image (colors in branding.desc);
                           show.qml + squid.png are the Calamares
                           default slideshow (stand-in — rebrand later)
      modules/             welcome, locale, partition, users,
                           unpackfs, packages, bootloader,
                           displaymanager, finished, shellprocess@simorgh
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
    etc/hostname           simorgh-live
    etc/systemd/system/getty@tty1.service.d/autologin.conf
```

## Known issues for the first push

- **Symlinks in the repo.** Four symlinks above (`display-manager.service`,
  the two `.wants` entries, and `etc/localtime`) are part of the ISO.
  Pushing via the git
  database API must store them as symlinks (mode `120000`, content =
  the target path), not as regular files — check the push script
  handles that before pushing.
