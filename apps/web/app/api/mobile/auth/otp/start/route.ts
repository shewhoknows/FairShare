import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { otpStartSchema } from '@/lib/validations'
import {
  generateOTP,
  hashOTP,
  normalizeAuthIdentifier,
  otpExpiresAt,
  sendOTP,
} from '@/lib/mobile-auth-identifiers'

export async function POST(req: NextRequest) {
  try {
    const body = await req.json()
    const parsed = otpStartSchema.safeParse(body)
    if (!parsed.success) {
      return NextResponse.json({ error: parsed.error.errors[0].message }, { status: 400 })
    }

    let identifier
    try {
      identifier = normalizeAuthIdentifier(parsed.data.identifier)
    } catch (error) {
      return NextResponse.json(
        { error: error instanceof Error ? error.message : 'Invalid identifier' },
        { status: 400 }
      )
    }

    const code = generateOTP(identifier)
    const challenge = await prisma.mobileOTPChallenge.create({
      data: {
        identifier: identifier.value,
        identifierType: identifier.type,
        codeHash: 'pending',
        expiresAt: otpExpiresAt(),
      },
    })

    await prisma.mobileOTPChallenge.update({
      where: { id: challenge.id },
      data: { codeHash: hashOTP(challenge.id, code) },
    })

    const delivery = await sendOTP(identifier, code)
    if (!delivery.success) {
      await prisma.mobileOTPChallenge.delete({ where: { id: challenge.id } })
      return NextResponse.json({ error: delivery.error ?? 'Could not send code' }, { status: 501 })
    }

    return NextResponse.json({
      challengeId: challenge.id,
      maskedIdentifier: identifier.masked,
      deliveryChannel: identifier.type,
      expiresInSeconds: 10 * 60,
      message: delivery.logged
        ? 'Code created for QA delivery.'
        : 'Code sent. It expires in 10 minutes.',
    })
  } catch (error) {
    console.error('[MOBILE OTP START]', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
