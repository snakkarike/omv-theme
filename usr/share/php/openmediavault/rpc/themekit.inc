<?php
/**
 * ThemeKit RPC service.
 *
 * Exposes ThemeKit.get / ThemeKit.set to the web UI. Reads and writes the
 * conf.service.themekit config object, then asks Salt to regenerate the
 * CSS and copy any custom wallpapers.
 *
 * NOTE: class/method names here follow the conventions used by current
 * OMV 8 plugins (Config\Database, ServiceAbstract, validateMethodContext,
 * validateMethod). Diff this against a real installed plugin's PHP
 * (e.g. openmediavault-customthemes) before shipping, in case the exact
 * signatures have shifted between point releases.
 */

namespace OMV\Rpc;

use OMV\Config\Database;

class ThemeKit extends \OMV\Rpc\ServiceAbstract
{
    public function getName()
    {
        return "ThemeKit";
    }

    public function initialize()
    {
        $this->registerMethod("get");
        $this->registerMethod("set");
    }

    public function get($params, $context)
    {
        $this->validateMethodContext($context, [
            "role" => OMV_ROLE_ADMINISTRATOR
        ]);

        $db = Database::getInstance();
        $object = $db->get("conf.service.themekit");

        return $object->getAssoc();
    }

    public function set($params, $context)
    {
        $this->validateMethodContext($context, [
            "role" => OMV_ROLE_ADMINISTRATOR
        ]);

        $this->validateMethod($params, [
            "type" => "object",
            "properties" => [
                "mode" => [
                    "type" => "string",
                    "enum" => ["light", "dark"]
                ],
                "accent" => [
                    "type" => "string",
                    "enum" => ["default", "red", "citrus", "lime", "sky", "plum", "rose"]
                ],
                "loginwallpaper" => ["type" => "string"],
                "standbywallpaper" => ["type" => "string"],
                "shutdownwallpaper" => ["type" => "string"]
            ]
        ]);

        $db = Database::getInstance();
        $object = $db->get("conf.service.themekit");
        $object->setAssoc($params);
        $db->set($object);

        // Re-render CSS / copy wallpapers via the salt state for this plugin.
        \OMV\System\Process::execute("omv-salt", ["deploy", "run", "themekit"]);

        return $object->getAssoc();
    }
}
