import assert from 'node:assert/strict'

const baseUrl = process.env.TEST_URL ?? 'http://127.0.0.1:3000'
const runId = `${Date.now()}-${Math.random().toString(16).slice(2)}`
const password = 'TestPass123!'

async function requestJson<T>(
  pathname: string,
  init: RequestInit = {}
): Promise<T> {
  const response = await requestRaw(pathname, init)

  const payload = await response.json().catch(() => null)
  assert.ok(response.ok, `${pathname} failed with ${response.status}: ${JSON.stringify(payload)}`)
  return payload as T
}

async function requestRaw(
  pathname: string,
  init: RequestInit = {}
) {
  return fetch(`${baseUrl}${pathname}`, {
    ...init,
    headers: {
      accept: 'application/json',
      ...(init.body ? { 'content-type': 'application/json' } : {}),
      ...(init.headers ?? {}),
    },
  })
}

type AuthResponse = {
  token: string
  user: { id: string; email: string | null }
}

type Group = {
  id: string
  name: string
  status: 'ACTIVE' | 'FINALIZED'
  finalizedAt: string | null
  finalizedById: string | null
  members: Array<{ userId: string; user: { email: string | null } }>
  expenses?: Array<{ id: string; description: string }>
}

type GroupResponse = {
  group: Group
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

type ExpensesResponse = {
  expenses: Array<{ id: string; description: string }>
}

type TransactionResponse = {
  transaction: {
    amount: number
    sender: { id: string }
    receiver: { id: string }
  }
}

type SuccessResponse = {
  success: boolean
}

async function register(name: string, email: string) {
  return requestJson<AuthResponse>('/api/mobile/auth/register', {
    method: 'POST',
    body: JSON.stringify({ name, email, password }),
  })
}

function authHeaders(token: string) {
  return { authorization: `Bearer ${token}` }
}

function equalSplit(userId: string, amount: number) {
  return { userId, amount, percentage: null, shares: null }
}

async function main() {
  const ownerEmail = `ledger-owner-${runId}@billbandit-test.com`
  const friendEmail = `ledger-friend-${runId}@billbandit-test.com`
  const outsiderEmail = `ledger-outsider-${runId}@billbandit-test.com`
  const owner = await register('Ledger Owner', ownerEmail)
  const friend = await register('Ledger Friend', friendEmail)
  const outsider = await register('Ledger Outsider', outsiderEmail)
  const headers = authHeaders(owner.token)
  const friendHeaders = authHeaders(friend.token)

  const created = await requestJson<GroupResponse>('/api/mobile/groups', {
    method: 'POST',
    headers,
    body: JSON.stringify({
      name: `MVP Ledger ${runId}`,
      description: 'Goa, India\n4-8 Dec 2026',
      currency: 'INR',
      category: 'TRIP',
    }),
  })
  assert.equal(created.group.members.length, 1)
  assert.equal(created.group.status, 'ACTIVE')
  assert.equal(created.group.finalizedAt, null)
  assert.equal(created.group.finalizedById, null)

  const member = await requestJson<MemberResponse>(`/api/mobile/groups/${created.group.id}/members`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ email: friendEmail }),
  })
  assert.equal(member.member.userId, friend.user.id)

  const withMember = await requestJson<GroupResponse>(`/api/mobile/groups/${created.group.id}`, {
    headers,
  })
  assert.ok(withMember.group.members.some((groupMember) => groupMember.userId === friend.user.id))

  const expenseBody = {
    description: 'Dinner at the dhaba',
    amount: 100,
    currency: 'INR',
    date: new Date().toISOString(),
    category: 'food',
    groupId: created.group.id,
    paidById: owner.user.id,
    splitType: 'EQUAL',
    splits: [equalSplit(owner.user.id, 50), equalSplit(friend.user.id, 50)],
    notes: null,
  }

  const createdExpense = await requestJson<ExpenseResponse>('/api/mobile/expenses', {
    method: 'POST',
    headers,
    body: JSON.stringify(expenseBody),
  })
  assert.equal(createdExpense.expense.paidById, owner.user.id)
  assert.equal(createdExpense.expense.splits.length, 2)

  const outsiderUpdate = await requestRaw(`/api/mobile/expenses/${createdExpense.expense.id}`, {
    method: 'PUT',
    headers,
    body: JSON.stringify({
      ...expenseBody,
      splits: [equalSplit(owner.user.id, 50), equalSplit(outsider.user.id, 50)],
    }),
  })
  assert.equal(outsiderUpdate.status, 400)

  const updatedExpense = await requestJson<ExpenseResponse>(`/api/mobile/expenses/${createdExpense.expense.id}`, {
    method: 'PUT',
    headers,
    body: JSON.stringify({
      ...expenseBody,
      amount: 120,
      splits: [equalSplit(owner.user.id, 60), equalSplit(friend.user.id, 60)],
    }),
  })
  assert.equal(updatedExpense.expense.amount, 120)

  const withDebt = await requestJson<GroupResponse>(`/api/mobile/groups/${created.group.id}`, {
    headers,
  })
  assert.equal(withDebt.balances?.simplifiedDebts.length, 1)
  assert.equal(withDebt.balances?.simplifiedDebts[0].fromId, friend.user.id)
  assert.equal(withDebt.balances?.simplifiedDebts[0].toId, owner.user.id)
  assert.equal(withDebt.balances?.simplifiedDebts[0].amount, 60)

  const outsiderTransaction = await requestRaw('/api/mobile/transactions', {
    method: 'POST',
    headers,
    body: JSON.stringify({
      senderId: outsider.user.id,
      receiverId: null,
      amount: 60,
      currency: 'INR',
      groupId: created.group.id,
    }),
  })
  assert.equal(outsiderTransaction.status, 403)

  const ambiguousTransaction = await requestRaw('/api/mobile/transactions', {
    method: 'POST',
    headers,
    body: JSON.stringify({
      senderId: friend.user.id,
      receiverId: friend.user.id,
      amount: 60,
      currency: 'INR',
      groupId: created.group.id,
    }),
  })
  assert.equal(ambiguousTransaction.status, 400)

  const transaction = await requestJson<TransactionResponse>('/api/mobile/transactions', {
    method: 'POST',
    headers,
    body: JSON.stringify({
      senderId: friend.user.id,
      receiverId: null,
      amount: 60,
      currency: 'INR',
      groupId: created.group.id,
      note: null,
    }),
  })
  assert.equal(transaction.transaction.sender.id, friend.user.id)
  assert.equal(transaction.transaction.receiver.id, owner.user.id)

  const settled = await requestJson<GroupResponse>(`/api/mobile/groups/${created.group.id}`, {
    headers,
  })
  assert.deepEqual(settled.balances?.simplifiedDebts, [])

  const temporaryExpense = await requestJson<ExpenseResponse>('/api/mobile/expenses', {
    method: 'POST',
    headers,
    body: JSON.stringify({
      ...expenseBody,
      description: 'Temporary chai',
      amount: 20,
      splits: [equalSplit(owner.user.id, 10), equalSplit(friend.user.id, 10)],
    }),
  })
  const deleted = await requestJson<SuccessResponse>(`/api/mobile/expenses/${temporaryExpense.expense.id}`, {
    method: 'DELETE',
    headers,
  })
  assert.equal(deleted.success, true)

  const expenses = await requestJson<ExpensesResponse>(`/api/mobile/expenses?groupId=${created.group.id}`, {
    headers,
  })
  assert.ok(expenses.expenses.some((expense) => expense.id === createdExpense.expense.id))
  assert.ok(expenses.expenses.every((expense) => expense.id !== temporaryExpense.expense.id))

  const memberFinalize = await requestRaw(`/api/mobile/groups/${created.group.id}/finalize`, {
    method: 'POST',
    headers: friendHeaders,
  })
  assert.equal(memberFinalize.status, 403)

  const finalized = await requestJson<GroupResponse>(`/api/mobile/groups/${created.group.id}/finalize`, {
    method: 'POST',
    headers,
  })
  assert.equal(finalized.group.status, 'FINALIZED')
  assert.ok(finalized.group.finalizedAt)
  assert.equal(finalized.group.finalizedById, owner.user.id)
  assert.deepEqual(finalized.balances?.simplifiedDebts, [])

  const finalizedAgain = await requestJson<GroupResponse>(`/api/mobile/groups/${created.group.id}/finalize`, {
    method: 'POST',
    headers,
  })
  assert.equal(finalizedAgain.group.status, 'FINALIZED')
  assert.equal(finalizedAgain.group.finalizedAt, finalized.group.finalizedAt)
  assert.equal(finalizedAgain.group.finalizedById, finalized.group.finalizedById)

  const finalizedMemberAdd = await requestRaw(`/api/mobile/groups/${created.group.id}/members`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ email: outsiderEmail }),
  })
  assert.equal(finalizedMemberAdd.status, 409)

  const finalizedExpenseCreate = await requestRaw('/api/mobile/expenses', {
    method: 'POST',
    headers,
    body: JSON.stringify({
      ...expenseBody,
      description: 'Finalized ledger snack',
      amount: 40,
      splits: [equalSplit(owner.user.id, 20), equalSplit(friend.user.id, 20)],
    }),
  })
  assert.equal(finalizedExpenseCreate.status, 409)

  const finalizedExpenseUpdate = await requestRaw(`/api/mobile/expenses/${createdExpense.expense.id}`, {
    method: 'PUT',
    headers,
    body: JSON.stringify({
      ...expenseBody,
      amount: 140,
      splits: [equalSplit(owner.user.id, 70), equalSplit(friend.user.id, 70)],
    }),
  })
  assert.equal(finalizedExpenseUpdate.status, 409)

  const finalizedExpenseDelete = await requestRaw(`/api/mobile/expenses/${createdExpense.expense.id}`, {
    method: 'DELETE',
    headers,
  })
  assert.equal(finalizedExpenseDelete.status, 409)

  console.log('Mobile ledger API flow checks passed.')
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
