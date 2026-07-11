<?php
/**
 * ThemeKit RPC service.
 *
 * Exposes ThemeKit.get / ThemeKit.set to the web UI. Reads and writes the
 * conf.service.themekit config object, then asks Salt to regenerate the
 * CSS.
 */

use OMV\Config\Database;

class OMVRpcServiceThemeKit extends \OMV\Rpc\ServiceAbstract
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

        syslog(LOG_INFO, "ThemeKit.set called with params: " . json_encode($params));


        $db = Database::getInstance();
        $object = $db->get("conf.service.themekit");
        $object->setAssoc($params);
        $db->set($object);
        syslog(LOG_INFO, "ThemeKit object after setAssoc: " . json_encode($object->getAssoc()));

        // Re-render CSS via the salt state for this plugin.
        // We run this in the background so it doesn't block the RPC response!
        // We also sleep for 2 seconds to ensure omv-engined has finished writing the new config to disk.
        exec("(sleep 2; omv-salt deploy run themekit) > /dev/null 2>&1 &");

        return $object->getAssoc();
    }
}
