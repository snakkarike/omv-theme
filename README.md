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

## Build and Install

**1. Clone it on obsidian and check the build tooling is there**

```bash
sudo apt install -y git devscripts debhelper build-essential
cd ~
git clone https://github.com/snakkarike/omv-theme.git openmediavault-themekit
```

Note the directory the repo lands in doesn't matter for the package name, that's set inside `debian/control`, but `dpkg-buildpackage` wants to run from inside the source tree.

**2. Build the .deb**

```bash
cd ~/openmediavault-themekit
dpkg-buildpackage -us -uc -b
```

This drops `openmediavault-themekit_0.1.0_all.deb` in `~` (one directory up from the source tree). If this step fails, it's almost always a missing build-dep, `debhelper-compat (= 13)` from `debian/control` needs a matching debhelper version on the box, so if `apt install debhelper` gave you something older, check with `dpkg -l debhelper`.

**3. Install it**

```bash
cd ~
sudo dpkg -i openmediavault-themekit_0.1.0_all.deb
sudo apt -f install
```

`postinst` runs automatically here: it registers the config schema, then calls `omv-salt deploy run themekit`, which is the step that actually writes `assets/theme-custom.css`, patches `index.html`, and backs up the original wallpapers. Watch the terminal output of `dpkg -i` for errors from that, since `postinst` has `set -e` but most steps are wrapped in `|| true` so a failure there won't block install, it'll just silently no-op.

**4. Verify the backend before touching the UI**

```bash
omv-confdbadm read conf.service.themekit
omv-rpc "ThemeKit" "get"
```

Both should return JSON with `mode: "dark"`, `accent: "default"`, empty wallpaper paths. If `omv-confdbadm read` fails, the datamodel didn't register, check `journalctl -xe` around the install time for the actual `omv-confdbadm create` error. If `omv-rpc` fails but the confdbadm read worked, that's a PHP problem, and given my earlier caveat about `ThemeKit.php` being written from convention rather than a live reference, this is the step most likely to break.

**5. Check the files actually landed right**

```bash
cat /var/www/openmediavault/assets/theme-custom.css
grep theme-custom /var/www/openmediavault/index.html
ls -la /var/www/openmediavault/assets/images/*.orig
```

The `.orig` backups confirm the wallpaper-backup step ran even though you haven't set a custom wallpaper yet, since that block runs unconditionally.

**6. Load the UI**

Hard refresh (Ctrl+Shift+R, since `index.html` itself changed) and look for "Theme Kit" under System in the sidebar. If the nav item's missing but everything above worked, that's a workbench YAML key mismatch, check the browser console (F12) for a manifest parse error, since that's the part I'm least confident matches OMV 8.5.1 exactly.

**7. If something's off, isolate it**

```bash
sudo omv-salt deploy run themekit   # re-run just the state, safe to repeat
journalctl -u php8.2-fpm -f          # tail while you click around
```

Paste back whatever breaks at each step and I'll patch the specific file rather than guessing again.

## Uninstall

```
sudo apt purge openmediavault-themekit
```
