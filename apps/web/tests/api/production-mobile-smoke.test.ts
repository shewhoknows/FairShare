import assert from 'node:assert/strict'
import https from 'node:https'

const baseUrl = process.env.TEST_URL ?? 'https://billbandit-api.contenthelper.in'
const hostHeader = process.env.MOBILE_AUTH_SMOKE_HOST_HEADER
const tlsServerName = process.env.MOBILE_AUTH_SMOKE_TLS_SERVERNAME ?? hostHeader
const otpIdentifier = process.env.MOBILE_AUTH_SMOKE_IDENTIFIER
const otpCode = process.env.MOBILE_AUTH_SMOKE_OTP_CODE ?? process.env.MOBILE_AUTH_TEST_CODE
const runId = `${Date.now()}-${Math.random().toString(16).slice(2)}`
const runLabel = Date.now().toString(36).slice(-6)
const password = 'TestPass123!'

if (!otpIdentifier || !otpCode) {
  console.error([
    'Production mobile smoke requires a scoped OTP test account.',
    'Set MOBILE_AUTH_SMOKE_IDENTIFIER to the allowed phone/email.',
    'Set MOBILE_AUTH_SMOKE_OTP_CODE or MOBILE_AUTH_TEST_CODE to the matching OTP code.',
    `Example: MOBILE_AUTH_SMOKE_IDENTIFIER=+15555550199 MOBILE_AUTH_SMOKE_OTP_CODE=123456 TEST_URL=${baseUrl} npm run smoke:production-mobile`,
  ].join('\n'))
  process.exit(1)
}

type OTPStartResponse = {
  challengeId: string
  maskedIdentifier: string
  deliveryChannel: 'email' | 'phone'
}

type AuthResponse = {
  token: string
  user: {
    id: string
    email: string | null
    phone: string | null
    preferredName: string | null
    upiID: string | null
    isProfileComplete: boolean
  }
}

type UserResponse = {
  user: AuthResponse['user']
}

type GroupResponse = {
  group: {
    id: string
    name: string
    members: Array<{ userId: string; user: { email: string | null } }>
    expenses?: Array<{ id: string; description: string }>
  }
  balances: {
    simplifiedDebts: Array<{ fromId: string; toId: string; amount: number }>
  } | null
}

type MemberResponse = {
  member: { userId: string; user: { email: string | null } }
}

type ExpenseResponse = {
  expense: {
    id: string
    description: string
    amount: number
    paidById: string
    splits: Array<{ userId: string; amount: number }>
  }
}

type TransactionResponse = {
  transaction: {
    amount: number
    sender: { id: string }
    receiver: { id: string }
  }
}

type HealthResponse = {
  status: string
  railway?: { environment?: string; service?: string }
}

type SmokeRequestInit = {
  method?: string
  headers?: Record<string, string>
  body?: string
}

async function requestJson<T>(pathname: string, init: SmokeRequestInit = {}): Promise<T> {
  const response = await requestText(pathname, init)
  const payload = response.body ? JSON.parse(response.body) : null
  assert.ok(response.ok, `${pathname} failed with ${response.status}: ${JSON.stringify(payload)}`)
  return payload as T
}

async function requestText(pathname: string, init: SmokeRequestInit = {}) {
  const headers = {
    accept: 'application/json',
    ...(init.body ? { 'content-type': 'application/json' } : {}),
    ...(init.headers ?? {}),
  }

  if (!hostHeader) {
    const response = await fetch(`${baseUrl}${pathname}`, {
      method: init.method,
      headers,
      body: init.body,
    })
    return {
      ok: response.ok,
      status: response.status,
      body: await response.text(),
    }
  }

  const url = new URL(pathname, baseUrl)
  return new Promise<{ ok: boolean; status: number; body: string }>((resolve, reject) => {
    const request = https.request(url, {
      method: init.method ?? 'GET',
      headers: {
        ...headers,
        host: hostHeader,
      },
      servername: tlsServerName,
    }, (response) => {
      let body = ''
      response.setEncoding('utf8')
      response.on('data', (chunk) => {
        body += chunk
      })
      response.on('end', () => {
        const status = response.statusCode ?? 0
        resolve({ ok: status >= 200 && status < 300, status, body })
      })
    })
    request.on('error', reject)
    if (init.body) {
      request.write(init.body)
    }
    request.end()
  })
}

function authHeaders(token: string) {
  return { authorization: `Bearer ${token}` }
}

function equalSplit(userId: string, amount: number) {
  return { userId, amount, percentage: null, shares: null }
}

async function registerFriend() {
  const email = `production-smoke-friend-${runId}@billbandit-test.com`
  const response = await requestJson<AuthResponse>('/api/mobile/auth/register', {
    method: 'POST',
    body: JSON.stringify({
      name: 'Production Smoke Friend',
      email,
      password,
    }),
  })
  return { email, id: response.user.id }
}

async function main() {
  const health = await requestJson<HealthResponse>('/api/health')
  assert.equal(health.status, 'ok')

  const challenge = await requestJson<OTPStartResponse>('/api/mobile/auth/otp/start', {
    method: 'POST',
    body: JSON.stringify({ identifier: otpIdentifier }),
  })
  assert.ok(challenge.challengeId)

  const ownerAuth = await requestJson<AuthResponse>('/api/mobile/auth/otp/verify', {
    method: 'POST',
    body: JSON.stringify({ challengeId: challenge.challengeId, code: otpCode }),
  })
  assert.ok(ownerAuth.token.length > 20)

  const ownerProfile = await requestJson<UserResponse>('/api/mobile/auth/profile', {
    method: 'PUT',
    headers: authHeaders(ownerAuth.token),
    body: JSON.stringify({
      name: 'Production Smoke Owner',
      preferredName: 'Smoke Owner',
      upiID: `prod.smoke.${runId}@upi`,
    }),
  })
  assert.equal(ownerProfile.user.isProfileComplete, true)

  const friend = await registerFriend()

  const created = await requestJson<GroupResponse>('/api/mobile/groups', {
    method: 'POST',
    headers: authHeaders(ownerAuth.token),
    body: JSON.stringify({
      name: `Smoke Ledger ${runLabel}`,
      description: 'Goa, India\n4-8 Dec 2026',
      currency: 'INR',
      category: 'TRIP',
    }),
  })
  assert.equal(created.group.members.length, 1)

  const member = await requestJson<MemberResponse>(`/api/mobile/groups/${created.group.id}/members`, {
    method: 'POST',
    headers: authHeaders(ownerAuth.token),
    body: JSON.stringify({ email: friend.email }),
  })
  assert.equal(member.member.userId, friend.id)

  const expense = await requestJson<ExpenseResponse>('/api/mobile/expenses', {
    method: 'POST',
    headers: authHeaders(ownerAuth.token),
    body: JSON.stringify({
      description: 'Smoke test dinner',
      amount: 120,
      currency: 'INR',
      date: new Date().toISOString(),
      category: 'food',
      groupId: created.group.id,
      paidById: ownerAuth.user.id,
      splitType: 'EQUAL',
      splits: [
        equalSplit(ownerAuth.user.id, 60),
        equalSplit(friend.id, 60),
      ],
      notes: null,
    }),
  })
  assert.equal(expense.expense.splits.length, 2)

  const withDebt = await requestJson<GroupResponse>(`/api/mobile/groups/${created.group.id}`, {
    headers: authHeaders(ownerAuth.token),
  })
  assert.equal(withDebt.balances?.simplifiedDebts.length, 1)
  assert.equal(withDebt.balances?.simplifiedDebts[0].fromId, friend.id)
  assert.equal(withDebt.balances?.simplifiedDebts[0].toId, ownerAuth.user.id)
  assert.equal(withDebt.balances?.simplifiedDebts[0].amount, 60)

  const settlement = await requestJson<TransactionResponse>('/api/mobile/transactions', {
    method: 'POST',
    headers: authHeaders(ownerAuth.token),
    body: JSON.stringify({
      senderId: friend.id,
      receiverId: null,
      amount: 60,
      currency: 'INR',
      groupId: created.group.id,
      note: 'Production mobile smoke settlement',
    }),
  })
  assert.equal(settlement.transaction.sender.id, friend.id)
  assert.equal(settlement.transaction.receiver.id, ownerAuth.user.id)

  const settled = await requestJson<GroupResponse>(`/api/mobile/groups/${created.group.id}`, {
    headers: authHeaders(ownerAuth.token),
  })
  assert.deepEqual(settled.balances?.simplifiedDebts, [])

  console.log(JSON.stringify({
    ok: true,
    baseUrl,
    railway: health.railway ?? null,
    ownerUserId: ownerAuth.user.id,
    friendUserId: friend.id,
    groupId: created.group.id,
    expenseId: expense.expense.id,
    settled: true,
  }, null, 2))
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
