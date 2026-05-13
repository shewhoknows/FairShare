import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'
import { z } from 'zod'

const addFriendSchema = z.object({
  email: z.string().email(),
})

export async function GET() {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const friendships = await prisma.friendship.findMany({
    where: {
      OR: [{ fromId: session.user.id }, { toId: session.user.id }],
      status: 'ACCEPTED',
    },
    include: {
      from: { select: { id: true, name: true, email: true, image: true } },
      to:   { select: { id: true, name: true, email: true, image: true } },
    },
  })

  const friends = friendships.map((f) =>
    f.fromId === session.user.id ? f.to : f.from
  )

  return NextResponse.json({ friends })
}

export async function POST(req: NextRequest) {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const body = await req.json()
  const parsed = addFriendSchema.safeParse(body)
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.errors[0].message }, { status: 400 })
  }

  const { email } = parsed.data

  if (email === session.user.email) {
    return NextResponse.json({ error: "You can't add yourself as a friend" }, { status: 400 })
  }

  const targetUser = await prisma.user.findUnique({
    where: { email },
    select: { id: true, name: true, email: true, image: true },
  })

  if (!targetUser) {
    return NextResponse.json({ error: 'No user found with that email' }, { status: 404 })
  }

  // Check if friendship already exists
  const existing = await prisma.friendship.findFirst({
    where: {
      OR: [
        { fromId: session.user.id, toId: targetUser.id },
        { fromId: targetUser.id, toId: session.user.id },
      ],
    },
  })

  if (existing) {
    if (existing.status === 'ACCEPTED') {
      return NextResponse.json({ error: 'Already friends' }, { status: 409 })
    }
    if (existing.status === 'PENDING') {
      return NextResponse.json({ error: 'Friend request already sent' }, { status: 409 })
    }
  }

  const friendship = await prisma.friendship.create({
    data: {
      fromId: session.user.id,
      toId: targetUser.id,
      status: 'ACCEPTED', // Auto-accept for simplicity
    },
    include: {
      to: { select: { id: true, name: true, email: true, image: true } },
    },
  })

  await prisma.activityLog.create({
    data: {
      userId: session.user.id,
      type: 'FRIEND_ADDED',
      description: `${session.user.name} added ${targetUser.name ?? targetUser.email} as a friend`,
    },
  })

  return NextResponse.json({ friend: friendship.to }, { status: 201 })
}
