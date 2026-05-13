import { NextRequest, NextResponse } from 'next/server'
import { resendVerificationEmail } from '@/lib/verification'
import { sendVerificationEmail } from '@/lib/email'
import { z } from 'zod'

const resendSchema = z.object({
  email: z.string().email(),
})

export async function POST(req: NextRequest) {
  try {
    const body = await req.json()
    const parsed = resendSchema.safeParse(body)

    if (!parsed.success) {
      return NextResponse.json(
        { error: 'Invalid email address' },
        { status: 400 }
      )
    }

    const { email } = parsed.data
    const result = await resendVerificationEmail(email)

    if (!result.success) {
      return NextResponse.json(
        { error: result.error },
        { status: 400 }
      )
    }

    // Send the verification email
    await sendVerificationEmail(email, result.token!)

    return NextResponse.json({
      success: true,
      message: 'Verification email sent. Please check your inbox.',
    })
  } catch (error) {
    console.error('[RESEND VERIFICATION]', error)
    return NextResponse.json(
      { error: 'Failed to send verification email' },
      { status: 500 }
    )
  }
}
