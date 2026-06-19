# BillBandit App Screens And Workflow

Scope: active BillBandit ink/auth launch surface on the iPhone 17 Pro simulator, iOS 26.5. Legacy Fairshare dashboard/group SwiftUI files still exist in the repo, but they are not part of the current BillBandit root flow documented here.

## Screenshot Gallery

| # | Screen | Screenshot | How it was reached |
|---|---|---|---|
| 01 | Welcome | [01-welcome.jpg](billbandit-workflow/screenshots/01-welcome.jpg) | `--root=prototype --ink-screen=01` |
| 02 | New Member | [02-new-member.jpg](billbandit-workflow/screenshots/02-new-member.jpg) | `--root=prototype --ink-screen=02` |
| 03 | Trips Empty | [03-trips-empty.jpg](billbandit-workflow/screenshots/03-trips-empty.jpg) | `--root=prototype --ink-screen=03` |
| 04 | Your Trips | [04-your-trips.jpg](billbandit-workflow/screenshots/04-your-trips.jpg) | `--root=prototype --ink-screen=04 --ink-demo-data` |
| 05 | New Ledger | [05-new-ledger.jpg](billbandit-workflow/screenshots/05-new-ledger.jpg) | `--root=prototype --ink-screen=05` |
| 05a | New Ledger Date Picker | [05a-new-ledger-dates.jpg](billbandit-workflow/screenshots/05a-new-ledger-dates.jpg) | New Ledger -> Dates |
| 06 | Live Ledger | [06-live-ledger.jpg](billbandit-workflow/screenshots/06-live-ledger.jpg) | `--root=prototype --ink-screen=06 --ink-demo-data` |
| 06a | Live Ledger Empty State | [06a-live-ledger-empty.jpg](billbandit-workflow/screenshots/06a-live-ledger-empty.jpg) | New Ledger -> Open the ledger |
| 07 | Settle | [07-settle.jpg](billbandit-workflow/screenshots/07-settle.jpg) | `--root=prototype --ink-screen=07 --ink-demo-data` |
| 08 | Record Payment | [08-record-payment.jpg](billbandit-workflow/screenshots/08-record-payment.jpg) | Settle -> tap a settlement row |
| 09 | Final Bill | [09-final-bill.jpg](billbandit-workflow/screenshots/09-final-bill.jpg) | Record Payment -> Mark as paid |
| 10 | Add Entry | [10-add-entry.jpg](billbandit-workflow/screenshots/10-add-entry.jpg) | `--root=prototype --ink-screen=10 --ink-demo-data` |
| 11 | Add Friend | [11-add-friend.jpg](billbandit-workflow/screenshots/11-add-friend.jpg) | `--root=prototype --ink-screen=11` |
| 12 | Auth Start | [12-auth-start.jpg](billbandit-workflow/screenshots/12-auth-start.jpg) | `--root=auth --reset-auth-session` |
| 13 | OTP Verify | [13-auth-otp.jpg](billbandit-workflow/screenshots/13-auth-otp.jpg) | `--root=auth --ink-auth-step=verify` |
| 14 | Profile Completion | [14-auth-profile.jpg](billbandit-workflow/screenshots/14-auth-profile.jpg) | `--root=auth --ink-auth-step=profile` |
| 15 | Auth Loading | [15-auth-loading.jpg](billbandit-workflow/screenshots/15-auth-loading.jpg) | `--root=auth-loading` |

## Primary Workflow

1. Welcome: the signed-out user starts at the BillBandit welcome screen.
2. Auth Start: Login or Create Account opens the email/phone auth receipt.
3. OTP Verify: after an identifier is submitted, the user enters a 6 digit code or resends it.
4. Profile Completion: if the account is incomplete, the user adds name, preferred name, and UPI ID.
5. Trips Empty: a new user with no ledgers lands on the empty trips state.
6. New Ledger: Start a trip opens the ledger composer with title, location, dates, and friends.
7. Date Picker: tapping Dates opens the trip date range sheet.
8. Live Ledger Empty: Open the ledger creates a trip and shows the zero-expense state.
9. Add Entry: Add Entry opens the bill entry form with payer and split controls.
10. Live Ledger: saved expenses appear on the receipt-style ledger with running total, share, and net balance.
11. Your Trips: Back or the Trips tab returns to the trip list.

## Settlement Workflow

Settle, Record Payment, and Final Bill are implemented screens and were captured with demo ledger data. The current live-ledger tab set shows Ledger, Trips, and Profile; the Settle tab only appears once the Settle route is already active. If settlement is part of the MVP user path, the next product/code step is to expose Settle from the normal ledger surface.

## QA Launch Arguments

The capture pass added narrow QA launch arguments:

- `--ink-demo-data` seeds the existing prototype trip store with local demo trips.
- `--ink-auth-step=verify` opens the OTP screen with a demo identifier.
- `--ink-auth-step=profile` opens profile completion with a demo identifier and partial profile.
- `--root=auth-loading` opens the transient auth loading view.

These launch arguments do not affect normal app startup.
