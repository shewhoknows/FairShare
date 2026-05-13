/**
 * Simplify Debts – Greedy algorithm
 *
 * Given a set of pairwise balances (who owes whom), produces the minimal
 * number of transactions that settles all debts.
 *
 * Algorithm:
 *  1. Compute net balance for every participant
 *     (positive = they're owed money, negative = they owe money)
 *  2. Greedily match the largest creditor with the largest debtor
 *  3. Record a transaction and reduce balances accordingly
 *  4. Repeat until all balances are ~0
 */

export interface DebtTransaction {
  fromId: string
  toId: string
  amount: number
}

/**
 * @param netBalances  Map<userId, net> where positive = owed money, negative = owes money
 * @returns            Minimal list of transactions to settle all debts
 */
export function simplifyDebts(
  netBalances: Map<string, number>
): DebtTransaction[] {
  const EPS = 0.005 // ignore sub-cent rounding noise

  // Deep-copy so we don't mutate the caller's map
  const balances = new Map<string, number>()
  Array.from(netBalances.entries()).forEach(([id, bal]) => {
    const rounded = Math.round(bal * 100) / 100
    if (Math.abs(rounded) > EPS) balances.set(id, rounded)
  })

  const creditors: { id: string; amount: number }[] = []
  const debtors: { id: string; amount: number }[] = []

  Array.from(balances.entries()).forEach(([id, bal]) => {
    if (bal > EPS) creditors.push({ id, amount: bal })
    else if (bal < -EPS) debtors.push({ id, amount: -bal }) // store as positive
  })

  // Sort descending so we always process the largest first
  creditors.sort((a, b) => b.amount - a.amount)
  debtors.sort((a, b) => b.amount - a.amount)

  const transactions: DebtTransaction[] = []

  let ci = 0
  let di = 0

  while (ci < creditors.length && di < debtors.length) {
    const creditor = creditors[ci]
    const debtor = debtors[di]

    const transfer = Math.min(creditor.amount, debtor.amount)
    const rounded = Math.round(transfer * 100) / 100

    if (rounded > EPS) {
      transactions.push({
        fromId: debtor.id,
        toId: creditor.id,
        amount: rounded,
      })
    }

    creditor.amount -= transfer
    debtor.amount -= transfer

    if (creditor.amount < EPS) ci++
    if (debtor.amount < EPS) di++
  }

  return transactions
}

/**
 * Build a net-balance map from a list of expenses + settlements.
 *
 * Each expense contributes:
 *   payer gets credit equal to sum of other participants' splits
 *   each participant (except payer) has a debit equal to their split amount
 *
 * Each settlement reduces the corresponding debt.
 */
export function buildNetBalances(
  expenses: {
    paidById: string
    splits: { userId: string; amount: number }[]
  }[],
  transactions: { senderId: string; receiverId: string; amount: number }[]
): Map<string, number> {
  const net = new Map<string, number>()

  const add = (id: string, delta: number) =>
    net.set(id, (net.get(id) ?? 0) + delta)

  for (const expense of expenses) {
    for (const split of expense.splits) {
      if (split.userId !== expense.paidById) {
        add(expense.paidById, split.amount)  // payer is owed
        add(split.userId, -split.amount)     // participant owes
      }
    }
  }

  for (const txn of transactions) {
    // senderId paid receiverId → reduces receiverId's credit
    add(txn.receiverId, -txn.amount)
    add(txn.senderId, txn.amount)
  }

  return net
}

/**
 * Calculate pairwise balances within a set of expenses.
 * Returns Map<`${userId1}-${userId2}`, amount> where positive means user1 owes user2.
 */
export function calculatePairwiseBalances(
  expenses: {
    paidById: string
    splits: { userId: string; amount: number }[]
  }[],
  transactions: { senderId: string; receiverId: string; amount: number }[]
): Map<string, number> {
  // balance[a][b] = net amount a owes b (can be negative, meaning b owes a)
  const raw = new Map<string, number>()

  const key = (a: string, b: string) =>
    a < b ? `${a}-${b}` : `${b}-${a}`

  const sign = (a: string, b: string) => (a < b ? 1 : -1)

  const addPair = (debtor: string, creditor: string, amount: number) => {
    const k = key(debtor, creditor)
    const s = sign(debtor, creditor) // +1 if debtor is first in key
    raw.set(k, (raw.get(k) ?? 0) + amount * s)
  }

  for (const expense of expenses) {
    for (const split of expense.splits) {
      if (split.userId !== expense.paidById) {
        addPair(split.userId, expense.paidById, split.amount)
      }
    }
  }

  for (const txn of transactions) {
    // senderId paid receiverId → reduces that debt
    addPair(txn.receiverId, txn.senderId, txn.amount)
  }

  return raw
}
