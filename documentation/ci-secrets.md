# CI signing strategy

The `test` job in `.github/workflows/ci.yml` runs **unsigned** on the GitHub-hosted `macos-latest` runner. No GitHub Secrets are required.

## Why unsigned

The app's `keychain-access-groups` entitlement requires a real Apple Development signing identity — ad-hoc signing fails. Locally that's fine (the developer's Mac is registered in the macOS Development profile). On CI it isn't:

- macOS Development profiles are pinned to specific device UDIDs.
- GitHub-hosted `macos-latest` runners are ephemeral and report a different provisioning UDID every run.
- Pre-registering them is impossible; auto-registering them requires App Store Connect API credentials and `-allowProvisioningUpdates`, which is a meaningful additional integration.

Rather than carry that, CI:

1. Sets `CODE_SIGN_IDENTITY=""`, `CODE_SIGNING_REQUIRED=NO`, `CODE_SIGNING_ALLOWED=NO` so `xcodebuild` doesn't sign anything.
2. Skips `StockAlertsTests/KeychainStoreTests`, the only suite that exercises `keychain-access-groups` and would fail at runtime in an unsigned build.

Everything else (logic, networking with `StubURLProtocol`, SwiftData, `MarketClock`, alert evaluation, etc.) runs in CI exactly as locally.

## What's still covered

| Tier | Where |
| --- | --- |
| Lint | CI (`swiftlint --strict`) |
| All non-keychain unit tests | CI |
| `KeychainStoreTests` | **Local only** — `./scripts/test.sh` before pushing. The pattern of testing the SecItem/DPK boundary via subprocess is the test of record; CLAUDE.md captures it. |

If you add a new suite that depends on `keychain-access-groups` or other entitlement-gated APIs, either:

- Add it to the `-skip-testing:` list in `.github/workflows/ci.yml`, **and** make sure it's part of your local pre-push run; or
- Switch CI to a signing-capable strategy (see below).

## Future: re-enabling signed CI

If you later need entitlement-dependent suites to run in CI, the cleanest path is App Store Connect API + `-allowProvisioningUpdates`, which auto-registers the runner's UDID each run. That requires:

- An App Store Connect API key (Issuer ID, Key ID, base64-encoded `.p8`) stored as Repository Secrets.
- Importing the dev cert into a runner-local keychain (the previous approach in this file).
- Passing `-authenticationKeyID`, `-authenticationKeyIssuerID`, `-authenticationKeyPath` to `xcodebuild`.

Self-hosted Mac runners are an alternative — register the runner's UDID once against the existing development profile and the original signing setup works without changes.
