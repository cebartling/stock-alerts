# stock-alerts

Stock alerts menu bar app for macOS.

## Getting started

Prerequisites:

- macOS 14 or later
- Xcode 16+ with an Apple ID signed into **Xcode → Settings → Accounts** (a free Personal Team works; a paid Developer Program team is only needed for distribution/notarization)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

### First-time signing setup

The app uses the Data Protection Keychain via the **Keychain Sharing** entitlement, which requires signing with a real development certificate — not ad-hoc. Each contributor supplies their own Apple Developer Team ID via a gitignored `Local.xcconfig`:

```bash
cp Local.xcconfig.example Local.xcconfig
```

Edit `Local.xcconfig` and replace `YOUR_TEAM_ID_HERE` with your 10-character Apple Developer Team ID. Two ways to find it:

```bash
# Terminal:
security find-identity -v -p codesigning
# Look for "Apple Development: Your Name (ABC123DEF4)" — the parenthesized value.
```

or in Xcode: open any project, select a target, **Build Settings** → search `DEVELOPMENT_TEAM`.

**Never commit `Local.xcconfig` itself** — it's in `.gitignore` for a reason.

### Generate the Xcode project

`StockAlerts.xcodeproj` is regenerated from `project.yml`; it's gitignored. After checkout (and any time `project.yml` or `Local.xcconfig` changes):

```bash
xcodegen generate
```

### Run the app

Open `StockAlerts.xcodeproj` in Xcode and ⌘R. The app installs itself as a menu bar icon (no Dock icon). Click it → popover → **Open Stock Alerts** to reveal the main window. Add a Finnhub API key via the gear icon (Settings).

### Run the tests

```bash
./scripts/test.sh
```

The script wraps `xcodebuild test` with the flags this project always needs (`-allowProvisioningUpdates`, macOS arm64 destination, Debug config). Extra args forward to `xcodebuild`, e.g.:

```bash
./scripts/test.sh -only-testing:StockAlertsTests/KeychainStoreTests
```

## Repository layout

- `project.yml` — XcodeGen source of truth for `StockAlerts.xcodeproj`
- `StockAlerts/` — app target sources
- `StockAlertsTests/` — Swift Testing target
- `scripts/test.sh` — test runner wrapper
- `documentation/specifications/SPEC.md` — original design sketch

## License

MIT — see `LICENSE`.
