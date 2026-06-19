# BillBandit 💰

> A production-ready Splitwise clone built with Next.js 14, Prisma, PostgreSQL, and Railway.

Split expenses fairly with friends, roommates, and travel companions. Track balances, simplify debts, and settle up—all in one place.

---

## ✨ Features

- **Auth** – Email/password signup + Google OAuth (NextAuth.js)
- **Groups** – Create groups by category (Home, Trip, Work, etc.), invite members
- **Expenses** – Add expenses with 4 split types: Equal, Exact, Percentage, Shares
- **Balances** – Real-time balance calculation showing who owes whom
- **Simplify Debts** – Greedy algorithm minimizes the number of settlements
- **Settle Up** – Record payments and clear balances
- **Activity Feed** – Full audit trail of all expense activity
- **CSV Export** – Export your expenses to CSV
- **Mobile-first** – Fully responsive with bottom-nav on mobile

---

## 🚀 Quick Start (Railway – 5 minutes)

### Prerequisites
- [Node.js 20+](https://nodejs.org)
- [Railway account](https://railway.app)
- [Railway CLI](https://docs.railway.app/develop/cli): `npm install -g @railway/cli`

### 1. Clone the repo
```bash
git clone https://github.com/YOUR_USERNAME/billbandit.git
cd billbandit
```

### 2. Copy and fill in environment variables
```bash
cp apps/web/.env.example apps/web/.env
```

Edit `apps/web/.env`:
```env
DATABASE_URL="<auto-set by Railway>"
NEXTAUTH_SECRET="generate-with: openssl rand -base64 32"
NEXTAUTH_URL="https://your-app.railway.app"
GOOGLE_CLIENT_ID="your-google-client-id"
GOOGLE_CLIENT_SECRET="your-google-client-secret"
```

### 3. Deploy to Railway
```bash
railway login
railway init                   # create new Railway project
railway add --database postgres # add Postgres (DATABASE_URL auto-set)
railway up                     # deploy!
```

Railway automatically runs:
```
npm ci → prisma generate → prisma migrate deploy → next build → next start
```

### 4. (Optional) Seed demo data
```bash
railway run npm run db:seed
```

Login with: `alice@example.com` / `password123`

---

## 🛠 Local Development

```bash
# 1. Install dependencies
npm install

# 2. Set up database (PostgreSQL required)
cp apps/web/.env.example apps/web/.env
# Edit DATABASE_URL in apps/web/.env

# 3. Run migrations and seed
npm run db:push
npm run db:seed

# 4. Start dev server
npm run dev
```

Open [http://localhost:3000](http://localhost:3000)

### iOS app

The native iOS MVP lives in `apps/ios/` and is generated with XcodeGen.

```bash
# From the repo root
npm install
cp apps/web/.env.example apps/web/.env
# Fill DATABASE_URL, NEXTAUTH_SECRET, and MOBILE_JWT_SECRET
npm run db:push
npm run dev

# In another terminal
cd apps/ios
xcodegen generate
xcodebuild -project BillBandit.xcodeproj -scheme BillBandit -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Debug iOS builds use `http://localhost:3000` from `apps/ios/Config/Debug.xcconfig`. Update `apps/ios/Config/Release.xcconfig` with your deployed HTTPS backend before making a release build.

---

## 📁 Project Structure

```
billbandit/
├── apps/
│   ├── web/
│   │   ├── app/                # Next.js pages and API routes
│   │   ├── components/         # Shared web UI
│   │   ├── lib/                # Auth, DTOs, calculations, Prisma access
│   │   ├── prisma/             # Schema, migrations, fixture-backed seed
│   │   └── tests/              # API parity and Playwright coverage
│   └── ios/
│       ├── BillBanditApp/       # Native app sources, tests, generated fixture mirror
│       └── project.yml         # XcodeGen project definition
│
├── packages/
│   └── contracts/
│       ├── openapi.yaml        # Shared mobile/backend contract
│       ├── fixtures/           # Canonical parity scenarios
│       └── scripts/            # Contract checks and fixture sync helpers
│
├── services/
│   └── api/README.md           # Explicit API extraction boundary
│
├── package.json                # Workspace orchestration
├── railway.toml               # Railway deploy config
└── .github/workflows/         # CI/CD pipeline
```

---

## API Boundary and Parity

The live API remains inside `apps/web/app/api` for now. `services/api/README.md`
documents that as an explicit backend boundary while `packages/contracts/openapi.yaml`
acts as the shared cross-platform contract.

Parity proof is fixture-backed:

- `npm run contract:check`
- `npm run test:api`
- `npm run test:web`
- iOS UI coverage in `apps/ios/BillBanditApp/UITests`

The `Feature Parity` GitHub Actions workflow runs those lanes separately for pull
requests and main-branch pushes.

---

## Reviewer Guide

This repository is intentionally split so the web app and iOS app can evolve
independently while still proving that shared user journeys behave the same.

Review in this order:

1. `packages/contracts/openapi.yaml`
   Defines the shared backend contract that both clients are expected to honor.
2. `packages/contracts/fixtures/parity-fixtures.json`
   Holds the canonical users, groups, expenses, and debts used for parity checks.
3. `apps/web/prisma/seed.ts` and `apps/web/tests/api/parity-api.test.ts`
   Show how the backend loads those fixtures and verifies API behavior.
4. `apps/web/tests/e2e/parity-fixtures.spec.ts`
   Proves the shared fixture scenario renders correctly in the web app.
5. `apps/ios/BillBanditApp/Sources/ParityFixtures.swift` and
   `apps/ios/BillBanditApp/UITests/BillBanditUITests.swift`
   Show the mirrored iOS fixture layer and UI proof.
6. `.github/workflows/parity.yml`
   Captures the PR gate that keeps the contract and parity checks honest.

The current backend choice is deliberate: API routes still run inside the Next.js
app for deployment simplicity, but `services/api/README.md` records the future
extraction boundary so that move can happen without changing the contract.

---

## Validation Matrix

| Area | What it proves | Command |
|---|---|---|
| Contract | OpenAPI file is present, referenced endpoints stay covered, generated fixture mirror stays valid | `npm run fixtures:ios:sync && npm run contract:check` |
| Backend API | Shared fixture scenarios work through the mobile-facing API surface | `npm run test:api` |
| Web app | Full browser suite passes, including the fixture-backed parity journey | `npm run test:web` |
| iOS app | Native project builds and UI tests exercise the mirrored fixture scenario | `cd apps/ios && xcodegen generate`, then `cd ../.. && xcodebuild test -project apps/ios/BillBandit.xcodeproj -scheme BillBandit -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |
| Repo health | Type safety, linting, and production build remain intact | `npm run typecheck && npm run lint && npm run build` |

The parity workflow runs the same evidence lanes in CI on pull requests and on
pushes to `main`, so feature work must keep the web app, iOS app, and shared
contract aligned.

---

## 🔑 Environment Variables

| Variable | Description | Required |
|---|---|---|
| `DATABASE_URL` | PostgreSQL connection string | ✅ |
| `NEXTAUTH_SECRET` | Random 32-byte secret | ✅ |
| `NEXTAUTH_URL` | Full URL of your app | ✅ |
| `GOOGLE_CLIENT_ID` | Google OAuth client ID | Optional |
| `GOOGLE_CLIENT_SECRET` | Google OAuth client secret | Optional |

### Generating `NEXTAUTH_SECRET`
```bash
openssl rand -base64 32
```

### Setting up Google OAuth
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a project → Credentials → OAuth 2.0 Client ID
3. Add authorized redirect URI: `https://your-app.railway.app/api/auth/callback/google`

---

## 🧮 Debt Simplification Algorithm

BillBandit uses a greedy algorithm to minimize transactions:

1. Calculate each user's **net balance** (positive = owed money, negative = owes money)
2. Sort creditors (positive) and debtors (negative) by magnitude
3. Match the largest creditor with the largest debtor
4. Record a transaction for `min(credit, debt)` and reduce both balances
5. Repeat until all balances are ~0

This reduces N*(N-1)/2 possible pair payments to at most N-1 transactions.

---

## 🗄 Database Schema

Core models:
- **User** – Auth + profile
- **Group** – Shared expense group with category
- **GroupMember** – User ↔ Group junction (ADMIN/MEMBER role)
- **Expense** – Expense with split type and category
- **ExpenseSplit** – Per-user portion of an expense
- **Transaction** – Settlement payment record
- **Friendship** – User ↔ User connection
- **Comment** – Comments on expenses
- **ActivityLog** – Audit trail

---

## 🚢 Railway Setup Details

Railway builds from the root `Dockerfile`, which now installs the workspace,
generates Prisma from `apps/web/prisma/schema.prisma`, builds the web app, runs
migrations, and starts the workspace entrypoint.

The `DATABASE_URL` environment variable is automatically injected by Railway's Postgres plugin.

---

## 📝 License

MIT © BillBandit
# Deploy trigger Tue May 12 18:41:06 IST 2026
# Deploy 1778591606
# Deploy 1778591787
