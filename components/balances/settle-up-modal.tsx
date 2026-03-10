'use client'
import { useState } from 'react'
import {
  Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter,
} from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Avatar, AvatarImage, AvatarFallback } from '@/components/ui/avatar'
import { toast } from '@/hooks/use-toast'
import { formatCurrency, getInitials } from '@/lib/utils'

interface Props {
  open: boolean
  onOpenChange: (open: boolean) => void
  receiverId: string
  receiverName: string | null
  receiverImage: string | null
  suggestedAmount: number
  currency?: string
  groupId?: string
  onSuccess?: () => void
}

export function SettleUpModal({
  open,
  onOpenChange,
  receiverId,
  receiverName,
  receiverImage,
  suggestedAmount,
  currency = 'USD',
  groupId,
  onSuccess,
}: Props) {
  const [amount, setAmount] = useState(suggestedAmount.toFixed(2))
  const [note, setNote] = useState('')
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    const numAmount = parseFloat(amount)
    if (isNaN(numAmount) || numAmount <= 0) return

    setLoading(true)
    try {
      const res = await fetch('/api/transactions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          receiverId,
          amount: numAmount,
          currency,
          groupId,
          note: note || undefined,
        }),
      })

      if (!res.ok) {
        const data = await res.json()
        throw new Error(data.error ?? 'Failed to record payment')
      }

      toast({ title: `Payment of ${formatCurrency(numAmount, currency)} recorded!`, variant: 'default' })
      onOpenChange(false)
      onSuccess?.()
    } catch (err: any) {
      toast({ title: 'Error', description: err.message, variant: 'destructive' })
    } finally {
      setLoading(false)
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-sm">
        <DialogHeader>
          <DialogTitle>Settle up</DialogTitle>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="flex items-center gap-3 p-3 bg-gray-50 rounded-lg">
            <Avatar className="w-10 h-10">
              <AvatarImage src={receiverImage ?? ''} />
              <AvatarFallback>{getInitials(receiverName)}</AvatarFallback>
            </Avatar>
            <div>
              <p className="text-sm font-medium">Paying {receiverName ?? 'user'}</p>
              <p className="text-xs text-gray-500">
                Suggested: {formatCurrency(suggestedAmount, currency)}
              </p>
            </div>
          </div>

          <div>
            <Label>Amount</Label>
            <div className="relative mt-1">
              <span className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500 text-sm">
                {currency}
              </span>
              <Input
                type="number"
                step="0.01"
                min="0.01"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                className="pl-12"
                required
              />
            </div>
          </div>

          <div>
            <Label>Note (optional)</Label>
            <Input
              placeholder="e.g. Venmo, Zelle, cash…"
              value={note}
              onChange={(e) => setNote(e.target.value)}
            />
          </div>

          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              Cancel
            </Button>
            <Button type="submit" variant="teal" disabled={loading}>
              {loading ? 'Recording…' : 'Record payment'}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
