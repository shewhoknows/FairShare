'use client'
import { useEffect, useState } from 'react'
import { useSession } from 'next-auth/react'
import Link from 'next/link'
import { Plus, TrendingUp, TrendingDown, ArrowRight, Download } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Avatar, AvatarImage, AvatarFallback } from '@/components/ui/avatar'
import { AddExpenseModal } from '@/components/expenses/add-expense-modal'
import { SettleUpModal } from '@/components/balances/settle-up-modal'
import { CreateGroupModal } from '@/components/groups/create-group-modal'
import { ExpenseCard } from '@/components/expenses/expense-card'
import { formatCurrency, getInitials, formatRelativeDate } from '@/lib/utils'

interface BalanceUser {
  user: { id: string; name: string | null; image: string | null }
  amount: number
}

export default function DashboardPage() {
  const { data: session } = useSession()
  const [balances, setBalances] = useState<any[]>([])
  const [totalOwed, setTotalOwed] = useState(0)
  const [totalOwe, setTotalOwe] = useState(0)
  const [currency, setCurrency] = useState('USD')
  const [recentExpenses, setRecentExpenses] = useState<any[]>([])
  const [groups, setGroups] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [addExpenseOpen, setAddExpenseOpen] = useState(false)
  const [editingExpense, setEditingExpense] = useState<any>(null)
  const [createGroupOpen, setCreateGroupOpen] = useState(false)
  const [settleModal, setSettleModal] = useState<{
    open: boolean; receiverId: string; receiverName: string | null; receiverImage: string | null; amount: number; receivedMode?: boolean
  }>({ open: false, receiverId: '', receiverName: null, receiverImage: null, amount: 0 })

  const fetchData = async () => {
    try {
      const [balancesRes, expensesRes, groupsRes] = await Promise.all([
        fetch('/api/balances'),
        fetch('/api/expenses?limit=5'),
        fetch('/api/groups'),
      ])
      const balancesData = await balancesRes.json()
      const expensesData = await expensesRes.json()
      const groupsData = await groupsRes.json()

      setBalances(balancesData.balances ?? [])
      setTotalOwed(balancesData.totalOwed ?? 0)
      setTotalOwe(balancesData.totalOwe ?? 0)
      setCurrency(balancesData.currency ?? 'INR')
      setRecentExpenses(expensesData.expenses ?? [])
      setGroups(groupsData.groups ?? [])
    } catch (err) {
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { fetchData() }, [])

  const net = totalOwed - totalOwe

  return (
    <div className="max-w-4xl mx-auto px-4 sm:px-6 py-8">
      {/* Header */}
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">
            Hi, {session?.user?.name?.split(' ')[0]} 👋
          </h1>
          <p className="text-gray-500 text-sm mt-0.5">Here's your expense overview</p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" size="sm" onClick={() => setCreateGroupOpen(true)}>
            <Plus className="w-4 h-4 mr-1" />
            Group
          </Button>
          <Button variant="teal" size="sm" onClick={() => setAddExpenseOpen(true)}>
            <Plus className="w-4 h-4 mr-1" />
            Expense
          </Button>
        </div>
      </div>

      {/* Balance summary cards */}
      <div className="grid grid-cols-3 gap-2 sm:gap-4 mb-8">
        <Card>
          <CardContent className="p-3 sm:p-6">
            <p className="text-[10px] sm:text-xs font-medium text-gray-500 uppercase tracking-wide mb-1">Total balance</p>
            <p className={`text-base sm:text-2xl font-bold ${net >= 0 ? 'text-green-600' : 'text-red-500'}`}>
              {net >= 0 ? '+' : ''}{formatCurrency(net, currency)}
            </p>
            <p className="text-[10px] sm:text-xs text-gray-400 mt-0.5 sm:mt-1">
              {net >= 0 ? 'Overall you are owed' : 'Overall you owe'}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-3 sm:p-6">
            <div className="flex items-center gap-1 mb-1">
              <TrendingUp className="w-3.5 h-3.5 text-green-500" />
              <p className="text-[10px] sm:text-xs font-medium text-gray-500 uppercase tracking-wide">You are owed</p>
            </div>
            <p className="text-base sm:text-2xl font-bold text-green-600">{formatCurrency(totalOwed, currency)}</p>
            <p className="text-[10px] sm:text-xs text-gray-400 mt-0.5 sm:mt-1">from {balances.filter(b => b.amount > 0).length} people</p>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-3 sm:p-6">
            <div className="flex items-center gap-1 mb-1">
              <TrendingDown className="w-3.5 h-3.5 text-red-500" />
              <p className="text-[10px] sm:text-xs font-medium text-gray-500 uppercase tracking-wide">You owe</p>
            </div>
            <p className="text-base sm:text-2xl font-bold text-red-500">{formatCurrency(totalOwe, currency)}</p>
            <p className="text-[10px] sm:text-xs text-gray-400 mt-0.5 sm:mt-1">to {balances.filter(b => b.amount < 0).length} people</p>
          </CardContent>
        </Card>
      </div>

      <div className="grid md:grid-cols-2 gap-6">
        {/* Balances */}
        <div>
          <div className="flex items-center justify-between mb-3">
            <h2 className="font-semibold text-gray-900">Balances</h2>
            <a
              href="/api/export/csv"
              className="text-xs text-teal-600 hover:underline flex items-center gap-1"
            >
              <Download className="w-3 h-3" />
              Export CSV
            </a>
          </div>

          {loading ? (
            <div className="space-y-3">
              {[1, 2, 3].map((i) => (
                <div key={i} className="h-16 bg-gray-100 rounded-lg animate-pulse" />
              ))}
            </div>
          ) : balances.length === 0 ? (
            <div className="bg-white rounded-lg border border-gray-100 p-8 text-center">
              <p className="text-gray-400 text-sm">No balances yet</p>
              <p className="text-gray-400 text-xs mt-1">Add an expense to get started</p>
            </div>
          ) : (
            <div className="space-y-2">
              {balances.map((balance) => (
                <div
                  key={balance.user.id}
                  className="flex items-center gap-3 bg-white rounded-lg border border-gray-100 p-3 hover:shadow-sm transition-shadow"
                >
                  <Avatar className="w-9 h-9">
                    <AvatarImage src={balance.user.image ?? ''} />
                    <AvatarFallback className="text-xs">
                      {getInitials(balance.user.name)}
                    </AvatarFallback>
                  </Avatar>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-gray-900 truncate">
                      {balance.user.name ?? balance.user.email}
                    </p>
                    <p className="text-xs text-gray-500">
                      {balance.amount > 0 ? 'owes you' : 'you owe'}
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    <span
                      className={`text-sm font-semibold ${
                        balance.amount > 0 ? 'text-green-600' : 'text-red-500'
                      }`}
                    >
                      {formatCurrency(Math.abs(balance.amount), currency)}
                    </span>
                    {balance.amount < 0 && (
                      <Button
                        size="sm"
                        variant="outline"
                        className="h-7 text-xs"
                        onClick={() =>
                          setSettleModal({
                            open: true,
                            receiverId: balance.user.id,
                            receiverName: balance.user.name,
                            receiverImage: balance.user.image,
                            amount: Math.abs(balance.amount),
                            receivedMode: false,
                          })
                        }
                      >
                        Settle
                      </Button>
                    )}
                    {balance.amount > 0 && (
                      <Button
                        size="sm"
                        variant="outline"
                        className="h-7 text-xs text-green-700 border-green-300 hover:bg-green-50"
                        onClick={() =>
                          setSettleModal({
                            open: true,
                            receiverId: balance.user.id,
                            receiverName: balance.user.name,
                            receiverImage: balance.user.image,
                            amount: Math.abs(balance.amount),
                            receivedMode: true,
                          })
                        }
                      >
                        Received
                      </Button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Recent expenses */}
        <div>
          <div className="flex items-center justify-between mb-3">
            <h2 className="font-semibold text-gray-900">Recent expenses</h2>
          </div>

          {loading ? (
            <div className="space-y-3">
              {[1, 2, 3].map((i) => (
                <div key={i} className="h-20 bg-gray-100 rounded-lg animate-pulse" />
              ))}
            </div>
          ) : recentExpenses.length === 0 ? (
            <div className="bg-white rounded-lg border border-gray-100 p-8 text-center">
              <p className="text-gray-400 text-sm">No expenses yet</p>
              <Button
                variant="teal"
                size="sm"
                className="mt-3"
                onClick={() => setAddExpenseOpen(true)}
              >
                <Plus className="w-4 h-4 mr-1" />
                Add your first expense
              </Button>
            </div>
          ) : (
            <div className="space-y-3">
              {recentExpenses.map((expense) => (
                <ExpenseCard
                  key={expense.id}
                  expense={expense}
                  onDeleted={fetchData}
                  onEdit={(exp) => setEditingExpense(exp)}
                />
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Groups */}
      {groups.length > 0 && (
        <div className="mt-8">
          <div className="flex items-center justify-between mb-3">
            <h2 className="font-semibold text-gray-900">Your groups</h2>
            <Link href="/groups" className="text-sm text-teal-600 hover:underline flex items-center gap-1">
              View all <ArrowRight className="w-3.5 h-3.5" />
            </Link>
          </div>
          <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-3">
            {groups.slice(0, 3).map((group) => (
              <Link key={group.id} href={`/groups/${group.id}`}>
                <div className="bg-white rounded-lg border border-gray-100 p-4 hover:shadow-md transition-shadow cursor-pointer">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-teal-100 rounded-lg flex items-center justify-center text-xl">
                      {group.category === 'TRIP' ? '✈️' :
                       group.category === 'HOME' ? '🏠' :
                       group.category === 'WORK' ? '💼' :
                       group.category === 'COUPLE' ? '💑' : '📦'}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="font-medium text-gray-900 truncate">{group.name}</p>
                      <p className="text-xs text-gray-500">
                        {group.members.length} members · {group._count.expenses} expenses
                      </p>
                    </div>
                  </div>
                </div>
              </Link>
            ))}
          </div>
        </div>
      )}

      {/* Modals */}
      <AddExpenseModal
        open={addExpenseOpen || !!editingExpense}
        onOpenChange={(v) => {
          if (!v) { setAddExpenseOpen(false); setEditingExpense(null) }
          else setAddExpenseOpen(true)
        }}
        groupId=""
        members={[]}
        onSuccess={fetchData}
        expense={editingExpense ?? undefined}
      />

      <CreateGroupModal open={createGroupOpen} onOpenChange={setCreateGroupOpen} />

      <SettleUpModal
        open={settleModal.open}
        onOpenChange={(v) => setSettleModal((s) => ({ ...s, open: v }))}
        receiverId={settleModal.receiverId}
        receiverName={settleModal.receiverName}
        receiverImage={settleModal.receiverImage}
        suggestedAmount={settleModal.amount}
        currency={currency}
        onSuccess={fetchData}
        receivedMode={settleModal.receivedMode ?? false}
      />
    </div>
  )
}
