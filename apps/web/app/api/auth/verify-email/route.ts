import { NextRequest, NextResponse } from 'next/server'
import { validateVerificationToken } from '@/lib/verification'

export const dynamic = 'force-dynamic'

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url)
    const token = searchParams.get('token')

    if (!token) {
      return NextResponse.redirect(new URL('/sign-in?error=missing_token', req.url))
    }

    const result = await validateVerificationToken(token)

    if (result.success) {
      return NextResponse.redirect(new URL('/sign-in?verified=true', req.url))
    } else {
      return NextResponse.redirect(new URL(`/sign-in?error=${encodeURIComponent(result.error || 'verification_failed')}`, req.url))
    }
  } catch (error) {
    console.error('[VERIFY EMAIL]', error)
    return NextResponse.redirect(new URL('/sign-in?error=server_error', req.url))
  }
}
