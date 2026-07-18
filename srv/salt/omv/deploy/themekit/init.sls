{% set config = salt['omv_conf.get']('conf.service.themekit') %}
{% set webroot = '/var/www/openmediavault' %}

{% set cat = config.fontCategory | default('all') %}
{% if cat == 'sans-serif' %}
{% set active_font = config.customFont_sans_serif | default('') %}
{% elif cat == 'serif' %}
{% set active_font = config.customFont_serif | default('') %}
{% elif cat == 'display' %}
{% set active_font = config.customFont_display | default('') %}
{% elif cat == 'handwriting' %}
{% set active_font = config.customFont_handwriting | default('') %}
{% elif cat == 'monospace' %}
{% set active_font = config.customFont_monospace | default('') %}
{% else %}
{% set active_font = config.customFont_all | default('') %}
{% endif %}

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
        theme: {{ config.theme | json }}
        accent: {{ config.accent | json }}
        accentSpecialPages: {{ config.accentSpecialPages | json }}
        customFont: {{ active_font | json }}
        baseFontSize: {{ config.baseFontSize | json }}
        enableTypography: {{ config.enableTypography | default(False) | json }}
        enableCustomBranding: {{ config.enableCustomBranding | default(False) | json }}
        brandingType: {{ config.brandingType | default('text') | json }}
        brandingText: {{ config.brandingText | default('OpenMediaVault') | json }}
        brandingImageUrl: {{ config.brandingImageUrl | default('') | json }}

user_custom_css:
  file.managed:
    - name: {{ webroot }}/assets/user-custom.css
    - source: salt://omv/deploy/themekit/files/user-custom.css.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: True
    - context:
        customCss: {{ config.customCss | default('') | json }}
        enableCustomCss: {{ config.enableCustomCss | default(False) | json }}

download_google_font:
  cmd.script:
    - name: salt://omv/deploy/themekit/files/download_font.py
    - template: jinja
    - stateful: True
    - env:
      - PYTHONUNBUFFERED: "1"
      - THEMEKIT_ACTIVE_FONT: {{ active_font | json }}

# index.html IS a tracked package file and gets replaced wholesale on
# every openmediavault-webgui update, so this patch must be idempotent
# and re-applied every time this state runs (postinst + apt hook both
# call it), not just once at install.

patch_index_html:
  cmd.run:
    - name: >
        FONT_MD5=$(md5sum {{ webroot }}/assets/theme-font.css | cut -d' ' -f1) &&
        CUSTOM_MD5=$(md5sum {{ webroot }}/assets/theme-custom.css | cut -d' ' -f1) &&
        USER_MD5=$(md5sum {{ webroot }}/assets/user-custom.css | cut -d' ' -f1) &&
        sed -i -e 's#<link rel="stylesheet" href="assets/theme-font.css[^>]*>##g' {{ webroot }}/index.html &&
        sed -i -e 's#<link rel="stylesheet" href="assets/theme-custom.css[^>]*>##g' {{ webroot }}/index.html &&
        sed -i -e 's#<link rel="stylesheet" href="assets/user-custom.css[^>]*>##g' {{ webroot }}/index.html &&
        sed -i "s#</head>#<link rel=\"stylesheet\" href=\"assets/theme-font.css?v=${FONT_MD5}\">\n<link rel=\"stylesheet\" href=\"assets/theme-custom.css?v=${CUSTOM_MD5}\">\n<link rel=\"stylesheet\" href=\"assets/user-custom.css?v=${USER_MD5}\">\n</head>#" {{ webroot }}/index.html
    - unless: >
        FONT_MD5=$(md5sum {{ webroot }}/assets/theme-font.css | cut -d' ' -f1) &&
        CUSTOM_MD5=$(md5sum {{ webroot }}/assets/theme-custom.css | cut -d' ' -f1) &&
        USER_MD5=$(md5sum {{ webroot }}/assets/user-custom.css | cut -d' ' -f1) &&
        grep -q "theme-font.css?v=${FONT_MD5}" {{ webroot }}/index.html &&
        grep -q "theme-custom.css?v=${CUSTOM_MD5}" {{ webroot }}/index.html &&
        grep -q "user-custom.css?v=${USER_MD5}" {{ webroot }}/index.html
    - require:
        - cmd: download_google_font
        - file: theme_custom_css
        - file: user_custom_css
