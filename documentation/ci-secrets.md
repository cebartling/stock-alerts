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

If one doesn't already exist, create it on developer.apple.com (you must be logged in):

#### 1. Confirm or create the App ID

1. Go to <https://developer.apple.com/account/resources/identifiers/list>.
2. Filter by **App IDs**. If `com.pintailconsultingllc.StockAlerts` already exists, click it. Otherwise click **+ → App IDs → App**, set Platform **macOS**, Bundle ID **Explicit** = `com.pintailconsultingllc.StockAlerts`.
3. Leave **Capabilities** alone — Keychain Sharing is an iOS-only capability and does not appear in the macOS App ID capability list. macOS enforces keychain access groups entirely via the app's `.entitlements` file plus the team prefix from the signing identity, so no portal-side toggle is required.
4. Continue / Register.

> `$(AppIdentifierPrefix)com.pintailconsultingllc.StockAlerts` resolves to `<TEAMID>.com.pintailconsultingllc.StockAlerts` at build time. That's the default keychain group; no custom value is needed in the portal.

#### 2. Make sure your Mac development certificate is registered

1. Go to <https://developer.apple.com/account/resources/certificates/list>.
2. You need an **Apple Development** (or **Mac Development**) certificate tied to your Mac. If you already build & sign locally, you have one. If not: **+ → Apple Development → Continue**, and upload a CSR generated from Keychain Access (*Certificate Assistant → Request a Certificate From a Certificate Authority*, "Saved to disk").

#### 3. Register your Mac as a device

1. Go to <https://developer.apple.com/account/resources/devices/list>, Platform **macOS**.
2. You need the **Provisioning UDID** (not the hardware UUID):

   ```bash
   system_profiler SPHardwareDataType | awk '/Provisioning UDID/ {print $3}'
   ```

3. Click **+**, name the device, paste the UDID, Continue / Register.

#### 4. Create the provisioning profile

1. Go to <https://developer.apple.com/account/resources/profiles/list>.
2. **+** → under **Development** pick **macOS App Development** → Continue.
3. **App ID**: select `com.pintailconsultingllc.StockAlerts` → Continue.
4. **Certificates**: check your Apple/Mac Development certificate → Continue.
5. **Devices**: check your Mac → Continue.
6. **Provisioning Profile Name**: e.g. `StockAlerts macOS Development` → Generate.
7. **Download** the `.provisionprofile`.

#### 5. Encode for the secret

```bash
base64 -i StockAlerts_Development.provisionprofile | pbcopy
```

Paste into `BUILD_PROVISIONING_PROFILE_BASE64`.

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
