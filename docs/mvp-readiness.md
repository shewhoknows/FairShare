# MVP Readiness Conclusion

The MVP goal finishes when the ink iOS app can complete the locked ledger surface against the mobile API, pass the automated checks below, and produce an installable TestFlight build without changing the existing `com.eshabhoon.fairshare` bundle identifier.

## Finish Conditions

- Authenticated iOS users land in the ink app shell after profile completion.
- Signed-in ledger data comes from the mobile API, not local-only fixtures.
- A user can create a trip ledger, add an existing user by email, add/update/delete equal-split expenses, view balances and simplified settlements, and record a settlement involving them.
- API tests cover both read parity and the write ledger loop.
- The iOS simulator build and UI tests pass.
- Release builds receive a real `BILLBANDIT_API_BASE_URL`.
- Sign in with Apple entitlement is present in the archive and enabled for the App Store Connect App ID.
- App Store Connect/TestFlight signing uses the existing `com.eshabhoon.fairshare` app identity.

## Current Status

- Done: API-backed ink ledger wiring is implemented in the signed-in iOS surface.
- Done: Local prototype mode remains available for screenshot and UI-test flows.
- Done: Mobile API parity, auth, and ledger write-flow tests are available and wired into parity CI.
- Done: Simulator build/tests pass locally.
- Done: The app target includes the Sign in with Apple entitlement file needed by native Apple auth.
- Done: A TestFlight export options file and release checklist are available.
- Done: Sign in with Apple is enabled on the Apple Developer App ID.
- Done: Railway production variables include the mobile JWT secret and Apple audience values for `com.eshabhoon.fairshare`.
- Needs attention: `billbandit-api.contenthelper.in` still exists in Railway, but the active registry delegation for `contenthelper.in` currently points to Cloudflare nameservers, where the `billbandit-api` CNAME/TXT records were not visible during the latest release smoke. Add the Railway records at the active DNS provider before public/TestFlight release, or use the documented host-header smoke fallback only for internal verification.
- Done: Resend production OTP email is configured through `BillBandit <otp@send.contenthelper.in>`, the `send.contenthelper.in` sending domain is verified, and a live OTP email was delivered via the mobile API.
- Remaining before TestFlight upload: confirm the distribution signing profile for `com.eshabhoon.fairshare` and upload an App Store Connect-accepted build number.

## Verification Commands

- `npm run contract:check`
- `npm run typecheck`
- `npm run lint`
- `npm run build`
- `npm run test:api`
- `npm run test:mobile-ledger`
- `npm --workspace apps/web run test:mobile-auth`
- `MOBILE_AUTH_SMOKE_IDENTIFIER="+15555550199" MOBILE_AUTH_SMOKE_OTP_CODE="123456" npm run smoke:production-mobile`
- XcodeBuildMCP simulator build/test for `BillBandit`
