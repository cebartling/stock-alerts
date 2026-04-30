# CI secrets

The `test` job in `.github/workflows/ci.yml` signs the StockAlerts target with a real Apple Development certificate (the `keychain-access-groups` entitlement requires it — ad-hoc signing fails). To do that on a fresh GitHub-hosted `macos-latest` runner, the workflow imports a P12 cert + provisioning profile from **GitHub Actions Repository Secrets** each run.

## Required Repository Secrets

These are **Repository Secrets** (scoped to this single GitHub repo) — *not* Environment Secrets and *not* Organization Secrets. Configure on github.com at:

**Repo → Settings → Secrets and variables → Actions → Secrets tab → "Repository secrets" section → "New repository secret"**

Direct URL: `https://github.com/<owner>/<repo>/settings/secrets/actions`

Add each of the following as a separate repository secret:

| Secret | Contents |
| --- | --- |
| `BUILD_CERTIFICATE_BASE64` | Base64 of your exported Apple Development P12 (cert + private key) |
| `P12_PASSWORD` | Password used when exporting the P12 |
| `BUILD_PROVISIONING_PROFILE_BASE64` | Base64 of the macOS Development `.provisionprofile` matching `com.pintailconsultingllc.StockAlerts` and including `keychain-access-groups` |
| `KEYCHAIN_PASSWORD` | Any random string; passed to `security create-keychain` for the runner-local keychain |
| `DEVELOPMENT_TEAM` | Your 10-char Apple Developer Team ID (same value used in local `Local.xcconfig`) |

## Producing the values

### `BUILD_CERTIFICATE_BASE64` + `P12_PASSWORD`

1. Open **Keychain Access** → *login* keychain → Certificates.
2. Find your `Apple Development: Your Name (TEAMID)` cert. Expand it so the private key is visible.
3. Select **both** the cert and its private key, right-click → **Export 2 items…** → `.p12` format.
4. Set a strong password — this becomes `P12_PASSWORD`.
5. Encode and copy:

   ```bash
   base64 -i AppleDevelopment.p12 | pbcopy
   ```

   Paste into `BUILD_CERTIFICATE_BASE64`.

### `BUILD_PROVISIONING_PROFILE_BASE64`

The profile must be a **macOS Development** profile that:

- Targets bundle ID `com.pintailconsultingllc.StockAlerts`
- Includes the `keychain-access-groups` entitlement for `$(AppIdentifierPrefix)com.pintailconsultingllc.StockAlerts`
- Is signed by the same team as `DEVELOPMENT_TEAM`

Generate at <https://developer.apple.com/account/resources/profiles/list> if one doesn't already exist, then download and:

```bash
base64 -i StockAlerts_Development.provisionprofile | pbcopy
```

### `KEYCHAIN_PASSWORD`

Any random string. The runner-local keychain it unlocks is destroyed at the end of every job.

```bash
openssl rand -base64 24 | pbcopy
```

### `DEVELOPMENT_TEAM`

The 10-character ID you already use locally in `Local.xcconfig`. Same value:

```bash
security find-identity -v -p codesigning
# "Apple Development: Your Name (ABC123DEF4)" — the parenthesized value
```

## Rotation

- **P12 cert** expires roughly yearly. When it does, re-export from Keychain Access and update `BUILD_CERTIFICATE_BASE64` (and `P12_PASSWORD` if you chose a new one).
- **Provisioning profile** expires when the cert it's tied to does. Regenerate alongside the cert and update `BUILD_PROVISIONING_PROFILE_BASE64`.
- **Team ID** does not rotate.
- **Keychain password** is ephemeral — rotate any time without coordination.

## Security notes

- All five values are stored as GitHub Actions Repository Secrets and referenced in the workflow as `${{ secrets.* }}`; nothing is committed to the repo.
- Repository Secrets are not exposed to workflows triggered from forks of this repo, which keeps the signing material out of untrusted PR runs.
- The runner-local keychain is destroyed in an `if: always()` cleanup step so a failed job still tears it down.
- `Local.xcconfig` is regenerated from `DEVELOPMENT_TEAM` at job start and is gitignored — it never ends up in the build context outside the runner.
