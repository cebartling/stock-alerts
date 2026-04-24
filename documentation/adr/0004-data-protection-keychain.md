# ADR-0004: Data Protection Keychain for secret storage

- **Status**: Accepted
- **Date**: 2026-04-23

## Context

The app needs to persist a Finnhub API key between launches. The natural default — the user's `login.keychain-db` via `SecItemAdd` without extra flags — has two problems for this project:

1. **Test isolation.** Integration tests in `KeychainStoreTests` exercise real `SecItem*` round-trips. With the default store, tests can land items in the contributor's real login keychain on crash and have no viable path on CI (no login keychain, or a locked one that prompts).
2. **Production hygiene.** A sandboxed menu bar app's secret doesn't belong in the same pool as the user's Safari passwords.

Three candidate solutions were evaluated during implementation:

| Option                                        | Outcome                                                                                                                                          |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| Dedicated file keychain via `security` CLI    | Scheme pre/post actions worked in isolation, but the sandboxed test host hung ~340 s waiting for authorization to use a keychain it didn't own. |
| Disable App Sandbox on the test target        | Would sidestep the above but diverges test environment from production.                                                                           |
| Data Protection Keychain + Keychain Sharing   | Cleanly isolated per app. Chosen.                                                                                                                 |

## Decision

`KeychainStore` issues every `SecItem*` call with `kSecUseDataProtectionKeychain: true`. The app declares the `keychain-access-groups` entitlement (`$(AppIdentifierPrefix)com.pintailconsultingllc.StockAlerts`) in `project.yml` so the sandbox permits DPK access.

The entitlement requires signing with a real development certificate — ad-hoc signing fails at codesign-time. Each contributor's Team ID is supplied via the gitignored `Local.xcconfig` ([ADR-0001](0001-xcodegen-local-xcconfig.md)).

## Consequences

- All writes land in the app-scoped Data Protection Keychain; `login.keychain-db` is never touched by this app. Verified by `writes_doNotPolluteLoginKeychainFile` in `KeychainStoreTests`.
- Development signing is now a prerequisite for building or running tests (`./scripts/test.sh` passes `-allowProvisioningUpdates` so xcodebuild can refresh profiles; direct `xcodebuild test` without that flag fails).
- The in-process `SecItemCopyMatching` API cannot discriminate DPK-stored items from legacy-keychain items once `keychain-access-groups` is entitled — both queries hit the same access-group-scoped pool. The only reliable discriminator is the on-disk keychain file, which is why the regression test shells out to `/usr/bin/security`.
- No migration is provided for pre-DPK entries. The app is pre-release; any stored keys were experimental and can be re-entered via Settings.

## Alternatives considered

- **Dedicated test keychain via `security` CLI + scheme pre/post actions**: documented above. The sandboxed test host hangs on authorization. Deprecated `SecKeychainOpen` or `security set-key-partition-list` gymnastics could work around it but are not worth the complexity.
- **Disable App Sandbox on `StockAlertsTests`**: would permit the dedicated-keychain approach but would make tests run under a different security posture than the shipped app, potentially hiding sandbox-related bugs.
- **Store the API key in `UserDefaults`**: rejected outright in the spec. User-writable plain text.
