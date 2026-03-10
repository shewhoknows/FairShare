import { z } from 'zod'

export const registerSchema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters'),
  email: z.string().email('Invalid email address'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
})

export const loginSchema = z.object({
  email: z.string().email('Invalid email address'),
  password: z.string().min(1, 'Password is required'),
})

export const createGroupSchema = z.object({
  name: z.string().min(1, 'Group name is required').max(50),
  description: z.string().max(200).optional(),
  currency: z.string().default('USD'),
  category: z.enum(['HOME', 'TRIP', 'COUPLE', 'WORK', 'OTHER']).default('OTHER'),
})

export const addMemberSchema = z.object({
  email: z.string().email('Invalid email address'),
})

export const splitSchema = z.object({
  userId: z.string(),
  amount: z.number().min(0),
  percentage: z.number().min(0).max(100).optional(),
  shares: z.number().min(1).optional(),
})

export const createExpenseSchema = z.object({
  description: z.string().min(1, 'Description is required').max(100),
  amount: z.number().positive('Amount must be positive'),
  currency: z.string().default('USD'),
  date: z.string().or(z.date()),
  category: z.string().default('general'),
  groupId: z.string().optional(),
  paidById: z.string(),
  splitType: z.enum(['EQUAL', 'EXACT', 'PERCENTAGE', 'SHARES']),
  splits: z.array(splitSchema).min(1, 'At least one split is required'),
  notes: z.string().max(500).optional(),
  isRecurring: z.boolean().default(false),
  recurringInterval: z.enum(['DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY']).optional(),
})

export const createTransactionSchema = z.object({
  receiverId: z.string(),
  amount: z.number().positive(),
  currency: z.string().default('USD'),
  groupId: z.string().optional(),
  note: z.string().max(200).optional(),
})

export const addCommentSchema = z.object({
  content: z.string().min(1).max(500),
})

export type RegisterInput = z.infer<typeof registerSchema>
export type LoginInput = z.infer<typeof loginSchema>
export type CreateGroupInput = z.infer<typeof createGroupSchema>
export type CreateExpenseInput = z.infer<typeof createExpenseSchema>
export type CreateTransactionInput = z.infer<typeof createTransactionSchema>
