import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'
import { createExpenseSchema } from '@/lib/validations'
import { roundAmount } from '@/lib/utils'

export async function GET(req: NextRequest) {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

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
    // Verify membership
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
      paidBy: { select: { id: true, name: true, image: true } },
      splits: { include: { user: { select: { id: true, name: true, image: true } } } },
      group: { select: { id: true, name: true } },
    },
    orderBy: { date: 'desc' },
    take: limit,
  })

  return NextResponse.json({ expenses })
}

export async function POST(req: NextRequest) {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  try {
    const body = await req.json()
    const parsed = createExpenseSchema.safeParse(body)

    if (!parsed.success) {
      return NextResponse.json(
        { error: parsed.error.errors[0].message },
        { status: 400 }
      )
    }

    const data = parsed.data

    // Validate group membership if groupId provided
    if (data.groupId) {
      const membership = await prisma.groupMember.findUnique({
        where: { groupId_userId: { groupId: data.groupId, userId: session.user.id } },
      })
      if (!membership) return NextResponse.json({ error: 'Forbidden' }, { status: 403 })

      // Validate all split users are group members
      const memberIds = (
        await prisma.groupMember.findMany({
          where: { groupId: data.groupId },
          select: { userId: true },
        })
      ).map((m) => m.userId)

      for (const split of data.splits) {
        if (!memberIds.includes(split.userId)) {
          return NextResponse.json(
            { error: `User ${split.userId} is not a member of this group` },
            { status: 400 }
          )
        }
      }
    }

    // Validate split amounts sum to expense amount
    const splitTotal = data.splits.reduce((s, split) => s + split.amount, 0)
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
          create: data.splits.map((s) => ({
            userId: s.userId,
            amount: roundAmount(s.amount),
            percentage: s.percentage,
            shares: s.shares,
          })),
        },
      },
      include: {
        paidBy: { select: { id: true, name: true, image: true } },
        splits: { include: { user: { select: { id: true, name: true, image: true } } } },
        group: { select: { id: true, name: true } },
      },
    })

    await prisma.activityLog.create({
      data: {
        userId: session.user.id,
        type: 'EXPENSE_CREATED',
        description: `${session.user.name} added "${data.description}" ($${data.amount.toFixed(2)})`,
        metadata: { expenseId: expense.id, groupId: data.groupId },
      },
    })

    return NextResponse.json({ expense }, { status: 201 })
  } catch (error) {
    console.error('[POST /api/expenses]', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
