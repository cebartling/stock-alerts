---
name: verifier-app
description: Verify StockAlerts behavior at runtime by driving the dev HTTP control server with curl (read EngineState, add/remove watchlist symbols, create/reset/delete alerts, force a poll) — deterministic, no Accessibility, no side effects. Use when verifying QuoteEngine / repository / QuoteEngineViewModel / view behavior, especially live list updates (views read QuoteEngineViewModel.refresh(), not SwiftData @Query). A GUI screenshot path is included only for confirming actual pixel rendering.
---

# verifier-app

StockAlerts is a `LSUIElement` menu-bar app. In **Debug builds** it starts a
dev-only HTTP control server (`DevHTTPServer`, `#if DEBUG`, `127.0.0.1:8765`,
overridable via `STOCKALERTS_DEV_PORT`) — a second driving adapter over the same
`QuoteEngine` + repository ports the UI uses. **Prefer HTTP for behavior, state,
and data verification.** It's deterministic, needs no Accessibility, and has no
side effects.

**Why HTTP-first (hard-won):** coordinate-driving the menu-bar GUI is brittle on
a live machine and can leak keystrokes into whatever window is actually under the
cursor — it once typed a stray comment into a browser tab. The HTTP surface
avoids all of that. Use the GUI path (Step 3) **only** when the claim is about
rendering/layout that HTTP can't show.

Tests and `swiftlint` are **not** evidence here — CI runs them. Evidence is the
running app's HTTP responses (and, for visual claims, a screenshot).

## Step 1 — Build (Debug) and launch

The dev server is `#if DEBUG` and starts from `StockAlertsApp.init` at launch
(not the MenuBarExtra `.task`, which only runs when the popover first opens). So
a **Debug** build is required; Release compiles the server out entirely.

```bash
APP=$(find ~/Library/Developer/Xcode/DerivedData/StockAlerts-*/Build/Products/Debug \
      -maxdepth 1 -name 'StockAlerts.app' 2>/dev/null | head -1)
# Build if missing (signed — keychain entitlement needs a real dev cert; see CLAUDE.md):
#   xcodebuild -project StockAlerts.xcodeproj -scheme StockAlerts -configuration Debug \
#     -destination 'platform=macOS,arch=arm64' -allowProvisioningUpdates build
open "$APP"; sleep 3
pgrep -f 'StockAlerts.app/Contents/MacOS/StockAlerts' >/dev/null && echo "running" || echo "NOT running"
lsof -nP -iTCP:8765 2>/dev/null | grep -q LISTEN && echo "dev server: listening" || echo "dev server: NOT listening"
```

A clean launch + listening port already exercises the composition root,
`QuoteEngineViewModel.init`, the `ModelContainer(SymbolRecord, AlertRecord)`, and
`DevHTTPServer.start()`. If it launches but isn't listening, you likely have a
**Release** build, or `start()` threw — check `log show --predicate 'process ==
"StockAlerts"' --last 2m | grep DevHTTP`.

## Step 2 — Drive + assert over curl (PRIMARY)

Endpoints:
```
GET    /state                     -> {quotes, lastError, lastSuccessfulFetch, clockTick}
GET    /watchlist                 -> ["AAPL", ...]
POST   /watchlist  {"symbol":"X"} -> updated ["AAPL","X"]   (addSymbol -> refresh)
DELETE /watchlist/{symbol}        -> updated [...]
GET    /alerts?symbol=AAPL        -> [AlertDTO]
POST   /alerts {"symbol","condition","threshold"} -> created AlertDTO  (condition: above|below|percentChangeUp|percentChangeDown)
POST   /alerts/{id}/reset         -> {"ok":true}
DELETE /alerts/{id}               -> {"ok":true}
POST   /tick                      -> StateDTO after a real Finnhub fetch
```

The poll loop only starts once the popover opens, so quotes in `/state` are empty
until you **`POST /tick`** — which is also the deterministic way to drive a fetch.

Canonical R1 flow (each line is a step; note the before/after):
```bash
P=${STOCKALERTS_DEV_PORT:-8765}
curl -s localhost:$P/watchlist; echo                                   # baseline
curl -s -XPOST localhost:$P/watchlist -d '{"symbol":"MSFT"}'; echo     # add -> updated list (R1)
curl -s localhost:$P/watchlist; echo                                   # MSFT present
curl -s -XPOST localhost:$P/tick | python3 -m json.tool | head -20     # real quotes for AAPL/MSFT
curl -s -XPOST localhost:$P/alerts -d '{"symbol":"AAPL","condition":"above","threshold":1}'; echo
curl -s "localhost:$P/alerts?symbol=AAPL"; echo                        # includes the new alert
curl -s -XDELETE localhost:$P/watchlist/MSFT; echo                     # remove -> back to baseline
curl -s -o /dev/null -w '404? %{http_code}\n' localhost:$P/nope        # unknown -> 404
curl -s -o /dev/null -w '400? %{http_code}\n' -XPOST localhost:$P/watchlist -d 'garbage'  # malformed -> 400
```

PASS = the mutations reflect in the immediately-following read (add shows up,
delete removes it), `/tick` returns live quotes, and the error paths give 404/400.
At least one 🔍 probe (the 404/400 lines, or a double-add no-op) every run.

**Clean up data you added:** `DELETE` any symbols/alerts you created so the store
is left as you found it.

## Step 3 — Visual confirmation (OPTIONAL — only for rendering/layout claims)

HTTP proves data and behavior, not pixels. If the claim is specifically about
*how it looks* (a new badge, layout, color, the Market-Open dot), confirm with a
screenshot — but only then, and carefully:

- **Accessibility gate** (needed for menu/AX driving): a real UI-element probe,
  not `count processes` (which isn't AX-gated and falsely reports granted):
  ```bash
  osascript -e 'tell application "System Events" to tell process "Finder" to count menu bars' \
    >/dev/null 2>&1 && echo "AX: granted" || echo "AX: DENIED (-25211)"
  ```
  If denied: System Settings → Privacy & Security → Accessibility → enable the
  controlling terminal, then retry. If a terminal is **full-screen**, the system
  menu bar is hidden — exit full-screen first.
- **Open the main window reliably via the menu** (not a coordinate click on the
  transient popover): `Window ▸ Stock Alerts`:
  ```bash
  osascript -e 'tell application "System Events" to tell process "StockAlerts" to \
    click menu item "Stock Alerts" of menu 1 of menu bar item "Window" of menu bar 1'
  ```
- **Screenshot the window region** (get geometry from AX, capture in points):
  ```bash
  osascript -e 'tell application "System Events" to tell process "StockAlerts" to get position of window 1'
  osascript -e 'tell application "System Events" to tell process "StockAlerts" to get size of window 1'
  # then, with x,y,w,h:  screencapture -x -R<x>,<y>,<w>,<h> /tmp/verify.png
  ```
- **NEVER blind coordinate-click or type.** SwiftUI window/popover content is an
  `NSHostingView` that doesn't expose its controls to System Events, which tempts
  coordinate clicks — that's exactly what leaks keystrokes into other windows.
  Drive *data* over HTTP (Step 2); use the GUI only to *look*. If you must click,
  `AXRaise` the StockAlerts window and confirm it's frontmost and covers the
  point first.

## Step 4 — Clean up

```bash
osascript -e 'tell application "StockAlerts" to quit' 2>/dev/null \
  || kill "$(pgrep -f 'StockAlerts.app/Contents/MacOS/StockAlerts')" 2>/dev/null
```
Reference any `/tmp/verify-*.png` in the report; if `SendUserFile` exists, send
them. HTTP response bodies travel inline as evidence.

## Report

Standard verify shape (Verdict / Claim / Method / Steps / Findings). Verdicts:

- **PASS** — you drove the running app over HTTP and the behavior held (mutations
  reflected on read; `/tick` returned live quotes; error paths correct). For
  visual claims, the screenshot shows the expected rendering.
- **FAIL** — a mutation didn't reflect on the next read (R1 regression), `/tick`
  or an endpoint errored unexpectedly, or the app crashed.
- **BLOCKED** — Debug app wouldn't launch, or the dev port never came up (and you
  couldn't tell why from the log). For a *visual-only* claim, Accessibility denied
  or menu bar hidden. Say which.
- **SKIP** — pure Domain/Application/Adapters change with no runtime-observable
  behavior beyond what `swift test` covers. One line why.

A clean launch alone is **not** PASS — drive at least one mutation+read over HTTP.
