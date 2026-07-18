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

{% set branding_url = config.brandingImageUrl | default('') %}
{% set branding_ext = '' %}
{% set branding_url_mobile = config.brandingImageUrlMobile | default('') %}
{% set branding_ext_mobile = '' %}
{% if config.enableCustomBranding | default(False) and config.brandingType | default('text') == 'image' %}
{% if branding_url %}
{% set parsed_ext = branding_url.split('.')[-1].split('?')[0] | lower %}
{% if parsed_ext in ['png', 'jpg', 'jpeg', 'svg', 'gif', 'webp'] %}
{% set branding_ext = parsed_ext %}
{% else %}
{% set branding_ext = 'png' %}
{% endif %}
{% endif %}

{% if branding_url_mobile %}
{% set parsed_ext_mobile = branding_url_mobile.split('.')[-1].split('?')[0] | lower %}
{% if parsed_ext_mobile in ['png', 'jpg', 'jpeg', 'svg', 'gif', 'webp'] %}
{% set branding_ext_mobile = parsed_ext_mobile %}
{% else %}
{% set branding_ext_mobile = 'png' %}
{% endif %}
{% endif %}

clear_old_logos:
  cmd.run:
    - name: rm -f {{ webroot }}/assets/custom_logo.* {{ webroot }}/assets/custom_logo_mobile.*

{% if branding_url %}
download_custom_logo:
  cmd.run:
    - name: wget -q --timeout=10 -O {{ webroot }}/assets/custom_logo.{{ branding_ext }} "{{ branding_url }}" || true
    - require:
      - cmd: clear_old_logos
{% endif %}

{% if branding_url_mobile %}
download_custom_logo_mobile:
  cmd.run:
    - name: wget -q --timeout=10 -O {{ webroot }}/assets/custom_logo_mobile.{{ branding_ext_mobile }} "{{ branding_url_mobile }}" || true
    - require:
      - cmd: clear_old_logos
{% endif %}
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
        brandingImageExt: {{ branding_ext | json }}
        brandingTextMobile: {{ config.brandingTextMobile | default('OMV') | json }}
        brandingImageUrlMobile: {{ config.brandingImageUrlMobile | default('') | json }}
        brandingImageExtMobile: {{ branding_ext_mobile | json }}

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
