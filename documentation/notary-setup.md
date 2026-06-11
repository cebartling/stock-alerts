# Notary credential setup

`./scripts/release.sh` notarizes the app through a saved keychain credential
profile named **`stockalerts-notary`**. The script never stores or sees the
secret itself — it only references the profile by name (`--keychain-profile
stockalerts-notary`). You save the credential once per machine.

This is a one-time setup step (it's also setup step 4 in
[`release.md`](release.md)). It's split out here because it's the most common
thing missing on a fresh machine — `release.sh` preflight fails with:

```
Error: Notary profile 'stockalerts-notary' not usable.
```

## Status as of the v0.1.1 attempt

- ✅ **Signing identity present:** `Developer ID Application: Christopher Bartling (RDD45JXSRK)`
- ❌ **Notary profile `stockalerts-notary` not saved** — blocks notarization.

The release pipeline stops at preflight (before archiving), so nothing was built,
tagged, or published. Save the profile with one of the options below, then re-run
`./scripts/release.sh`.

## Option A — App Store Connect API key (recommended)

Rotatable without touching your Apple ID password. Create the key at **App Store
Connect → Users and Access → Integrations → App Store Connect API**, download the
`AuthKey_XXXXXXXXXX.p8` once, and note the **Key ID** and **Issuer ID**.

```bash
xcrun notarytool store-credentials stockalerts-notary \
    --key /path/to/AuthKey_XXXXXXXXXX.p8 \
    --key-id XXXXXXXXXX \
    --issuer xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

## Option B — App-specific password

One click at [appleid.apple.com](https://appleid.apple.com) → **Sign-In and
Security → App-Specific Passwords**. `YOUR_TEAM_ID` is the `DEVELOPMENT_TEAM`
value from `Local.xcconfig`.

```bash
xcrun notarytool store-credentials stockalerts-notary \
    --apple-id you@example.com \
    --team-id YOUR_TEAM_ID \
    --password abcd-efgh-ijkl-mnop
```

## Verify

```bash
xcrun notarytool history --keychain-profile stockalerts-notary
```

If that succeeds, preflight will pass. To use a different profile name, set
`STOCKALERTS_NOTARY_PROFILE` before running the script.
