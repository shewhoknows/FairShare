import { test, expect } from '@playwright/test'
import { AUTH_A, getCredentials } from './helpers'

test.use({ storageState: AUTH_A })

test.describe.serial('Friends', () => {
  test('3.1 friends page renders', async ({ page }) => {
    await page.goto('/friends')
    await expect(page.getByRole('heading', { name: 'Friends' })).toBeVisible({ timeout: 15_000 })
    await expect(page).toHaveURL(/\/friends/)
  })

  test('3.2 add friend by email', async ({ page }) => {
    const { userB } = getCredentials()
    await page.goto('/friends')
    await expect(page.getByRole('heading', { name: 'Friends' })).toBeVisible({ timeout: 15_000 })

    await page.getByRole('button', { name: /add friend/i }).click()
    await expect(page.getByRole('dialog')).toBeVisible()

    await page.getByRole('dialog').getByPlaceholder(/email/i).fill(userB.email)
    await page.getByRole('dialog').getByRole('button', { name: 'Add friend' }).click()

    await expect(page.getByText(userB.name)).toBeVisible({ timeout: 15_000 })
  })

  test('3.3 non-existent email shows error', async ({ page }) => {
    await page.goto('/friends')
    await expect(page.getByRole('heading', { name: 'Friends' })).toBeVisible({ timeout: 15_000 })

    await page.getByRole('button', { name: /add friend/i }).click()
    await expect(page.getByRole('dialog')).toBeVisible()

    await page.getByRole('dialog').getByPlaceholder(/email/i).fill('nobody-real@notexist-xyz.com')
    await page.getByRole('dialog').getByRole('button', { name: 'Add friend' }).click()

    await expect(page.getByText(/not found|no user|doesn't exist/i)).toBeVisible({ timeout: 8_000 })
  })

  test('3.4 friend balance shows INR symbol', async ({ page }) => {
    await page.goto('/friends')
    await expect(page.getByRole('heading', { name: 'Friends' })).toBeVisible({ timeout: 15_000 })
    const visibleText = await page.locator('body').innerText()
    expect(visibleText).toContain('₹')
    expect(visibleText).not.toMatch(/\$\d+\.\d{2}/)
  })
})
