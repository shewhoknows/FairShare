import { test, expect, Browser } from '@playwright/test'
import { AUTH_A, AUTH_B, getCredentials } from './helpers'

let groupUrl = ''
const expenseDesc = `Balance Test ${Date.now()}`

test.use({ storageState: AUTH_A })

test.describe.serial('Balances & Settle Up', () => {
  test('7.0 setup — create group, add B, add expense', async ({ page }) => {
    const { userB } = getCredentials()

    await page.goto('/groups')
    await page.waitForLoadState('networkidle')
    await page.getByRole('button', { name: /new group/i }).click()
    await expect(page.getByRole('dialog')).toBeVisible()
    await page.getByRole('dialog').getByPlaceholder('e.g. NYC Trip, Our Apartment…').fill('Balance Test Group')
    await page.getByRole('dialog').getByRole('button', { name: 'Create group' }).click()
    await expect(page).toHaveURL(/\/groups\//, { timeout: 10_000 })
    groupUrl = page.url()

    await page.getByRole('tab', { name: /members/i }).click()
    await page.getByPlaceholder('friend@example.com').fill(userB.email)
    await page.getByRole('button', { name: 'Add' }).click()
    await expect(page.getByText(userB.email)).toBeVisible({ timeout: 8_000 })

    await page.getByRole('tab', { name: /expenses/i }).click()
    await page.getByRole('button', { name: 'Expense' }).click()
    await expect(page.getByRole('dialog')).toBeVisible()
    await page.getByRole('dialog').getByPlaceholder('e.g. Dinner, Uber, Groceries').fill(expenseDesc)
    await page.getByRole('dialog').getByPlaceholder('0.00').first().fill('1000')
    await page.getByRole('dialog').getByRole('button', { name: /add expense|save changes/i }).click()
    await expect(page.getByRole('dialog')).not.toBeVisible({ timeout: 8_000 })
  })

  test('7.1 balances tab shows debt in INR', async ({ page }) => {
    await page.goto(groupUrl)
    await page.getByRole('tab', { name: /balances/i }).click()
    const content = await page.content()
    expect(content).toContain('₹')
  })

  test('7.2 User B can settle up as debtor', async ({ browser }: { browser: Browser }) => {
    const ctx = await browser.newContext({ storageState: AUTH_B })
    const page = await ctx.newPage()

    await page.goto(groupUrl)
    await page.getByRole('tab', { name: /balances/i }).click()

    await expect(page.getByRole('button', { name: 'Settle' })).toBeVisible({ timeout: 5_000 })
    await page.getByRole('button', { name: 'Settle' }).click()

    await expect(page.getByRole('dialog')).toBeVisible()
    await page.getByRole('dialog').getByRole('button', { name: 'Record payment' }).click()
    await expect(page.getByRole('dialog')).not.toBeVisible({ timeout: 8_000 })

    await ctx.close()
  })

  test('7.3 User A sees Mark received button after new expense', async ({ page }) => {
    await page.goto(groupUrl)
    await page.getByRole('tab', { name: /expenses/i }).click()
    await page.getByRole('button', { name: 'Expense' }).click()
    await expect(page.getByRole('dialog')).toBeVisible()
    await page.getByRole('dialog').getByPlaceholder('e.g. Dinner, Uber, Groceries').fill(`${expenseDesc} 2`)
    await page.getByRole('dialog').getByPlaceholder('0.00').first().fill('800')
    await page.getByRole('dialog').getByRole('button', { name: /add expense|save changes/i }).click()
    await expect(page.getByRole('dialog')).not.toBeVisible({ timeout: 8_000 })

    await page.getByRole('tab', { name: /balances/i }).click()
    await expect(page.getByRole('button', { name: 'Mark received' })).toBeVisible({ timeout: 5_000 })
  })

  test('7.4 User A marks payment received', async ({ page }) => {
    await page.goto(groupUrl)
    await page.getByRole('tab', { name: /balances/i }).click()

    await page.getByRole('button', { name: 'Mark received' }).click()
    await expect(page.getByRole('dialog')).toBeVisible()
    await page.getByRole('dialog').getByRole('button', { name: 'Mark received' }).click()
    await expect(page.getByRole('dialog')).not.toBeVisible({ timeout: 8_000 })
  })
})
