'use client'
import { useEffect, useState } from 'react'
import { useParams, useRouter } from 'next/navigation'
import { useSession } from 'next-auth/react'
import { Plus, UserPlus, ArrowLeft, Download, ChevronRight, Sparkles } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Avatar, AvatarImage, AvatarFallback } from '@/components/ui/avatar'
import { Badge } from '@/components/ui/badge'
import { AddExpenseModal } from '@/components/expenses/add-expense-modal'
import { ExpenseCard } from '@/components/expenses/expense-card'
import { SettleUpModal } from '@/components/balances/settle-up-modal'
import { toast } from '@/hooks/use-toast'
import { formatCurrency, getInitials } from '@/lib/utils'
import Link from 'next/link'

const CATEGORY_EMOJI: Record<string, string> = {
  TRIP: '✈️', HOME: '🏠', WORK: '💼', COUPLE: '💑', OTHER: '📦',
}

export default function GroupDetailPage() {
  const { id } = useParams<{ id: string }>()
  const { data: session } = useSession()
  const router = useRouter()

  const [group, setGroup] = useState<any>(null)
  const [balances, setBalances] = useState<any>({ netBalances: [], simplifiedDebts: [] })
  const [loading, setLoading] = useState(true)
  const [addExpenseOpen, setAddExpenseOpen] = useState(false)
  const [editingExpense, setEditingExpense] = useState<any>(null)
  const [inviteEmail, setInviteEmail] = useState('')
  const [inviting, setInviting] = useState(false)
  const [settleModal, setSettleModal] = useState<any>({ open: false })

  const fetchGroup = async () => {
    try {
      const [groupRes, balancesRes] = await Promise.all([
        fetch(`/api/groups/${id}`),
        fetch(`/api/groups/${id}/balances`),
      ])
      const groupData = await groupRes.json()
      const balancesData = await balancesRes.json()
      if (groupRes.ok) setGroup(groupData.group)
      if (balancesRes.ok) setBalances(balancesData)
    } catch (err) {
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { fetchGroup() }, [id])

  const handleInvite = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!inviteEmail.trim()) return
    setInviting(true)
    try {
      const res = await fetch(`/api/groups/${id}/members`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: inviteEmail }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error ?? 'Failed to add member')
      toast({ title: `${data.member.user.name ?? inviteEmail} added to the group!` })
      setInviteEmail('')
      fetchGroup()
    } catch (err: any) {
      toast({ title: 'Error', description: err.message, variant: 'destructive' })
    } finally {
      setInviting(false)
    }
  }

  if (loading) {
    return (
      <div className="max-w-3xl mx-auto px-4 sm:px-6 py-8">
        <div className="h-8 w-48 bg-gray-100 rounded animate-pulse mb-4" />
        <div className="h-48 bg-gray-100 rounded-xl animate-pulse" />
      </div>
    )
  }

  if (!group) {
    return (
      <div className="max-w-3xl mx-auto px-4 sm:px-6 py-8 text-center">
        <p className="text-gray-500">Group not found</p>
        <Button variant="outline" className="mt-4" onClick={() => router.back()}>Go back</Button>
      </div>
    )
  }

  const myMembership = group.members.find((m: any) => m.userId === session?.user?.id)
  const isAdmin = myMembership?.role === 'ADMIN'
  const totalGroupExpenses = group.expenses.reduce((s: number, e: any) => s + e.amount, 0)

  return (
    <div className="max-w-3xl mx-auto px-4 sm:px-6 py-8">
      {/* Back */}
      <Link
        href="/groups"
        className="inline-flex items-center gap-1.5 text-sm text-gray-500 hover:text-gray-700 mb-6"
      >
        <ArrowLeft className="w-4 h-4" />
        Back to groups
      </Link>

      {/* Group header */}
      <div className="bg-white rounded-xl border border-gray-100 p-6 mb-6">
        <div className="flex items-start gap-4">
          <div className="w-14 h-14 bg-teal-50 rounded-xl flex items-center justify-center text-3xl flex-shrink-0">
            {CATEGORY_EMOJI[group.category] ?? '📦'}
          </div>
          <div className="flex-1 min-w-0">
            <h1 className="text-2xl font-bold text-gray-900">{group.name}</h1>
            {group.description && (
              <p className="text-gray-500 text-sm mt-0.5">{group.description}</p>
            )}
            <div className="flex items-center gap-4 mt-2 text-sm text-gray-500">
              <span>{group.members.length} members</span>
              <span>·</span>
              <span>{group.expenses.length} expenses</span>
              <span>·</span>
              <span>Total: {formatCurrency(totalGroupExpenses, group.currency)}</span>
            </div>
          </div>
          <div className="flex gap-2 flex-shrink-0">
            <a href={`/api/export/csv?groupId=${id}`}>
              <Button variant="outline" size="sm">
                <Download className="w-4 h-4 sm:mr-1" />
                <span className="hidden sm:inline">Export</span>
              </Button>
            </a>
            <Button variant="teal" size="sm" onClick={() => setAddExpenseOpen(true)}>
              <Plus className="w-4 h-4 sm:mr-1" />
              <span className="hidden sm:inline">Expense</span>
            </Button>
          </div>
        </div>
      </div>

      <Tabs defaultValue="expenses">
        <TabsList className="mb-6">
          <TabsTrigger value="expenses">Expenses</TabsTrigger>
          <TabsTrigger value="balances">Balances</TabsTrigger>
          <TabsTrigger value="members">Members</TabsTrigger>
        </TabsList>

        {/* Expenses tab */}
        <TabsContent value="expenses">
          {group.expenses.length === 0 ? (
            <div className="bg-white rounded-xl border border-gray-100 p-12 text-center">
              <p className="text-gray-400 text-sm mb-3">No expenses yet</p>
              <Button variant="teal" onClick={() => setAddExpenseOpen(true)}>
                <Plus className="w-4 h-4 mr-1" />
                Add first expense
              </Button>
            </div>
          ) : (
            <div className="space-y-3">
              {group.expenses.map((expense: any) => (
                <ExpenseCard
                  key={expense.id}
                  expense={expense}
                  onDeleted={fetchGroup}
                  onEdit={(exp) => setEditingExpense(exp)}
                />
              ))}
            </div>
          )}
        </TabsContent>

        {/* Balances tab */}
        <TabsContent value="balances">
          <div className="space-y-4">
            {/* Net balances */}
            <div className="bg-white rounded-xl border border-gray-100 p-5">
              <h3 className="font-semibold text-gray-900 mb-4">Net balances</h3>
              <div className="space-y-3">
                {balances.netBalances.map((balance: any) => (
                  <div key={balance.userId} className="flex items-center gap-3">
                    <Avatar className="w-8 h-8">
                      <AvatarImage src={balance.image ?? ''} />
                      <AvatarFallback className="text-xs">{getInitials(balance.name)}</AvatarFallback>
                    </Avatar>
                    <span className="flex-1 text-sm">
                      {balance.userId === session?.user?.id ? 'You' : balance.name}
                    </span>
                    <div className="flex items-center gap-2">
                      <span
                        className={`text-sm font-semibold ${
                          balance.netAmount > 0 ? 'text-green-600' : balance.netAmount < 0 ? 'text-red-500' : 'text-gray-400'
                        }`}
                      >
                        {balance.netAmount > 0 ? '+' : ''}
                        {formatCurrency(balance.netAmount, group.currency)}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Simplified debts */}
            {balances.simplifiedDebts.length > 0 && (
              <div className="bg-white rounded-xl border border-gray-100 p-5">
                <div className="flex items-center gap-2 mb-4">
                  <Sparkles className="w-4 h-4 text-teal-600" />
                  <h3 className="font-semibold text-gray-900">Simplified payments</h3>
                  <Badge variant="teal" className="ml-auto">
                    {balances.simplifiedDebts.length} payment{balances.simplifiedDebts.length !== 1 ? 's' : ''}
                  </Badge>
                </div>
                <div className="space-y-2">
                  {balances.simplifiedDebts.map((debt: any, i: number) => {
                    const isMyDebt = debt.fromId === session?.user?.id
                    const iAmCreditor = debt.toId === session?.user?.id
                    return (
                      <div
                        key={i}
                        className={`flex items-center gap-3 p-3 rounded-lg ${
                          isMyDebt ? 'bg-red-50' : iAmCreditor ? 'bg-green-50' : 'bg-gray-50'
                        }`}
                      >
                        <span className="text-sm flex-1">
                          <span className="font-medium">
                            {debt.fromId === session?.user?.id ? 'You' : debt.fromName}
                          </span>
                          {' → '}
                          <span className="font-medium">
                            {debt.toId === session?.user?.id ? 'You' : debt.toName}
                          </span>
                        </span>
                        <span className={`text-sm font-bold ${isMyDebt ? 'text-red-600' : iAmCreditor ? 'text-green-600' : 'text-gray-700'}`}>
                          {formatCurrency(debt.amount, group.currency)}
                        </span>
                        {isMyDebt && (
                          <Button
                            size="sm"
                            variant="outline"
                            className="h-7 text-xs"
                            onClick={() =>
                              setSettleModal({
                                open: true,
                                receiverId: debt.toId,
                                receiverName: debt.toName,
                                receiverImage: null,
                                amount: debt.amount,
                                groupId: id,
                                receivedMode: false,
                              })
                            }
                          >
                            Settle
                          </Button>
                        )}
                        {iAmCreditor && (
                          <Button
                            size="sm"
                            variant="outline"
                            className="h-7 text-xs text-green-700 border-green-300 hover:bg-green-100"
                            onClick={() =>
                              setSettleModal({
                                open: true,
                                receiverId: debt.fromId,
                                receiverName: debt.fromName,
                                receiverImage: null,
                                amount: debt.amount,
                                groupId: id,
                                receivedMode: true,
                              })
                            }
                          >
                            Mark received
                          </Button>
                        )}
                      </div>
                    )
                  })}
                </div>
              </div>
            )}

            {balances.simplifiedDebts.length === 0 && balances.netBalances.every((b: any) => Math.abs(b.netAmount) < 0.01) && (
              <div className="bg-green-50 rounded-xl border border-green-100 p-6 text-center">
                <p className="text-green-700 font-medium">🎉 All settled up!</p>
                <p className="text-green-600 text-sm mt-1">No outstanding balances in this group</p>
              </div>
            )}
          </div>
        </TabsContent>

        {/* Members tab */}
        <TabsContent value="members">
          <div className="bg-white rounded-xl border border-gray-100 p-5">
            <h3 className="font-semibold text-gray-900 mb-4">
              Members ({group.members.length})
            </h3>
            <div className="space-y-3 mb-6">
              {group.members.map((member: any) => (
                <div key={member.userId} className="flex items-center gap-3">
                  <Avatar className="w-9 h-9">
                    <AvatarImage src={member.user.image ?? ''} />
                    <AvatarFallback className="text-xs">{getInitials(member.user.name)}</AvatarFallback>
                  </Avatar>
                  <div className="flex-1">
                    <p className="text-sm font-medium text-gray-900">
                      {member.user.name ?? member.user.email}
                      {member.userId === session?.user?.id && (
                        <span className="text-gray-400 font-normal"> (you)</span>
                      )}
                    </p>
                    <p className="text-xs text-gray-500">{member.user.email}</p>
                  </div>
                  {member.role === 'ADMIN' && (
                    <Badge variant="teal" className="text-xs">Admin</Badge>
                  )}
                </div>
              ))}
            </div>

            {/* Invite */}
            <div className="border-t border-gray-100 pt-4">
              <h4 className="text-sm font-medium text-gray-700 mb-3">Add member</h4>
              <form onSubmit={handleInvite} className="flex gap-2">
                <input
                  type="email"
                  value={inviteEmail}
                  onChange={(e) => setInviteEmail(e.target.value)}
                  placeholder="friend@example.com"
                  className="flex-1 text-sm border border-gray-200 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-teal-500"
                  required
                />
                <Button type="submit" variant="teal" size="sm" disabled={inviting}>
                  <UserPlus className="w-4 h-4 mr-1" />
                  {inviting ? 'Adding…' : 'Add'}
                </Button>
              </form>
            </div>
          </div>
        </TabsContent>
      </Tabs>

      {/* Modals */}
      <AddExpenseModal
        open={addExpenseOpen || !!editingExpense}
        onOpenChange={(v) => {
          if (!v) { setAddExpenseOpen(false); setEditingExpense(null) }
          else setAddExpenseOpen(true)
        }}
        groupId={id}
        members={group.members}
        onSuccess={fetchGroup}
        expense={editingExpense ?? undefined}
      />

      <SettleUpModal
        open={settleModal.open}
        onOpenChange={(v) => setSettleModal((s: any) => ({ ...s, open: v }))}
        receiverId={settleModal.receiverId ?? ''}
        receiverName={settleModal.receiverName ?? null}
        receiverImage={settleModal.receiverImage ?? null}
        suggestedAmount={settleModal.amount ?? 0}
        currency={group.currency}
        groupId={settleModal.groupId}
        onSuccess={fetchGroup}
        receivedMode={settleModal.receivedMode ?? false}
      />
    </div>
  )
}
