import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireMobileSession } from '@/lib/mobile-auth'
import { mobileGroup } from '@/lib/mobile-dto'
import { getGroupNetBalances, getSimplifiedDebts } from '@/lib/balance-calculator'

async function getGroupWithLedger(groupId: string) {
  return prisma.group.findUnique({
    where: { id: groupId },
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
}

function groupResponse(group: NonNullable<Awaited<ReturnType<typeof getGroupWithLedger>>>) {
  const members = group.members.map((member) => member.user)
  const netBalances = getGroupNetBalances(group.expenses, group.transactions, members)
  const simplifiedDebts = getSimplifiedDebts(group.expenses, group.transactions, members)

  return {
    group: mobileGroup(group),
    balances: { netBalances, simplifiedDebts },
  }
}

export async function POST(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const { session, response } = await requireMobileSession(req)
  if (!session) return response

  const membership = await prisma.groupMember.findUnique({
    where: { groupId_userId: { groupId: params.id, userId: session.user.id } },
    select: { role: true },
  })
  if (!membership || membership.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
  }

  await prisma.group.updateMany({
    where: { id: params.id, finalizedAt: null },
    data: {
      finalizedAt: new Date(),
      finalizedById: session.user.id,
    },
  })

  const group = await getGroupWithLedger(params.id)
  if (!group) return NextResponse.json({ error: 'Group not found' }, { status: 404 })

  return NextResponse.json(groupResponse(group))
}
