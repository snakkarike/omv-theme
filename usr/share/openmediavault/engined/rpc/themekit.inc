<?php
/**
 * ThemeKit RPC service.
 *
 * Exposes ThemeKit.get / ThemeKit.set to the web UI. Reads and writes the
 * conf.service.themekit config object and notifies the engine so the
 * module listener can mark the themekit module dirty.
 */

use OMV\Config\Database;
use OMV\Engine\Notify\Dispatcher;

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

        // Validate against the RPC-specific schema, not the conf.service.*
        // config datamodel — validateMethodParams requires a "type": "rpc"
        // datamodel; conf.service.themekit doesn't implement getParamsSchema().
        $this->validateMethodParams($params, "rpc.themekit.set");

        $db = Database::getInstance();
        $object = $db->get("conf.service.themekit");
        
        // Merge the incoming parameters with the existing configuration to
        // prevent wiping out fields from other tabs when submitting a
        // partial form (e.g. saving Typography without Settings).
        $existing = $object->getAssoc();
        $merged = array_merge($existing, $params);

        $object->setAssoc($merged);
        $db->set($object);

        // Notify listeners so the engined module marks themekit as dirty
        // and the Apply Changes banner appears in the UI.
        Dispatcher::getInstance()->notify(
            OMV_NOTIFY_MODIFY,
            "org.openmediavault.conf.service.themekit",
            $object->getAssoc());

        return $object->getAssoc();
    }
}
