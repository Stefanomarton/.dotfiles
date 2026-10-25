# AGENTS.md

**Workspaces widget** — Quickshell widget for Hyprland: the Smart picker and Exposé.

## Files

```
shell.qml               shortcuts (smart, expose, pickers-close) + windows
Config.qml / Theme.qml  settings / colors (Theme.qml → ../shared/Theme.qml)
rank.js                 pure ranking of the Smart list (.pragma library)
rank_test.js            node rank_test.js — asserts on rank.js
SmartPickerManager.qml  Smart data (Quickshell.Hyprland, DesktopEntries) and actions
SmartPicker.qml         Smart UI: one list + live workspace preview
WorkspaceManager.qml    workspace/window data used by Exposé
ExposeManager.qml / Expose.qml   Exposé overview
ClipboardPicker.qml     clipboard picker (Super+V = quickshell:clipboard): cliphist + preview;
                        paste and Emacs popup via scripts/dettatura-emacs.sh
SPEC-smart.md           what the Smart picker does
```

Run: `qs -p .` (started by `modules/autostart.lua`). Shortcuts: Super+S = `quickshell:smart`,
Super+E = `quickshell:expose` (both in `modules/menu.lua`).

## Smart picker

One list ranked by match (exact > prefix > contains > fuzzy; ties: workspace > window > app);
Enter activates the highlighted row, the first one after typing. Behaviour and keys: `SPEC-smart.md`.

- Empty search: windows by last use (`focusHistoryID`), then project workspaces; the current ones excluded.
- Prefixes: `w ` workspaces · `p ` windows · `a ` apps · `m ` move the focused window · `>` shell command.
- Apps with an open window are hidden: typing an app name finds its window if open, else launches it.

## Architecture

- No processes on open: `Hyprland.toplevels/workspaces/monitors` (event driven) plus
  `refreshToplevels()` in `show()` for `lastIpcObject` (class, geometry, focus order).
- Actions: `Hyprland.dispatch` with the Lua dispatchers; several at once are sent as one
  `function() hl.dispatch(…); … end`.
- Preview tiles capture one frame of `HyprlandToplevel.wayland` with `ScreencopyView`, `live: false`
  (live at 144 Hz cost ~7% CPU, ~15% Hyprland CPU, ~10% GPU while open). Needs `ToplevelManager`
  warmed up, done in `SmartPicker.qml`.
- Measured cost per keystroke: ranking ~0.25 ms (72 apps), list rebuild ~1.8 ms warm; opening
  ~11 ms to first frame. `rules.lua` gives the picker `no_anim` (else an 800 ms popin).
- After changing `rank.js`, run `node rank_test.js`.

## Quirks (Quickshell 0.3.0)

- Use `WlrLayershell.xxx` attached properties and `exclusionMode: ExclusionMode.Ignore`.
- `pragma Singleton` QML files are auto-registered by name.
- Edit files in place: replacing them (`sed -i`) breaks the live reload.
