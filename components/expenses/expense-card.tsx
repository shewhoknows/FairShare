'use client'
import { useState } from 'react'
import { useSession } from 'next-auth/react'
import { Trash2, MessageCircle, ChevronDown, ChevronUp } from 'lucide-react'
import { formatCurrency, formatDate, getCategoryEmoji, getInitials } from '@/lib/utils'
import { Avatar, AvatarImage, AvatarFallback } from '@/components/ui/avatar'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { toast } from '@/hooks/use-toast'

interface ExpenseSplit {
  userId: string
  amount: number
  user: { id: string; name: string | null; image: string | null }
}

interface Comment {
  id: string
  content: string
  createdAt: string
  user: { id: string; name: string | null; image: string | null }
}

interface Expense {
  id: string
  description: string
  amount: number
  currency: string
  date: string
  category: string
  splitType: string
  paidBy: { id: string; name: string | null; image: string | null }
  splits: ExpenseSplit[]
  comments: Comment[]
  group?: { id: string; name: string } | null
}

interface Props {
  expense: Expense
  onDeleted?: () => void
}

export function ExpenseCard({ expense, onDeleted }: Props) {
  const { data: session } = useSession()
  const [expanded, setExpanded] = useState(false)
  const [deleting, setDeleting] = useState(false)
  const [comment, setComment] = useState('')
  const [comments, setComments] = useState(expense.comments)
  const [submitting, setSubmitting] = useState(false)

  const myUserId = session?.user?.id
  const mySplit = expense.splits.find((s) => s.userId === myUserId)
  const iWasPayer = expense.paidBy.id === myUserId
  const myOwed = iWasPayer
    ? expense.splits
        .filter((s) => s.userId !== myUserId)
        .reduce((sum, s) => sum + s.amount, 0)
    : -(mySplit?.amount ?? 0)

  const handleDelete = async () => {
    if (!confirm('Delete this expense?')) return
    setDeleting(true)
    try {
      const res = await fetch(`/api/expenses/${expense.id}`, { method: 'DELETE' })
      if (!res.ok) throw new Error('Failed to delete')
      toast({ title: 'Expense deleted' })
      onDeleted?.()
    } catch {
      toast({ title: 'Error deleting expense', variant: 'destructive' })
    } finally {
      setDeleting(false)
    }
  }

  const handleComment = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!comment.trim()) return
    setSubmitting(true)
    try {
      const res = await fetch(`/api/expenses/${expense.id}/comments`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ content: comment }),
      })
      if (!res.ok) throw new Error()
      const { comment: newComment } = await res.json()
      setComments((c) => [...c, newComment])
      setComment('')
    } catch {
      toast({ title: 'Failed to post comment', variant: 'destructive' })
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="bg-white rounded-lg border border-gray-100 shadow-sm hover:shadow-md transition-shadow">
      <div className="flex items-start gap-3 p-4">
        {/* Category icon */}
        <div className="w-10 h-10 bg-gray-50 rounded-lg flex items-center justify-center text-xl flex-shrink-0">
          {getCategoryEmoji(expense.category)}
        </div>

        {/* Main content */}
        <div className="flex-1 min-w-0">
          <div className="flex items-start justify-between gap-2">
            <div>
              <p className="font-medium text-gray-900">{expense.description}</p>
              <p className="text-xs text-gray-500 mt-0.5">
                {formatDate(expense.date)} ·{' '}
                <span className="font-medium">
                  {expense.paidBy.id === myUserId ? 'You' : expense.paidBy.name ?? 'Someone'}
                </span>{' '}
                paid {formatCurrency(expense.amount, expense.currency)}
              </p>
            </div>

            <div className="text-right flex-shrink-0">
              <p
                className={`font-semibold text-sm ${
                  myOwed > 0 ? 'text-green-600' : myOwed < 0 ? 'text-red-500' : 'text-gray-400'
                }`}
              >
                {myOwed > 0
                  ? `+${formatCurrency(myOwed, expense.currency)}`
                  : myOwed < 0
                  ? formatCurrency(myOwed, expense.currency)
                  : 'settled'}
              </p>
              <p className="text-xs text-gray-400">
                {myOwed > 0 ? 'you get back' : myOwed < 0 ? 'you owe' : ''}
              </p>
            </div>
          </div>

          {/* Tags */}
          <div className="flex items-center gap-2 mt-2">
            <Badge variant="outline" className="text-xs">
              {expense.splitType.charAt(0) + expense.splitType.slice(1).toLowerCase()} split
            </Badge>
            {expense.group && (
              <Badge variant="teal" className="text-xs">
                {expense.group.name}
              </Badge>
            )}
          </div>
        </div>

        {/* Actions */}
        <div className="flex items-center gap-1 flex-shrink-0">
          <Button
            variant="ghost"
            size="icon"
            className="h-8 w-8 text-gray-400 hover:text-gray-600"
            onClick={() => setExpanded((v) => !v)}
          >
            {expanded ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
          </Button>

          {iWasPayer && (
            <Button
              variant="ghost"
              size="icon"
              className="h-8 w-8 text-gray-400 hover:text-red-500"
              onClick={handleDelete}
              disabled={deleting}
            >
              <Trash2 className="w-4 h-4" />
            </Button>
          )}
        </div>
      </div>

      {/* Expanded section */}
      {expanded && (
        <div className="border-t border-gray-50 px-4 py-3 space-y-3">
          {/* Splits */}
          <div>
            <p className="text-xs font-medium text-gray-500 mb-2">SPLIT BREAKDOWN</p>
            <div className="space-y-1.5">
              {expense.splits.map((split) => (
                <div key={split.userId} className="flex items-center gap-2">
                  <Avatar className="w-6 h-6">
                    <AvatarImage src={split.user.image ?? ''} />
                    <AvatarFallback className="text-xs">
                      {getInitials(split.user.name)}
                    </AvatarFallback>
                  </Avatar>
                  <span className="text-sm text-gray-700 flex-1">
                    {split.user.id === myUserId ? 'You' : split.user.name ?? 'Someone'}
                  </span>
                  <span className="text-sm font-medium text-gray-900">
                    {formatCurrency(split.amount, expense.currency)}
                  </span>
                </div>
              ))}
            </div>
          </div>

          {/* Comments */}
          <div>
            <p className="text-xs font-medium text-gray-500 mb-2">
              COMMENTS ({comments.length})
            </p>
            {comments.map((c) => (
              <div key={c.id} className="flex gap-2 mb-2">
                <Avatar className="w-6 h-6 flex-shrink-0">
                  <AvatarImage src={c.user.image ?? ''} />
                  <AvatarFallback className="text-xs">{getInitials(c.user.name)}</AvatarFallback>
                </Avatar>
                <div className="bg-gray-50 rounded-lg px-3 py-1.5 flex-1">
                  <p className="text-xs font-medium text-gray-700">
                    {c.user.id === myUserId ? 'You' : c.user.name}
                  </p>
                  <p className="text-sm text-gray-600">{c.content}</p>
                </div>
              </div>
            ))}

            <form onSubmit={handleComment} className="flex gap-2 mt-2">
              <input
                type="text"
                value={comment}
                onChange={(e) => setComment(e.target.value)}
                placeholder="Add a comment…"
                className="flex-1 text-sm border border-gray-200 rounded-md px-3 py-1.5 focus:outline-none focus:ring-2 focus:ring-teal-500"
              />
              <Button type="submit" size="sm" variant="teal" disabled={submitting || !comment.trim()}>
                Post
              </Button>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
