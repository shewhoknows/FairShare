import { PrismaClient, SplitType, GroupCategory, FriendshipStatus } from '@prisma/client'
import bcrypt from 'bcryptjs'

const prisma = new PrismaClient()

async function main() {
  console.log('🌱 Seeding database...')

  // Clean up
  await prisma.activityLog.deleteMany()
  await prisma.comment.deleteMany()
  await prisma.transaction.deleteMany()
  await prisma.expenseSplit.deleteMany()
  await prisma.expense.deleteMany()
  await prisma.groupMember.deleteMany()
  await prisma.group.deleteMany()
  await prisma.friendship.deleteMany()
  await prisma.session.deleteMany()
  await prisma.account.deleteMany()
  await prisma.user.deleteMany()

  const hash = (p: string) => bcrypt.hashSync(p, 10)

  // Create users
  const alice = await prisma.user.create({
    data: {
      name: 'Alice Johnson',
      email: 'alice@example.com',
      password: hash('password123'),
      image: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Alice',
    },
  })

  const bob = await prisma.user.create({
    data: {
      name: 'Bob Smith',
      email: 'bob@example.com',
      password: hash('password123'),
      image: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Bob',
    },
  })

  const carol = await prisma.user.create({
    data: {
      name: 'Carol White',
      email: 'carol@example.com',
      password: hash('password123'),
      image: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Carol',
    },
  })

  const dave = await prisma.user.create({
    data: {
      name: 'Dave Brown',
      email: 'dave@example.com',
      password: hash('password123'),
      image: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Dave',
    },
  })

  console.log('✓ Created 4 users')

  // Friendships
  await prisma.friendship.createMany({
    data: [
      { fromId: alice.id, toId: bob.id,   status: FriendshipStatus.ACCEPTED },
      { fromId: alice.id, toId: carol.id, status: FriendshipStatus.ACCEPTED },
      { fromId: alice.id, toId: dave.id,  status: FriendshipStatus.ACCEPTED },
      { fromId: bob.id,   toId: carol.id, status: FriendshipStatus.ACCEPTED },
    ],
  })

  console.log('✓ Created friendships')

  // Group: NYC Trip
  const nycGroup = await prisma.group.create({
    data: {
      name: 'NYC Trip',
      description: 'Summer trip to New York City',
      category: GroupCategory.TRIP,
      currency: 'USD',
      members: {
        create: [
          { userId: alice.id, role: 'ADMIN' },
          { userId: bob.id,   role: 'MEMBER' },
          { userId: carol.id, role: 'MEMBER' },
        ],
      },
    },
  })

  // Group: Apartment
  const aptGroup = await prisma.group.create({
    data: {
      name: 'Our Apartment',
      description: 'Shared apartment expenses',
      category: GroupCategory.HOME,
      currency: 'USD',
      members: {
        create: [
          { userId: alice.id, role: 'ADMIN' },
          { userId: dave.id,  role: 'MEMBER' },
        ],
      },
    },
  })

  console.log('✓ Created 2 groups')

  // Expense 1: Hotel (Alice paid, split equally among Alice, Bob, Carol)
  const hotelExpense = await prisma.expense.create({
    data: {
      description: 'Hotel – 3 nights',
      amount: 450,
      currency: 'USD',
      groupId: nycGroup.id,
      paidById: alice.id,
      splitType: SplitType.EQUAL,
      category: 'accommodation',
      date: new Date('2024-07-10'),
      splits: {
        create: [
          { userId: alice.id, amount: 150 },
          { userId: bob.id,   amount: 150 },
          { userId: carol.id, amount: 150 },
        ],
      },
    },
  })

  // Expense 2: Dinner (Bob paid, split equally)
  await prisma.expense.create({
    data: {
      description: 'Dinner at Carbone',
      amount: 180,
      currency: 'USD',
      groupId: nycGroup.id,
      paidById: bob.id,
      splitType: SplitType.EQUAL,
      category: 'food',
      date: new Date('2024-07-11'),
      splits: {
        create: [
          { userId: alice.id, amount: 60 },
          { userId: bob.id,   amount: 60 },
          { userId: carol.id, amount: 60 },
        ],
      },
    },
  })

  // Expense 3: Museum tickets (Carol paid, exact split)
  await prisma.expense.create({
    data: {
      description: 'MoMA tickets',
      amount: 75,
      currency: 'USD',
      groupId: nycGroup.id,
      paidById: carol.id,
      splitType: SplitType.EXACT,
      category: 'entertainment',
      date: new Date('2024-07-12'),
      splits: {
        create: [
          { userId: alice.id, amount: 25 },
          { userId: bob.id,   amount: 25 },
          { userId: carol.id, amount: 25 },
        ],
      },
    },
  })

  // Expense 4: Rent (Dave paid)
  await prisma.expense.create({
    data: {
      description: 'August Rent',
      amount: 2400,
      currency: 'USD',
      groupId: aptGroup.id,
      paidById: dave.id,
      splitType: SplitType.EQUAL,
      category: 'housing',
      date: new Date('2024-08-01'),
      splits: {
        create: [
          { userId: alice.id, amount: 1200 },
          { userId: dave.id,  amount: 1200 },
        ],
      },
    },
  })

  // Expense 5: Utilities (Alice paid)
  await prisma.expense.create({
    data: {
      description: 'Electricity & Internet',
      amount: 120,
      currency: 'USD',
      groupId: aptGroup.id,
      paidById: alice.id,
      splitType: SplitType.PERCENTAGE,
      category: 'utilities',
      date: new Date('2024-08-05'),
      splits: {
        create: [
          { userId: alice.id, amount: 60,  percentage: 50 },
          { userId: dave.id,  amount: 60,  percentage: 50 },
        ],
      },
    },
  })

  console.log('✓ Created 5 expenses')

  // A comment on the hotel expense
  await prisma.comment.create({
    data: {
      content: 'Great deal on the hotel! 🏨',
      expenseId: hotelExpense.id,
      userId: bob.id,
    },
  })

  // Activity logs
  await prisma.activityLog.createMany({
    data: [
      {
        userId: alice.id,
        type: 'GROUP_CREATED',
        description: 'Alice created the group NYC Trip',
        metadata: { groupId: nycGroup.id },
      },
      {
        userId: alice.id,
        type: 'EXPENSE_CREATED',
        description: 'Alice added "Hotel – 3 nights" ($450.00)',
        metadata: { expenseId: hotelExpense.id },
      },
      {
        userId: bob.id,
        type: 'EXPENSE_CREATED',
        description: 'Bob added "Dinner at Carbone" ($180.00)',
      },
    ],
  })

  console.log('✓ Created activity logs')
  console.log('')
  console.log('✅ Seed complete! Login with:')
  console.log('   alice@example.com / password123')
  console.log('   bob@example.com   / password123')
  console.log('   carol@example.com / password123')
  console.log('   dave@example.com  / password123')
}

main()
  .catch((e) => {
    console.error(e)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
