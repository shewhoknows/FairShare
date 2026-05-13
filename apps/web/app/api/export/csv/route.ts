import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'

function escapeCSV(val: string | number | null | undefined): string {
  const str = String(val ?? '')
  if (str.includes(',') || str.includes('"') || str.includes('\n')) {
    return `"${str.replace(/"/g, '""')}"`
  }
  return str
}

export async function GET(req: NextRequest) {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { searchParams } = new URL(req.url)
  const groupId = searchParams.get('groupId')

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
      paidBy: { select: { name: true, email: true } },
      group:  { select: { name: true } },
      splits: { include: { user: { select: { name: true, email: true } } } },
    },
    orderBy: { date: 'desc' },
  })

  const headers = [
    'Date',
    'Description',
    'Category',
    'Amount',
    'Currency',
    'Paid By',
    'Group',
    'Split Type',
    'Your Share',
    'Notes',
  ]

  const rows = expenses.map((e) => {
    const yourSplit = e.splits.find((s) => s.user.email === session.user.email)
    return [
      new Date(e.date).toISOString().split('T')[0],
      e.description,
      e.category,
      e.amount.toFixed(2),
      e.currency,
      e.paidBy.name ?? e.paidBy.email,
      e.group?.name ?? 'Non-group',
      e.splitType,
      yourSplit ? yourSplit.amount.toFixed(2) : '0.00',
      e.notes ?? '',
    ].map(escapeCSV)
  })

  const csv = [headers.join(','), ...rows.map((r) => r.join(','))].join('\n')

  return new NextResponse(csv, {
    status: 200,
    headers: {
      'Content-Type': 'text/csv',
      'Content-Disposition': `attachment; filename="fairshare-export-${Date.now()}.csv"`,
    },
  })
}
