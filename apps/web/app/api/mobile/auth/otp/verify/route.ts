import crypto from 'crypto'
import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { otpVerifySchema } from '@/lib/validations'
import { createMobileToken } from '@/lib/mobile-auth'
import { mobileUser } from '@/lib/mobile-dto'
import { hashOTP, syntheticEmailForPhone } from '@/lib/mobile-auth-identifiers'

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
    const parsed = otpVerifySchema.safeParse(body)
    if (!parsed.success) {
      return NextResponse.json({ error: parsed.error.errors[0].message }, { status: 400 })
    }

    const challenge = await prisma.mobileOTPChallenge.findUnique({
      where: { id: parsed.data.challengeId },
    })

    if (!challenge || challenge.consumedAt || challenge.expiresAt.getTime() < Date.now()) {
      return NextResponse.json({ error: 'Code expired. Request a new one.' }, { status: 400 })
    }

    if (challenge.attempts >= 5) {
      return NextResponse.json({ error: 'Too many attempts. Request a new code.' }, { status: 429 })
    }

    const expectedHash = hashOTP(challenge.id, parsed.data.code)
    const valid = crypto.timingSafeEqual(
      Buffer.from(challenge.codeHash),
      Buffer.from(expectedHash)
    )

    await prisma.mobileOTPChallenge.update({
      where: { id: challenge.id },
      data: {
        attempts: { increment: 1 },
        consumedAt: valid ? new Date() : undefined,
      },
    })

    if (!valid) {
      return NextResponse.json({ error: 'Invalid code' }, { status: 401 })
    }

    const user =
      challenge.identifierType === 'email'
        ? await findOrCreateEmailUser(challenge.identifier)
        : await findOrCreatePhoneUser(challenge.identifier)

    return NextResponse.json({ token: createMobileToken(user), user: mobileUser(user) })
  } catch (error) {
    console.error('[MOBILE OTP VERIFY]', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}

async function findOrCreateEmailUser(email: string) {
  const existing = await prisma.user.findUnique({ where: { email }, select: userSelect })
  if (existing) return existing

  const localPart = email.split('@')[0]
  return prisma.user.create({
    data: {
      email,
      emailVerified: new Date(),
      name: localPart,
      preferredName: localPart,
      image: `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(email)}`,
    },
    select: userSelect,
  })
}

async function findOrCreatePhoneUser(phone: string) {
  const existing = await prisma.user.findUnique({ where: { phone }, select: userSelect })
  if (existing) return existing

  return prisma.user.create({
    data: {
      email: syntheticEmailForPhone(phone),
      phone,
      image: `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(phone)}`,
    },
    select: userSelect,
  })
}
