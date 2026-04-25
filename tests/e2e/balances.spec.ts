import { test, expect, Browser } from '@playwright/test'
import { AUTH_A, AUTH_B, getCredentials } from './helpers'

let groupUrl = ''
const expenseDesc = `Balance Test ${Date.now()}`

test.use({ storageState: AUTH_A })

test.describe.serial('Balances & Settle Up', () => {
  test('7.0 setup — create group, add B, add expense', async ({ page }) => {
    const { userB } = getCredentials()

    await page.goto('/groups')
    await page.getByRole('button', { name: /new group|create group/i }).click()
    await expect(page.getByRole('dialog')).toBeVisible()
    await page.getByRole('dialog').getByPlaceholder(/name/i).fill('Balance Test Group')
    await page.getByRole('dialog').getByRole('button', { name: /create/i }).click()
    await expect(page).toHaveURL(/\/groups\//, { timeout: 10_000 })
    groupUrl = page.url()

    // Add User B
    await page.getByRole('tab', { name: /members/i }).click()
    await page.getByPlaceholder(/friend@example.com/i).fill(userB.email)
    await page.getByRole('button', { name: /^add$/i }).click()
    await expect(page.getByText(userB.email)).toBeVisible({ timeout: 8_000 })

    // Add expense (User A pays, B owes)
    await page.getByRole('tab', { name: /expenses/i }).click()
    await page.getByRole('button', { name: /add expense/i }).click()
    await expect(page.getByRole('dialog')).toBeVisible()
    await page.getByRole('dialog').getByPlaceholder(/description/i).fill(expenseDesc)
    await page.getByRole('dialog').getByPlaceholder(/0\.00|amount/i).fill('1000')
    await page.getByRole('dialog').getByRole('button', { name: /add expense|save|create/i }).click()
    await expect(page.getByRole('dialog')).not.toBeVisible({ timeout: 8_000 })
  })

  test('7.1 balances tab shows debt in INR', async ({ page }) => {
    await page.goto(groupUrl)
    await page.getByRole('tab', { name: /balances/i }).click()
    // Page should mention ₹ — B owes A ₹500
    const content = await page.content()
    expect(content).toContain('₹')
  })

  test('7.2 User B can settle up as debtor', async ({ browser }: { browser: Browser }) => {
    const ctx = await browser.newContext({ storageState: AUTH_B })
    const page = await ctx.newPage()

    await page.goto(groupUrl)
    await page.getByRole('tab', { name: /balances/i }).click()

    // Look for Settle Up button
    await expect(page.getByRole('button', { name: /settle up/i })).toBeVisible({ timeout: 5_000 })
    await page.getByRole('button', { name: /settle up/i }).click()

    await expect(page.getByRole('dialog')).toBeVisible()
    // Confirm the payment
    await page.getByRole('dialog').getByRole('button', { name: /confirm|settle|pay/i }).click()
    await expect(page.getByRole('dialog')).not.toBeVisible({ timeout: 8_000 })

    await ctx.close()
  })

  test('7.3 User A sees creditor Received button', async ({ page }) => {
    // Add another expense so A is owed again
    await page.goto(groupUrl)
    await page.getByRole('tab', { name: /expenses/i }).click()
    await page.getByRole('button', { name: /add expense/i }).click()
    await expect(page.getByRole('dialog')).toBeVisible()
    await page.getByRole('dialog').getByPlaceholder(/description/i).fill(`${expenseDesc} 2`)
    await page.getByRole('dialog').getByPlaceholder(/0\.00|amount/i).fill('800')
    await page.getByRole('dialog').getByRole('button', { name: /add expense|save|create/i }).click()
    await expect(page.getByRole('dialog')).not.toBeVisible({ timeout: 8_000 })

    await page.getByRole('tab', { name: /balances/i }).click()
    // User A as creditor should see a green "Received" button
    await expect(page.getByRole('button', { name: /received/i })).toBeVisible({ timeout: 5_000 })
  })

  test('7.4 User A marks payment received', async ({ page }) => {
    await page.goto(groupUrl)
    await page.getByRole('tab', { name: /balances/i }).click()

    await page.getByRole('button', { name: /received/i }).click()
    await expect(page.getByRole('dialog')).toBeVisible()
    await page.getByRole('dialog').getByRole('button', { name: /confirm|mark|received/i }).click()
    await expect(page.getByRole('dialog')).not.toBeVisible({ timeout: 8_000 })
  })
})
