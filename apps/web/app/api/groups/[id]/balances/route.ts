import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'
import { getGroupNetBalances, getSimplifiedDebts } from '@/lib/balance-calculator'

export async function GET(
  _req: NextRequest,
  { params }: { params: { id: string } }
) {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const membership = await prisma.groupMember.findUnique({
    where: { groupId_userId: { groupId: params.id, userId: session.user.id } },
  })
  if (!membership) return NextResponse.json({ error: 'Forbidden' }, { status: 403 })

  const [expenses, transactions, members] = await Promise.all([
    prisma.expense.findMany({
      where: { groupId: params.id, isDeleted: false },
      include: { splits: true },
    }),
    prisma.transaction.findMany({ where: { groupId: params.id } }),
    prisma.groupMember.findMany({
      where: { groupId: params.id },
      include: { user: { select: { id: true, name: true, image: true } } },
    }),
  ])

  const memberUsers = members.map((m) => m.user)

  const netBalances = getGroupNetBalances(expenses, transactions, memberUsers)
  const simplifiedDebts = getSimplifiedDebts(expenses, transactions, memberUsers)

  return NextResponse.json({ netBalances, simplifiedDebts })
}
