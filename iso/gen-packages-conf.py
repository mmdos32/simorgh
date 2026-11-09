#!/usr/bin/env python3
"""Generate iso/airootfs/etc/calamares/modules/packages.conf from packages/pacman.txt.
Run at build time (build.sh) and whenever pacman.txt changes.
Usage: python3 iso/gen-packages-conf.py
"""
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "iso/airootfs/etc/calamares/modules/packages.conf"

# Extra packages the installed system needs that pacman.txt doesn't list:
# sudo (the installer + yay need it), grub + efibootmgr (the bootloader
# module installs GRUB into the target).
EXTRA = ["sudo", "grub", "efibootmgr"]
# Live-only packages unpackfs copies into the target but the installed
# system doesn't need.
REMOVE = ["calamares", "archinstall"]


def read_list(path):
    pkgs = []
    for line in pathlib.Path(path).read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        pkgs.append(line)
    return pkgs


pkgs = read_list(ROOT / "packages/pacman.txt")
for p in EXTRA:
    if p not in pkgs:
        pkgs.append(p)

lines = [
    "# Generated from packages/pacman.txt — do not edit by hand.",
    "# Regenerate with: python3 iso/gen-packages-conf.py",
    "# (build.sh runs this automatically before mkarchiso.)",
    "---",
    "backend: pacman",
    "update_db: true",
    "operations:",
    "  - install:",
]
for p in pkgs:
    lines.append(f"    - {p}")
lines.append("  - try_remove:")
for p in REMOVE:
    lines.append(f"    - {p}")
OUT.write_text("\n".join(lines) + "\n")
print(f"Wrote {OUT} ({len(pkgs)} install, {len(REMOVE)} remove)")
