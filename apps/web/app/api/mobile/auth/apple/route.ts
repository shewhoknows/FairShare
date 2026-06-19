import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { appleSignInSchema } from '@/lib/validations'
import { createMobileToken } from '@/lib/mobile-auth'
import { mobileUser } from '@/lib/mobile-dto'
import { syntheticEmailForAppleSubject } from '@/lib/mobile-auth-identifiers'
import { verifyAppleIdentityToken } from '@/lib/apple-id-token'

const userSelect = {
  id: true,
  name: true,
  email: true,
  image: true,
  phone: true,
  preferredName: true,
  upiID: true,
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json()
    const parsed = appleSignInSchema.safeParse(body)
    if (!parsed.success) {
      return NextResponse.json({ error: parsed.error.errors[0].message }, { status: 400 })
    }

    const identity = await verifyAppleIdentityToken(parsed.data.identityToken, parsed.data.nonce)
    const email = identity.email ?? parsed.data.email

    const linkedAccount = await prisma.account.findUnique({
      where: {
        provider_providerAccountId: {
          provider: 'apple',
          providerAccountId: identity.subject,
        },
      },
      include: { user: true },
    })

    if (linkedAccount?.user) {
      const user = await prisma.user.findUniqueOrThrow({
        where: { id: linkedAccount.user.id },
        select: userSelect,
      })
      return NextResponse.json({ token: createMobileToken(user), user: mobileUser(user) })
    }

    const user = await findOrCreateAppleUser(
      identity.subject,
      email,
      parsed.data.name ?? parsed.data.fullName
    )
    await prisma.account.create({
      data: {
        userId: user.id,
        type: 'oauth',
        provider: 'apple',
        providerAccountId: identity.subject,
      },
    })

    return NextResponse.json({ token: createMobileToken(user), user: mobileUser(user) })
  } catch (error) {
    console.error('[MOBILE APPLE AUTH]', error)
    return NextResponse.json({ error: 'Apple sign-in failed' }, { status: 401 })
  }
}

async function findOrCreateAppleUser(subject: string, email?: string, name?: string) {
  if (email) {
    const existing = await prisma.user.findUnique({ where: { email }, select: userSelect })
    if (existing) return existing
  }

  return prisma.user.create({
    data: {
      email: email ?? syntheticEmailForAppleSubject(subject),
      emailVerified: email ? new Date() : null,
      name: name ?? null,
      preferredName: name ?? null,
      image: `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(subject)}`,
    },
    select: userSelect,
  })
}
