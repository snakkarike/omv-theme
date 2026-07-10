# openmediavault-themekit

A starting-point OMV 8 plugin: a "Theme Kit" page under System with
light/dark mode, an accent color picker, and wallpaper path fields for
the login, standby, and shutdown screens. Settings are stored in OMV's
config database, and a Salt state renders them into an actual CSS file
plus copies wallpapers into place. An apt hook re-runs that Salt state
after every `apt upgrade`, so your theme survives OMV updates.

## Layout

- `debian/` - standard Debian packaging (control, rules, postinst, postrm)
- `usr/share/openmediavault/datamodels/themekit.json` - config schema
- `usr/share/php/openmediavault/Rpc/ThemeKit.php` - get/set RPC backend
- `usr/share/openmediavault/workbench/` - YAML manifests for the
  navigation entry, route, and the settings form page itself
- `srv/salt/omv/deploy/themekit/` - the Salt state + Jinja CSS template
  that actually applies mode/accent/wallpapers to disk
- `etc/apt/apt.conf.d/85themekit` - persistence hook

## What's confirmed vs. still a guess

Checked directly against a live OMV 8.5.1 install (obsidian):

- No `css/` or `images/` directories exist in the webroot, only
  `assets/`. There is no pre-wired `theme-custom.css` hook anywhere,
  unlike older OMV versions.
- `index.html` loads a single hash-named bundle,
  `styles.<hash>.css`, that hash changes on every OMV rebuild, so
  nothing can reference it by name. The only stable injection point is
  patching `index.html` itself to add a `<link>` right before
  `</head>`, after the hash-named stylesheet so ours wins the cascade.
- `index.html` is a package-tracked file and gets replaced wholesale on
  every `openmediavault-webgui` update, so the patch has to be
  idempotent and re-run on every deploy (handled in `themekit.sls` via
  `patch_index_html`, guarded by a `grep` check), not just once at
  install.
- Real wallpaper files: `assets/images/login.jpg`, `standby.jpg`,
  `shutdown.jpg` (there's also `authentication.jpg`, which looks like
  the login form's own background, separate from the full-page login
  wallpaper, not wired up here but easy to add the same way).
- No built-in dark theme or `.dark-theme` class exists to toggle, so
  this ships a full override sheet rather than a light switch.
- Confirmed `:root` CSS variables actually used app-wide (not just the
  boot loader splash): `--mat-background-color-body`,
  `--mat-background-color-card`, `--mat-background-color-background`,
  `--mat-background-color-hover`, `--mat-background-color-selected-button`,
  `--mat-color-text`, `--mat-color-secondary-text`,
  `--mat-color-disabled-text`, `--mat-color-hint-text`,
  `--mat-primary-color-text`. These are what `theme-custom.css.j2`
  overrides.

Still unverified, worth checking once this is actually installed:

- Whether the confirmed variable set is enough to visibly re-theme
  everything, or whether specific Angular Material components (MDC
  toolbar, sidenav, cards) pull from their own `--mdc-*`/`--mat-sys-*`
  tokens that weren't caught by the `--mat-*` grep. If a piece of
  chrome doesn't change color, inspect it in devtools, find the
  variable it's actually reading, and add it to the template.
- The exact PHP RPC method signatures and workbench YAML field keys.
  I wrote `ThemeKit.php` and the `component.d` YAML from documented OMV
  8 conventions, not from a working reference on this box. Diffing
  against `lisanet/openmediavault-customthemes` (built for OMV 8.1.1+)
  before packaging would catch anything that's drifted.

Test the datamodel and RPC service directly first, before touching the
UI:
```
omv-confdbadm read conf.service.themekit
omv-rpc "ThemeKit" "get"
```
If those work, the backend is solid regardless of what the frontend
YAML looks like.

## Build

On a Debian/Ubuntu box with `devscripts` and `debhelper` installed:

```
sudo apt install devscripts debhelper
cd openmediavault-themekit
dpkg-buildpackage -us -uc -b
```

This produces `../openmediavault-themekit_0.1.0_all.deb` one directory
up.

## Install and iterate

```
sudo dpkg -i ../openmediavault-themekit_0.1.0_all.deb
sudo apt -f install   # pulls in any missing deps
```

Then refresh the OMV web UI. If the nav item or page doesn't show up:

```
sudo omv-confdbadm read conf.service.themekit   # confirm schema registered
sudo omv-salt deploy run themekit                # force a re-render
journalctl -u php8.2-fpm -f                      # watch for PHP errors
```

Since you're already comfortable in Angular/NG-ZORRO land: the payoff
here is that you don't touch TypeScript at all, the workbench reads
these YAML manifests and builds the form itself. Your existing
Trust Now CSS token approach (navy/sage/per-product accent) would map
cleanly onto the `theme-custom.css.j2` template if you want to reuse
that palette instead of the six preset accents above.

## Uninstall

```
sudo apt purge openmediavault-themekit
```
