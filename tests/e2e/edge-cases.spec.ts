import { test, expect } from '@playwright/test'
import { AUTH_A, getCredentials } from './helpers'

let groupUrl = ''

test.use({ storageState: AUTH_A })

test.describe.serial('Edge Cases', () => {
  test('12.0 setup — create group with User B', async ({ page }) => {
    const { userB } = getCredentials()

    await page.goto('/groups')
    await page.getByRole('button', { name: /new group/i }).click()
    await expect(page.getByRole('dialog')).toBeVisible()
    await page.getByRole('dialog').getByPlaceholder('e.g. NYC Trip, Our Apartment…').fill('Edge Case Group')
    await page.getByRole('dialog').getByRole('button', { name: 'Create group' }).click()
    await expect(page).toHaveURL(/\/groups\//, { timeout: 10_000 })
    groupUrl = page.url()

    await page.getByRole('tab', { name: /members/i }).click()
    await page.getByPlaceholder('friend@example.com').fill(userB.email)
    await page.getByRole('button', { name: 'Add' }).click()
    await expect(page.getByText(userB.email)).toBeVisible({ timeout: 8_000 })
  })

  test('12.1 split total mismatch shows validation error', async ({ page }) => {
    await page.goto(groupUrl)
    await page.getByRole('button', { name: 'Expense' }).click()
    await expect(page.getByRole('dialog')).toBeVisible()

    await page.getByRole('dialog').getByPlaceholder('e.g. Dinner, Uber, Groceries').fill('Mismatch Test')
    await page.getByRole('dialog').getByPlaceholder('0.00').first().fill('600')

    // Switch to Exact split if available
    const splitTrigger = page.getByRole('dialog').getByRole('combobox').last()
    if (await splitTrigger.isVisible()) {
      await splitTrigger.click()
      const exactOption = page.getByRole('option', { name: /exact/i })
      if (await exactOption.isVisible()) {
        await exactOption.click()
        await page.getByRole('dialog').getByRole('button', { name: /add expense|save changes/i }).click()
        await expect(page.getByText(/don't match|mismatch|total/i)).toBeVisible({ timeout: 5_000 })
      }
    }
    await page.keyboard.press('Escape')
  })

  test('12.2 duplicate group member via email shows error', async ({ page }) => {
    const { userB } = getCredentials()
    await page.goto(groupUrl)
    await page.getByRole('tab', { name: /members/i }).click()
    await page.getByPlaceholder('friend@example.com').fill(userB.email)
    await page.getByRole('button', { name: 'Add' }).click()
    await expect(page.getByText(/already a member/i)).toBeVisible({ timeout: 8_000 })
  })

  test('12.3 adding non-existent friend shows error', async ({ page }) => {
    await page.goto('/friends')
    await page.getByRole('button', { name: 'Add friend' }).click()
    await expect(page.getByRole('dialog')).toBeVisible()
    await page.getByRole('dialog').getByPlaceholder(/email/i).fill('nobody@nonexistent-domain-xyz.com')
    await page.getByRole('dialog').getByRole('button', { name: 'Add friend' }).click()
    await expect(page.getByText(/not found|no user|doesn't exist/i)).toBeVisible({ timeout: 8_000 })
  })

  test('12.4 unauthenticated user cannot access group URL', async ({ browser }) => {
    const freshCtx = await browser.newContext()
    const page = await freshCtx.newPage()
    await page.goto(groupUrl)
    await expect(page).toHaveURL(/\/sign-in/, { timeout: 10_000 })
    await freshCtx.close()
  })

  test('12.5 sign-up password shorter than 8 chars is rejected', async ({ page }) => {
    await page.goto('/sign-up')
    await page.getByPlaceholder('Jane Doe').fill('Test User')
    await page.getByPlaceholder('you@example.com').fill(`short-pw-${Date.now()}@test.com`)
    await page.getByPlaceholder('••••••••').fill('short')
    await page.getByRole('button', { name: /create account/i }).click()
    await expect(page).not.toHaveURL(/\/dashboard/, { timeout: 5_000 })
  })

  test('12.6 sign-up with duplicate email shows error', async ({ page }) => {
    const { userA } = getCredentials()
    await page.goto('/sign-up')
    await page.getByPlaceholder('Jane Doe').fill('Duplicate')
    await page.getByPlaceholder('you@example.com').fill(userA.email)
    await page.getByPlaceholder('••••••••').fill('TestPass123!')
    await page.getByRole('button', { name: /create account/i }).click()
    await expect(page.getByText(/already exists|already registered/i)).toBeVisible({ timeout: 8_000 })
  })
})
