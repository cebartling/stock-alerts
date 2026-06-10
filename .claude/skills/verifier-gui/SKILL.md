---
name: verifier-gui
description: Verify StockAlerts UI/view changes by launching the menu-bar app and driving it (open window, add/delete/reorder watchlist symbols, create/reset/delete alerts) with screenshots as evidence. Use when verifying SwiftUI view or QuoteEngineViewModel changes that need runtime observation rather than just tests — especially anything touching live list updates (the views read from QuoteEngineViewModel.refresh(), not SwiftData @Query). Requires macOS Accessibility permission for the controlling terminal.
---

# verifier-gui

StockAlerts is a `LSUIElement` menu-bar app (no Dock icon). Its views observe
`QuoteEngineViewModel`, which re-reads the SwiftData repositories via `refresh()`
after every mutation and republishes through `@Published` — there is **no
`@Query`**, so "does the list update after I add/delete something?" can only be
answered by driving the running UI. That's what this skill does.

The evidence is screenshots + the AX-read row text of the running app. Tests and
`swiftlint` are **not** evidence here — CI already runs them.

## Step 0 — Accessibility permission (BLOCKING, do this first)

Driving the menu bar and typing into fields needs the **controlling process**
(the terminal/agent running `osascript`) to have macOS Accessibility permission.
Detect it:

```bash
# Use a REAL UI-element probe. Process *listing* (`count processes`) is NOT
# AX-gated and gives a false "granted"; reading a process's menu bars IS.
osascript -e 'tell application "System Events" to tell process "Finder" to count menu bars' >/dev/null 2>&1 \
  && echo "AX: granted" \
  || echo "AX: DENIED (error -25211)"
```

If DENIED, **stop and report BLOCKED** with these grant instructions — do not try
to click via `cliclick`/coordinates instead (synthetic clicks *and* keystrokes
are both AX-gated, and the add-symbol flow needs typing):

> System Settings → Privacy & Security → Accessibility → enable the terminal app
> that runs this agent (e.g. Terminal, iTerm, cmux). Then re-run.

Also note: if a terminal is in macOS **full-screen**, the system menu bar is
hidden and the status item can't be clicked — tell the user to exit full-screen.

## Step 1 — Build / locate and launch

Prefer the already-built signed bundle (the app must be dev-signed for the
keychain entitlement — see CLAUDE.md "Signing"):

```bash
APP=$(find ~/Library/Developer/Xcode/DerivedData/StockAlerts-*/Build/Products/Debug \
      -maxdepth 1 -name 'StockAlerts.app' 2>/dev/null | head -1)
# If none, build it (signed): ./scripts/test.sh builds the app target, or:
#   xcodebuild -project StockAlerts.xcodeproj -scheme StockAlerts -configuration Debug \
#     -destination 'platform=macOS,arch=arm64' -allowProvisioningUpdates build
codesign -dv "$APP" 2>&1 | grep -q "Signature size" && echo "signed: yes"
open "$APP"; sleep 3
pgrep -lf "StockAlerts.app/Contents/MacOS/StockAlerts" | head -1   # confirm running
ls -t ~/Library/Logs/DiagnosticReports/StockAlerts-*.ips 2>/dev/null | head -1 || echo "no crash report"
```

A clean launch already verifies the composition root, `QuoteEngineViewModel.init`,
and `ModelContainer(for: SymbolRecord, AlertRecord)` don't trap. No Finnhub key is
needed — watchlist/alert CRUD and live list updates don't depend on quotes.

## Step 2 — Open the window

Click the menu-bar status item, then "Open Stock Alerts". Element references below
are best-effort against the SwiftUI AX tree; adjust indices if the tree differs
(dump it with `… entire contents of menu bar 1` to inspect).

```bash
osascript <<'EOF'
tell application "System Events" to tell process "StockAlerts"
    set frontmost to true
    click menu bar item 1 of menu bar 1   -- the MenuBarExtra status item -> opens popover
    delay 0.5
    -- popover content is a window; click the "Open Stock Alerts" button
    click (first button of window 1 whose description contains "Open Stock Alerts")
    delay 0.8
end tell
EOF
```

If the status-item click is unreliable, capture its position and click via coords:
`position of menu bar item 1 of menu bar 1` → feed to `cliclick c:X,Y`.

## Step 3 — Drive a mutation and OBSERVE the list update (the actual claim)

Set the "Add symbol" field, click Add, then read the sidebar rows back — this is
the R1 check: the row must appear **without** a manual refresh.

```bash
osascript <<'EOF'
tell application "System Events" to tell process "StockAlerts"
    set win to window "Stock Alerts"
    set value of text field 1 of win to "AAPL"
    click (first button of win whose name is "Add")
    delay 0.6
    -- read sidebar row labels as text evidence
    return value of static texts of win
end tell
EOF
screencapture -x /tmp/verify-after-add.png   # screenshot evidence
```

PASS for the add path = "AAPL" appears in the returned static texts (and the
screenshot) immediately after Add, with no other action.

## Step 4 — Probes (pick what the change points at)

- 🔍 **Delete**: select the row, `delete` key or the row's delete affordance →
  re-read rows → it's gone (exercises `viewModel.removeSymbols`/`removeSymbol` →
  `refresh()`).
- 🔍 **Reorder**: drag a row (or driver-permitting) → order changes and persists.
- 🔍 **Alerts**: open a symbol (`SymbolDetailView`), set the threshold field, click
  "Add alert" → it appears under the symbol; Reset/trash → updates at once
  (exercises `addAlert`/`resetAlert`/`removeAlert` → `refresh()`).
- 🔍 **Persistence**: quit and relaunch → the symbol/alert is still there
  (`SwiftData*Repository` round-trip).
- 🔍 **Empty add**: click Add with the field empty → no-op, no crash.

## Step 5 — Capture and clean up

```bash
# screenshots live in /tmp/verify-*.png; reference them in the report.
osascript -e 'tell application "StockAlerts" to quit' 2>/dev/null \
  || kill "$(pgrep -f 'StockAlerts.app/Contents/MacOS/StockAlerts')" 2>/dev/null
```

If `SendUserFile` is available, send the screenshots so the reviewer can see them;
otherwise reference the `/tmp/verify-*.png` paths and keep the AX-read row text
inline (text travels in the report, a bare path only works on a shared filesystem).

## Report

Use the standard verify report shape (Verdict / Claim / Method / Steps / Findings).
Verdicts specific to this surface:

- **PASS** — you drove the running app and the list changed live after the
  mutation (row text + screenshot show it).
- **FAIL** — you drove it and the list did **not** update after a mutation (the
  R1 regression), or a mutation crashed the app.
- **BLOCKED** — Accessibility denied (Step 0), app wouldn't launch, or the menu
  bar was hidden (full-screen). Say which, with the Step 0 grant instructions.
- **SKIP** — the change has no UI surface (pure Domain/Application/Adapters logic;
  that's already covered by `swift test`). One line why.

Every run includes at least one 🔍 probe. A clean launch alone is **not** PASS —
it doesn't show a list updating; that's at most a note under a BLOCKED verdict.
