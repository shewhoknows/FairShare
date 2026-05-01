import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { createExpenseSchema } from '@/lib/validations'
import { requireMobileSession } from '@/lib/mobile-auth'
import { mobileExpense } from '@/lib/mobile-dto'
import { formatCurrency, roundAmount } from '@/lib/utils'

async function findAccessibleExpense(id: string, userId: string) {
  const expense = await prisma.expense.findUnique({
    where: { id, isDeleted: false },
    include: {
      paidBy: { select: { id: true, name: true, image: true, email: true } },
      splits: { include: { user: { select: { id: true, name: true, image: true, email: true } } } },
      group: { select: { id: true, name: true } },
    },
  })
  if (!expense) return { expense: null, response: NextResponse.json({ error: 'Not found' }, { status: 404 }) }

  const hasAccess =
    expense.paidById === userId ||
    expense.splits.some((split) => split.userId === userId)
  if (!hasAccess) {
    return { expense: null, response: NextResponse.json({ error: 'Forbidden' }, { status: 403 }) }
  }
  return { expense, response: null }
}

export async function GET(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const { session, response } = await requireMobileSession(req)
  if (!session) return response

  const { expense, response: expenseResponse } = await findAccessibleExpense(params.id, session.user.id)
  if (!expense) return expenseResponse
  return NextResponse.json({ expense: mobileExpense(expense) })
}

export async function PUT(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const { session, response } = await requireMobileSession(req)
  if (!session) return response

  const existing = await prisma.expense.findUnique({
    where: { id: params.id, isDeleted: false },
    select: { paidById: true },
  })
  if (!existing) return NextResponse.json({ error: 'Not found' }, { status: 404 })
  if (existing.paidById !== session.user.id) {
    return NextResponse.json({ error: 'Only the payer can edit an expense' }, { status: 403 })
  }

  try {
    const body = await req.json()
    const parsed = createExpenseSchema.safeParse(body)
    if (!parsed.success) {
      return NextResponse.json({ error: parsed.error.errors[0].message }, { status: 400 })
    }

    const data = parsed.data
    const splitTotal = data.splits.reduce((sum, split) => sum + split.amount, 0)
    if (Math.abs(splitTotal - data.amount) > 0.02) {
      return NextResponse.json(
        { error: `Split amounts (${splitTotal.toFixed(2)}) don't match expense total (${data.amount.toFixed(2)})` },
        { status: 400 }
      )
    }

    await prisma.expenseSplit.deleteMany({ where: { expenseId: params.id } })
    const updated = await prisma.expense.update({
      where: { id: params.id },
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
        type: 'EXPENSE_UPDATED',
        description: `${session.user.name} updated "${data.description}" (${formatCurrency(data.amount, data.currency)})`,
        metadata: { expenseId: params.id },
      },
    })

    return NextResponse.json({ expense: mobileExpense(updated) })
  } catch (error) {
    console.error('[MOBILE PUT /expenses/[id]]', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}

export async function DELETE(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const { session, response } = await requireMobileSession(req)
  if (!session) return response

  const expense = await prisma.expense.findUnique({
    where: { id: params.id },
    select: { paidById: true, description: true },
  })
  if (!expense) return NextResponse.json({ error: 'Not found' }, { status: 404 })
  if (expense.paidById !== session.user.id) {
    return NextResponse.json({ error: 'Only the payer can delete an expense' }, { status: 403 })
  }

  await prisma.expense.update({ where: { id: params.id }, data: { isDeleted: true } })
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

