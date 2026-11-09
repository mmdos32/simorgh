# Contributing to Simorgh

Thanks for helping make Simorgh better. A few ground rules:

## What fits

Simorgh is minimal, modern, and glassy. A contribution fits if it:

- keeps the defaults small (new apps go in the menu, not in the default install),
- matches the glassy look (blur, rounded corners, thin accent borders),
- works on a fresh Arch install (test `./install.sh` on a clean system or VM).

## How to contribute

1. Fork the repo and create a branch.
2. Make one focused change per pull request.
3. Run `bash -n` on any shell script you touch, and re-check the
   configs you changed (Waybar JSON, Hyprland binds).
4. Update the README if your change adds a keybind, a menu entry, or
   a new default.

## New themes

A theme is a directory under `themes/<name>/` with `colors`,
`hyprland.lua`, `waybar.css`, `rofi.rasi`, `kitty.conf`, and
`swaync.css`, plus a matching `wallpapers/<name>.png` (1920×1080). All themes are glassy.

## Reporting bugs

Use the bug report template: what happened, how to reproduce it, and
your GPU (Intel/AMD/NVIDIA) — graphics issues are usually GPU-specific.
