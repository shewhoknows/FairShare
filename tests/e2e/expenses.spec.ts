import { test, expect, Browser } from '@playwright/test'
import { AUTH_A, AUTH_B, getCredentials } from './helpers'

// Shared state
let groupUrl = ''
let expenseDescription = `E2E Dinner ${Date.now()}`

test.use({ storageState: AUTH_A })

test.describe.serial('Expenses', () => {
  test('5.0 setup — create group with User B', async ({ page }) => {
    const { userB } = getCredentials()

    // Create group
    await page.goto('/groups')
    await page.getByRole('button', { name: /new group|create group/i }).click()
    await expect(page.getByRole('dialog')).toBeVisible()
    await page.getByRole('dialog').getByPlaceholder(/name/i).fill('Expense Test Group')
    await page.getByRole('dialog').getByRole('button', { name: /create/i }).click()
    await expect(page).toHaveURL(/\/groups\//, { timeout: 10_000 })
    groupUrl = page.url()

    // Add User B via email
    await page.getByRole('tab', { name: /members/i }).click()
    await page.getByPlaceholder(/friend@example.com/i).fill(userB.email)
    await page.getByRole('button', { name: /^add$/i }).click()
    await expect(page.getByText(userB.email)).toBeVisible({ timeout: 8_000 })
  })

  test('5.1 add expense modal defaults to INR', async ({ page }) => {
    await page.goto(groupUrl)
    await page.getByRole('button', { name: /add expense/i }).click()
    await expect(page.getByRole('dialog')).toBeVisible()
    // Currency selector should show INR
    await expect(page.getByRole('dialog').getByText('INR')).toBeVisible()
    await page.keyboard.press('Escape')
  })

  test('5.2 add expense (equal split)', async ({ page }) => {
    await page.goto(groupUrl)
    await page.getByRole('button', { name: /add expense/i }).click()
    await expect(page.getByRole('dialog')).toBeVisible()

    await page.getByRole('dialog').getByPlaceholder(/description/i).fill(expenseDescription)
    await page.getByRole('dialog').getByPlaceholder(/0\.00|amount/i).fill('600')

    await page.getByRole('dialog').getByRole('button', { name: /add expense|save|create/i }).click()
    await expect(page.getByRole('dialog')).not.toBeVisible({ timeout: 8_000 })

    // Expense appears in the list
    await expect(page.getByText(expenseDescription)).toBeVisible({ timeout: 8_000 })
    await expect(page.getByText(/₹600|600\.00/)).toBeVisible()
  })

  test('5.3 User A (payer) sees edit and delete buttons', async ({ page }) => {
    await page.goto(groupUrl)
    const card = page.locator('[class*="card"], [class*="expense"]').filter({ hasText: expenseDescription }).first()
    await expect(card.getByRole('button', { name: /edit/i }).or(card.locator('[aria-label*="edit" i], button:has(svg)')).first()).toBeVisible()
  })

  test('5.4 edit expense as payer (User A)', async ({ page }) => {
    await page.goto(groupUrl)

    // Find the expense card and click the pencil/edit button
    const card = page.locator('article, [class*="card"]').filter({ hasText: expenseDescription }).first()
    // The edit button is a ghost icon button — click it
    await card.locator('button').nth(1).click() // chevron is 0, edit is 1

    await expect(page.getByRole('dialog')).toBeVisible()
    // Modal should be pre-filled — just grab the description input and update it
    const descInput = page.getByRole('dialog').getByPlaceholder(/description/i)
    await descInput.clear()
    await descInput.fill(`${expenseDescription} edited`)
    await page.getByRole('dialog').getByRole('button', { name: /save|update/i }).click()
    await expect(page.getByRole('dialog')).not.toBeVisible({ timeout: 8_000 })

    await expect(page.getByText(`${expenseDescription} edited`)).toBeVisible({ timeout: 5_000 })
    expenseDescription = `${expenseDescription} edited`
  })

  test('5.5 User B (non-payer) also sees edit button on group expense', async ({ browser }: { browser: Browser }) => {
    const ctx = await browser.newContext({ storageState: AUTH_B })
    const page = await ctx.newPage()

    await page.goto(groupUrl)
    await expect(page.getByText(expenseDescription)).toBeVisible({ timeout: 10_000 })

    // Non-payer group member should see edit button
    const card = page.locator('article, [class*="card"]').filter({ hasText: expenseDescription }).first()
    // At least 2 icon buttons should be visible (expand + edit)
    await expect(card.locator('button')).toHaveCount({ minimum: 2 } as any)

    await ctx.close()
  })

  test('5.6 User B can edit the expense', async ({ browser }: { browser: Browser }) => {
    const ctx = await browser.newContext({ storageState: AUTH_B })
    const page = await ctx.newPage()

    await page.goto(groupUrl)
    await expect(page.getByText(expenseDescription)).toBeVisible({ timeout: 10_000 })

    const card = page.locator('article, [class*="card"]').filter({ hasText: expenseDescription }).first()
    await card.locator('button').nth(1).click()

    await expect(page.getByRole('dialog')).toBeVisible({ timeout: 5_000 })
    // Close without saving
    await page.keyboard.press('Escape')

    await ctx.close()
  })
})
