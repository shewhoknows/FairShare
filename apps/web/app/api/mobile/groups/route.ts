import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { createGroupSchema } from '@/lib/validations'
import { requireMobileSession } from '@/lib/mobile-auth'
import { mobileGroup } from '@/lib/mobile-dto'

export async function GET(req: NextRequest) {
  const { session, response } = await requireMobileSession(req)
  if (!session) return response

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

  return NextResponse.json({ groups: groups.map(mobileGroup) })
}

export async function POST(req: NextRequest) {
  const { session, response } = await requireMobileSession(req)
  if (!session) return response

  try {
    const body = await req.json()
    const parsed = createGroupSchema.safeParse(body)
    if (!parsed.success) {
      return NextResponse.json({ error: parsed.error.errors[0].message }, { status: 400 })
    }

    const { name, description, currency, category } = parsed.data
    const group = await prisma.group.create({
      data: {
        name,
        description,
        currency,
        category,
        members: { create: { userId: session.user.id, role: 'ADMIN' } },
      },
      include: {
        members: {
          include: { user: { select: { id: true, name: true, image: true, email: true } } },
        },
        _count: { select: { expenses: { where: { isDeleted: false } } } },
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

    return NextResponse.json({ group: mobileGroup(group) }, { status: 201 })
  } catch (error) {
    console.error('[MOBILE POST /groups]', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}

