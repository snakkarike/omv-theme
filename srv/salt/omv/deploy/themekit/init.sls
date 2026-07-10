{% set config = salt['omv_conf.get']('conf.service.themekit') %}
{% set webroot = '/var/www/openmediavault' %}

# --- CSS override, lives in assets/ which is not hash-named and is safe
# to leave in place across OMV rebuilds. -------------------------------

theme_custom_css:
  file.managed:
    - name: {{ webroot }}/assets/theme-custom.css
    - source: salt://omv/deploy/themekit/files/theme-custom.css.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: True
    - context:
        mode: {{ config.mode }}
        accent: {{ config.accent }}

# index.html IS a tracked package file and gets replaced wholesale on
# every openmediavault-webgui update, so this patch must be idempotent
# and re-applied every time this state runs (postinst + apt hook both
# call it), not just once at install.

patch_index_html:
  cmd.run:
    - name: >
        sed -i 's#</head>#<link rel="stylesheet" href="assets/theme-custom.css">\n</head>#'
        {{ webroot }}/index.html
    - unless: grep -q 'theme-custom.css' {{ webroot }}/index.html
    - require:
      - file: theme_custom_css

# --- Wallpapers. Back up the pristine originals once, then overwrite
# with whatever the user picked. postrm restores from the .orig copy. --

{% for slot, filename in [('login', 'login.jpg'), ('standby', 'standby.jpg'), ('shutdown', 'shutdown.jpg')] %}
backup_{{ slot }}_wallpaper:
  file.copy:
    - name: {{ webroot }}/assets/images/{{ filename }}.orig
    - source: {{ webroot }}/assets/images/{{ filename }}
    - unless: test -f "{{ webroot }}/assets/images/{{ filename }}.orig"
{% endfor %}

{% if config.loginwallpaper %}
apply_login_wallpaper:
  file.copy:
    - name: {{ webroot }}/assets/images/login.jpg
    - source: {{ config.loginwallpaper }}
    - force: True
    - onlyif: test -f "{{ config.loginwallpaper }}"
    - require:
      - file: backup_login_wallpaper
{% endif %}

{% if config.standbywallpaper %}
apply_standby_wallpaper:
  file.copy:
    - name: {{ webroot }}/assets/images/standby.jpg
    - source: {{ config.standbywallpaper }}
    - force: True
    - onlyif: test -f "{{ config.standbywallpaper }}"
    - require:
      - file: backup_standby_wallpaper
{% endif %}

{% if config.shutdownwallpaper %}
apply_shutdown_wallpaper:
  file.copy:
    - name: {{ webroot }}/assets/images/shutdown.jpg
    - source: {{ config.shutdownwallpaper }}
    - force: True
    - onlyif: test -f "{{ config.shutdownwallpaper }}"
    - require:
      - file: backup_shutdown_wallpaper
{% endif %}

