import { NextRequest, NextResponse } from 'next/server'
import { loginSchema } from '@/lib/validations'
import { authenticateMobileUser, createMobileToken } from '@/lib/mobile-auth'
import { mobileUser } from '@/lib/mobile-dto'

export async function POST(req: NextRequest) {
  try {
    const body = await req.json()
    const parsed = loginSchema.safeParse(body)
    if (!parsed.success) {
      return NextResponse.json({ error: parsed.error.errors[0].message }, { status: 400 })
    }

    const user = await authenticateMobileUser(parsed.data.email, parsed.data.password)
    if (!user) {
      return NextResponse.json({ error: 'Invalid email or password' }, { status: 401 })
    }

    return NextResponse.json({ token: createMobileToken(user), user: mobileUser(user) })
  } catch (error) {
    console.error('[MOBILE LOGIN]', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}

