'use client'
import { useEffect } from 'react'
import { SessionProvider } from 'next-auth/react'

export function Providers({ children }: { children: React.ReactNode }) {
  useEffect(() => {
    document.documentElement.dataset.appReady = 'true'

    return () => {
      delete document.documentElement.dataset.appReady
    }
  }, [])

  return <SessionProvider>{children}</SessionProvider>
}
