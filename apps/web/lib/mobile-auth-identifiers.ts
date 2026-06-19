import crypto from 'crypto'
import { sendEmail } from '@/lib/email'

export type AuthIdentifierType = 'email' | 'phone'

export type NormalizedAuthIdentifier = {
  type: AuthIdentifierType
  value: string
  masked: string
}

const OTP_TTL_MINUTES = 10

export function normalizeAuthIdentifier(input: string): NormalizedAuthIdentifier {
  const trimmed = input.trim()
  if (trimmed.includes('@')) {
    const value = trimmed.toLowerCase()
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) {
      throw new Error('Enter a valid email address')
    }
    return { type: 'email', value, masked: maskEmail(value) }
  }

  const digits = trimmed.replace(/[^\d+]/g, '')
  const normalized = digits.startsWith('+') ? digits : `+${digits.replace(/\+/g, '')}`
  const digitCount = normalized.replace(/\D/g, '').length
  if (digitCount < 8 || digitCount > 15) {
    throw new Error('Enter a valid phone number with country code')
  }
  return { type: 'phone', value: normalized, masked: maskPhone(normalized) }
}

export function generateOTP() {
  if (process.env.MOBILE_AUTH_TEST_CODE) return process.env.MOBILE_AUTH_TEST_CODE
  return String(crypto.randomInt(0, 1_000_000)).padStart(6, '0')
}

export function otpExpiresAt() {
  return new Date(Date.now() + OTP_TTL_MINUTES * 60 * 1000)
}

export function hashOTP(challengeId: string, code: string) {
  const secret = process.env.MOBILE_JWT_SECRET ?? process.env.NEXTAUTH_SECRET
  if (!secret) throw new Error('MOBILE_JWT_SECRET or NEXTAUTH_SECRET must be set')
  return crypto
    .createHmac('sha256', secret)
    .update(`${challengeId}:${code}`)
    .digest('hex')
}

export function syntheticEmailForPhone(phone: string) {
  const digest = crypto.createHash('sha256').update(phone).digest('hex').slice(0, 24)
  return `phone-${digest}@phone.billbandit.local`
}

export function syntheticEmailForAppleSubject(subject: string) {
  const digest = crypto.createHash('sha256').update(subject).digest('hex').slice(0, 24)
  return `apple-${digest}@apple.billbandit.local`
}

export async function sendOTP(identifier: NormalizedAuthIdentifier, code: string) {
  if (identifier.type === 'email') {
    return sendEmail({
      to: identifier.value,
      subject: 'Your BillBandit sign-in code',
      text: `Your BillBandit sign-in code is ${code}. It expires in ${OTP_TTL_MINUTES} minutes.`,
      html: `<p>Your BillBandit sign-in code is <strong>${code}</strong>.</p><p>It expires in ${OTP_TTL_MINUTES} minutes.</p>`,
    })
  }

  if (process.env.MOBILE_AUTH_TEST_CODE) {
    return { success: true, logged: true }
  }

  return {
    success: false,
    error: 'Phone OTP delivery is not configured yet. Set MOBILE_AUTH_TEST_CODE for QA or add an SMS provider.',
  }
}

function maskEmail(email: string) {
  const [name, domain] = email.split('@')
  const visible = name.slice(0, Math.min(2, name.length))
  return `${visible}${'•'.repeat(Math.max(2, name.length - visible.length))}@${domain}`
}

function maskPhone(phone: string) {
  const tail = phone.slice(-4)
  return `${phone.slice(0, 2)}${'•'.repeat(Math.max(4, phone.length - 6))}${tail}`
}
