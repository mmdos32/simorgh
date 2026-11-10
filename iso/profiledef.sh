#!/usr/bin/env bash
# Simorgh live ISO profile (archiso).
# Build it on Arch Linux with:  sudo ./iso/build.sh
# It produces a bootable installer image: boot it, run `simorgh-install`,
# and it installs base Arch (via archinstall) — the Simorgh desktop
# itself is installed after the first boot by the bootstrap one-liner.
iso_name="simorgh"
iso_label="SIMORGH_$(date +%Y%m)"
iso_publisher="Simorgh <https://github.com/mmdos32/simorgh>"
iso_application="Simorgh live/install ISO"
iso_version="1.0"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito' 'uefi-x64.systemd-boot.esp' 'uefi-x64.systemd-boot.eltorito')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
  ["/usr/local/bin/simorgh-install"]="0:0:755"
  ["/usr/local/bin/simorgh-target-install"]="0:0:755"
  ["/usr/local/lib/simorgh-live-setup.sh"]="0:0:755"
)
