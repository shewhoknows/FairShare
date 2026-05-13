import { chromium, request } from '@playwright/test'
import * as fs from 'fs'
import * as path from 'path'

const BASE_URL = process.env.TEST_URL ?? 'https://fairshare-production-e481.up.railway.app'
const ts = Date.now()

export const USER_A = {
  name: 'Test UserA',
  email: `usera-${ts}@fairshare-test.com`,
  password: 'TestPass123!',
}

export const USER_B = {
  name: 'Test UserB',
  email: `userb-${ts}@fairshare-test.com`,
  password: 'TestPass123!',
}

async function registerUser(user: typeof USER_A) {
  const ctx = await request.newContext({ baseURL: BASE_URL })
  const res = await ctx.post('/api/auth/register', {
    data: { name: user.name, email: user.email, password: user.password },
  })
  if (!res.ok()) {
    const body = await res.json().catch(() => ({}))
    throw new Error(`Registration failed for ${user.email}: ${(body as any).error ?? res.status()}`)
  }
  await ctx.dispose()
}

async function signInAndSaveState(user: typeof USER_A, stateFile: string) {
  const browser = await chromium.launch()
  const context = await browser.newContext()
  const page = await context.newPage()

  await page.goto(`${BASE_URL}/sign-in`)
  await page.getByPlaceholder('you@example.com').fill(user.email)
  await page.getByPlaceholder('••••••••').fill(user.password)
  await page.getByRole('button', { name: 'Sign in' }).click()
  await page.waitForURL('**/dashboard', { timeout: 20_000 })

  await context.storageState({ path: stateFile })
  await browser.close()
}

export default async function globalSetup() {
  const setupDir = path.join(__dirname)

  console.log('\n🔧 Global setup — creating test users...')
  await registerUser(USER_A)
  await registerUser(USER_B)

  console.log('🔑 Signing in and saving auth state...')
  await signInAndSaveState(USER_A, path.join(setupDir, '.auth-a.json'))
  await signInAndSaveState(USER_B, path.join(setupDir, '.auth-b.json'))

  fs.writeFileSync(
    path.join(setupDir, '.credentials.json'),
    JSON.stringify({ userA: USER_A, userB: USER_B }, null, 2)
  )

  console.log(`✅ Setup complete — User A: ${USER_A.email} | User B: ${USER_B.email}\n`)
}
