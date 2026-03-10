import { NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'
import { buildNetBalances, simplifyDebts } from '@/lib/algorithms/simplify-debts'

export async function GET() {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  // Get all expenses the user is involved in
  const expenses = await prisma.expense.findMany({
    where: {
      isDeleted: false,
      OR: [
        { paidById: session.user.id },
        { splits: { some: { userId: session.user.id } } },
      ],
    },
    include: {
      splits: true,
      paidBy: { select: { id: true, name: true, image: true } },
    },
  })

  const transactions = await prisma.transaction.findMany({
    where: {
      OR: [{ senderId: session.user.id }, { receiverId: session.user.id }],
    },
  })

  // Build net balances from the user's perspective
  const net = buildNetBalances(expenses, transactions)

  // Get all involved users
  const allUserIds = new Set<string>()
  for (const expense of expenses) {
    allUserIds.add(expense.paidById)
    expense.splits.forEach((s) => allUserIds.add(s.userId))
  }
  allUserIds.delete(session.user.id)

  const users = await prisma.user.findMany({
    where: { id: { in: Array.from(allUserIds) } },
    select: { id: true, name: true, image: true, email: true },
  })

  const userMap = new Map(users.map((u) => [u.id, u]))

  // Build pairwise balances just between current user and each other user
  const balances = users
    .map((u) => {
      // positive = current user is owed by u; negative = current user owes u
      const owedByCurrent = net.get(session.user.id) ?? 0
      // Actually compute from expenses directly for this pair
      let amount = 0
      for (const expense of expenses) {
        for (const split of expense.splits) {
          if (split.userId === u.id && expense.paidById === session.user.id) {
            amount += split.amount // u owes current user
          }
          if (split.userId === session.user.id && expense.paidById === u.id) {
            amount -= split.amount // current user owes u
          }
        }
      }
      // Adjust for transactions
      for (const txn of transactions) {
        if (txn.senderId === u.id && txn.receiverId === session.user.id) {
          amount -= txn.amount // u paid current user → reduces what u owes
        }
        if (txn.senderId === session.user.id && txn.receiverId === u.id) {
          amount += txn.amount // current user paid u → reduces what user owes
        }
      }
      return { user: u, amount: Math.round(amount * 100) / 100 }
    })
    .filter((b) => Math.abs(b.amount) > 0.005)

  const totalOwed = balances
    .filter((b) => b.amount > 0)
    .reduce((sum, b) => sum + b.amount, 0)

  const totalOwe = balances
    .filter((b) => b.amount < 0)
    .reduce((sum, b) => sum + Math.abs(b.amount), 0)

  return NextResponse.json({ balances, totalOwed, totalOwe })
}
