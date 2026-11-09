# SDDM configuration for Simorgh

The installer copies `simorgh.conf` to `/etc/sddm.conf.d/simorgh.conf`,
which sets the SDDM theme to **sugar-candy**.

The sugar-candy theme is installed from the AUR by `install.sh`
(`sddm-sugar-candy-git` in `packages/aur.txt`). If you remove that
package, SDDM falls back to its default theme — the login still works.

To use a different SDDM theme, change `Current=` in
`/etc/sddm.conf.d/simorgh.conf` and restart SDDM.
