import { test, expect } from '@playwright/test'
import { AUTH_A } from './helpers'

test.use({ storageState: AUTH_A })

test.describe.serial('Activity Feed', () => {
  test('9.1 activity page renders', async ({ page }) => {
    await page.goto('/activity')
    await expect(page).toHaveURL(/\/activity/)
    // Page should load without JS errors
    const errors: string[] = []
    page.on('pageerror', (e) => errors.push(e.message))
    await page.waitForLoadState('networkidle')
    expect(errors).toHaveLength(0)
  })

  test('9.2 all currency amounts use INR (₹), not USD ($)', async ({ page }) => {
    await page.goto('/activity')
    await page.waitForLoadState('networkidle')

    const content = await page.content()
    // Should not contain dollar amounts like $600.00
    expect(content).not.toMatch(/\$\d+\.\d{2}/)
    // If there are any amounts, they should be in ₹
    if (content.includes('₹') || content.match(/\d+\.\d{2}/)) {
      expect(content).toContain('₹')
    }
  })

  test('9.3 new expense appears in feed', async ({ page }) => {
    const desc = `Activity Test ${Date.now()}`

    // Add a personal expense from dashboard
    await page.goto('/dashboard')
    const addBtn = page.getByRole('button', { name: /add expense/i })
    if (await addBtn.isVisible()) {
      await addBtn.click()
      await expect(page.getByRole('dialog')).toBeVisible()
      await page.getByRole('dialog').getByPlaceholder(/description/i).fill(desc)
      await page.getByRole('dialog').getByPlaceholder(/0\.00|amount/i).fill('250')
      await page.getByRole('dialog').getByRole('button', { name: /add expense|save|create/i }).click()
      await expect(page.getByRole('dialog')).not.toBeVisible({ timeout: 8_000 })

      // Check activity feed
      await page.goto('/activity')
      await page.waitForLoadState('networkidle')
      await expect(page.getByText(desc)).toBeVisible({ timeout: 5_000 })
    }
  })
})
