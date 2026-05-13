'use client'
import { useEffect, useState } from 'react'
import Link from 'next/link'
import { Plus, Users } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Avatar, AvatarImage, AvatarFallback } from '@/components/ui/avatar'
import { CreateGroupModal } from '@/components/groups/create-group-modal'
import { getInitials } from '@/lib/utils'

const CATEGORY_EMOJI: Record<string, string> = {
  TRIP: '✈️', HOME: '🏠', WORK: '💼', COUPLE: '💑', OTHER: '📦',
}

export default function GroupsPage() {
  const [groups, setGroups] = useState<any[]>([])
  const [loading, setLoading] = useState(true)
  const [createOpen, setCreateOpen] = useState(false)

  const fetchGroups = async () => {
    try {
      const res = await fetch('/api/groups')
      const data = await res.json()
      setGroups(data.groups ?? [])
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { fetchGroups() }, [])

  return (
    <div className="max-w-3xl mx-auto px-4 sm:px-6 py-8">
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Groups</h1>
          <p className="text-gray-500 text-sm mt-0.5">Manage your shared expense groups</p>
        </div>
        <Button variant="teal" onClick={() => setCreateOpen(true)}>
          <Plus className="w-4 h-4 mr-1" />
          New group
        </Button>
      </div>

      {loading ? (
        <div className="space-y-3">
          {[1, 2, 3].map((i) => (
            <div key={i} className="h-20 bg-gray-100 rounded-xl animate-pulse" />
          ))}
        </div>
      ) : groups.length === 0 ? (
        <div className="bg-white rounded-xl border border-gray-100 p-16 text-center">
          <Users className="w-12 h-12 text-gray-300 mx-auto mb-4" />
          <h3 className="font-semibold text-gray-700 mb-1">No groups yet</h3>
          <p className="text-gray-400 text-sm mb-4">
            Create a group to start splitting expenses with friends
          </p>
          <Button variant="teal" onClick={() => setCreateOpen(true)}>
            <Plus className="w-4 h-4 mr-1" />
            Create your first group
          </Button>
        </div>
      ) : (
        <div className="space-y-3">
          {groups.map((group) => (
            <Link key={group.id} href={`/groups/${group.id}`}>
              <div className="bg-white rounded-xl border border-gray-100 p-4 hover:shadow-md transition-all cursor-pointer flex items-center gap-4">
                <div className="w-12 h-12 bg-teal-50 rounded-xl flex items-center justify-center text-2xl flex-shrink-0">
                  {CATEGORY_EMOJI[group.category] ?? '📦'}
                </div>
                <div className="flex-1 min-w-0">
                  <h3 className="font-semibold text-gray-900">{group.name}</h3>
                  {group.description && (
                    <p className="text-xs text-gray-500 truncate">{group.description}</p>
                  )}
                  <p className="text-xs text-gray-400 mt-0.5">
                    {group._count.expenses} expenses · {group.members.length} members
                  </p>
                </div>
                <div className="flex -space-x-2 flex-shrink-0">
                  {group.members.slice(0, 4).map((m: any) => (
                    <Avatar key={m.user.id} className="w-7 h-7 border-2 border-white">
                      <AvatarImage src={m.user.image ?? ''} />
                      <AvatarFallback className="text-xs">{getInitials(m.user.name)}</AvatarFallback>
                    </Avatar>
                  ))}
                  {group.members.length > 4 && (
                    <div className="w-7 h-7 rounded-full bg-gray-100 border-2 border-white flex items-center justify-center text-xs text-gray-500">
                      +{group.members.length - 4}
                    </div>
                  )}
                </div>
              </div>
            </Link>
          ))}
        </div>
      )}

      <CreateGroupModal open={createOpen} onOpenChange={setCreateOpen} />
    </div>
  )
}
