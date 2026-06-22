import { NextRequest, NextResponse } from 'next/server'
import { z } from 'zod'
import { prisma } from '@/lib/prisma'
import { requireMobileSession } from '@/lib/mobile-auth'
import { mobileUser } from '@/lib/mobile-dto'

const lookupSchema = z.object({
  email: z.string().email(),
})

export async function GET(req: NextRequest) {
  const { session, response } = await requireMobileSession(req)
  if (!session) return response

  const { searchParams } = new URL(req.url)
  const parsed = lookupSchema.safeParse({
    email: searchParams.get('email')?.trim().toLowerCase() ?? '',
  })

  if (!parsed.success) {
    return NextResponse.json({ exists: false, user: null })
  }

  const user = await prisma.user.findUnique({
    where: { email: parsed.data.email },
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

  if (!user || user.id === session.user.id) {
    return NextResponse.json({ exists: false, user: null })
  }

  return NextResponse.json({ exists: true, user: mobileUser(user) })
}
