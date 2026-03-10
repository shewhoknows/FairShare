# FairShare 💰

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
git clone https://github.com/YOUR_USERNAME/fairshare.git
cd fairshare
```

### 2. Copy and fill in environment variables
```bash
cp .env.example .env
```

Edit `.env`:
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
cp .env.example .env
# Edit DATABASE_URL in .env

# 3. Run migrations and seed
npx prisma migrate dev --name init
npm run db:seed

# 4. Start dev server
npm run dev
```

Open [http://localhost:3000](http://localhost:3000)

---

## 📁 Project Structure

```
fairshare/
├── app/
│   ├── (auth)/
│   │   ├── sign-in/          # Email + Google sign-in
│   │   └── sign-up/          # Registration
│   ├── (dashboard)/
│   │   ├── layout.tsx         # Auth-protected layout with sidebar
│   │   ├── dashboard/         # Home: balances + recent expenses
│   │   ├── groups/            # Groups list + [id] group detail
│   │   ├── friends/           # Friend list + add friends
│   │   └── activity/          # Activity feed
│   ├── api/
│   │   ├── auth/[...nextauth] # NextAuth handler
│   │   ├── groups/            # CRUD + members + balances
│   │   ├── expenses/          # CRUD + comments
│   │   ├── friends/           # Add/list friends
│   │   ├── balances/          # Global balance view
│   │   ├── transactions/      # Record settlements
│   │   ├── activity/          # Activity feed
│   │   └── export/csv/        # CSV export
│   ├── layout.tsx             # Root layout (SessionProvider, Toaster)
│   └── page.tsx               # Landing page
│
├── components/
│   ├── ui/                    # shadcn/ui base components
│   ├── navigation/            # Sidebar + mobile nav
│   ├── expenses/              # AddExpenseModal, ExpenseCard
│   ├── groups/                # CreateGroupModal
│   ├── balances/              # SettleUpModal
│   └── friends/               # AddFriendModal
│
├── lib/
│   ├── prisma.ts              # Prisma singleton
│   ├── auth.ts                # NextAuth config
│   ├── utils.ts               # Formatters, constants
│   ├── validations.ts         # Zod schemas
│   ├── balance-calculator.ts  # Balance computation
│   └── algorithms/
│       └── simplify-debts.ts  # Greedy debt simplification
│
├── prisma/
│   ├── schema.prisma          # Full DB schema
│   └── seed.ts                # Sample data
│
├── middleware.ts              # Protect dashboard routes
├── railway.toml               # Railway deploy config
└── .github/workflows/         # CI/CD pipeline
```

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

FairShare uses a greedy algorithm to minimize transactions:

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

Railway auto-detects Node.js and runs the build command from `railway.toml`:

```toml
buildCommand = "npm ci && npx prisma generate && npx prisma migrate deploy && npm run build"
startCommand = "npm run start"
```

The `DATABASE_URL` environment variable is automatically injected by Railway's Postgres plugin.

---

## 📝 License

MIT © FairShare
