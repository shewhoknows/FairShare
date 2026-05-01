import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { createTransactionSchema } from '@/lib/validations'
import { requireMobileSession } from '@/lib/mobile-auth'
import { formatCurrency } from '@/lib/utils'

export async function POST(req: NextRequest) {
  const { session, response } = await requireMobileSession(req)
  if (!session) return response

  try {
    const body = await req.json()
    const parsed = createTransactionSchema.safeParse(body)
    if (!parsed.success) {
      return NextResponse.json({ error: parsed.error.errors[0].message }, { status: 400 })
    }

    const { receiverId: rawReceiverId, senderId: rawSenderId, amount, currency, groupId, note } = parsed.data
    let senderId: string
    let receiverId: string

    if (rawSenderId) {
      senderId = rawSenderId
      receiverId = session.user.id
    } else if (rawReceiverId) {
      senderId = session.user.id
      receiverId = rawReceiverId
    } else {
      return NextResponse.json({ error: 'Either receiverId or senderId is required' }, { status: 400 })
    }

    if (senderId === receiverId) {
      return NextResponse.json({ error: "You can't settle with yourself" }, { status: 400 })
    }

    if (groupId) {
      const membership = await prisma.groupMember.findUnique({
        where: { groupId_userId: { groupId, userId: session.user.id } },
      })
      if (!membership) return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    const [sender, receiver] = await Promise.all([
      prisma.user.findUnique({ where: { id: senderId }, select: { id: true, name: true } }),
      prisma.user.findUnique({ where: { id: receiverId }, select: { id: true, name: true } }),
    ])
    if (!sender) return NextResponse.json({ error: 'Sender not found' }, { status: 404 })
    if (!receiver) return NextResponse.json({ error: 'Receiver not found' }, { status: 404 })

    const transaction = await prisma.transaction.create({
      data: {
        senderId,
        receiverId,
        amount,
        currency: currency ?? 'INR',
        groupId,
        note,
      },
      include: {
        sender: { select: { id: true, name: true, image: true, email: true } },
        receiver: { select: { id: true, name: true, image: true, email: true } },
        group: { select: { id: true, name: true } },
      },
    })

    await prisma.activityLog.create({
      data: {
        userId: session.user.id,
        type: 'PAYMENT_MADE',
        description: `${sender.name} paid ${receiver.name} ${formatCurrency(amount, currency ?? 'INR')}`,
        metadata: { transactionId: transaction.id, groupId },
      },
    })

    return NextResponse.json({
      transaction: {
        id: transaction.id,
        amount: transaction.amount,
        currency: transaction.currency,
        note: transaction.note,
        group: transaction.group,
        sender: transaction.sender,
        receiver: transaction.receiver,
        createdAt: transaction.createdAt.toISOString(),
      },
    }, { status: 201 })
  } catch (error) {
    console.error('[MOBILE POST /transactions]', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}

