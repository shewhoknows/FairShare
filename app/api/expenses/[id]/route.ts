import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'

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
