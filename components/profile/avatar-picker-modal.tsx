'use client'
import { useState } from 'react'
import { useSession } from 'next-auth/react'
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { Avatar, AvatarImage, AvatarFallback } from '@/components/ui/avatar'
import { toast } from '@/hooks/use-toast'
import { getInitials } from '@/lib/utils'

const AVATAR_SEEDS = [
  'Felix', 'Zoe', 'Max', 'Luna', 'Orion',
  'Nova', 'Axel', 'Mila', 'Kai',
]

const DICEBEAR_BASE = 'https://api.dicebear.com/7.x/avataaars/svg?seed='

function avatarUrl(seed: string) {
  return `${DICEBEAR_BASE}${encodeURIComponent(seed)}`
}

interface Props {
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function AvatarPickerModal({ open, onOpenChange }: Props) {
  const { data: session, update } = useSession()
  const [selected, setSelected] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  const currentImage = session?.user?.image ?? ''

  const handleSave = async () => {
    const imageUrl = selected
    if (!imageUrl || !session?.user?.id) return

    setSaving(true)
    try {
      const res = await fetch(`/api/users/${session.user.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ image: imageUrl }),
      })
      if (!res.ok) {
        const data = await res.json()
        throw new Error(data.error ?? 'Failed to update avatar')
      }
      await update({ image: imageUrl, name: session.user.name })
      toast({ title: 'Avatar updated!' })
      onOpenChange(false)
      setSelected(null)
    } catch (err: any) {
      toast({ title: 'Error', description: err.message, variant: 'destructive' })
    } finally {
      setSaving(false)
    }
  }

  const handleClose = () => {
    setSelected(null)
    onOpenChange(false)
  }

  const previewUrl = selected ?? currentImage

  return (
    <Dialog open={open} onOpenChange={handleClose}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Choose your avatar</DialogTitle>
        </DialogHeader>

        <div className="flex justify-center py-2">
          <Avatar className="w-20 h-20">
            <AvatarImage src={previewUrl} />
            <AvatarFallback className="text-2xl">
              {getInitials(session?.user?.name)}
            </AvatarFallback>
          </Avatar>
        </div>

        <div className="grid grid-cols-3 gap-3">
          {AVATAR_SEEDS.map((seed) => {
            const url = avatarUrl(seed)
            const isActive = (selected ?? currentImage) === url
            return (
              <button
                key={seed}
                type="button"
                onClick={() => setSelected(url)}
                className={`p-1.5 rounded-xl border-2 transition-colors ${
                  isActive
                    ? 'border-teal-500 bg-teal-50'
                    : 'border-transparent hover:border-gray-200'
                }`}
              >
                <Avatar className="w-full aspect-square">
                  <AvatarImage src={url} />
                  <AvatarFallback>{seed[0]}</AvatarFallback>
                </Avatar>
              </button>
            )
          })}
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={handleClose}>Cancel</Button>
          <Button
            variant="teal"
            onClick={handleSave}
            disabled={saving || !selected || selected === currentImage}
          >
            {saving ? 'Saving…' : 'Save avatar'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
