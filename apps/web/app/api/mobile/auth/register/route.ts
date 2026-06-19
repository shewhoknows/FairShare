import { NextRequest, NextResponse } from 'next/server'
import bcrypt from 'bcryptjs'
import { prisma } from '@/lib/prisma'
import { registerSchema } from '@/lib/validations'
import { createMobileToken } from '@/lib/mobile-auth'
import { mobileUser } from '@/lib/mobile-dto'
import { createVerificationToken } from '@/lib/verification'
import { sendVerificationEmail } from '@/lib/email'

export async function POST(req: NextRequest) {
  try {
    const body = await req.json()
    const parsed = registerSchema.safeParse(body)
    if (!parsed.success) {
      return NextResponse.json({ error: parsed.error.errors[0].message }, { status: 400 })
    }

    const { name, email, password } = parsed.data
    const existing = await prisma.user.findUnique({ where: { email } })
    if (existing) {
      return NextResponse.json({ error: 'An account with this email already exists' }, { status: 409 })
    }

    const user = await prisma.user.create({
      data: {
        name,
        email,
        password: await bcrypt.hash(password, 12),
        image: `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(name)}`,
      },
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

    // Create and send verification token
    const verificationToken = await createVerificationToken(email)
    const emailResult = await sendVerificationEmail(email, verificationToken)

    // Log verification URL for development/testing
    const appUrl = process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000'
    const verificationUrl = `${appUrl}/api/auth/verify-email?token=${verificationToken}`
    
    if (emailResult.logged) {
      console.log('')
      console.log('╔════════════════════════════════════════════════════════════════╗')
      console.log('║  🔐 VERIFICATION URL (for testing)                             ║')
      console.log('╠════════════════════════════════════════════════════════════════╣')
      console.log(`║  ${verificationUrl.slice(0, 62).padEnd(62)} ║`)
      if (verificationUrl.length > 62) {
        console.log(`║  ${verificationUrl.slice(62).padEnd(62)} ║`)
      }
      console.log('╚════════════════════════════════════════════════════════════════╝')
      console.log('')
    }

    return NextResponse.json(
      {
        token: createMobileToken(user),
        user: mobileUser(user),
        message: emailResult.logged 
          ? 'Registration successful! Check server console for verification link.'
          : 'Registration successful! Please check your email to verify your account.',
      },
      { status: 201 }
    )
  } catch (error) {
    console.error('[MOBILE REGISTER]', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
