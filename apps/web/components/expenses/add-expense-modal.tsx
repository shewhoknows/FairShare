'use client'
import { useState, useEffect } from 'react'
import { useSession } from 'next-auth/react'
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter,
} from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select'
import { Avatar, AvatarImage, AvatarFallback } from '@/components/ui/avatar'
import { toast } from '@/hooks/use-toast'
import { formatCurrency, getInitials, EXPENSE_CATEGORIES, CURRENCIES, splitEvenly, roundAmount } from '@/lib/utils'

interface Member {
  user: { id: string; name: string | null; image: string | null; email: string }
}

interface EditExpense {
  id: string
  description: string
  amount: number
  currency: string
  date: string
  category: string
  paidBy: { id: string }
  splitType: string
  splits: { userId: string; amount: number; percentage?: number | null; shares?: number | null }[]
}

interface Props {
  open: boolean
  onOpenChange: (open: boolean) => void
  groupId: string
  members: Member[]
  onSuccess?: () => void
  /** If provided, opens in edit mode */
  expense?: EditExpense
}

type SplitType = 'EQUAL' | 'EXACT' | 'PERCENTAGE' | 'SHARES'

export function AddExpenseModal({ open, onOpenChange, groupId, members, onSuccess, expense }: Props) {
  const { data: session } = useSession()
  const [loading, setLoading] = useState(false)
  const [splitType, setSplitType] = useState<SplitType>('EQUAL')
  const [amount, setAmount] = useState('')
  const [description, setDescription] = useState('')
  const [paidById, setPaidById] = useState(session?.user?.id ?? '')
  const [currency, setCurrency] = useState('INR')
  const [category, setCategory] = useState('general')
  const [date, setDate] = useState(new Date().toISOString().split('T')[0])
  const [selectedMembers, setSelectedMembers] = useState<string[]>([])
  const [exactAmounts, setExactAmounts] = useState<Record<string, string>>({})
  const [percentages, setPercentages] = useState<Record<string, string>>({})
  const [shares, setShares] = useState<Record<string, string>>({})

  const isEditing = !!expense

  useEffect(() => {
    if (open && expense) {
      // Edit mode: populate from existing expense
      setDescription(expense.description)
      setAmount(expense.amount.toString())
      setCurrency(expense.currency)
      setDate(expense.date.split('T')[0])
      setCategory(expense.category)
      setPaidById(expense.paidBy.id)
      setSplitType(expense.splitType as SplitType)
      const memberIds = expense.splits.map((s) => s.userId)
      setSelectedMembers(memberIds)
      // Initialize split inputs from stored values
      const exact: Record<string, string> = {}
      const pcts: Record<string, string> = {}
      const shs: Record<string, string> = {}
      for (const s of expense.splits) {
        exact[s.userId] = s.amount.toFixed(2)
        if (s.percentage != null) pcts[s.userId] = s.percentage.toString()
        if (s.shares != null) shs[s.userId] = s.shares.toString()
      }
      setExactAmounts(exact)
      setPercentages(pcts)
      setShares(shs)
    } else if (open && !expense) {
      // Create mode: reset to defaults
      setDescription('')
      setAmount('')
      setCurrency('INR')
      setDate(new Date().toISOString().split('T')[0])
      setCategory('general')
      setSplitType('EQUAL')
      setExactAmounts({})
      setPercentages({})
      setShares({})
      setSelectedMembers(members.map((m) => m.user.id))
      setPaidById(session?.user?.id ?? members[0]?.user.id ?? '')
    } else if (open) {
      setSelectedMembers(members.map((m) => m.user.id))
      setPaidById(session?.user?.id ?? members[0]?.user.id ?? '')
    }
  }, [open, expense, members, session?.user?.id])

  const buildSplits = () => {
    const numericAmount = parseFloat(amount)
    if (isNaN(numericAmount)) return []

    if (splitType === 'EQUAL') {
      const even = splitEvenly(numericAmount, selectedMembers.length)
      return selectedMembers.map((uid, i) => ({
        userId: uid,
        amount: even[i],
      }))
    }

    if (splitType === 'EXACT') {
      return selectedMembers.map((uid) => ({
        userId: uid,
        amount: parseFloat(exactAmounts[uid] ?? '0') || 0,
      }))
    }

    if (splitType === 'PERCENTAGE') {
      return selectedMembers.map((uid) => {
        const pct = parseFloat(percentages[uid] ?? '0') || 0
        return {
          userId: uid,
          amount: roundAmount((numericAmount * pct) / 100),
          percentage: pct,
        }
      })
    }

    if (splitType === 'SHARES') {
      const totalShares = selectedMembers.reduce(
        (sum, uid) => sum + (parseInt(shares[uid] ?? '1') || 1),
        0
      )
      return selectedMembers.map((uid) => {
        const s = parseInt(shares[uid] ?? '1') || 1
        return {
          userId: uid,
          amount: roundAmount((numericAmount * s) / totalShares),
          shares: s,
        }
      })
    }

    return []
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!amount || !description || selectedMembers.length === 0) return

    const splits = buildSplits()
    const total = splits.reduce((s, sp) => s + sp.amount, 0)

    if (Math.abs(total - parseFloat(amount)) > 0.02) {
      toast({
        title: 'Split error',
        description: `Splits total ${total.toFixed(2)} but expense is ${amount}`,
        variant: 'destructive',
      })
      return
    }

    setLoading(true)
    try {
      const url = isEditing ? `/api/expenses/${expense.id}` : '/api/expenses'
      const method = isEditing ? 'PUT' : 'POST'

      const res = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          description,
          amount: parseFloat(amount),
          currency,
          date,
          category,
          groupId: groupId || undefined,
          paidById,
          splitType,
          splits,
        }),
      })

      if (!res.ok) {
        const data = await res.json()
        throw new Error(data.error ?? (isEditing ? 'Failed to update expense' : 'Failed to add expense'))
      }

      toast({ title: isEditing ? 'Expense updated!' : 'Expense added!', variant: 'default' })
      onOpenChange(false)
      onSuccess?.()
    } catch (err: any) {
      toast({ title: 'Error', description: err.message, variant: 'destructive' })
    } finally {
      setLoading(false)
    }
  }

  const toggleMember = (uid: string) => {
    setSelectedMembers((prev) =>
      prev.includes(uid) ? prev.filter((id) => id !== uid) : [...prev, uid]
    )
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{isEditing ? 'Edit expense' : 'Add an expense'}</DialogTitle>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4">
          {/* Description + Amount */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div className="col-span-2">
              <Label>Description</Label>
              <Input
                placeholder="e.g. Dinner, Uber, Groceries"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                required
              />
            </div>

            <div>
              <Label>Amount</Label>
              <Input
                type="number"
                step="0.01"
                min="0.01"
                placeholder="0.00"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                required
              />
            </div>

            <div>
              <Label>Currency</Label>
              <Select value={currency} onValueChange={setCurrency}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {CURRENCIES.map((c) => (
                    <SelectItem key={c.code} value={c.code}>
                      {c.symbol} {c.code}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          {/* Paid by + Category + Date */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <Label>Paid by</Label>
              <Select value={paidById} onValueChange={setPaidById}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {members.map((m) => (
                    <SelectItem key={m.user.id} value={m.user.id}>
                      {m.user.name ?? m.user.email}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div>
              <Label>Category</Label>
              <Select value={category} onValueChange={setCategory}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {EXPENSE_CATEGORIES.map((c) => (
                    <SelectItem key={c.value} value={c.value}>
                      {c.emoji} {c.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="col-span-2">
              <Label>Date</Label>
              <Input type="date" value={date} onChange={(e) => setDate(e.target.value)} />
            </div>
          </div>

          {/* Split type */}
          <div>
            <Label>Split type</Label>
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-1 mt-1">
              {(['EQUAL', 'EXACT', 'PERCENTAGE', 'SHARES'] as SplitType[]).map((type) => (
                <button
                  key={type}
                  type="button"
                  onClick={() => setSplitType(type)}
                  className={`py-1.5 text-xs rounded-md font-medium transition-colors ${
                    splitType === type
                      ? 'bg-teal-600 text-white'
                      : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                  }`}
                >
                  {type.charAt(0) + type.slice(1).toLowerCase()}
                </button>
              ))}
            </div>
          </div>

          {/* Members + split inputs */}
          <div>
            <Label>Split between</Label>
            <div className="mt-2 space-y-2">
              {members.map((m) => {
                const isSelected = selectedMembers.includes(m.user.id)
                const numericAmount = parseFloat(amount) || 0
                const equalShare =
                  selectedMembers.length > 0
                    ? roundAmount(numericAmount / selectedMembers.length)
                    : 0

                return (
                  <div
                    key={m.user.id}
                    className={`flex items-center gap-3 p-2 rounded-lg border transition-colors ${
                      isSelected ? 'border-teal-200 bg-teal-50' : 'border-gray-100'
                    }`}
                  >
                    <button type="button" onClick={() => toggleMember(m.user.id)}>
                      <Avatar className="w-8 h-8">
                        <AvatarImage src={m.user.image ?? ''} />
                        <AvatarFallback className="text-xs">
                          {getInitials(m.user.name)}
                        </AvatarFallback>
                      </Avatar>
                    </button>

                    <span className="flex-1 text-sm font-medium">
                      {m.user.name ?? m.user.email}
                    </span>

                    {isSelected && (
                      <div className="text-right">
                        {splitType === 'EQUAL' && (
                          <span className="text-sm text-gray-600">
                            {formatCurrency(equalShare, currency)}
                          </span>
                        )}
                        {splitType === 'EXACT' && (
                          <Input
                            type="number"
                            step="0.01"
                            min="0"
                            placeholder="0.00"
                            className="w-24 h-7 text-sm"
                            value={exactAmounts[m.user.id] ?? ''}
                            onChange={(e) =>
                              setExactAmounts((p) => ({ ...p, [m.user.id]: e.target.value }))
                            }
                          />
                        )}
                        {splitType === 'PERCENTAGE' && (
                          <div className="flex items-center gap-1">
                            <Input
                              type="number"
                              step="1"
                              min="0"
                              max="100"
                              placeholder="0"
                              className="w-16 h-7 text-sm"
                              value={percentages[m.user.id] ?? ''}
                              onChange={(e) =>
                                setPercentages((p) => ({ ...p, [m.user.id]: e.target.value }))
                              }
                            />
                            <span className="text-xs text-gray-500">%</span>
                          </div>
                        )}
                        {splitType === 'SHARES' && (
                          <div className="flex items-center gap-1">
                            <Input
                              type="number"
                              step="1"
                              min="1"
                              placeholder="1"
                              className="w-16 h-7 text-sm"
                              value={shares[m.user.id] ?? '1'}
                              onChange={(e) =>
                                setShares((p) => ({ ...p, [m.user.id]: e.target.value }))
                              }
                            />
                            <span className="text-xs text-gray-500">shares</span>
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                )
              })}
            </div>
          </div>

          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              Cancel
            </Button>
            <Button type="submit" variant="teal" disabled={loading}>
              {loading ? (isEditing ? 'Saving…' : 'Adding…') : (isEditing ? 'Save changes' : 'Add expense')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
