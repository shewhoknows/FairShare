import { test, expect } from '@playwright/test'
import { getCredentials } from './helpers'

// Auth tests use a fresh unique user — no saved storageState
const ts = Date.now()
const FRESH_USER = {
  name: 'Fresh Tester',
  email: `fresh-${ts}@fairshare-test.com`,
  password: 'TestPass123!',
}

test.describe.serial('Authentication', () => {
  test('1.1 sign up creates account and lands on dashboard', async ({ page }) => {
    await page.goto('/sign-up')
    await page.getByPlaceholder('Jane Doe').fill(FRESH_USER.name)
    await page.getByPlaceholder('you@example.com').fill(FRESH_USER.email)
    await page.getByPlaceholder('••••••••').fill(FRESH_USER.password)
    await page.getByRole('button', { name: 'Create account' }).click()
    await expect(page).toHaveURL(/\/dashboard/, { timeout: 15_000 })
  })

  test('1.2 sign out redirects to landing page', async ({ page }) => {
    await page.goto('/sign-in')
    await page.getByPlaceholder('you@example.com').fill(FRESH_USER.email)
    await page.getByPlaceholder('••••••••').fill(FRESH_USER.password)
    await page.getByRole('button', { name: 'Sign in' }).click()
    await page.waitForURL(/\/dashboard/, { timeout: 15_000 })
    await page.getByRole('button', { name: 'Sign out' }).click()
    await expect(page).toHaveURL(/^\/$|\/(?!dashboard)/, { timeout: 10_000 })
  })

  test('1.3 wrong password shows inline error', async ({ page }) => {
    await page.goto('/sign-in')
    await page.getByPlaceholder('you@example.com').fill(FRESH_USER.email)
    await page.getByPlaceholder('••••••••').fill('wrongpassword')
    await page.getByRole('button', { name: 'Sign in' }).click()
    // Inline red error message should appear (not a redirect)
    await expect(page.locator('p.text-red-600, [class*="text-red"]').first()).toBeVisible({ timeout: 8_000 })
    await expect(page).not.toHaveURL(/\/dashboard/)
  })

  test('1.4 correct credentials sign in successfully', async ({ page }) => {
    await page.goto('/sign-in')
    await page.getByPlaceholder('you@example.com').fill(FRESH_USER.email)
    await page.getByPlaceholder('••••••••').fill(FRESH_USER.password)
    await page.getByRole('button', { name: 'Sign in' }).click()
    await expect(page).toHaveURL(/\/dashboard/, { timeout: 15_000 })
    // Sidebar shows user name
    await expect(page.getByText(FRESH_USER.name)).toBeVisible()
  })

  test('1.5 unauthenticated access to dashboard redirects to sign-in', async ({ page }) => {
    await page.goto('/dashboard')
    await expect(page).toHaveURL(/\/sign-in/, { timeout: 10_000 })
  })

  test('1.6 duplicate email on sign-up shows error', async ({ page }) => {
    const { userA } = getCredentials()
    await page.goto('/sign-up')
    await page.getByPlaceholder('Jane Doe').fill('Duplicate User')
    await page.getByPlaceholder('you@example.com').fill(userA.email)
    await page.getByPlaceholder('••••••••').fill('TestPass123!')
    await page.getByRole('button', { name: 'Create account' }).click()
    // Should show error (toast or inline)
    await expect(page.getByText(/already exists|already registered|account.*exist/i)).toBeVisible({ timeout: 8_000 })
  })
})
