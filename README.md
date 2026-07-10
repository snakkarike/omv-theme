# openmediavault-themekit

An OMV 8 plugin: a "Theme Kit" page under System that allows you to customize the accent color of the UI using a massive Tailwind color palette and a variety of themes. Settings are stored in OMV's config database, and a Salt state renders them into an actual CSS file. An apt hook re-runs that Salt state after every `apt upgrade`, so your theme survives OMV updates.

## Installation

To install the plugin on your OpenMediaVault server, download the latest release and install it via `dpkg`:

```bash
# Download the latest 1.0.0 release
wget https://github.com/snakkarike/openmediavault-themekit/releases/download/v1.0.0/openmediavault-themekit_1.0.0_all.deb

# Install the package
sudo dpkg -i openmediavault-themekit_1.0.0_all.deb
sudo apt-get install -f -y
```

Once installed, refresh your browser (`Ctrl+Shift+R`) and look for "Theme Kit" under System in the OMV sidebar.

## Layout

- `debian/` - standard Debian packaging (control, rules, postinst, postrm)
- `usr/share/openmediavault/datamodels/themekit.json` - config schema
- `usr/share/php/openmediavault/Rpc/ThemeKit.php` - get/set RPC backend
- `usr/share/openmediavault/workbench/` - YAML manifests for the navigation entry, route, and the settings form page itself
- `srv/salt/omv/deploy/themekit/` - the Salt state + Jinja CSS template that actually applies the theme to disk
- `etc/apt/apt.conf.d/85themekit` - persistence hook

## Architecture Details

- No `css/` or `images/` directories exist in the webroot, only `assets/`. There is no pre-wired `theme-custom.css` hook anywhere.
- `index.html` loads a single hash-named bundle, `styles.<hash>.css`, that hash changes on every OMV rebuild, so nothing can reference it by name. The only stable injection point is patching `index.html` itself to add a `<link>` right before `</head>`, after the hash-named stylesheet so ours wins the cascade.
- `index.html` is a package-tracked file and gets replaced wholesale on every `openmediavault-webgui` update, so the patch has to be idempotent and re-run on every deploy (handled in `init.sls` via `patch_index_html`, guarded by a `grep` check), not just once at install.
- The CSS template violently overrides specific hardcoded elements in OMV 8 (like the `#5dacdf` blue used on the top toolbar and active tabs) to ensure your selected accent color applies everywhere, while leaving the default OMV dark/light mode system entirely intact.

## Build from Source (For Developers)

**1. Clone it and install build dependencies**

```bash
sudo apt install -y git devscripts debhelper build-essential
cd ~
git clone https://github.com/snakkarike/openmediavault-themekit.git openmediavault-themekit
```

**2. Build the .deb**

```bash
cd ~/openmediavault-themekit
dpkg-buildpackage -us -uc -b
```

This drops `openmediavault-themekit_1.0.0_all.deb` in `~` (one directory up from the source tree). 

**3. Install it**

```bash
cd ~
sudo dpkg -i openmediavault-themekit_1.0.0_all.deb
sudo apt -f install
```

`postinst` runs automatically here: it registers the config schema, then calls `omv-salt deploy run themekit`, which is the step that actually writes `assets/theme-custom.css` and patches `index.html`.

**4. Verify the backend before touching the UI**

```bash
omv-confdbadm read conf.service.themekit
omv-rpc "ThemeKit" "get"
```

Both should return JSON with `accent: "default"` and `theme: "default"`. 

**5. Load the UI**

Hard refresh (Ctrl+Shift+R, since `index.html` itself changed) and look for "Theme Kit" under System in the sidebar. 

## Development & Upgrading

If you are modifying the code (e.g. editing `theme-custom.css.j2` or `init.sls`) and pushing to GitHub, you **must clear Salt's file cache** on the OMV server before applying the state, or Salt will aggressively serve the old template files. 

Run this exact sequence to pull changes and force-apply them:

```bash
cd ~/openmediavault-themekit

# 1. Force sync the code from GitHub to ensure we get the latest commit
git fetch origin
git reset --hard origin/main

# 2. Rebuild the package
dpkg-buildpackage -us -uc -b
cd ..

# 3. Purge the old installation and do a clean install
sudo apt-get purge openmediavault-themekit -y
sudo dpkg -i openmediavault-themekit_1.0.0_all.deb
sudo apt-get install -f -y

# 4. NUKE Salt's file cache so it doesn't serve the old template
sudo rm -rf /var/cache/salt/minion/files

# 5. Apply the state manually to see immediate output
sudo salt-call --local state.apply omv.deploy.themekit
```

Once that completes successfully, do a hard refresh (`Ctrl+Shift+R`) in the OMV web interface.

## Uninstall

```bash
sudo apt purge openmediavault-themekit
```
