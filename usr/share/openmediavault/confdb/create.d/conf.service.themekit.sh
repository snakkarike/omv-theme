#!/bin/sh

set -e

. /usr/share/openmediavault/scripts/helper-functions

if ! omv_config_exists "/config/services/themekit"; then
    omv_config_add_node "/config/services" "themekit"

    omv_config_add_key "/config/services/themekit" "theme" "default"
    omv_config_add_key "/config/services/themekit" "accent" "default"
    omv_config_add_key "/config/services/themekit" "accentSpecialPages" "false" "bool"
    omv_config_add_key "/config/services/themekit" "enableTypography" "false" "bool"
    omv_config_add_key "/config/services/themekit" "enableCustomCss" "false" "bool"
    omv_config_add_key "/config/services/themekit" "baseFontSize" "16" "integer"
    omv_config_add_key "/config/services/themekit" "customFont" ""
    omv_config_add_key "/config/services/themekit" "customCss" ""
    omv_config_add_key "/config/services/themekit" "fontCategory" "all"
    omv_config_add_key "/config/services/themekit" "customFont_all" ""
    omv_config_add_key "/config/services/themekit" "customFont_sans_serif" ""
    omv_config_add_key "/config/services/themekit" "customFont_serif" ""
    omv_config_add_key "/config/services/themekit" "customFont_display" ""
    omv_config_add_key "/config/services/themekit" "customFont_handwriting" ""
    omv_config_add_key "/config/services/themekit" "customFont_monospace" ""
    omv_config_add_key "/config/services/themekit" "enableCustomBranding" "false" "bool"
    omv_config_add_key "/config/services/themekit" "brandingType" "text"
    omv_config_add_key "/config/services/themekit" "brandingText" "OpenMediaVault"
    omv_config_add_key "/config/services/themekit" "brandingImageUrl" ""
fi

exit 0
