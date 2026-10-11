pragma Singleton
import QtQuick
import Quickshell
import qs.services
import qs.modules.common

/**
 * The settings pages iRiS Settings can host beside its own sections.
 * Pages are addressed by `key`; component paths are relative to the shell
 * root — resolve with Quickshell.shellPath(page.component). The "iris" entry
 * stands for iRiS's native sections and has no component of its own.
 */
Singleton {
    id: root

    readonly property var pages: [
        {
            key: "system",
            name: Translation.tr("System"),
            icon: "browse",
            desc: Translation.tr("Audio, battery, language, lock"),
            essential: true,
            component: "modules/settings/GeneralConfig.qml"
        },
        {
            key: "wallpaper",
            name: Translation.tr("Wallpaper"),
            icon: "texture",
            desc: Translation.tr("Backend, effects, backdrop"),
            essential: false,
            component: "modules/settings/BackgroundConfig.qml"
        },
        {
            key: "themes",
            name: Translation.tr("Themes"),
            icon: "palette",
            desc: Translation.tr("Colors, fonts, styles"),
            essential: true,
            component: "modules/settings/ThemesConfig.qml"
        },
        {
            key: "tools",
            name: Translation.tr("Tools"),
            icon: "build",
            desc: Translation.tr("Recording, crosshair, overlays"),
            essential: false,
            component: "modules/settings/ToolsConfig.qml"
        },
        {
            key: "services",
            name: Translation.tr("Services"),
            icon: "settings",
            desc: Translation.tr("Weather, music, calendar, apps"),
            essential: false,
            component: "modules/settings/ServicesConfig.qml"
        },
        {
            key: "advanced",
            name: Translation.tr("Advanced"),
            icon: "construction",
            desc: Translation.tr("Color gen, performance"),
            essential: false,
            component: "modules/settings/AdvancedConfig.qml"
        },
        {
            key: "shortcuts",
            name: Translation.tr("Shortcuts"),
            icon: "keyboard",
            desc: Translation.tr("Keybindings reference"),
            essential: true,
            component: "modules/settings/CheatsheetConfig.qml"
        },
        {
            key: "about",
            name: Translation.tr("About"),
            icon: "info",
            desc: Translation.tr("Version & credits"),
            essential: true,
            component: "modules/settings/About.qml"
        },
        {
            key: "monitors",
            name: Translation.tr("Monitors"),
            icon: "display_settings",
            desc: Translation.tr("Per-monitor shell visibility"),
            essential: true,
            component: "modules/settings/MonitorVisibilityConfig.qml"
        },
        {
            key: "autostart",
            name: Translation.tr("Autostart"),
            icon: "rocket_launch",
            desc: Translation.tr("Apps that start with iNiR"),
            essential: false,
            component: "modules/settings/AutostartConfig.qml"
        },
        {
            key: "sidebars",
            name: Translation.tr("Sidebars"),
            icon: "side_navigation",
            desc: Translation.tr("Left and right sidebar content and behavior"),
            essential: false,
            component: "modules/settings/SidebarsConfig.qml"
        },
        {
            key: "iris",
            name: "iRiS",
            icon: "visibility",
            desc: Translation.tr("Apple-inspired Island shell and modules"),
            essential: true,
            component: ""
        }
    ]
}
