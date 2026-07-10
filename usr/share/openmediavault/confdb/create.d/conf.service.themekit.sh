#!/bin/sh

set -e

. /usr/share/openmediavault/scripts/helper-functions

if ! omv_config_exists "/config/services/themekit"; then
    omv_config_add_node "/config/services" "themekit"
    omv_config_add_key "/config/services/themekit" "mode" "dark"
    omv_config_add_key "/config/services/themekit" "accent" "default"
    omv_config_add_key "/config/services/themekit" "loginwallpaper" ""
    omv_config_add_key "/config/services/themekit" "standbywallpaper" ""
    omv_config_add_key "/config/services/themekit" "shutdownwallpaper" ""
fi

exit 0
