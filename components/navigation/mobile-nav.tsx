'use client'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { signOut } from 'next-auth/react'
import { LayoutDashboard, Users, Activity, UserCircle, LogOut } from 'lucide-react'
import { cn } from '@/lib/utils'

const navItems = [
  { href: '/dashboard', label: 'Home',    icon: LayoutDashboard },
  { href: '/groups',    label: 'Groups',  icon: Users },
  { href: '/friends',   label: 'Friends', icon: UserCircle },
  { href: '/activity',  label: 'Activity', icon: Activity },
]

export function MobileNav() {
  const pathname = usePathname()

  return (
    <nav className="md:hidden fixed bottom-0 left-0 right-0 z-50 bg-white border-t border-gray-100">
      <div className="flex">
        {navItems.map(({ href, label, icon: Icon }) => {
          const active = pathname === href || pathname.startsWith(`${href}/`)
          return (
            <Link
              key={href}
              href={href}
              className={cn(
                'flex-1 flex flex-col items-center gap-1 py-3 text-xs font-medium transition-colors',
                active ? 'text-teal-600' : 'text-gray-400'
              )}
            >
              <Icon className="w-5 h-5" />
              {label}
            </Link>
          )
        })}
        <button
          onClick={() => signOut({ callbackUrl: '/' })}
          className="flex-1 flex flex-col items-center gap-1 py-3 text-xs font-medium text-gray-400 transition-colors hover:text-gray-600"
        >
          <LogOut className="w-5 h-5" />
          Sign out
        </button>
      </div>
    </nav>
  )
}
