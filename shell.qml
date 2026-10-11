//@ pragma UseQApplication
//@ pragma ShellId inir
// DISABLED: webapps — requires quickshell-webengine rebuild, re-enable when ready
//-@ pragma EnableQtWebEngineQuick
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QT_LOGGING_RULES=quickshell.dbus.properties=false;qt.qpa.wayland.textinput.warning=false
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
// Launcher keeps QT_SCALE_FACTOR=1; shell scaling lives in appearance.typography.sizeScale
// DISABLED: webapps — requires quickshell-webengine rebuild
//-@ pragma Env QTWEBENGINE_CHROMIUM_FLAGS=--disable-features=ThirdPartyCookieBlocking,StorageAccessAPI

import qs.modules.common

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.services.deferred

ShellRoot {
    id: root

    readonly property bool disableHotReload: Quickshell.env("INIR_DISABLE_HOT_RELOAD") === "1"
        || Quickshell.env("INIR_DISABLE_HOT_RELOAD") === "true"

    function _log(msg: string): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(msg);
    }

    // Force singleton instantiation — startup-critical only
    property var _idleService: Idle
    property var _powerProfilePersistence: PowerProfilePersistence
    property var _devNavigationService: DevNavigation
    property var _shellEditSessionService: ShellEditSession
    // Acquire org.kde.StatusNotifierWatcher before graphical-session.target
    // releases XDG autostart applications. The systemd unit uses Type=dbus.
    property var _trayService: TrayService
    property var _globalActionsService
    property var _packageSearchService

    // Deferred singletons — initialized after first frame to reduce boot contention
    // Tier 3: T+500ms (display/interaction services)
    property var _gameModeService
    property var _fontSyncService
    // Screen Time must exist for the whole enabled session, not only after its
    // sidebar page is first opened. It is explicitly materialized after the
    // first frame and when the user enables tracking later.
    property var _screenTimeService
    function _ensureScreenTimeService(): void {
        if (GlobalStates.deferredPanelsReady
                && (Config.options?.sidebar?.screenTime?.enable ?? false))
            root._screenTimeService = ScreenTime
    }
    // Tier 4: T+1500ms (background features - updates, sync, content services)
    property var _shellUpdatesService
    property var _autostartService
    property var _niriAnimationPresetsService

    function _ensureDeferredFamilyServices(): void {
        root._gameModeService = GameMode
        root._fontSyncService = FontSyncService
    }

    function _ensureLateFamilyServices(): void {
        root._shellUpdatesService = ShellUpdates
        root._autostartService = Autostart
        root._niriAnimationPresetsService = NiriAnimationPresets
    }

    // Boot phase timing (ms since epoch). Written to ~/.cache/inir/last-boot.json
    // when the deferred phase finishes. `inir status` reads this back to show users
    // exactly where their startup time goes — systemd → qs launch → QML completed →
    // Config ready → shell entry → deferred services. Useful for triaging "15-20s startup"
    // reports without asking the user to run journalctl.
    property real _bootCompletedAt: 0
    property real _bootConfigReadyAt: 0
    property real _bootShellEntryAt: 0
    property real _bootDeferredAt: 0
    readonly property string _bootCachePath: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/inir/last-boot.json"

    // No hot reload while the screen is locked: a reload tears the session lock down while it is held and leaves the compositor locked
    // with no password prompt. Edits load on the next change or restart.
    Binding {
        target: Quickshell
        property: "watchFiles"
        value: !root.disableHotReload && !GlobalStates.screenLocked
    }
    Connections {
        target: Quickshell
        function onWatchFilesChanged(): void { console.info("[Boot] hot reload", Quickshell.watchFiles ? "on" : "off") }
    }

    Component.onCompleted: {
        root._bootCompletedAt = Date.now();
        console.info("[Boot] T+0ms: Component.onCompleted (shell.qml ready)");
        // Tier 0: startup-critical singletons (no delay)
        root._log("[Boot] Tier 0: startup-critical singletons");
        FirstRunExperience.load();
        ConflictKiller.load();
        // Force MemoryPressureService instantiation for IPC (#164)
        void MemoryPressureService.enabled;
        // Same reason: GlobalActions owns the `globalActions` IPC target and is
        // otherwise only constructed when the command palette first opens, so
        // scripts and keybinds got "Target not found" until then. Tier 0 also
        // keeps the gap after a config reload as short as every other handler's.
        root._globalActionsService = GlobalActions;
        // Public packageSearch IPC must exist before any package UI is opened.
        root._packageSearchService = PackageSearch;
        
        // Reset shell entry state (hot-reload may preserve singletons)
        GlobalStates.shellEntryReady = false;
        GlobalStates.deferredPanelsReady = false;
        
        if (Config.ready) {
            root._bootConfigReadyAt = Date.now();
            console.info("[Boot] T+" + (root._bootConfigReadyAt - root._bootCompletedAt) + "ms: Config.ready (immediate)");
            // Config was already ready before this root was (re)built (hot-reload / preserved
            // singletons). onReadyChanged won't fire, so apply theme + icons here too,
            // otherwise the shell comes up with stale/unthemed colors and icons.
            Qt.callLater(() => ThemeService.applyCurrentTheme());
            Qt.callLater(() => IconThemeService.ensureInitialized());
            shellEntryTimer.start();
        }
    }

    // Shell entry animation: panels start hidden, slide in after a brief delay
    // 200ms is enough for LazyLoader panels to be created on warm cache;
    // on cold boot the progressive slide-in is better UX than extra blank time
    // Tier 1-2: Implicit — UI-critical services load with panels (Audio, Battery, etc.)
    Timer {
        id: shellEntryTimer
        interval: Appearance.animationsEnabled ? 200 : 0
        repeat: false
        onTriggered: {
            if (!root._bootShellEntryAt) root._bootShellEntryAt = Date.now();
            console.info("[Boot] T+" + (root._bootShellEntryAt - root._bootCompletedAt) + "ms: shellEntryReady (first frame)");
            GlobalStates.shellEntryReady = true;
            deferredInitTimer.start();
        }
    }

    // Deferred initialization: load non-critical services and panels after the first frame
    // is rendered, spreading startup work over time to reduce the boot contention burst
    // Tier 3: T+500ms — display/interaction services needed soon after first frame
    Timer {
        id: deferredInitTimer
        interval: 500
        repeat: false
        onTriggered: {
            root._log("[Boot] T+" + (Date.now() - root._bootCompletedAt) + "ms: Tier 3 (display/interaction)");
            root._ensureDeferredFamilyServices();
            Hyprsunset.load();
            GlobalStates.deferredPanelsReady = true;
            root._ensureScreenTimeService();
            // Boot greeting: show once per session (singleton preserves bootGreetingDone across hot-reload)
            if (!GlobalStates.bootGreetingDone && (Config.options?.bootGreeting?.enable ?? true)) {
                GlobalStates.bootGreetingOpen = true;
            }
            if (!root._bootDeferredAt) {
                root._bootDeferredAt = Date.now();
            }
            // Kick off Tier 4 loading
            lateFeaturesTimer.start();
        }
    }

    Connections {
        target: Config
        function onConfigChanged(): void {
            root._ensureScreenTimeService()
            if (GlobalStates.deferredPanelsReady)
                root._ensureDeferredFamilyServices()
            if (root._bootLateFeaturesAt > 0)
                root._ensureLateFamilyServices()
        }
    }

    // Tier 4: T+1500ms — background features that can wait (updates, sync, content)
    // These services do background work (network requests, file I/O) that doesn't affect UX
    property real _bootLateFeaturesAt: 0
    Timer {
        id: lateFeaturesTimer
        interval: 1000  // +1000ms after Tier 3 = T+1500ms total
        repeat: false
        onTriggered: {
            root._log("[Boot] T+" + (Date.now() - root._bootCompletedAt) + "ms: Tier 4 (background features)");
            root._ensureLateFamilyServices();
            root._bootLateFeaturesAt = Date.now();
            root._writeBootPhase();
        }
    }

    // Persist boot phase timestamps so `inir status` can report startup breakdown
    // without asking the user to run journalctl. Only written once per boot — hot-reloads
    // overwrite (which is intentional, latest run is what matters for diagnostics).
    function _writeBootPhase(): void {
        if (!root._bootCompletedAt) return;
        const data = {
            componentCompletedAt: Math.floor(root._bootCompletedAt),
            configReadyAt: Math.floor(root._bootConfigReadyAt),
            shellEntryAt: Math.floor(root._bootShellEntryAt),
            deferredReadyAt: Math.floor(root._bootDeferredAt),
            lateFeaturesAt: Math.floor(root._bootLateFeaturesAt),
            // Deltas for easier analysis
            deltas: {
                configReady: Math.floor(root._bootConfigReadyAt - root._bootCompletedAt),
                shellEntry: Math.floor(root._bootShellEntryAt - root._bootConfigReadyAt),
                deferred: Math.floor(root._bootDeferredAt - root._bootShellEntryAt),
                lateFeatures: Math.floor(root._bootLateFeaturesAt - root._bootDeferredAt)
            },
            shellPid: Quickshell.processId,
            writtenAt: Math.floor(Date.now())
        };
        bootPhaseWriter.setText(JSON.stringify(data, null, 2));
    }

    FileView {
        id: bootPhaseWriter
        path: root._bootCachePath
        printErrors: false
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) {
                if (!root._bootConfigReadyAt) {
                    root._bootConfigReadyAt = Date.now();
                    console.info("[Boot] T+" + (root._bootConfigReadyAt - root._bootCompletedAt) + "ms: Config.ready (async)");
                }
                root._log("[Boot] Applying theme and icon theme");
                Qt.callLater(() => ThemeService.applyCurrentTheme());
                Qt.callLater(() => IconThemeService.ensureInitialized());
                // Kick off shell entry animation after panels have been created.
                // Tier 3 is scheduled by shellEntryTimer so its 500 ms delay is
                // measured from the first frame, not concurrently with it.
                shellEntryTimer.start();
                if (!Config.options?.enabledPanels || Config.options.enabledPanels.length === 0)
                    Config.setNestedValue("enabledPanels", root.defaultPanels)
            }
        }
    }

    IpcHandler {
        target: "bar"
        function toggle(): void {
            GlobalStates.barOpen = !GlobalStates.barOpen
        }
        function close(): void {
            GlobalStates.barOpen = false
        }
        function open(): void {
            GlobalStates.barOpen = true
        }
    }

    // Shared OSD entrypoint. The OSD observes GlobalStates, so the command
    // remains available even while the visual tree is deferred.
    IpcHandler {
        target: "osdVolume"
        function trigger(): void { GlobalStates.osdVolumeOpen = true }
        function hide(): void { GlobalStates.osdVolumeOpen = false }
        function toggle(): void { GlobalStates.osdVolumeOpen = !GlobalStates.osdVolumeOpen }
    }

    IpcHandler {
        target: "osd"
        function volume(): void { GlobalStates.osdVolumeOpen = true }
        function brightness(): void { GlobalStates.osdBrightnessOpen = true }
        function mic(): void { GlobalStates.osdMicOpen = true }
        function keyboard(): void { GlobalStates.osdKeyboardLayoutOpen = true }
        function media(action: string): string {
            const normalized = action.length === 0 ? "play" : action
            if (!["play", "pause", "next", "previous"].includes(normalized))
                return "Unknown action: play, pause, next or previous"
            GlobalStates.showMediaAction(normalized)
            return normalized
        }
        function hide(): void {
            GlobalStates.osdVolumeOpen = false
            GlobalStates.osdBrightnessOpen = false
            GlobalStates.osdMicOpen = false
            GlobalStates.osdMediaOpen = false
            GlobalStates.osdKeyboardLayoutOpen = false
        }
    }

    // Keep the SDK command available without paying for widget discovery at
    // startup. The singleton is instantiated only when this IPC is actually
    // used (or a Settings/bar consumer requests it).
    IpcHandler {
        target: "customWidgets"
        function reload(): string {
            CustomWidgets.reload()
            return "Reloading custom widgets..."
        }
        function list(): string {
            return JSON.stringify(CustomWidgets.widgets.map(w => ({
                id: w.id, name: w.name, version: w.version,
                valid: w.valid, path: w.dirPath
            })), null, 2)
        }
        function create(name: string): string {
            if (!name || name.length === 0) return "Usage: inir customWidgets create <name>"
            CustomWidgets.create(name)
            return `Creating widget "${name}" in ${CustomWidgets.widgetsDir}/${name}/...`
        }
        function remove(widgetId: string): string {
            if (!widgetId || widgetId.length === 0) return "Usage: inir customWidgets remove <id>"
            CustomWidgets.remove(widgetId)
            return `Removing widget "${widgetId}"...`
        }
    }

    // Interaction routers stay resident with the root so commands remain
    // available while the heavier panel tree is deferred.
    IpcHandler {
        target: "controlPanel"
        function toggle(): void { GlobalStates.controlPanelOpen = !GlobalStates.controlPanelOpen }
        function close(): void { GlobalStates.controlPanelOpen = false }
        function open(): void { GlobalStates.controlPanelOpen = true }
    }

    IpcHandler {
        target: "sidebarLeft"
        function toggle(): void { GlobalStates.toggleSidebarLeft("") }
        function close(): void { GlobalStates.closeSidebarLeft() }
        function open(): void { GlobalStates.openSidebarLeft("") }
        function expand(): void {
            GlobalStates.openSidebarLeft("")
            GlobalStates.sidebarLeftExpanded = true
        }
        function compact(): void { GlobalStates.sidebarLeftExpanded = false }
        function status(): string {
            return JSON.stringify({
                open: GlobalStates.sidebarLeftOpen,
                expanded: GlobalStates.sidebarLeftExpanded,
            })
        }
    }

    IpcHandler {
        target: "sidebarRight"
        function toggle(): void { GlobalStates.toggleSidebarRight("") }
        function close(): void { GlobalStates.closeSidebarRight() }
        function open(): void { GlobalStates.openSidebarRight("") }
    }

    IpcHandler {
        target: "search"
        function toggle(): void { GlobalStates.searchOpen = !GlobalStates.searchOpen }
        function close(): void { GlobalStates.searchOpen = false }
        function open(): void { GlobalStates.searchOpen = true }
    }

    IpcHandler {
        target: "settings"
        function open(): void { GlobalStates.openSettings() }
        function toggle(): void { GlobalStates.toggleSettings() }
    }

    IpcHandler {
        target: "settingsNav"
        function page(index: int): void { GlobalStates.openSettingsPage(index) }
        function section(index: int, name: string): void { GlobalStates.openSettingsPage(index, name) }
        function current(): int { return GlobalStates.settingsOverlayCurrentPage }
    }

    // === Panel Loaders ===
    // Alt+Tab cycles windows in MRU order without a visual switcher.
    LazyLoader {
        active: Config.ready
        source: "modules/altSwitcher/AltSwitcherNoVisual.qml"
    }

    // IPC routers owned by the root so their targets exist before the panel tree loads.
    LazyLoader { active: Config.ready; source: "modules/regionSelector/RegionSelectorRouter.qml" }
    LazyLoader { active: Config.ready; source: "modules/tilingOverlay/TilingOverlayRouter.qml" }
    LazyLoader { active: Config.ready; source: "modules/wallpaperSelector/WallpaperSelectorRouter.qml" }

    IpcHandler {
        target: "osk"
        function toggle(): void { GlobalStates.oskOpen = !GlobalStates.oskOpen }
        function close(): void { GlobalStates.oskOpen = false }
        function open(): void { GlobalStates.oskOpen = true }
    }

    IpcHandler {
        target: "overlay"
        function toggle(): void { GlobalStates.overlayOpen = !GlobalStates.overlayOpen }
        function tool(identifier: string, action: string): string {
            const state = Persistent.states.overlay
            if (!state || typeof state[identifier] !== "object") return "Unknown tool"
            const open = state.open.includes(identifier)
            const wanted = action === "on" ? true : action === "off" ? false : !open
            if (wanted && !open) state.open.push(identifier)
            else if (!wanted && open) state.open = state.open.filter(id => id !== identifier)
            return wanted ? "on" : "off"
        }
    }

    IpcHandler {
        target: "session"
        function toggle(): void { GlobalStates.sessionOpen = !GlobalStates.sessionOpen }
        function close(): void { GlobalStates.sessionOpen = false }
        function open(): void { GlobalStates.sessionOpen = true }
    }

    IpcHandler {
        target: "cheatsheet"
        function toggle(): void { GlobalStates.cheatsheetOpen = !GlobalStates.cheatsheetOpen }
        function close(): void { GlobalStates.cheatsheetOpen = false }
        function open(): void { GlobalStates.cheatsheetOpen = true }
    }

    IpcHandler {
        target: "clipboard"
        function open(): void {
            LauncherSearch.ensurePrefix(Config.options?.search?.prefix?.clipboard ?? ";")
            GlobalStates.searchOpen = true
        }
        function close(): void { GlobalStates.searchOpen = false }
        function toggle(): void {
            if (GlobalStates.searchOpen) GlobalStates.searchOpen = false
            else open()
        }
    }

    // The launcher is the palette; `overview` stays as the target name keybinds already use.
    IpcHandler {
        target: "overview"
        function toggle(): void { GlobalStates.searchOpen = !GlobalStates.searchOpen }
        function close(): void { GlobalStates.searchOpen = false }
        function open(): void { GlobalStates.searchOpen = true }
        function toggleReleaseInterrupt(): void { GlobalStates.superReleaseMightTrigger = false }
        function clipboardToggle(): void {
            LauncherSearch.ensurePrefix(Config.options?.search?.prefix?.clipboard ?? ";")
            GlobalStates.searchOpen = true
        }
        function actionOpen(): void {
            LauncherSearch.ensurePrefix(Config.options?.search?.prefix?.action ?? "/")
            GlobalStates.searchOpen = true
        }
    }

    LazyLoader {
        loading: Config.ready
        activeAsync: Config.ready
        source: "modules/iris/critical/ShellIrisCriticalPanels.qml"
    }

    LazyLoader {
        readonly property bool enabled: Config.ready && GlobalStates.deferredPanelsReady
        loading: enabled
        activeAsync: enabled
        source: "ShellIrisPanels.qml"
    }

    // Close confirmation dialog (always loaded, handles IPC)
    LazyLoader { active: Config.ready; source: "modules/closeConfirm/CloseConfirm.qml" }

    // Shared (always loaded via ToastManager)
    ToastManager {}

    readonly property list<string> defaultPanels: [
        "irisBar", "irisBackground", "irisPalette", "irisControlCenter",
        "irisNotificationPopup", "irisOnScreenDisplay", "irisSessionScreen",
        "irisLock", "irisPolkit"
    ]
}
