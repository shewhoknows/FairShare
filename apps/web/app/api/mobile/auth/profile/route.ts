import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireMobileSession } from '@/lib/mobile-auth'
import { mobileUser } from '@/lib/mobile-dto'
import { completeMobileProfileSchema } from '@/lib/validations'

export async function PUT(req: NextRequest) {
  const { session, response } = await requireMobileSession(req)
  if (!session) return response

  try {
    const body = await req.json()
    const parsed = completeMobileProfileSchema.safeParse(body)
    if (!parsed.success) {
      return NextResponse.json({ error: parsed.error.errors[0].message }, { status: 400 })
    }

    const user = await prisma.user.update({
      where: { id: session.user.id },
      data: parsed.data,
      select: {
        id: true,
        name: true,
        email: true,
        image: true,
        phone: true,
        preferredName: true,
        upiID: true,
      },
    })

    return NextResponse.json({ user: mobileUser(user) })
  } catch (error) {
    console.error('[MOBILE PROFILE]', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
