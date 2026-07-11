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
        theme: {{ config.theme }}
        accent: {{ config.accent }}
        accentSpecialPages: {{ config.accentSpecialPages }}

# index.html IS a tracked package file and gets replaced wholesale on
# every openmediavault-webgui update, so this patch must be idempotent
# and re-applied every time this state runs (postinst + apt hook both
# call it), not just once at install.

patch_index_html:
  cmd.run:
    - name: >
        sed -i -e 's#<link rel="stylesheet" href="assets/theme-custom.css[^>]*>##g' {{ webroot }}/index.html &&
        sed -i 's#</head>#<link rel="stylesheet" href="assets/theme-custom.css?v='$(date +%s)'">\n</head>#' {{ webroot }}/index.html
    - require:
      - file: theme_custom_css

