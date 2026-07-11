# AGENTS.md

Project: **Workspaces Widget** — A Quickshell-based picker widget for Hyprland.

## What this is

A Quickshell popup widget providing fuzzy-search pickers for Hyprland workspaces and windows.

**Features:**
1. **Workspace picker** — fuzzy-search popup for creating, switching to, and destroying named workspaces. Shows window icons/names for each workspace.
2. **Window picker** — fuzzy-search popup with multi-select support: select multiple windows, move them to current/specific workspace, or close them all at once.
3. **Smart picker** — unified picker combining workspaces, windows, and applications. One interface to switch workspaces, focus/move windows, or launch new programs.

## File Structure

```
workspaces-widget/
├── shell.qml              # Main entry point
├── Config.qml             # Configuration singleton
├── Theme.qml              # Theme/colors singleton  
├── WorkspaceManager.qml   # Workspace picker logic singleton
├── WorkspacePicker.qml    # Workspace picker UI
├── WindowManager.qml      # Window picker logic singleton
├── WindowPicker.qml       # Window picker UI
├── SmartPickerManager.qml # Smart picker logic singleton
├── SmartPicker.qml        # Smart picker UI
├── flake.nix              # Nix package definition
└── AGENTS.md              # This file
```

## How to Run

```bash
qs -p .
# or via flake
nix run .#
```

## Keybindings

Add to your `hyprland.conf`:

```
bind = SUPER, W, global, quickshell:workspaces
bind = SUPER, P, global, quickshell:windows
bind = SUPER, R, global, quickshell:smart    # Smart unified picker
```

## Workspace Picker Usage

- **Open picker**: Press `SUPER+W` (or your configured keybind)
- **Search**: Type to filter existing workspaces
- **See windows**: Each workspace shows its windows with icons and titles (up to 4 visible, "+N more" for rest)
- **Live preview**: The highlighted workspace's window layout is shown as a live mini-map in a pane beside the picker (same feature as the smart picker; controlled by `pickerWorkspacePreview` / `pickerWorkspacePreviewLive`)
- **Create**: Type a new name and press Enter to create and switch
- **Switch**: Use ↑↓ arrows to navigate, Enter to switch
- **Destroy**: Press Delete or Ctrl+D to close all windows in the selected workspace
- **Close**: Press Escape or click outside

## Window Picker Usage

- **Open picker**: Press `SUPER+P` (or your configured keybind)
- **Search**: Type to filter by window title, class, or workspace name
- **Live preview**: A mini-map of the highlighted window's workspace is shown below the picker, with that window's tile outlined (same live-capture preview as the other pickers; `pickerWorkspacePreview` / `pickerWorkspacePreviewLive`)
- **Preview (legacy)**: With `pickerPreviewOnNavigate: true`, navigating also temporarily switches to the selected window's workspace
- **Select**: Press Space to toggle selection of the current window (multi-select mode)
- **Focus**: Press Enter to focus the highlighted window (or move selected windows to current if multi-selected)
- **Move to workspace**: Press Ctrl+Enter to move selected window(s) to a specific workspace
- **Close**: Press Alt+Backspace to close selected window(s)
- **Cancel**: Press Escape to return to the original workspace and close picker
- **Auto-reset**: If you delete text below `pickerPreviewMinChars`, the view returns to the original workspace

### Preview Mode Behavior

When `pickerPreviewOnNavigate: true` (default):
- **During navigation** (↑↓ or typing): Workspace preview only triggers after `pickerPreviewMinChars` (default: 2) characters are typed
- **Return**: Commits the selection (preview becomes permanent), moves window(s)
- **Escape**: Returns to the original workspace before closing
- **Below threshold**: Deleting text below `pickerPreviewMinChars` automatically returns to the original workspace

### Multi-Select Mode

- Use **Space** to select/deselect windows
- Selected windows are highlighted with an accent color
- **Enter**: Move all selected windows to current workspace
- **Ctrl+Enter**: Prompt for workspace name, move all selected windows there
- **Alt+Backspace**: Close all selected windows
- If no windows are selected, actions apply to the currently highlighted window

## Smart Picker Usage

The smart picker unifies workspaces, windows, and applications in one interface:

- **Open picker**: Press `SUPER+R` (or your configured keybind)
- **Search**: Type to filter across workspaces, windows, and applications
- **Fast workspace switching**: With an empty query, all project workspaces are
  listed on top so opening the picker and pressing **Enter** jumps straight to a
  workspace. The current workspace is pushed to the bottom (switching to it is a
  no-op), and Hyprland `special:` workspaces are never shown.
- **Results are ranked** by relevance:
  - On an empty query: project workspaces first, then windows, then apps
  - When typing: exact matches score highest, then "starts with", then "contains",
    then fuzzy. On ties, workspaces beat windows beat apps.
- **Workspace preview**: When a workspace is highlighted, a pane beside the picker
  shows a scaled mini-map of that workspace's window layout — each window drawn at
  its real position/size (from `hyprctl clients` geometry). Tiles are filled with a
  **live capture** of the window (via Hyprland's toplevel-export protocol,
  through Quickshell `ScreencopyView` + `ToplevelManager`), falling back to the app
  icon when a live capture isn't available. This is non-disruptive — unlike
  `pickerPreviewOnNavigate`, it does not switch your actual workspace.

### Narrowing & modes (vertico-style prefixes)

Type a single letter followed by a space to narrow the list to one category
(like Emacs vertico narrowing). Continue typing to filter within it.

- `w ` — **Workspaces** only
- `p ` — **Windows** only
- `a ` — **Applications** only
- `m ` — **Move current window → workspace** mode (see below)

The list sits on top with the **workspace preview below it**, and results are
shown in **two independent columns** — **workspaces** on the left, **windows +
applications** on the right — each with its own vertical scrolling (capped to a
few rows via `pickerSmartVisibleRows` so the preview below stays put). Navigate
with **↑↓** within a column and **←→** to switch columns. A column hides when
empty (e.g. when narrowed with `w `/`p `).

### Move-window mode (`m `)

`m ` + space enters "move the currently-focused window to a workspace" mode. The
window that was focused when the picker opened is captured on open and shown in
the header (`moving: <title>`). The list shows workspaces:

- **Enter** — move the window to the highlighted workspace, staying on the current one
- **Shift+Enter** — move the window there **and** switch to that workspace, focusing the window
- Typing a new name and pressing Enter moves it to a freshly-created workspace

### Item Types

Items are grouped under section headers (Workspaces / Windows / Applications):
- **Workspace** — switch to it or move it between monitors
- **Window** — focus, move, or close it
- **Application** — launch it

### Actions by Item Type

**Workspaces:**
- **Enter**: Switch to workspace
- **Ctrl+Enter**: Move workspace to other monitor
- **Alt+Enter**: Move workspace to current monitor

**Windows:**
- **Enter**: Focus window (or move selected windows if multi-selected)
- **Ctrl+Enter**: Move window to current workspace
- **Ctrl+Ctrl+Enter**: Move selected windows to specific workspace (prompts for name)
- **Space**: Toggle window selection (for multi-select)
- **Alt+Backspace**: Close window (or selected windows)

**Applications:**
- **Enter**: Launch application

### Multi-Select in Smart Picker

- Select multiple windows with **Space**
- Selected windows get rose highlight
- Actions apply to all selected:
  - **Enter**: Move all to current workspace
  - **Ctrl+Enter**: Prompt for target workspace
  - **Alt+Backspace**: Close all selected
- Press **Ctrl+Enter** when windows are selected to enter "workspace input mode"

## Configuration (Config.qml)

| Property | Default | Description |
|----------|---------|-------------|
| `pickerExcludedWorkspaces` | `["1".."10"]` | Extra workspaces hidden from picker (by exact name). All `special:` workspaces are always hidden automatically. |
| `startupWorkspaces` | `[]` | Named workspaces to create on shell load |
| `pickerWidth` | 750 | Picker popup width |
| `pickerMaxHeight` | 1200 | Picker popup max height |
| `pickerFontSize` | 20 | Font size for picker items |
| `pickerItemHeight` | 60 | Height of each picker item |
| `pickerBorderRadius` | 12 | Corner radius of picker |
| `pickerInputHeight` | 44 | Height of search input |
| `pickerPreviewOnNavigate` | `true` | Enable *live-switch* workspace preview during navigation (actually changes workspace) |
| `pickerPreviewMinChars` | `2` | Min chars typed before preview triggers |
| `pickerWorkspacePreview` | `true` | Show the workspace mini-map preview pane in the smart picker |
| `pickerWorkspacePreviewLive` | `true` | Fill preview tiles with live window captures; `false` = app icons only |
| `pickerPreviewWidth` | `2400` | Preview pane width in px (height follows the monitor aspect ratio); used by both the smart and workspace pickers |
| `windowPickerExcludedWorkspaces` | `[]` | Workspaces whose windows are hidden from window picker |

## Theme (Theme.qml)

Uses **Black Metal** Base16 color scheme. Key semantic aliases:
- `pickerBackground`, `pickerBorder` — Picker frame
- `pickerInputBackground`, `pickerInputFocusBorder` — Search input
- `pickerItemSelected`, `pickerItemHover` — List item states
- `pickerText`, `pickerSecondaryText`, `pickerHintText` — Text colors

## Architecture

### Singletons
`Config.qml`, `Theme.qml`, `WorkspaceManager.qml`, and `WindowManager.qml` use `pragma Singleton`. Quickshell auto-registers them by filename — no `qmldir` needed.

### Data Flow — Workspace Picker
```
User presses SUPER+W
       ↓
GlobalShortcut.onPressed → WorkspaceManager.toggle()
       ↓
hyprctl workspaces -j → parse workspace list
       ↓
hyprctl clients -j → parse → populate window icons/names per workspace
       ↓
WorkspacePicker visible with keyboard focus
       ↓
User types → fuzzy filter list
       ↓
Enter → switch to selected OR create new workspace
       ↓
hyprctl dispatch "hl.dsp.focus({ workspace = 'name:<name>' })"
```

### Data Flow — Window Picker
```
User presses SUPER+P
       ↓
GlobalShortcut.onPressed → WindowManager.toggle()
       ↓
hyprctl clients -j → parse → build window list
       ↓
WindowPicker visible with keyboard focus
       ↓
User types → fuzzy filter by title/class/workspace
       ↓
Space → toggle window selection (multi-select)
       ↓
Enter → hyprctl dispatch "hl.dsp.window.move({ workspace = 'e+0', window = 'address:<addr>' })" (for each selected)
Ctrl+Enter → prompt workspace → hyprctl dispatch "hl.dsp.window.move({ workspace = 'name:<ws>', window = 'address:<addr>' })"
Alt+Backspace → hyprctl dispatch "hl.dsp.window.close({ window = 'address:<addr>' })"
```

### Data Flow — Smart Picker
```
User presses SUPER+R
       ↓
GlobalShortcut.onPressed → SmartPickerManager.toggle()
       ↓
hyprctl workspaces -j → parse workspaces
hyprctl clients -j → parse windows
find *.desktop files → parse Name/Exec/Icon → build app list
       ↓
Combine & score results:
  - Workspaces (special: hidden; project workspaces first, current pushed down)
  - Windows (score boost if on current workspace)
  - Applications (alphabetical, filtered by match)
       ↓
SmartPicker visible with keyboard focus
       ↓
User types → fuzzy filter across all types
       ↓
Item type determines action:
  Workspace → hyprctl dispatch "hl.dsp.focus({ workspace = 'name:<ws>' })"
  Window → hyprctl dispatch "hl.dsp.focus({ window = 'address:<addr>' })"
  App → hyprctl dispatch "hl.dsp.exec_cmd('<command>')"
```

## Quirks (Quickshell 0.3.0)

- Use `WlrLayershell.xxx` attached properties (not direct properties)
- Use `exclusionMode: ExclusionMode.Ignore` (not `exclusiveZone: -1`)
- `mask: Region {}` for full input passthrough
- `pragma Singleton` QML files are auto-registered by name

## Hyprland Dependencies

- `hyprctl workspaces -j` — for workspace list (incl. each workspace's monitor)
- `hyprctl clients -j` — for window list + geometry (`at`/`size`) used by the preview
- `hyprctl monitors -j` — for monitor bounds used to scale the preview mini-map
- **Wayland foreign-toplevel-management + Hyprland toplevel-export** — via Quickshell
  `ToplevelManager`/`ScreencopyView` for live window captures in the preview
- `hyprctl dispatch "hl.dsp.focus({ workspace = 'name:<name>' })"` — for switching
- `hyprctl dispatch "hl.dsp.focus({ window = 'address:<addr>' })"` — for focusing
- `hyprctl dispatch "hl.dsp.window.move({ ... })"` — for moving windows
- `hyprctl eval "hl.dispatch(hl.dsp.window.close({ window = 'address:<addr>' })); ..."` — for destroying workspaces (batch)
