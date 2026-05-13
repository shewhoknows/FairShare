import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireMobileSession } from '@/lib/mobile-auth'
import { mobileGroup } from '@/lib/mobile-dto'
import { getGroupNetBalances, getSimplifiedDebts } from '@/lib/balance-calculator'

export async function GET(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const { session, response } = await requireMobileSession(req)
  if (!session) return response

  const membership = await prisma.groupMember.findUnique({
    where: { groupId_userId: { groupId: params.id, userId: session.user.id } },
  })
  if (!membership) return NextResponse.json({ error: 'Forbidden' }, { status: 403 })

  const group = await prisma.group.findUnique({
    where: { id: params.id },
    include: {
      members: {
        include: { user: { select: { id: true, name: true, image: true, email: true } } },
        orderBy: { joinedAt: 'asc' },
      },
      expenses: {
        where: { isDeleted: false },
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
      },
      transactions: {
        include: {
          sender: { select: { id: true, name: true, image: true } },
          receiver: { select: { id: true, name: true, image: true } },
        },
        orderBy: { createdAt: 'desc' },
      },
    },
  })

  if (!group) return NextResponse.json({ error: 'Group not found' }, { status: 404 })

  const members = group.members.map((member) => member.user)
  const netBalances = getGroupNetBalances(group.expenses, group.transactions, members)
  const simplifiedDebts = getSimplifiedDebts(group.expenses, group.transactions, members)

  return NextResponse.json({
    group: mobileGroup(group),
    balances: { netBalances, simplifiedDebts },
  })
}

