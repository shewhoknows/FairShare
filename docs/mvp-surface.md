# MVP Surface

This locks the MVP to the recommended path: a focused iOS-first ledger app using the ink visual direction, backed by the real mobile API.

## Primary Surface

- iOS app only, through the ink app shell after authentication and profile completion.
- Mobile API is the source of truth for signed-in ledger data.
- Web remains supporting infrastructure for auth/API/parity work, not the MVP product surface.

## In Scope

- Sign in with mobile auth, including OTP and Apple sign-in paths already represented in the app.
- Complete the required user profile before entering the app.
- Empty trips state for users with no ledgers.
- Create a trip ledger through `POST /api/mobile/groups`.
- Open a ledger from `GET /api/mobile/groups` and `GET /api/mobile/groups/{id}`.
- Add members to an existing ledger by email through `POST /api/mobile/groups/{id}/members`.
- Add, edit, and delete equal-split expenses through the mobile expenses API.
- Show backend-hydrated group balances and simplified settlements.
- Record a settlement involving the signed-in user through `POST /api/mobile/transactions`.

## Deferred

- Group title/location/date editing through the mobile API.
- Phone-based invite or friend creation from the ledger screen.
- Non-equal split styles in the ink flow.
- Receipt capture, itemized receipts, recurring expenses, and export/share flows.
- Full web dashboard polish as a user-facing MVP surface.
- Public launch mechanics beyond the existing App Store Connect bundle identity.

## Bundle Constraint

Keep the existing `fairshare` bundle identifier segment. App Store Connect already depends on it.
