import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireMobileSession } from '@/lib/mobile-auth'
import { mobileExpense, mobileGroup, mobileUser } from '@/lib/mobile-dto'

export async function GET(req: NextRequest) {
  const { session, response } = await requireMobileSession(req)
  if (!session) return response

  const [expenses, transactions, groups] = await Promise.all([
    prisma.expense.findMany({
      where: {
        isDeleted: false,
        OR: [
          { paidById: session.user.id },
          { splits: { some: { userId: session.user.id } } },
        ],
      },
      include: {
        paidBy: { select: { id: true, name: true, image: true } },
        splits: {
          select: {
            userId: true,
            amount: true,
            percentage: true,
            shares: true,
            user: { select: { id: true, name: true, image: true, email: true } },
          },
        },
        group: { select: { id: true, name: true } },
      },
      orderBy: { date: 'desc' },
      take: 5,
    }),
    prisma.transaction.findMany({
      where: {
        OR: [{ senderId: session.user.id }, { receiverId: session.user.id }],
      },
    }),
    prisma.group.findMany({
      where: {
        members: { some: { userId: session.user.id } },
        isArchived: false,
      },
      include: {
        members: {
          include: { user: { select: { id: true, name: true, email: true, image: true } } },
        },
        _count: { select: { expenses: { where: { isDeleted: false } } } },
      },
      orderBy: { updatedAt: 'desc' },
      take: 5,
    }),
  ])

  const allUserIds = new Set<string>()
  for (const expense of expenses) {
    allUserIds.add(expense.paidById)
    expense.splits.forEach((split) => allUserIds.add(split.userId))
  }
  allUserIds.delete(session.user.id)

  const users = await prisma.user.findMany({
    where: { id: { in: Array.from(allUserIds) } },
    select: { id: true, name: true, email: true, image: true },
  })

  const balances = users
    .map((user) => {
      let amount = 0
      for (const expense of expenses) {
        for (const split of expense.splits) {
          if (split.userId === user.id && expense.paidById === session.user.id) {
            amount += split.amount
          }
          if (split.userId === session.user.id && expense.paidById === user.id) {
            amount -= split.amount
          }
        }
      }
      for (const transaction of transactions) {
        if (transaction.senderId === user.id && transaction.receiverId === session.user.id) {
          amount -= transaction.amount
        }
        if (transaction.senderId === session.user.id && transaction.receiverId === user.id) {
          amount += transaction.amount
        }
      }
      return { user: mobileUser(user), amount: Math.round(amount * 100) / 100 }
    })
    .filter((balance) => Math.abs(balance.amount) > 0.005)

  const totalOwed = balances
    .filter((balance) => balance.amount > 0)
    .reduce((sum, balance) => sum + balance.amount, 0)
  const totalOwe = balances
    .filter((balance) => balance.amount < 0)
    .reduce((sum, balance) => sum + Math.abs(balance.amount), 0)

  const currency =
    expenses.reduce<Record<string, number>>((counts, expense) => {
      counts[expense.currency] = (counts[expense.currency] ?? 0) + 1
      return counts
    }, {})

  return NextResponse.json({
    balances,
    totalOwed: Math.round(totalOwed * 100) / 100,
    totalOwe: Math.round(totalOwe * 100) / 100,
    currency: Object.entries(currency).sort((a, b) => b[1] - a[1])[0]?.[0] ?? 'INR',
    recentExpenses: expenses.map(mobileExpense),
    groups: groups.map(mobileGroup),
  })
}

