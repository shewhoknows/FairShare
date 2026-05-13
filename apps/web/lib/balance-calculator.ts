import { buildNetBalances, simplifyDebts, DebtTransaction } from './algorithms/simplify-debts'

export interface UserBalance {
  userId: string
  name: string | null
  image: string | null
  netAmount: number   // positive = owed money; negative = owes money
}

export interface PairBalance {
  fromUserId: string
  fromName: string | null
  toUserId: string
  toName: string | null
  amount: number      // always positive; "from" owes "to" this much
}

type Expense = {
  paidById: string
  splits: { userId: string; amount: number }[]
}

type Transaction = {
  senderId: string
  receiverId: string
  amount: number
}

type UserInfo = {
  id: string
  name: string | null
  image: string | null
}

/**
 * Returns each member's net balance for a group.
 */
export function getGroupNetBalances(
  expenses: Expense[],
  transactions: Transaction[],
  members: UserInfo[]
): UserBalance[] {
  const net = buildNetBalances(expenses, transactions)

  return members.map((m) => ({
    userId: m.id,
    name: m.name,
    image: m.image,
    netAmount: Math.round((net.get(m.id) ?? 0) * 100) / 100,
  }))
}

/**
 * Returns the minimal set of payments to settle all group debts.
 */
export function getSimplifiedDebts(
  expenses: Expense[],
  transactions: Transaction[],
  members: UserInfo[]
): (DebtTransaction & { fromName: string | null; toName: string | null })[] {
  const net = buildNetBalances(expenses, transactions)
  const simplified = simplifyDebts(net)

  const userMap = new Map(members.map((m) => [m.id, m]))

  return simplified.map((t) => ({
    ...t,
    fromName: userMap.get(t.fromId)?.name ?? null,
    toName:   userMap.get(t.toId)?.name ?? null,
  }))
}

/**
 * Returns pairwise "X owes Y" balances across all expenses (non-simplified).
 * Useful for the "between two friends" view.
 */
export function getPairwiseDebts(
  expenses: Expense[],
  transactions: Transaction[],
  members: UserInfo[]
): PairBalance[] {
  const net = buildNetBalances(expenses, transactions)
  const simplified = simplifyDebts(net)

  const userMap = new Map(members.map((m) => [m.id, m]))

  return simplified
    .filter((t) => t.amount > 0.005)
    .map((t) => ({
      fromUserId: t.fromId,
      fromName: userMap.get(t.fromId)?.name ?? null,
      toUserId: t.toId,
      toName: userMap.get(t.toId)?.name ?? null,
      amount: t.amount,
    }))
}
