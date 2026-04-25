'use client'
import { useState, Suspense } from 'react'
import Link from 'next/link'
import { useRouter, useSearchParams } from 'next/navigation'
import { signIn } from 'next-auth/react'
import { Split, Chrome } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { toast } from '@/hooks/use-toast'

function RegisteredBanner() {
  const searchParams = useSearchParams()
  if (searchParams.get('registered') !== 'true') return null
  return (
    <div className="bg-teal-50 border border-teal-200 text-teal-800 text-sm rounded-xl px-4 py-3 mb-4">
      Account created! Sign in below to get started.
    </div>
  )
}

export default function SignInPage() {
  const router = useRouter()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [googleLoading, setGoogleLoading] = useState(false)
  const [errorMsg, setErrorMsg] = useState('')

  const handleCredentials = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setErrorMsg('')
    console.log('[sign-in] attempting credentials sign-in for:', email)
    try {
      const result = await signIn('credentials', {
        email,
        password,
        redirect: false,
      })

      console.log('[sign-in] result:', result)

      if (!result) {
        const msg = 'No response from authentication server'
        console.error('[sign-in] error: result is null/undefined')
        setErrorMsg(msg)
        toast({ title: 'Sign in failed', description: msg, variant: 'destructive' })
      } else if (result.error) {
        const msg = result.error === 'CredentialsSignin'
          ? 'Invalid email or password'
          : result.error
        console.error('[sign-in] error:', result.error, 'status:', result.status)
        setErrorMsg(msg)
        toast({ title: 'Sign in failed', description: msg, variant: 'destructive' })
      } else if (!result.ok) {
        const msg = `Sign in failed (status ${result.status})`
        console.error('[sign-in] not ok:', result)
        setErrorMsg(msg)
        toast({ title: 'Sign in failed', description: msg, variant: 'destructive' })
      } else {
        console.log('[sign-in] success, redirecting to dashboard')
        router.push('/dashboard')
        router.refresh()
      }
    } catch (err: any) {
      console.error('[sign-in] exception:', err)
      const msg = err?.message ?? 'Unexpected error during sign in'
      setErrorMsg(msg)
      toast({ title: 'Sign in failed', description: msg, variant: 'destructive' })
    } finally {
      setLoading(false)
    }
  }

  const handleGoogle = async () => {
    setGoogleLoading(true)
    await signIn('google', { callbackUrl: '/dashboard' })
  }

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col items-center justify-center px-4">
      <div className="w-full max-w-sm">
        {/* Logo */}
        <div className="flex items-center justify-center gap-2 mb-8">
          <div className="w-10 h-10 bg-teal-600 rounded-xl flex items-center justify-center">
            <Split className="w-5 h-5 text-white" />
          </div>
          <span className="text-2xl font-bold text-gray-900">FairShare</span>
        </div>

        <Suspense>
          <RegisteredBanner />
        </Suspense>

        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5 sm:p-8">
          <h1 className="text-2xl font-bold text-gray-900 mb-1">Welcome back</h1>
          <p className="text-gray-500 text-sm mb-6">Sign in to your account</p>

          {/* Google */}
          <Button
            variant="outline"
            className="w-full gap-2 mb-4"
            onClick={handleGoogle}
            disabled={googleLoading}
          >
            <Chrome className="w-4 h-4" />
            {googleLoading ? 'Redirecting…' : 'Continue with Google'}
          </Button>

          <div className="relative mb-4">
            <div className="absolute inset-0 flex items-center">
              <div className="w-full border-t border-gray-200" />
            </div>
            <div className="relative flex justify-center text-xs">
              <span className="px-2 bg-white text-gray-400">or</span>
            </div>
          </div>

          {/* Email/Password */}
          <form onSubmit={handleCredentials} className="space-y-4">
            <div>
              <Label>Email</Label>
              <Input
                type="email"
                placeholder="you@example.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                autoComplete="email"
              />
            </div>

            <div>
              <Label>Password</Label>
              <Input
                type="password"
                placeholder="••••••••"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                autoComplete="current-password"
              />
            </div>

            {errorMsg && (
              <p className="text-sm text-red-600 bg-red-50 border border-red-200 rounded-lg px-3 py-2">
                {errorMsg}
              </p>
            )}

            <Button type="submit" variant="teal" className="w-full" disabled={loading}>
              {loading ? 'Signing in…' : 'Sign in'}
            </Button>
          </form>
        </div>

        <p className="text-center text-sm text-gray-500 mt-4">
          Don&apos;t have an account?{' '}
          <Link href="/sign-up" className="text-teal-600 font-medium hover:underline">
            Sign up free
          </Link>
        </p>

        {/* Demo hint */}
        <p className="text-center text-xs text-gray-400 mt-3">
          Demo: alice@example.com / password123
        </p>
      </div>
    </div>
  )
}
