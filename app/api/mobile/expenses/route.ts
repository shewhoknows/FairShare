import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { createExpenseSchema } from '@/lib/validations'
import { requireMobileSession } from '@/lib/mobile-auth'
import { mobileExpense } from '@/lib/mobile-dto'
import { formatCurrency, roundAmount } from '@/lib/utils'

export async function GET(req: NextRequest) {
  const { session, response } = await requireMobileSession(req)
  if (!session) return response

  const { searchParams } = new URL(req.url)
  const groupId = searchParams.get('groupId')
  const limit = parseInt(searchParams.get('limit') ?? '50')

  const where: any = {
    isDeleted: false,
    OR: [
      { paidById: session.user.id },
      { splits: { some: { userId: session.user.id } } },
    ],
  }

  if (groupId) {
    const membership = await prisma.groupMember.findUnique({
      where: { groupId_userId: { groupId, userId: session.user.id } },
    })
    if (!membership) return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    where.groupId = groupId
    delete where.OR
  }

  const expenses = await prisma.expense.findMany({
    where,
    include: {
      paidBy: { select: { id: true, name: true, image: true, email: true } },
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
    take: Number.isFinite(limit) ? Math.min(Math.max(limit, 1), 100) : 50,
  })

  return NextResponse.json({ expenses: expenses.map(mobileExpense) })
}

export async function POST(req: NextRequest) {
  const { session, response } = await requireMobileSession(req)
  if (!session) return response

  try {
    const body = await req.json()
    const parsed = createExpenseSchema.safeParse(body)
    if (!parsed.success) {
      return NextResponse.json({ error: parsed.error.errors[0].message }, { status: 400 })
    }

    const data = parsed.data
    if (data.groupId) {
      const membership = await prisma.groupMember.findUnique({
        where: { groupId_userId: { groupId: data.groupId, userId: session.user.id } },
      })
      if (!membership) return NextResponse.json({ error: 'Forbidden' }, { status: 403 })

      const memberIds = (
        await prisma.groupMember.findMany({
          where: { groupId: data.groupId },
          select: { userId: true },
        })
      ).map((member) => member.userId)

      for (const split of data.splits) {
        if (!memberIds.includes(split.userId)) {
          return NextResponse.json({ error: `User ${split.userId} is not a member of this group` }, { status: 400 })
        }
      }
      if (!memberIds.includes(data.paidById)) {
        return NextResponse.json({ error: 'Payer is not a member of this group' }, { status: 400 })
      }
    }

    const splitTotal = data.splits.reduce((sum, split) => sum + split.amount, 0)
    if (Math.abs(splitTotal - data.amount) > 0.02) {
      return NextResponse.json(
        { error: `Split amounts (${splitTotal.toFixed(2)}) don't match expense total (${data.amount.toFixed(2)})` },
        { status: 400 }
      )
    }

    const expense = await prisma.expense.create({
      data: {
        description: data.description,
        amount: roundAmount(data.amount),
        currency: data.currency,
        date: new Date(data.date),
        category: data.category,
        groupId: data.groupId,
        paidById: data.paidById,
        splitType: data.splitType,
        notes: data.notes,
        isRecurring: data.isRecurring,
        recurringInterval: data.recurringInterval,
        splits: {
          create: data.splits.map((split) => ({
            userId: split.userId,
            amount: roundAmount(split.amount),
            percentage: split.percentage,
            shares: split.shares,
          })),
        },
      },
      include: {
        paidBy: { select: { id: true, name: true, image: true, email: true } },
        splits: { include: { user: { select: { id: true, name: true, image: true, email: true } } } },
        group: { select: { id: true, name: true } },
      },
    })

    await prisma.activityLog.create({
      data: {
        userId: session.user.id,
        type: 'EXPENSE_CREATED',
        description: `${session.user.name} added "${data.description}" (${formatCurrency(data.amount, data.currency)})`,
        metadata: { expenseId: expense.id, groupId: data.groupId },
      },
    })

    return NextResponse.json({ expense: mobileExpense(expense) }, { status: 201 })
  } catch (error) {
    console.error('[MOBILE POST /expenses]', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}

