# ADR-0005: MenuBar popover + separate Window scene, Dock icon hidden

- **Status**: Accepted
- **Date**: 2026-04-23

## Context

The v1 UI was a single `MenuBarExtra` popover packing the watchlist, add-symbol field, per-row alert bell (opening a sheet), and a Quit button into 320 pt of vertical space. It was adequate for glancing at prices but cramped for building up multiple alerts or managing a larger watchlist. The user asked for a real application window while keeping the menu bar as an at-a-glance entry point.

## Decision

The app exposes **three scenes** in `StockAlertsApp`:

1. `MenuBarExtra { MenuBarPopoverView() }` — the always-available quick-glance popover. Trimmed to: header + "Open Stock Alerts" button + read-only ticker list + gear (SettingsLink) + Quit.
2. `Window("Stock Alerts", id: "main") { MainWindowView() }` — a macOS 14+ single-instance `Window` scene. Uses `NavigationSplitView` (sidebar watchlist + detail pane per symbol). Opening `id: "main"` a second time focuses the existing window rather than stacking.
3. `Settings { SettingsView() }` — the macOS Settings scene, opened from the popover's gear icon via `SettingsLink`.

`LSUIElement = YES` in `Info.plist` stays — the app has no Dock icon. The menu bar icon is the permanent entry point; the window opens and closes freely without terminating the app.

Opening the main window from the popover uses `@Environment(\.openWindow)` **paired with** `NSApp.activate(ignoringOtherApps: true)`. Without the explicit activation, a window opened from an `LSUIElement` app does not become frontmost.

## Consequences

- Contributors have two view entry points to maintain. Stores and the engine are shared via `@EnvironmentObject` and `.modelContainer(...)` on both scenes; both use SwiftData `@Query` independently for reactive reads.
- Keyboard shortcut `⌘,` for Settings does not work from the popover (the popover isn't a frontmost window). `SettingsLink` is the canonical opener.
- The app intentionally does **not** promote itself to a regular Dock-icon-bearing app when the window opens. This is a deliberate UX choice for a status-bar utility.

## Alternatives considered

- **Replace the popover entirely; menu bar icon opens the main window directly.** Simpler model but loses the at-a-glance view. Rejected.
- **Native `MenuBarExtra` menu (style `.menu`) instead of `.window`.** Fastest to build — purely system menu items — but prices can't render inline with formatting, and no room for the prominent "Open Stock Alerts" button. Rejected.
- **Promote the app to a Dock-icon-bearing regular app when the window opens** (`NSApp.setActivationPolicy(.regular)` on window open, `.accessory` on close). More conventional but adds stateful dance and edge cases (app-terminates-on-last-window-close semantics). Rejected.
