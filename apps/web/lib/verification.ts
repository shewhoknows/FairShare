import crypto from 'crypto'
import { prisma } from '@/lib/prisma'

const VERIFICATION_TOKEN_EXPIRY_HOURS = 24

export function generateVerificationToken(): string {
  return crypto.randomBytes(32).toString('hex')
}

export async function createVerificationToken(email: string): Promise<string> {
  const token = generateVerificationToken()
  const expires = new Date()
  expires.setHours(expires.getHours() + VERIFICATION_TOKEN_EXPIRY_HOURS)

  // Delete any existing tokens for this email
  await prisma.verificationToken.deleteMany({
    where: { identifier: email },
  })

  // Create new token
  await prisma.verificationToken.create({
    data: {
      identifier: email,
      token,
      expires,
    },
  })

  return token
}

export async function validateVerificationToken(token: string): Promise<{ success: boolean; email?: string; error?: string }> {
  const verificationToken = await prisma.verificationToken.findUnique({
    where: { token },
  })

  if (!verificationToken) {
    return { success: false, error: 'Invalid or expired verification token' }
  }

  if (verificationToken.expires < new Date()) {
    // Clean up expired token
    await prisma.verificationToken.delete({
      where: { token },
    })
    return { success: false, error: 'Verification token has expired' }
  }

  // Find the user and mark email as verified
  const user = await prisma.user.findUnique({
    where: { email: verificationToken.identifier },
  })

  if (!user) {
    return { success: false, error: 'User not found' }
  }

  // Update user's emailVerified timestamp
  await prisma.user.update({
    where: { id: user.id },
    data: { emailVerified: new Date() },
  })

  // Delete the used token
  await prisma.verificationToken.delete({
    where: { token },
  })

  return { success: true, email: verificationToken.identifier }
}

export async function isEmailVerified(email: string): Promise<boolean> {
  const user = await prisma.user.findUnique({
    where: { email },
    select: { emailVerified: true },
  })

  return user?.emailVerified != null
}

export async function resendVerificationEmail(email: string): Promise<{ success: boolean; error?: string; token?: string }> {
  const user = await prisma.user.findUnique({
    where: { email },
  })

  if (!user) {
    return { success: false, error: 'User not found' }
  }

  if (user.emailVerified) {
    return { success: false, error: 'Email is already verified' }
  }

  // Create new token
  const token = await createVerificationToken(email)

  return { success: true, token }
}
