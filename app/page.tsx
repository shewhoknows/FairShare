import Link from 'next/link'
import { Split, ArrowRight, CheckCircle, BarChart3, Users, Zap } from 'lucide-react'
import { Button } from '@/components/ui/button'

const features = [
  {
    icon: Users,
    title: 'Groups & Friends',
    description: 'Create groups for trips, home, or anything. Add friends and track who owes what.',
  },
  {
    icon: Split,
    title: 'Flexible Splits',
    description: 'Split equally, by exact amounts, percentages, or custom shares.',
  },
  {
    icon: BarChart3,
    title: 'Real-time Balances',
    description: 'Instantly see net balances and the simplified debt graph across all your groups.',
  },
  {
    icon: Zap,
    title: 'Simplify Debts',
    description: 'Our algorithm minimizes transactions needed to settle up the whole group at once.',
  },
]

const steps = [
  { step: '1', title: 'Create a group', desc: 'Add your friends or roommates to a shared group.' },
  { step: '2', title: 'Log expenses',   desc: 'Add expenses as you go—dinner, flights, groceries.' },
  { step: '3', title: 'Settle up',      desc: 'See exactly who owes what and record payments.' },
]

export default function LandingPage() {
  return (
    <div className="min-h-screen bg-white">
      {/* Nav */}
      <header className="border-b border-gray-100">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 h-16 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 bg-teal-600 rounded-lg flex items-center justify-center">
              <Split className="w-4 h-4 text-white" />
            </div>
            <span className="text-xl font-bold text-gray-900">FairShare</span>
          </div>
          <div className="flex items-center gap-3">
            <Link href="/sign-in">
              <Button variant="ghost" size="sm">Sign in</Button>
            </Link>
            <Link href="/sign-up">
              <Button variant="teal" size="sm">Get started free</Button>
            </Link>
          </div>
        </div>
      </header>

      {/* Hero */}
      <section className="max-w-6xl mx-auto px-4 sm:px-6 py-20 text-center">
        <div className="inline-flex items-center gap-2 bg-teal-50 text-teal-700 text-sm font-medium px-3 py-1 rounded-full mb-6">
          <Zap className="w-3.5 h-3.5" />
          Free expense sharing for everyone
        </div>
        <h1 className="text-5xl sm:text-6xl font-bold text-gray-900 mb-6 leading-tight">
          Split expenses,<br />
          <span className="text-teal-600">not friendships</span>
        </h1>
        <p className="text-xl text-gray-500 mb-10 max-w-2xl mx-auto">
          FairShare makes it easy to track shared expenses and settle debts with friends,
          family, and roommates. No spreadsheets needed.
        </p>
        <div className="flex flex-col sm:flex-row gap-3 justify-center">
          <Link href="/sign-up">
            <Button variant="teal" size="lg" className="gap-2">
              Start splitting for free
              <ArrowRight className="w-4 h-4" />
            </Button>
          </Link>
          <Link href="/sign-in">
            <Button variant="outline" size="lg">Sign in to your account</Button>
          </Link>
        </div>
      </section>

      {/* Features */}
      <section className="bg-gray-50 py-20">
        <div className="max-w-6xl mx-auto px-4 sm:px-6">
          <h2 className="text-3xl font-bold text-gray-900 text-center mb-12">
            Everything you need to split fairly
          </h2>
          <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-6">
            {features.map(({ icon: Icon, title, description }) => (
              <div key={title} className="bg-white rounded-xl p-6 border border-gray-100 shadow-sm">
                <div className="w-10 h-10 bg-teal-50 rounded-lg flex items-center justify-center mb-4">
                  <Icon className="w-5 h-5 text-teal-600" />
                </div>
                <h3 className="font-semibold text-gray-900 mb-2">{title}</h3>
                <p className="text-sm text-gray-500">{description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* How it works */}
      <section className="max-w-6xl mx-auto px-4 sm:px-6 py-20">
        <h2 className="text-3xl font-bold text-gray-900 text-center mb-12">
          How it works
        </h2>
        <div className="grid sm:grid-cols-3 gap-8">
          {steps.map(({ step, title, desc }) => (
            <div key={step} className="text-center">
              <div className="w-12 h-12 bg-teal-600 text-white rounded-full flex items-center justify-center text-xl font-bold mx-auto mb-4">
                {step}
              </div>
              <h3 className="font-semibold text-gray-900 mb-2">{title}</h3>
              <p className="text-sm text-gray-500">{desc}</p>
            </div>
          ))}
        </div>
      </section>

      {/* CTA */}
      <section className="bg-teal-600 py-16">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 text-center">
          <h2 className="text-3xl font-bold text-white mb-4">
            Ready to split fairly?
          </h2>
          <p className="text-teal-100 mb-8">
            Join thousands of people who use FairShare to manage shared expenses.
          </p>
          <Link href="/sign-up">
            <Button size="lg" className="bg-white text-teal-700 hover:bg-teal-50 gap-2">
              Get started — it's free
              <ArrowRight className="w-4 h-4" />
            </Button>
          </Link>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-gray-100 py-8">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-6 h-6 bg-teal-600 rounded flex items-center justify-center">
              <Split className="w-3 h-3 text-white" />
            </div>
            <span className="text-sm font-semibold text-gray-700">FairShare</span>
          </div>
          <p className="text-xs text-gray-400">© 2024 FairShare. Split expenses fairly.</p>
        </div>
      </footer>
    </div>
  )
}
