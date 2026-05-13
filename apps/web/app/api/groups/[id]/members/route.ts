import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'
import { addMemberSchema } from '@/lib/validations'

export async function POST(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  // Only admins or members can add people
  const myMembership = await prisma.groupMember.findUnique({
    where: { groupId_userId: { groupId: params.id, userId: session.user.id } },
  })
  if (!myMembership) return NextResponse.json({ error: 'Forbidden' }, { status: 403 })

  const body = await req.json()
  const parsed = addMemberSchema.safeParse(body)
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.errors[0].message }, { status: 400 })
  }

  const { email } = parsed.data

  const userToAdd = await prisma.user.findUnique({
    where: { email },
    select: { id: true, name: true, email: true, image: true },
  })

  if (!userToAdd) {
    return NextResponse.json({ error: 'No user found with that email address' }, { status: 404 })
  }

  // Check if already a member
  const existing = await prisma.groupMember.findUnique({
    where: { groupId_userId: { groupId: params.id, userId: userToAdd.id } },
  })
  if (existing) {
    return NextResponse.json({ error: 'User is already a member of this group' }, { status: 409 })
  }

  const member = await prisma.groupMember.create({
    data: { groupId: params.id, userId: userToAdd.id, role: 'MEMBER' },
    include: { user: { select: { id: true, name: true, image: true, email: true } } },
  })

  await prisma.activityLog.create({
    data: {
      userId: session.user.id,
      type: 'GROUP_JOINED',
      description: `${userToAdd.name ?? userToAdd.email} joined the group`,
      metadata: { groupId: params.id },
    },
  })

  return NextResponse.json({ member }, { status: 201 })
}

export async function DELETE(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { searchParams } = new URL(req.url)
  const userId = searchParams.get('userId')
  if (!userId) return NextResponse.json({ error: 'userId required' }, { status: 400 })

  const myMembership = await prisma.groupMember.findUnique({
    where: { groupId_userId: { groupId: params.id, userId: session.user.id } },
  })

  // Can remove yourself, or admin can remove anyone
  if (!myMembership || (userId !== session.user.id && myMembership.role !== 'ADMIN')) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
  }

  await prisma.groupMember.delete({
    where: { groupId_userId: { groupId: params.id, userId } },
  })

  return NextResponse.json({ success: true })
}
