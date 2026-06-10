# Releasing StockAlerts (DMG)

`./scripts/release.sh` builds a **notarized, stapled** `.dmg` you can hand to
anyone — it opens with no Gatekeeper warning on a Mac that has never seen your
signing certificate. The script runs the whole Apple distribution chain:
`xcodebuild archive` → `-exportArchive` (Developer ID) → `xcrun notarytool
submit` → staple → `create-dmg` → staple the DMG → `spctl` verify. Output lands
in `dist/StockAlerts-<version>.dmg`.

This is **local-only** today; a CI release workflow is a follow-up (it depends on
the cert/secret patterns from the CI test job — see
[`ci-secrets.md`](ci-secrets.md)).

## One-time setup (per developer machine)

You need a **paid** Apple Developer Program membership for Developer ID signing
and notarization (the free Personal Team used for local testing can't do this).

1. **Install `create-dmg`:**

   ```bash
   brew install create-dmg
   ```

   (`xcodegen` is already a prerequisite — see the README.)

2. **Install your Developer ID Application certificate.** In the
   [Apple Developer portal](https://developer.apple.com/account/resources/certificates),
   create/download a **Developer ID Application** certificate and double-click it
   to add it to your **login** keychain. Confirm it's there:

   ```bash
   security find-identity -v -p codesigning | grep "Developer ID Application"
   ```

3. **Sign your Apple ID into Xcode** (Xcode → Settings → Accounts). Export uses
   **automatic** signing, so Xcode fetches/creates the Developer ID provisioning
   profile on demand. The profile is required because the app declares
   `keychain-access-groups`.

4. **Save a notary credential profile** named `stockalerts-notary`. The
   recommended path is an **App Store Connect API key** (rotatable without
   touching your Apple ID password):

   ```bash
   # App Store Connect → Users and Access → Integrations → App Store Connect API
   # → create a key, download the AuthKey_XXXX.p8 once, note the Key ID + Issuer ID.
   xcrun notarytool store-credentials stockalerts-notary \
       --key /path/to/AuthKey_XXXXXXXXXX.p8 \
       --key-id XXXXXXXXXX \
       --issuer xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   ```

   **Alternative — app-specific password** (one click at
   [appleid.apple.com](https://appleid.apple.com) → Sign-In and Security →
   App-Specific Passwords):

   ```bash
   xcrun notarytool store-credentials stockalerts-notary \
       --apple-id you@example.com \
       --team-id YOUR_TEAM_ID \
       --password abcd-efgh-ijkl-mnop   # YOUR_TEAM_ID = DEVELOPMENT_TEAM from Local.xcconfig
   ```

   Either way the credential lives in the keychain; the script only ever names
   the profile, never the secret. To use a different profile name, set
   `STOCKALERTS_NOTARY_PROFILE`.

5. **Generate the DMG background** (only if `dmg-assets/background.png` is
   missing — it's committed, so normally you don't):

   ```bash
   swift scripts/generate-dmg-background.swift
   ```

## Cut a release

1. Bump `MARKETING_VERSION` in `project.yml` if this is a new version (the DMG
   filename and volume name come from the built app's `CFBundleShortVersionString`,
   not from any flag you pass).
2. Run it:

   ```bash
   ./scripts/release.sh
   ```

3. The notarized, stapled DMG appears at `dist/StockAlerts-<version>.dmg`. Share it.

The script is idempotent — `build/` and `dist/` are gitignored staging dirs and
are overwritten on each run.

## Verify (sanity checks)

```bash
spctl --assess --type install --verbose dist/StockAlerts-<version>.dmg
# expect: accepted   source=Notarized Developer ID

xcrun stapler validate dist/StockAlerts-<version>.dmg   # passes offline
```

Then mount it (`open dist/StockAlerts-<version>.dmg`), drag **StockAlerts.app**
onto **Applications**, launch from Spotlight, and confirm the menu-bar icon
appears with no Gatekeeper or keychain-access-group errors.

## Distribute via GitHub Releases

The DMG is shared through this repo's **Releases** page. Because it's notarized
**and** stapled, the staple travels inside the file — Gatekeeper validates it
offline, so anyone who downloads it gets a clean "drag to Applications" with no
warning and no "unidentified developer" prompt.

Tag the release `v<version>`, matching `MARKETING_VERSION` in `project.yml`, and
attach the DMG (requires `gh auth login` once):

```bash
gh release create v0.1.0 \
    dist/StockAlerts-0.1.0.dmg \
    --title "StockAlerts 0.1.0" \
    --notes "What's new in this release…"
```

The DMG appears as a downloadable asset on the release. For a staging cut, add
`--draft` (publish later from the GitHub UI) or `--prerelease`.

> Automating this on a `v*` tag push (a `release.yml` GitHub Actions workflow) is
> a tracked follow-up — see the note in [`ci-secrets.md`](ci-secrets.md).
> Developer ID signing isn't device-pinned the way the Development profile is, so
> a signed release job is feasible on GitHub-hosted runners (unlike the unsigned
> test job).

## Troubleshooting

- **First archive fails: "No Developer ID Application provisioning profile."**
  Automatic signing hasn't created the profile yet. Open `StockAlerts.xcodeproj`
  in Xcode once (it generates the profile on demand), then re-run the script.

- **Notarization comes back `Invalid`.** Read the JSON failure log — the script
  prints the submission `id`:

  ```bash
  xcrun notarytool log <submission-id> --keychain-profile stockalerts-notary
  ```

- **Preflight: "No Developer ID Application identity."** The cert isn't in your
  login keychain — redo setup step 2.

- **Preflight: "Notary profile not usable."** The credential profile is missing
  or wrong — redo setup step 4 (or point `STOCKALERTS_NOTARY_PROFILE` at the one
  you have).
