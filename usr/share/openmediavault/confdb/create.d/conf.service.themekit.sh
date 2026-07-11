#!/bin/sh

set -e

. /usr/share/openmediavault/scripts/helper-functions

if ! omv_config_exists "/config/services/themekit"; then
    omv_config_add_node "/config/services" "themekit"

    omv_config_add_key "/config/services/themekit" "accent" "default"
    omv_config_add_key "/config/services/themekit" "accentSpecialPages" "false" "bool"
fi

exit 0
