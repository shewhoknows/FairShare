'use client'
import { useState, useEffect, Suspense } from 'react'
import Link from 'next/link'
import { useRouter, useSearchParams } from 'next/navigation'
import { signIn } from 'next-auth/react'
import { Split, Chrome, CheckCircle, AlertCircle } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { toast } from '@/hooks/use-toast'

function VerificationStatus() {
  const searchParams = useSearchParams()
  const [verificationStatus, setVerificationStatus] = useState<'verified' | 'error' | null>(null)
  const [errorMessage, setErrorMessage] = useState('')

  useEffect(() => {
    const verified = searchParams.get('verified')
    const error = searchParams.get('error')
    
    if (verified === 'true') {
      setVerificationStatus('verified')
      toast({
        title: 'Email verified!',
        description: 'Your email has been verified. You can now sign in.',
      })
    } else if (error) {
      setVerificationStatus('error')
      const errorMessages: Record<string, string> = {
        'missing_token': 'Verification link is invalid.',
        'verification_failed': 'Verification failed. The link may have expired.',
        'server_error': 'Something went wrong. Please try again.',
      }
      setErrorMessage(errorMessages[error] || 'Verification failed.')
    }
  }, [searchParams])

  if (verificationStatus === 'verified') {
    return (
      <div className="mb-4 p-3 bg-green-50 border border-green-200 rounded-lg flex items-center gap-2">
        <CheckCircle className="w-5 h-5 text-green-600" />
        <p className="text-sm text-green-800">Email verified successfully! You can now sign in.</p>
      </div>
    )
  }

  if (verificationStatus === 'error') {
    return (
      <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg flex items-center gap-2">
        <AlertCircle className="w-5 h-5 text-red-600" />
        <p className="text-sm text-red-800">{errorMessage}</p>
      </div>
    )
  }

  return null
}

export default function SignInPage() {
  const router = useRouter()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [googleLoading, setGoogleLoading] = useState(false)

  const handleCredentials = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    try {
      const result = await signIn('credentials', {
        email,
        password,
        redirect: false,
      })

      if (result?.error) {
        toast({
          title: 'Sign in failed',
          description: 'Invalid email or password',
          variant: 'destructive',
        })
      } else {
        router.push('/dashboard')
        router.refresh()
      }
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

        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5 sm:p-8">
          <Suspense fallback={null}>
            <VerificationStatus />
          </Suspense>
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

            <Button type="submit" variant="teal" className="w-full" disabled={loading}>
              {loading ? 'Signing in…' : 'Sign in'}
            </Button>
          </form>
        </div>

        <p className="text-center text-sm text-gray-500 mt-4">
          Don't have an account?{' '}
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
