# Pomodoro Widget - Development Notes

## Overview

A Pomodoro timer widget for Hyprland using QuickShell. Displays a colored screen border overlay with a notch-style timer display.

## Implementation Details

### Architecture

- **QuickShell**: Qt/QML-based shell framework for Wayland compositors
- **Layer Shell**: Uses `WlrLayershell` for overlay positioning
- **Singletons**: `PomodoroState` and `Config` are QML singletons for global state

### Key Technical Solutions

#### Mouse Passthrough
The overlay needs to not block mouse input to windows below. Solved using:
```qml
mask: Region {}
```
An empty `Region` means no part of the window accepts input.

#### Screen Border with Rounded Corners
Uses `Canvas` to draw the border because QML Rectangles can't create hollow shapes with inner rounded corners. The canvas draws:
- 4 edge rectangles
- 4 corner pieces with `arcTo()` for rounded inner edges

#### Breathing Border Animation

When `Config.fluidBorderAnimation` is enabled, the border color pulses smoothly using a cosine-eased sine wave:

```js
var t = 0.5 - 0.5 * Math.cos(fp * 2 * Math.PI)  // 0→1→0, no jump at loop point
var blend = t * (1 - Config.fluidMinBrightness)
ctx.fillStyle = Qt.rgba(
    bc.r + (mc.r - bc.r) * blend,
    bc.g + (mc.g - bc.g) * blend,
    bc.b + (mc.b - bc.b) * blend, bc.a)
```

- `fluidPhase` (0→1) is driven by a looping `NumberAnimation` on the Canvas
- The border lerps from its base color toward a per-phase **mix color** at peak
- `fluidMinBrightness` controls how far the lerp goes: `0.0` = full mix color, `1.0` = no change
- Mix colors are chosen per phase (`focusMixColor`, `breakMixColor`, `pauseMixColor`) and default to dark tints of the phase hue
- `onFluidPhaseChanged` triggers `requestPaint()` each frame when enabled

#### MacBook-Style Notch
The timer display is integrated into the top border using canvas paths:
- `quadraticCurveTo()` creates smooth transitions
- Timer text is positioned inside the notch area
- Hidden `Text` element measures timer width for notch sizing

#### Global Shortcuts
QuickShell registers shortcuts with the compositor:
```qml
GlobalShortcut {
    name: "pomodoro-start"
    description: "Start Pomodoro timer"
    onPressed: PomodoroState.start()
}
```

Hyprland binds to these via `global` dispatcher:
```conf
bind = , F9, global, quickshell:pomodoro-start
```

The app ID is `quickshell` (not configurable), shortcut names are custom.

### State Machine

```
STOPPED -> (start) -> FOCUS -> (complete) -> BREAK -> (complete) -> FOCUS
                        |                      |
                        v                      v
                     PAUSED <--------------> PAUSED
```

- Focus: 25 min (red)
- Short break: 5 min (green) - after each focus
- Long break: 15 min (green) - after 4 focus sessions
- Paused: amber/yellow

### Notifications

Uses `notify-send` via QuickShell's `Process` with `startDetached()` (fire-and-forget):
```qml
notifyProcess.command = ["notify-send", "-u", "normal", "-t", "5000", "-a", "Pomodoro", title, message]
notifyProcess.startDetached()
```

### Sound & On-Screen Messages

`PomodoroState` emits a `signal showMessage(string text)` and plays sounds via a dedicated `Process`. Events fire on: focus start, pause, resume, break start, and periodic interval.

#### Sound playback
Uses `sh -c` wrapping so `soundCommand` (e.g. `paplay`) resolves correctly via PATH. Process is restarted with `running = false` → `running = true` to reliably re-trigger:
```qml
soundProcess.command = ["sh", "-c", Config.soundCommand + ' "$1"', "--", path]
soundProcess.running = false
soundProcess.running = true
```
**Do not use `startDetached()` for audio** — it is unreliable for processes that need to restart.

#### Interval reminder
A `Timer` in `PomodoroState` fires every `intervalMinutes` during active focus (automatically paused when `isPaused` or `isBreak`). It is explicitly `restart()`ed when a new focus session begins so the interval is always relative to session start.

#### On-screen overlay
`shell.qml` connects to `PomodoroState.showMessage` via `Connections` and shows a centered pill `Rectangle` with the current phase color as background and white text. Fades in (200ms) → holds (`messageDurationMs`) → fades out (600ms) via `SequentialAnimation`.

## File Descriptions

| File | Purpose |
|------|---------|
| `shell.qml` | Main entry point, creates overlay windows for each screen |
| `PomodoroState.qml` | Singleton with timer logic, state management |
| `Config.qml` | Singleton with user-configurable settings |
| `qmldir` | Registers singletons for QML import system |
| `flake.nix` | Nix flake with devShell and package outputs |

## Common Issues

### Shortcuts not working
1. Check registration: `hyprctl globalshortcuts`
2. App ID is `quickshell`, not `pomodoro`
3. Correct format: `quickshell:pomodoro-start`

### Overlay blocking mouse
Ensure `mask: Region {}` is set on `PanelWindow`

### Widget not visible
- Check `visible: PomodoroState.running` - need to start timer first
- Verify layer: `WlrLayershell.layer: WlrLayer.Overlay`

## Future Improvements

Potential enhancements:
- [ ] Statistics tracking
- [ ] Custom session lengths via runtime config
- [ ] Tray icon / status indicator
- [ ] Multiple timer presets
- [ ] Session history / logging

## Config Reference

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `focusMinutes` | int | 45 | Focus session duration |
| `shortBreakMinutes` | int | 5 | Short break duration |
| `longBreakMinutes` | int | 15 | Long break duration |
| `sessionsUntilLongBreak` | int | 4 | Sessions before long break |
| `focusColor` | color | `#FF0000` | Border color during focus |
| `breakColor` | color | `#5f8787` | Border color during break |
| `pauseColor` | color | `#444444` | Border color when paused |
| `primaryMonitorOnly` | bool | true | Restrict overlay to primary screen |
| `borderWidth` | int | 10 | Border thickness in pixels |
| `cornerRadius` | int | 15 | Inner corner radius in pixels |
| `colorTransitionMs` | int | 200 | Color change animation duration |
| `fluidBorderAnimation` | bool | true | Enable breathing animation |
| `fluidAnimationDurationMs` | int | 4000 | One full breath cycle in ms |
| `fluidMinBrightness` | real | 0.3 | Darkest point: 0.0=full mix, 1.0=no change |
| `focusMixColor` | color | `#3d0000` | Breathe toward this color during focus |
| `breakMixColor` | color | `#003d15` | Breathe toward this color during break |
| `pauseMixColor` | color | `#3d3300` | Breathe toward this color during pause |
| `songNotchEnabled` | bool | false | Show current song in bottom notch |
| `notificationsEnabled` | bool | false | Send desktop notifications on phase change |
| `soundCommand` | string | `"paplay"` | Binary used to play sounds (e.g. `aplay`, `mpv --no-video`) |
| `focusStartSound` | string | `""` | Sound file played on focus start / resume |
| `pauseSound` | string | `""` | Sound file played on pause |
| `breakSound` | string | `""` | Sound file played on break start |
| `intervalSound` | string | `""` | Sound file played on interval reminder |
| `focusStartMessage` | string | `""` | On-screen message on focus start / resume |
| `pauseMessage` | string | `""` | On-screen message on pause |
| `breakMessage` | string | `""` | On-screen message on break start |
| `intervalMessage` | string | `""` | On-screen message on interval reminder |
| `messageDurationMs` | int | 3000 | How long the message overlay stays visible |
| `intervalEnabled` | bool | false | Enable periodic reminders during focus |
| `intervalMinutes` | int | 10 | Minutes between interval reminders |

## Common Issues

### Audio not playing
- Verify the sound file path is absolute and the file exists
- Test the command manually: `paplay /path/to/file.ogg`
- If `paplay` is not found, set `soundCommand` to the full path or switch to `aplay`/`pw-play`
- **Do not use `startDetached()`** for the sound `Process` — use `running = false` → `running = true`

## Dependencies

- QuickShell
- Qt6 (qtbase, qtdeclarative)
- Hyprland (for global shortcuts)
- notify-send (for notifications)
- paplay / aplay or similar (for sound, optional)
