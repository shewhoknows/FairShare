import { z } from 'zod'

const nullToUndefined = (value: unknown) => value === null ? undefined : value
const optionalNullable = <T extends z.ZodTypeAny>(schema: T) =>
  z.preprocess(nullToUndefined, schema.optional())
const defaultableNullable = <T extends z.ZodTypeAny>(schema: T) =>
  z.preprocess(nullToUndefined, schema)

export const registerSchema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters'),
  email: z.string().email('Invalid email address'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
})

export const loginSchema = z.object({
  email: z.string().email('Invalid email address'),
  password: z.string().min(1, 'Password is required'),
})

export const otpStartSchema = z.object({
  identifier: z.string().min(3, 'Enter an email address or phone number'),
})

export const otpVerifySchema = z.object({
  challengeId: z.string().min(1, 'Challenge ID is required'),
  code: z.string().regex(/^\d{6}$/, 'Enter the 6 digit code'),
})

export const appleSignInSchema = z.object({
  identityToken: z.string().min(20, 'Apple identity token is required'),
  nonce: z.string().optional(),
  name: z.string().min(1).optional(),
  fullName: z.string().min(1).optional(),
  authorizationCode: z.string().optional(),
  email: z.string().email().optional(),
})

export const completeMobileProfileSchema = z.object({
  name: z.string().min(2).max(80).optional(),
  preferredName: z.string().min(1).max(40).optional(),
  upiID: z.string().min(3).max(120).optional(),
})

export const createGroupSchema = z.object({
  name: z.string().min(1, 'Group name is required').max(50),
  description: optionalNullable(z.string().max(200)),
  currency: z.string().default('INR'),
  category: z.enum(['HOME', 'TRIP', 'COUPLE', 'WORK', 'OTHER']).default('OTHER'),
})

export const addMemberSchema = z.object({
  email: z.string().email('Invalid email address'),
})

export const splitSchema = z.object({
  userId: z.string(),
  amount: z.number().min(0),
  percentage: optionalNullable(z.number().min(0).max(100)),
  shares: optionalNullable(z.number().min(1)),
})

export const createExpenseSchema = z.object({
  description: z.string().min(1, 'Description is required').max(100),
  amount: z.number().positive('Amount must be positive'),
  currency: z.string().default('INR'),
  date: z.string().or(z.date()),
  category: z.string().default('general'),
  groupId: optionalNullable(z.string()),
  paidById: z.string(),
  splitType: z.enum(['EQUAL', 'EXACT', 'PERCENTAGE', 'SHARES']),
  splits: z.array(splitSchema).min(1, 'At least one split is required'),
  notes: optionalNullable(z.string().max(500)),
  isRecurring: z.boolean().default(false),
  recurringInterval: z.enum(['DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY']).optional(),
})

export const createTransactionSchema = z.object({
  receiverId: optionalNullable(z.string()),
  senderId: optionalNullable(z.string()),
  amount: z.number().positive(),
  currency: defaultableNullable(z.string().default('INR')),
  groupId: optionalNullable(z.string()),
  note: optionalNullable(z.string().max(200)),
})

export const addCommentSchema = z.object({
  content: z.string().min(1).max(500),
})

export type RegisterInput = z.infer<typeof registerSchema>
export type LoginInput = z.infer<typeof loginSchema>
export type OTPStartInput = z.infer<typeof otpStartSchema>
export type OTPVerifyInput = z.infer<typeof otpVerifySchema>
export type AppleSignInInput = z.infer<typeof appleSignInSchema>
export type CompleteMobileProfileInput = z.infer<typeof completeMobileProfileSchema>
export type CreateGroupInput = z.infer<typeof createGroupSchema>
export type CreateExpenseInput = z.infer<typeof createExpenseSchema>
export type CreateTransactionInput = z.infer<typeof createTransactionSchema>
