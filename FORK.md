# Fork notes

This is a personal, thinned hard fork of [snowarch/iNiR](https://github.com/snowarch/iNiR), branched from upstream 2.33.0 (`48cdcecb`). It is **modified** from upstream and no longer mergeable with it. `NOTICE` adds terms to GPL-3: keep the NOTICE and attribution, mark the fork as modified, and do not publish it under the names iNiR or iRiS.

The goal: one panel family (iris) on niri, Arch only, without the features, dependencies and assets the owner does not use. The longer-term goal is a hand-assembled merge of the iris sidebars and the ii sidebars.

`README.md`, `ARCHITECTURE.md`, `STRUCTURE.md` and `docs/` are still upstream's and describe much that no longer exists. Trust the code and this file.

## Shape of the code

- **What it is:** a Quickshell (QML) desktop shell for the niri compositor, plus an installer and dotfiles.
- **Entry:** `shell.qml` → `modules/iris/critical/ShellIrisCriticalPanels.qml` (first frame) and `modules/iris/ShellIrisPanels.qml` → `modules/iris/ShellIrisPanelsImpl.qml` (everything else).
- **iris** (`modules/iris/`) is the only panel family: Island/bar, palette (launcher), control center, sidebars, notification popups, OSD, session screen, lock, polkit, settings, theme studio.
- **ii sidebars** (`modules/sidebarLeft`, `modules/sidebarRight`, hosted by `modules/sidebar/SidebarHost.qml`) are loaded inside iris when `iris.sidebars.<side>.kind` is `"ii"`.
- **Shared panels iris loads by path:** `modules/ii/overlay`, `modules/cheatsheet`, `modules/regionSelector`, `modules/wallpaperLauncher`, `modules/wallpaperSelector/WallpaperCoverflow.qml`, `modules/recordingOsd`, `modules/tilingOverlay`, `modules/lock`, `modules/closeConfirm`.
- **Services:** singletons in `services/`, registered in `services/qmldir`. Global UI state lives in `GlobalStates.qml`.
- **Settings:** iris's own (`modules/iris/settings/`, options listed in `IrisOptions.qml`), which also hosts the Material pages listed in `modules/settings/SettingsPageRegistry.qml`, addressed by `key`.
- **Config:** schema in `modules/common/Config.qml`, defaults in `defaults/config.json`. At runtime the shell reads `~/.config/illogical-impulse/config.json`; the installer symlinks that directory to `~/.config/inir`.
- **IPC:** `IpcHandler` blocks in QML, called as `inir <target> <function>` (or `qs -p <repo> ipc call <target> <function>`). `scripts/lib/ipc-registry.sh` and the fish completions are generated from the QML and `docs/IPC.md`.
- **Launcher and installer:** `scripts/inir` (CLI), `setup` + `sdata/` (installer, Arch only), `dots/` and `defaults/niri/` (dotfiles and niri config).

## State of the work

- All work is on branch `thin`. **Nothing is committed yet**; `origin` still points at upstream, so pushing needs a separate fork remote first.
- New untracked files that must be added when committing: `modules/sidebarRight/calendar/qmldir`, `modules/sidebarRight/notepad/qmldir`, `FORK.md`, `tools/fork/`.
- Size: 2,528 → about 1,716 tracked files, 111 MB → about 45 MB.

## Decisions

| Topic | Decision |
|---|---|
| Approach | Hard fork: deep removal including schema, settings and translations |
| Panel family | iris only; waffle and the ii family are removed |
| Sidebars | Keep both the iris sidebars and ii's two sidebars until they are merged by hand |
| Compositor / distro | niri on Arch (and derivatives) only |
| Locales | English and German |
| Wallpaper | Chosen once, rarely changed; the picker is local-library only and should not get more features |
| Keep | System-wide theming and dotfiles, laptop/input hardware support, the global visual styles, the iris theme studio / Customize mode |

## What was removed

**Panel families**
- Waffle entirely (`modules/waffle`, its schema block, settings, IPC targets, keybinds, layer rules).
- The ii family except its sidebars: bars, dock, overview, dashboard, control panel, media popup, ii lock/OSD/notification popups/polkit/session screen, screen corners, boot greeting, clipboard panel, equalizer, workspace strip, shell-update panel.
- Family switching: `FamilyTransitionOverlay.qml`, `ShellIiPanels.qml`, `ShellWafflePanels.qml`, the `panelFamily` IPC target and cycle keybind.
- The standalone Material settings window (`settings.qml`, `waffleSettings.qml`, `inir settings-window`) and the first-run wizard (`welcome.qml`, `inir welcome`, the `welcomeWizard` config block).

**Features**
- Anime tracker and schedule, booru browser, news, YT Music (with mpv/yt-dlp/deno), song recognition, lyrics, mascot, Japanese dictionary.
- AI chat and voice search (`defaults/ai`, services, sidebar tab, detached window).
- The Wallhaven sidebar browser, the wallpaper picker's online tab, and the backends `services/Wallhaven.qml`, `Booru.qml`, `BooruResponseData.qml`.
- Desktop widget layer and desktop icons on the wallpaper.
- From iris: the Dock (`IrisDock.qml`) and Orbit (`modules/iris/orbit`), plus `IrisGate.qml`, `IrisBadge.qml`, `WindowPreviewService.qml`.

**Installer and packaging**
- Void, Debian, Fedora, generic and Nix support (`sdata/dist-*` except Arch, `nix/`, `flake.nix`, related docs and test scripts).
- Upstream AUR packaging in `distro/`.
- Dependencies dropped: mpv, mpv-mpris, yt-dlp, yt-dlp-ejs, deno, socat, songrec, the non-English tesseract packs, and `ytmusicapi`/`yt-dlp` from `sdata/uv/requirements`. Added: `tesseract-data-deu`.

**Assets**
- All bundled wallpapers except `assets/wallpapers/qs-niri.jpg`; all locales except `translations/en_US.json` and `de_DE.json`; `dots/.config/mpv`.

## What was changed

- `shell.qml` loads only iris (`modules/iris/critical/ShellIrisCriticalPanels.qml`, `ShellIrisPanels.qml`). The `clipboard` and `overview` IPC targets route to the iris palette; `settings` is just open/toggle.
- `modules/iris/ShellIrisPanelsImpl.qml` picks the sidebar implementation per side from `iris.sidebars.left.kind` / `iris.sidebars.right.kind`: `"iris"` (default) or `"ii"`.
- ii's left sidebar keeps four tabs: widgets, translator, tools, software.
- `modules/common/Config.qml` and `defaults/config.json`: `panelFamily` is `"iris"`, `enabledPanels` defaults to the iris panel list, `iris.dock.enable` is `false`, and the blocks for removed features that were touched so far are gone.
- `modules/settings/SettingsPageRegistry.qml` is a small key-based registry (system, wallpaper, themes, tools, services, advanced, shortcuts, about, monitors, autostart, sidebars, iris). iris settings hosts the Material pages through `IrisOptions.morePages`.
- `modules/iris/wallpaper/IrisWallpaperPicker.qml` is local-only. `wallpaperSelector browse <source> <query>` keeps its signature but ignores the source.
- `services/FirstRunExperience.qml` only applies the default wallpaper on first start.
- `GlobalStates.qml`: settings always open as the iris overlay; waffle and AI state removed.
- OCR is limited to English and German (`ToolsConfig.qml`, `RegionSelection.qml`, `scripts/ocr-runner.sh`).
- `scripts/colors/switchwall.sh` has no waffle logic.
- `scripts/lib/ipc-registry.sh` and the fish completions were regenerated (73 → 54 IPC targets).
- Installer: `sdata/dist-determine.sh`, `deps-map.sh`, `doctor.sh`, `package-installers.sh`, `setup` and `scripts/inir` are Arch-only.

## Still to do

Thinning that was agreed but not finished:

- **Floating pieces and app bubbles** in iris: `modules/iris/stage/IrisStage.qml` and the placement code, woven through the bar, frame and Customize mode. Needs its own careful pass.
- **Dock and Orbit leftovers**: geometry in `IrisFrame` / `IrisStage` / `ShellLayoutController`, settings rows, previews, theme entries, `GlobalStates.irisOrbit*`, config keys. `IrisDockOrder` is still used by the palette.
- **Hyprland code paths**: untouched.
- **Desktop-widget code** still imported by the iris lock screen (`modules/background/widgets`).
- **Config schema and defaults**: keys for removed features are still declared (for example the sidebar tab order lists, `policies.weeb`).
- **"Material sidebars" settings page** (`modules/settings/SidebarsConfig.qml`) and `SidebarLayoutEditor.qml` still show rows for removed tabs.
- **Stale references**: `services/DevNavigation.qml` destinations, unused scripts, translation catalogs with removed strings, `settings-search-index.generated.json`.
- **Installer**: the non-systemd (runit) supervisor path is still in the launcher; the installer as a whole was only syntax-checked, never run.
- **Tests**: `scripts/test-local-distribution.sh` asserts on removed features and mostly fails; prune or drop it.
- **Docs**: rewrite or delete `README.md`, `ARCHITECTURE.md`, `STRUCTURE.md`, `docs/`. `docs/IPC.md` still documents removed targets (`wwidgets`, `ytmusic`) and feeds the IPC registry generator.

Later:

- Hand-assemble one sidebar pair out of the iris and ii implementations, then delete the loser and the `kind` switch.
- Possibly remove the wallpaper picker altogether in favour of `inir wallpaperSelector set <path>` or a static config value.

## How to verify changes

The tools live in `tools/fork/` and are part of the repository. Run them from the repo root.

**Static check** for dangling imports, types, paths, singleton members and config keys:

```sh
python3 tools/fork/check.py . | LC_ALL=C sort | LC_ALL=C comm -13 tools/fork/base.txt -
```

Empty output is clean. `base.txt` is the list of findings upstream 2.33.0 already had (false positives and pre-existing issues), so only new ones are shown. `basenames.txt` is the list of type names that existed upstream, used to tell a removed type from an unknown one.

**Reachability**: QML/JS files that nothing reaches from `shell.qml`, which are candidates for deletion:

```sh
python3 tools/fork/reach.py .                 # ignore hits under scripts/ and translations/
python3 tools/fork/reach.py . --why=<file>    # the chain that keeps a file alive
```

**Runtime smoke test** in a nested niri window:

```sh
STEPS='sidebarLeft open|settings open|wallpaperSelector toggle' tools/fork/run.sh . <tag> 8
```

- It starts niri as a window inside the current Wayland session, with an isolated `HOME` and a private session bus, runs the shell from the given directory, waits the given number of seconds, then calls each `|`-separated IPC step and takes a screenshot after each.
- Output goes to `tools/fork/t/<tag>/` (gitignored): `qs.log` (full shell log), `steps.log` (each step with the warnings and errors it produced), `shot.png` and `step<N>.png`.
- `SEED='<json>'` pre-seeds the config file, for example `SEED='{"iris":{"sidebars":{"left":{"kind":"ii"},"right":{"kind":"ii"}}}}'` to test the ii sidebars.
- It needs `niri`, `quickshell` (`qs`), `dbus-run-session` and ImageMagick (`magick`).
- Icons render as text unless the Material Symbols fonts are installed (`ttf-material-symbols-variable`) or their `.ttf` files are placed in `tools/fork/fonts/` (gitignored), from where the harness copies them into the isolated home.
- Expected noise in `qs.log` on a fresh home: "File does not exist" warnings from `FileView`, a portal registration warning, and a font-sync failure.

Never test by running `qs` against the real session or home directory: startup writes GTK, KDE and terminal theme files.

`tools/fork/ed.py` is a small helper for scripted edits that fail loudly when the expected text is not there (`F(path).sub/cut/rx/lines/block/save`). Its `block()` only works when the matched header line contains the opening `{`.

After changing IPC handlers or `docs/IPC.md`, regenerate the registry and completions:

```sh
python3 scripts/lib/generate-ipc-registry.py
```

Shell scripts were checked with `bash -n`, and the niri config with `niri validate -c <file>`.

Last verified state: static check clean; bar, iris sidebars, ii sidebars, palette, control center, settings, cheatsheet, overlay, session screen and the wallpaper picker open without QML errors in the nested window. The installer and the `inir` launcher subcommands were not run.

## Gotchas

- A directory imported as `qs.modules.x.y` needs a physical `qmldir` when it is only reached through `source:`-loaded files. Quickshell generates qmldirs only for directories it reaches by following `import` statements from `shell.qml`. The symptom is `module "qs.modules.…" is not installed` at runtime.
- A default `enabledPanels` list that names panels which no longer exist gives an empty screen with no error.
- Removing a settings page shifts nothing any more: pages are addressed by `key`, not by index. Keep it that way.
- `scripts/colors/switchwall.sh` reads config values by position from a `_cfg[]` array; removing an entry means renumbering the ones after it.
- When deleting a service, also remove its line from `services/qmldir`; a stale entry is not an error until something imports it.
