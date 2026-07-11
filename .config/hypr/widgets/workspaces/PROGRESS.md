# Workspaces Widget — Progress

A [Quickshell](https://quickshell.org) (0.3.0) picker widget for Hyprland: fuzzy
pickers for workspaces, windows, and applications, with live workspace previews.

- **Location**: `~/.dotfiles/.config/hypr/widgets/workspaces/`
  (Stow-symlinked to `~/.config/hypr/widgets/workspaces/`; moved here 2026-07-11)
- **Launched** from `~/.config/hypr/modules/autostart.lua`:
  `qs -p ~/.config/hypr/widgets/workspaces/`
- **Dispatch API**: this copy uses Hyprland's new **Lua `hl.dsp.*`** dispatchers
  (matches the current Hyprland config). Keybinds in `modules/keybindings.lua`:
  `SUPER+W` workspaces · `SUPER+P` windows · `SUPER+R` smart.
- See `AGENTS.md` for full usage/architecture docs.

## The three pickers

| Picker | Shortcut | Purpose |
|--------|----------|---------|
| Workspace | `quickshell:workspaces` (SUPER+W) | switch / create / destroy / move named workspaces |
| Window | `quickshell:windows` (SUPER+P) | focus / move / close windows, multi-select |
| Smart | `quickshell:smart` (SUPER+R) | unified: workspaces + windows + apps |

## Feature checklist (implemented)

- [x] Numeric `1`–`10` and all `special:` workspaces hidden from pickers
- [x] Fast workspace switching (project workspaces ranked first; current ws sinks)
- [x] **Live workspace preview** in *all three* pickers — a scaled mini-map of the
      highlighted workspace's window layout, each tile a live capture via Hyprland
      toplevel-export (`ScreencopyView` + `ToplevelManager`), app-icon fallback.
      Non-disruptive (doesn't switch workspaces).
  - Window picker: previews the highlighted window's workspace, with that
    window's tile outlined.
- [x] Vertical layout: **list on top, preview below**, whole stack centered.
      Lists are capped to a few rows so the preview doesn't shift while navigating.
- [x] Minimal, readable rows (no type badges).
- [x] Smart picker **two columns**: workspaces (left) | windows + apps (right),
      each with independent vertical scrolling. `↑↓` within a column, `←→` switch.
      Apps only appear when searching (or `a ` narrow).
- [x] Vertico-style **narrowing prefixes**: `w ` workspaces · `p ` windows ·
      `a ` apps · `m ` move-current-window mode.
- [x] **Move-window mode** (`m `): Enter moves the focused window to the chosen
      workspace (stay); Shift+Enter moves + follows.
- [x] Arrow-key list scrolling fixed (view follows the selection).

## Config knobs (`Config.qml`)

- `pickerWorkspacePreview` / `pickerWorkspacePreviewLive` — preview on/off, live vs icons
- `pickerPreviewHeight` (520) / `pickerPreviewWidth` (2400, max) — preview size (fit-box)
- `pickerWorkspaceVisibleRows` (3) / `pickerSmartVisibleRows` (4) / `pickerWindowVisibleRows` (6)
- `pickerExcludedWorkspaces` (`1`–`10`) — extra hidden workspaces (special: auto-hidden)

## Notes / open items

- **Duplicate copy**: an older, divergent copy using the *classic* `hyprctl dispatch`
  syntax lives at `~/.marton-drive/personal/projects/workspaces-widget/` (its own
  git repo). It's now redundant — safe to delete once this dotfiles copy is confirmed.
- Sibling widgets now live alongside this one under `~/.config/hypr/widgets/`:
  `corner/` (launched from `autostart.lua`) and `pomodoro/` (standalone — launch
  manually with `qs -p ~/.config/hypr/widgets/pomodoro/`; not wired to a keybind).
- `SmartPicker.qml` has a pre-existing benign "binding loop … height" warning on the
  card (Qt breaks it); not from recent work.
- Possible next steps: MRU workspace ordering, per-tile window titles in the preview,
  clamp preview width for non-ultrawide monitors, optional Tab/Ctrl+←→ column nav.
