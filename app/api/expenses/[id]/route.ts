import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'
import { createExpenseSchema } from '@/lib/validations'
import { roundAmount, formatCurrency } from '@/lib/utils'

export async function GET(
  _req: NextRequest,
  { params }: { params: { id: string } }
) {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const expense = await prisma.expense.findUnique({
    where: { id: params.id, isDeleted: false },
    include: {
      paidBy: { select: { id: true, name: true, image: true } },
      splits: { include: { user: { select: { id: true, name: true, image: true } } } },
      group: { select: { id: true, name: true } },
      comments: {
        include: { user: { select: { id: true, name: true, image: true } } },
        orderBy: { createdAt: 'asc' },
      },
    },
  })

  if (!expense) return NextResponse.json({ error: 'Not found' }, { status: 404 })

  // Verify user has access
  const hasAccess =
    expense.paidById === session.user.id ||
    expense.splits.some((s) => s.userId === session.user.id)

  if (!hasAccess) return NextResponse.json({ error: 'Forbidden' }, { status: 403 })

  return NextResponse.json({ expense })
}

export async function PUT(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const expense = await prisma.expense.findUnique({
    where: { id: params.id, isDeleted: false },
    select: { paidById: true, groupId: true },
  })

  if (!expense) return NextResponse.json({ error: 'Not found' }, { status: 404 })
  if (expense.paidById !== session.user.id) {
    return NextResponse.json({ error: 'Only the payer can edit an expense' }, { status: 403 })
  }

  try {
    const body = await req.json()
    const parsed = createExpenseSchema.safeParse(body)
    if (!parsed.success) {
      return NextResponse.json({ error: parsed.error.errors[0].message }, { status: 400 })
    }

    const data = parsed.data

    // Validate split amounts sum to expense amount
    const splitTotal = data.splits.reduce((s, split) => s + split.amount, 0)
    if (Math.abs(splitTotal - data.amount) > 0.02) {
      return NextResponse.json(
        { error: `Split amounts (${splitTotal.toFixed(2)}) don't match expense total (${data.amount.toFixed(2)})` },
        { status: 400 }
      )
    }

    // Delete old splits and recreate
    await prisma.expenseSplit.deleteMany({ where: { expenseId: params.id } })

    const updated = await prisma.expense.update({
      where: { id: params.id },
      data: {
        description: data.description,
        amount: roundAmount(data.amount),
        currency: data.currency,
        date: new Date(data.date),
        category: data.category,
        paidById: data.paidById,
        splitType: data.splitType,
        notes: data.notes,
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
        type: 'EXPENSE_UPDATED',
        description: `${session.user.name} updated "${data.description}" (${formatCurrency(data.amount, data.currency)})`,
        metadata: { expenseId: params.id },
      },
    })

    return NextResponse.json({ expense: updated })
  } catch (error) {
    console.error('[PUT /api/expenses/[id]]', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}

export async function DELETE(
  _req: NextRequest,
  { params }: { params: { id: string } }
) {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const expense = await prisma.expense.findUnique({
    where: { id: params.id },
    select: { paidById: true, description: true, amount: true },
  })

  if (!expense) return NextResponse.json({ error: 'Not found' }, { status: 404 })
  if (expense.paidById !== session.user.id) {
    return NextResponse.json({ error: 'Only the payer can delete an expense' }, { status: 403 })
  }

  await prisma.expense.update({
    where: { id: params.id },
    data: { isDeleted: true },
  })

  await prisma.activityLog.create({
    data: {
      userId: session.user.id,
      type: 'EXPENSE_DELETED',
      description: `${session.user.name} deleted "${expense.description}"`,
      metadata: { expenseId: params.id },
    },
  })

  return NextResponse.json({ success: true })
}
