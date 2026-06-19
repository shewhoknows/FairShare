'use client'
import { useEffect, useState } from 'react'
import { Activity } from 'lucide-react'
import { Avatar, AvatarImage, AvatarFallback } from '@/components/ui/avatar'
import { formatRelativeDate, getInitials } from '@/lib/utils'

const TYPE_COLOR: Record<string, string> = {
  EXPENSE_CREATED: 'bg-teal-100 text-teal-700',
  EXPENSE_UPDATED: 'bg-blue-100 text-blue-700',
  EXPENSE_DELETED: 'bg-red-100 text-red-700',
  PAYMENT_MADE:    'bg-green-100 text-green-700',
  GROUP_CREATED:   'bg-purple-100 text-purple-700',
  GROUP_JOINED:    'bg-indigo-100 text-indigo-700',
  FRIEND_ADDED:    'bg-pink-100 text-pink-700',
  COMMENT_ADDED:   'bg-gray-100 text-gray-600',
}

const TYPE_LABEL: Record<string, string> = {
  EXPENSE_CREATED: 'Expense',
  EXPENSE_UPDATED: 'Updated',
  EXPENSE_DELETED: 'Deleted',
  PAYMENT_MADE:    'Payment',
  GROUP_CREATED:   'Group',
  GROUP_JOINED:    'Joined',
  FRIEND_ADDED:    'Friend',
  COMMENT_ADDED:   'Comment',
}

export default function ActivityPage() {
  const [activity, setActivity] = useState<any[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetch('/api/activity')
      .then((r) => r.json())
      .then((d) => setActivity(d.activity ?? []))
      .finally(() => setLoading(false))
  }, [])

  return (
    <div className="max-w-2xl mx-auto px-4 sm:px-6 py-8">
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-gray-900">Activity</h1>
        <p className="text-gray-500 text-sm mt-0.5">Recent updates from your groups and friends</p>
      </div>

      {loading ? (
        <div className="space-y-3">
          {[1, 2, 3, 4, 5].map((i) => (
            <div key={i} className="h-16 bg-gray-100 rounded-xl animate-pulse" />
          ))}
        </div>
      ) : activity.length === 0 ? (
        <div className="bg-white rounded-xl border border-gray-100 p-16 text-center">
          <Activity className="w-12 h-12 text-gray-300 mx-auto mb-4" />
          <h3 className="font-semibold text-gray-700 mb-1">No activity yet</h3>
          <p className="text-gray-400 text-sm">
            Your expense activity will appear here
          </p>
        </div>
      ) : (
        <div className="space-y-2">
          {activity.map((item) => (
            <div
              key={item.id}
              className="flex items-start gap-3 bg-white rounded-xl border border-gray-100 p-4"
            >
              <Avatar className="w-9 h-9 flex-shrink-0">
                <AvatarImage src={item.user?.image ?? ''} />
                <AvatarFallback className="text-xs">{getInitials(item.user?.name)}</AvatarFallback>
              </Avatar>
              <div className="flex-1 min-w-0">
                <p className="text-sm text-gray-800">{item.description}</p>
                <p className="text-xs text-gray-400 mt-0.5">
                  {formatRelativeDate(item.createdAt)}
                </p>
              </div>
              <span
                className={`text-xs font-medium px-2 py-0.5 rounded-full flex-shrink-0 ${
                  TYPE_COLOR[item.type] ?? 'bg-gray-100 text-gray-600'
                }`}
              >
                {TYPE_LABEL[item.type] ?? item.type}
              </span>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
