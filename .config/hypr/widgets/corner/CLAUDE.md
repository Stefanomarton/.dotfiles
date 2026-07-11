# corner-widget

Quickshell widget che mostra il nome del workspace attivo nell'angolo dello schermo.

## Stack
- **Quickshell** (QML) — `shell.qml`, `Config.qml`, `Theme.qml`
- **Wayland** layer-shell (`WlrLayershell`)
- **Hyprland** integration (`Quickshell.Hyprland`)

## Architettura
- `shell.qml` — logica principale, una `PanelWindow` per monitor via `Variants`
- `Config.qml` — parametri configurabili (posizione, dimensioni, font, monitor)
- `Theme.qml` — colori (sfondo, bordo, testo)

## Note importanti

### Input mask e hover
`mask: Region {}` rende la finestra completamente click-through ma impedisce anche gli eventi hover alla `MouseArea`. Se serve rilevare l'hover, **non usare `mask: Region {}`**.

### Hover trasparente
Il widget diventa opacity 0 al passaggio del mouse (con animazione 150ms), così è possibile vedere sotto. La `MouseArea` con `hoverEnabled: true` gestisce il rilevamento.

## Esecuzione
```
qs -p .
```
