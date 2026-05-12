export function mobileUser(user: {
  id: string
  name?: string | null
  email?: string | null
  image?: string | null
}) {
  return {
    id: user.id,
    name: user.name ?? null,
    email: user.email ?? null,
    image: user.image ?? null,
  }
}

export function mobileMember(member: {
  userId: string
  role: string
  joinedAt?: Date
  user: {
    id: string
    name?: string | null
    email?: string | null
    image?: string | null
  }
}) {
  return {
    userId: member.userId,
    role: member.role,
    joinedAt: member.joinedAt?.toISOString() ?? null,
    user: mobileUser(member.user),
  }
}

export function mobileExpense(expense: any) {
  return {
    id: expense.id,
    description: expense.description,
    amount: expense.amount,
    currency: expense.currency,
    date: expense.date?.toISOString?.() ?? expense.date,
    category: expense.category,
    groupId: expense.groupId ?? null,
    group: expense.group
      ? { id: expense.group.id, name: expense.group.name }
      : null,
    paidById: expense.paidById,
    paidBy: expense.paidBy ? mobileUser(expense.paidBy) : null,
    splitType: expense.splitType,
    notes: expense.notes ?? null,
    splits: (expense.splits ?? []).map((split: any) => ({
      userId: split.userId,
      amount: split.amount,
      percentage: split.percentage ?? null,
      shares: split.shares ?? null,
      user: split.user ? mobileUser(split.user) : null,
    })),
    createdAt: expense.createdAt?.toISOString?.() ?? expense.createdAt ?? null,
    updatedAt: expense.updatedAt?.toISOString?.() ?? expense.updatedAt ?? null,
  }
}

export function mobileGroup(group: any) {
  return {
    id: group.id,
    name: group.name,
    description: group.description ?? null,
    image: group.image ?? null,
    currency: group.currency,
    category: group.category,
    memberCount: group.members?.length ?? group._count?.members ?? 0,
    expenseCount: group._count?.expenses ?? group.expenses?.length ?? 0,
    members: (group.members ?? []).map(mobileMember),
    expenses: group.expenses ? group.expenses.map(mobileExpense) : undefined,
    createdAt: group.createdAt?.toISOString?.() ?? group.createdAt ?? null,
    updatedAt: group.updatedAt?.toISOString?.() ?? group.updatedAt ?? null,
  }
}

