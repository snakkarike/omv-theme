<?php
/**
 * ThemeKit Engine Module.
 *
 * Listens for configuration changes and marks the module as dirty so that
 * omv-engined will trigger omv-salt deploy run themekit when applied.
 */

namespace Engined\Module;

use OMV\Engine\Notify\Dispatcher;
use OMV\Engine\Module\ServiceAbstract;
use OMV\Engine\Notify\IListener;

class ThemeKit extends ServiceAbstract implements IListener
{
    public function getName()
    {
        return "themekit";
    }

    public function bindListeners(Dispatcher $dispatcher)
    {
        $dispatcher->addListener(
            OMV_NOTIFY_MODIFY,
            "org.openmediavault.conf.service.themekit",
            [$this, "setDirty"]
        );
    }
}
