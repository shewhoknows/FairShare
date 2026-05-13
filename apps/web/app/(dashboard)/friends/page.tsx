'use client'
import { useEffect, useState } from 'react'
import { Plus, UserCircle } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Avatar, AvatarImage, AvatarFallback } from '@/components/ui/avatar'
import { AddFriendModal } from '@/components/friends/add-friend-modal'
import { getInitials } from '@/lib/utils'

export default function FriendsPage() {
  const [friends, setFriends] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [addOpen, setAddOpen] = useState(false)

  const fetchFriends = async () => {
    try {
      const res = await fetch('/api/friends')
      const data = await res.json()
      setFriends(data.friends ?? [])
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { fetchFriends() }, [])

  return (
    <div className="max-w-2xl mx-auto px-4 sm:px-6 py-8">
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Friends</h1>
          <p className="text-gray-500 text-sm mt-0.5">People you split expenses with</p>
        </div>
        <Button variant="teal" onClick={() => setAddOpen(true)}>
          <Plus className="w-4 h-4 mr-1" />
          Add friend
        </Button>
      </div>

      {loading ? (
        <div className="space-y-3">
          {[1, 2, 3].map((i) => (
            <div key={i} className="h-16 bg-gray-100 rounded-xl animate-pulse" />
          ))}
        </div>
      ) : friends.length === 0 ? (
        <div className="bg-white rounded-xl border border-gray-100 p-16 text-center">
          <UserCircle className="w-12 h-12 text-gray-300 mx-auto mb-4" />
          <h3 className="font-semibold text-gray-700 mb-1">No friends yet</h3>
          <p className="text-gray-400 text-sm mb-4">
            Add friends to split expenses outside of groups
          </p>
          <Button variant="teal" onClick={() => setAddOpen(true)}>
            <Plus className="w-4 h-4 mr-1" />
            Add your first friend
          </Button>
        </div>
      ) : (
        <div className="space-y-2">
          {friends.map((friend) => (
            <div
              key={friend.id}
              className="flex items-center gap-3 bg-white rounded-xl border border-gray-100 p-4"
            >
              <Avatar className="w-10 h-10">
                <AvatarImage src={friend.image ?? ''} />
                <AvatarFallback>{getInitials(friend.name)}</AvatarFallback>
              </Avatar>
              <div className="flex-1 min-w-0">
                <p className="font-medium text-gray-900">{friend.name ?? friend.email}</p>
                <p className="text-xs text-gray-500">{friend.email}</p>
              </div>
            </div>
          ))}
        </div>
      )}

      <AddFriendModal open={addOpen} onOpenChange={setAddOpen} onSuccess={fetchFriends} />
    </div>
  )
}
