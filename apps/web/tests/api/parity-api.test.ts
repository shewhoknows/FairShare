import assert from 'node:assert/strict'
import fixtures from '../../../../packages/contracts/fixtures/parity-fixtures.json'

const baseUrl = process.env.TEST_URL ?? 'http://127.0.0.1:3000'
const alice = fixtures.users.find((user) => user.id === fixtures.expectedDashboard.userId)

if (!alice) {
  throw new Error('Parity fixture is missing the dashboard user.')
}

async function requestJson<T>(
  pathname: string,
  init: RequestInit = {}
): Promise<T> {
  const response = await fetch(`${baseUrl}${pathname}`, {
    ...init,
    headers: {
      accept: 'application/json',
      ...(init.body ? { 'content-type': 'application/json' } : {}),
      ...(init.headers ?? {}),
    },
  })

  const payload = await response.json().catch(() => null)
  assert.ok(response.ok, `${pathname} failed with ${response.status}: ${JSON.stringify(payload)}`)
  return payload as T
}

type AuthResponse = {
  token: string
  user: { id: string; email: string | null }
}

type DashboardResponse = {
  totalOwed: number
  totalOwe: number
  currency: string
  balances: Array<{ user: { id: string }; amount: number }>
}

type GroupsResponse = {
  groups: Array<{ id: string; name: string }>
}

type GroupResponse = {
  group: { id: string; name: string }
  balances: {
    simplifiedDebts: Array<{ fromId: string; toId: string; amount: number }>
  }
}

type ExpensesResponse = {
  expenses: Array<{ id: string; description: string }>
}

async function main() {
  const auth = await requestJson<AuthResponse>('/api/mobile/auth/login', {
    method: 'POST',
    body: JSON.stringify({ email: alice.email, password: alice.password }),
  })

  assert.equal(auth.user.id, alice.id)
  assert.ok(auth.token.length > 20)

  const authHeaders = { authorization: `Bearer ${auth.token}` }
  const dashboard = await requestJson<DashboardResponse>('/api/mobile/dashboard', {
    headers: authHeaders,
  })

  assert.equal(dashboard.currency, fixtures.expectedDashboard.currency)
  assert.equal(dashboard.totalOwed, fixtures.expectedDashboard.totalOwed)
  assert.equal(dashboard.totalOwe, fixtures.expectedDashboard.totalOwe)

  const dashboardBalances = new Map(
    dashboard.balances.map((balance) => [balance.user.id, balance.amount])
  )
  for (const balance of fixtures.expectedDashboard.balances) {
    assert.equal(dashboardBalances.get(balance.userId), balance.amount)
  }

  const groups = await requestJson<GroupsResponse>('/api/mobile/groups', {
    headers: authHeaders,
  })
  const visibleGroupIds = new Set(groups.groups.map((group) => group.id))
  for (const group of fixtures.groups) {
    assert.ok(visibleGroupIds.has(group.id), `Missing fixture group ${group.id}`)
  }

  const groupExpectation = fixtures.expectedGroupDebts[0]
  const groupDetail = await requestJson<GroupResponse>(
    `/api/mobile/groups/${groupExpectation.groupId}`,
    { headers: authHeaders }
  )
  assert.equal(groupDetail.group.id, groupExpectation.groupId)

  const actualDebts = groupDetail.balances.simplifiedDebts
    .map((debt) => `${debt.fromId}:${debt.toId}:${debt.amount}`)
    .sort()
  const expectedDebts = groupExpectation.debts
    .map((debt) => `${debt.fromId}:${debt.toId}:${debt.amount}`)
    .sort()
  assert.deepEqual(actualDebts, expectedDebts)

  const expenses = await requestJson<ExpensesResponse>(
    `/api/mobile/expenses?groupId=${groupExpectation.groupId}`,
    { headers: authHeaders }
  )
  const expectedExpenseIds = fixtures.expenses
    .filter((expense) => expense.groupId === groupExpectation.groupId)
    .map((expense) => expense.id)
    .sort()
  const actualExpenseIds = expenses.expenses.map((expense) => expense.id).sort()
  assert.deepEqual(actualExpenseIds, expectedExpenseIds)

  console.log('Fixture-backed mobile API parity checks passed.')
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
