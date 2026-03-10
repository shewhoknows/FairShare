import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'
import { addCommentSchema } from '@/lib/validations'

export async function POST(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const session = await getServerSession(authOptions)
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const expense = await prisma.expense.findUnique({
    where: { id: params.id, isDeleted: false },
    include: { splits: { select: { userId: true } } },
  })

  if (!expense) return NextResponse.json({ error: 'Not found' }, { status: 404 })

  const hasAccess =
    expense.paidById === session.user.id ||
    expense.splits.some((s) => s.userId === session.user.id)

  if (!hasAccess) return NextResponse.json({ error: 'Forbidden' }, { status: 403 })

  const body = await req.json()
  const parsed = addCommentSchema.safeParse(body)
  if (!parsed.success) {
    return NextResponse.json({ error: parsed.error.errors[0].message }, { status: 400 })
  }

  const comment = await prisma.comment.create({
    data: {
      content: parsed.data.content,
      expenseId: params.id,
      userId: session.user.id,
    },
    include: { user: { select: { id: true, name: true, image: true } } },
  })

  return NextResponse.json({ comment }, { status: 201 })
}
