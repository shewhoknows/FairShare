import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'
import { createGroupSchema } from '@/lib/validations'

export async function GET() {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const groups = await prisma.group.findMany({
    where: {
      members: { some: { userId: session.user.id } },
      isArchived: false,
    },
    include: {
      members: {
        include: { user: { select: { id: true, name: true, image: true, email: true } } },
      },
      _count: { select: { expenses: { where: { isDeleted: false } } } },
    },
    orderBy: { updatedAt: 'desc' },
  })

  return NextResponse.json({ groups })
}

export async function POST(req: NextRequest) {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  try {
    const body = await req.json()
    const parsed = createGroupSchema.safeParse(body)

    if (!parsed.success) {
      return NextResponse.json(
        { error: parsed.error.errors[0].message },
        { status: 400 }
      )
    }

    const { name, description, currency, category } = parsed.data

    const group = await prisma.group.create({
      data: {
        name,
        description,
        currency,
        category,
        members: {
          create: { userId: session.user.id, role: 'ADMIN' },
        },
      },
      include: {
        members: {
          include: { user: { select: { id: true, name: true, image: true, email: true } } },
        },
      },
    })

    await prisma.activityLog.create({
      data: {
        userId: session.user.id,
        type: 'GROUP_CREATED',
        description: `${session.user.name} created the group "${name}"`,
        metadata: { groupId: group.id },
      },
    })

    return NextResponse.json({ group }, { status: 201 })
  } catch (error) {
    console.error('[POST /api/groups]', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
