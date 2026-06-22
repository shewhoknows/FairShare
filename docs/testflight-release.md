# TestFlight Release Checklist

This project keeps the App Store Connect bundle identifier as `com.eshabhoon.fairshare`.

## Prerequisites

- Apple Developer App ID `com.eshabhoon.fairshare` exists and has Sign in with Apple enabled.
- The provisioning profile used for archive includes the Sign in with Apple entitlement.
- Release builds use `https://billbandit-api.contenthelper.in` as the real HTTPS mobile API base URL.
- `CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist` are accepted by App Store Connect for the next upload.
- App Store Connect API key or an authenticated Xcode account is available for upload.

## Local Archive

```sh
BILLBANDIT_API_BASE_URL="https://billbandit-api.contenthelper.in" \
xcodebuild \
  -project apps/ios/BillBandit.xcodeproj \
  -scheme BillBandit \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath build/BillBandit.xcarchive \
  archive
```

## Upload To TestFlight

```sh
xcodebuild \
  -exportArchive \
  -archivePath build/BillBandit.xcarchive \
  -exportPath build/TestFlight \
  -exportOptionsPlist apps/ios/ExportOptions.plist \
  -allowProvisioningUpdates
```

Use `-authenticationKeyPath`, `-authenticationKeyID`, and `-authenticationKeyIssuerID` with the upload command when running outside an Xcode-authenticated machine.

## Pre-Upload Checks

- `npm run contract:check`
- `npm run test:api`
- `npm run test:mobile-ledger`
- `npm --workspace apps/web run test:mobile-auth`
- `MOBILE_AUTH_SMOKE_IDENTIFIER="+15555550199" MOBILE_AUTH_SMOKE_OTP_CODE="123456" npm run smoke:production-mobile`
- `npm run release:prove`
- Xcode simulator build/test for `BillBandit`
- Manual smoke on a build pointed at the same API URL used for archive

The release factory writes its output to `release-evidence/<timestamp>/`. Read
`report.md` first; it is the release decision record. The build is not
TestFlight-ready while that report contains any `blocker` gate.

## Railway Custom Domain

Railway service: `FairShare`

Custom domain: `billbandit-api.contenthelper.in`

These DNS records are saved at the `contenthelper.in` DNS host:

| Type | Host/name | Value |
|---|---|---|
| `CNAME` | `billbandit-api` | `r0t6mi4v.up.railway.app` |
| `TXT` | `_railway-verify.billbandit-api` | `railway-verify=d08767a866da0b44029fa659a02f97ee16c43006697e8ecc6a6700a0691083d5` |

Railway status:

- Domain verification: verified.
- Certificate: issued for `billbandit-api.contenthelper.in`.
- Target port: `8080`.

Verify:

```sh
curl https://billbandit-api.contenthelper.in/api/health
```

## Production Email OTP

Resend sending domain: `send.contenthelper.in`

Railway production variable:

- `EMAIL_FROM=BillBandit <otp@send.contenthelper.in>`

DNS records are saved at the `contenthelper.in` DNS host:

| Type | Host/name | Value |
|---|---|---|
| `TXT` | `resend._domainkey.send` | Resend DKIM public key |
| `MX` | `send.send` | `feedback-smtp.ap-northeast-1.amazonses.com` with priority `10` |
| `TXT` | `send.send` | `v=spf1 include:amazonses.com ~all` |

Verification status:

- Resend domain `send.contenthelper.in`: verified.
- Production OTP smoke test to `eshabhoon@gmail.com`: Resend event `delivered` on 2026-06-19.

## Production Mobile Smoke

Use this when inbox access is blocked or before a TestFlight upload needs a
production API proof. It logs in with a scoped OTP test identifier, completes
profile setup, creates a ledger, adds a generated test member, adds an equal
split expense, records the settlement, and confirms the simplified debts are
empty.

Preferred command when DNS is healthy:

```sh
MOBILE_AUTH_SMOKE_IDENTIFIER="+15555550199" \
MOBILE_AUTH_SMOKE_OTP_CODE="123456" \
npm run smoke:production-mobile
```

Fallback command while `billbandit-api.contenthelper.in` DNS is being repaired:

```sh
TEST_URL="https://r0t6mi4v.up.railway.app" \
MOBILE_AUTH_SMOKE_HOST_HEADER="billbandit-api.contenthelper.in" \
MOBILE_AUTH_SMOKE_IDENTIFIER="+15555550199" \
MOBILE_AUTH_SMOKE_OTP_CODE="123456" \
npm run smoke:production-mobile
```

The matching Railway variables are `MOBILE_AUTH_TEST_CODE` and
`MOBILE_AUTH_TEST_IDENTIFIERS`. Keep `MOBILE_AUTH_TEST_IDENTIFIERS` scoped to
explicit QA identifiers, and remove both variables before public release unless
that QA login path is intentionally being kept active.

For faster Debug simulator QA only, launch the iOS app with
`--prefill-qa-auth` to prefill the same test phone and OTP. The shortcut is
compiled out of non-Debug builds.

## DNS Delegation Note

As of the latest release check, the registry delegation for `contenthelper.in`
resolves to Cloudflare nameservers:

- `annabel.ns.cloudflare.com`
- `shane.ns.cloudflare.com`

GoDaddy may still show stale DNS records if it is only the registrar. The
production custom-domain records must exist at the active authoritative DNS
provider. Verify before upload:

```sh
dig +trace billbandit-api.contenthelper.in CNAME
dig @annabel.ns.cloudflare.com billbandit-api.contenthelper.in CNAME
dig @shane.ns.cloudflare.com billbandit-api.contenthelper.in CNAME
```

Expected custom-domain records:

- `CNAME billbandit-api -> r0t6mi4v.up.railway.app`
- `TXT _railway-verify.billbandit-api -> railway-verify=d08767a866da0b44029fa659a02f97ee16c43006697e8ecc6a6700a0691083d5`
