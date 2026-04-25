import { test, expect, Browser } from '@playwright/test'
import { AUTH_A, AUTH_B, getCredentials } from './helpers'

let groupUrl = ''
let expenseDescription = `E2E Dinner ${Date.now()}`

test.use({ storageState: AUTH_A })

test.describe.serial('Expenses', () => {
  test('5.0 setup — create group with User B', async ({ page }) => {
    const { userB } = getCredentials()

    await page.goto('/groups')
    await page.waitForLoadState('networkidle')
    await page.getByRole('button', { name: /new group/i }).click()
    await expect(page.getByRole('dialog')).toBeVisible()
    await page.getByRole('dialog').getByPlaceholder('e.g. NYC Trip, Our Apartment…').fill('Expense Test Group')
    await page.getByRole('dialog').getByRole('button', { name: 'Create group' }).click()
    await expect(page).toHaveURL(/\/groups\//, { timeout: 10_000 })
    groupUrl = page.url()

    await page.getByRole('tab', { name: /members/i }).click()
    await page.getByPlaceholder('friend@example.com').fill(userB.email)
    await page.getByRole('button', { name: 'Add' }).click()
    await expect(page.getByText(userB.email)).toBeVisible({ timeout: 8_000 })
  })

  test('5.1 add expense modal defaults to INR', async ({ page }) => {
    await page.goto(groupUrl)
    await page.getByRole('button', { name: 'Expense' }).click()
    await expect(page.getByRole('dialog')).toBeVisible()
    await expect(page.getByRole('dialog').getByText('INR')).toBeVisible()
    await page.keyboard.press('Escape')
  })

  test('5.2 add expense (equal split)', async ({ page }) => {
    await page.goto(groupUrl)
    await page.getByRole('button', { name: 'Expense' }).click()
    await expect(page.getByRole('dialog')).toBeVisible()

    await page.getByRole('dialog').getByPlaceholder('e.g. Dinner, Uber, Groceries').fill(expenseDescription)
    await page.getByRole('dialog').getByPlaceholder('0.00').first().fill('600')

    await page.getByRole('dialog').getByRole('button', { name: /add expense|save changes/i }).click()
    await expect(page.getByRole('dialog')).not.toBeVisible({ timeout: 8_000 })

    await expect(page.getByText(expenseDescription)).toBeVisible({ timeout: 8_000 })
    await expect(page.getByText(/₹600|600\.00/)).toBeVisible()
  })

  test('5.3 User A (payer) sees edit button', async ({ page }) => {
    await page.goto(groupUrl)
    const card = page.locator('article, [class*="card"]').filter({ hasText: expenseDescription }).first()
    await expect(card.locator('button').nth(1)).toBeVisible()
  })

  test('5.4 edit expense as payer (User A)', async ({ page }) => {
    await page.goto(groupUrl)
    const card = page.locator('article, [class*="card"]').filter({ hasText: expenseDescription }).first()
    await card.locator('button').nth(1).click()

    await expect(page.getByRole('dialog')).toBeVisible()
    const descInput = page.getByRole('dialog').getByPlaceholder('e.g. Dinner, Uber, Groceries')
    await descInput.clear()
    await descInput.fill(`${expenseDescription} edited`)
    await page.getByRole('dialog').getByRole('button', { name: /add expense|save changes/i }).click()
    await expect(page.getByRole('dialog')).not.toBeVisible({ timeout: 8_000 })

    await expect(page.getByText(`${expenseDescription} edited`)).toBeVisible({ timeout: 5_000 })
    expenseDescription = `${expenseDescription} edited`
  })

  test('5.5 User B (non-payer) can open edit modal', async ({ browser }: { browser: Browser }) => {
    const ctx = await browser.newContext({ storageState: AUTH_B })
    const page = await ctx.newPage()

    await page.goto(groupUrl)
    await expect(page.getByText(expenseDescription)).toBeVisible({ timeout: 10_000 })

    const card = page.locator('article, [class*="card"]').filter({ hasText: expenseDescription }).first()
    await card.locator('button').nth(1).click()
    await expect(page.getByRole('dialog')).toBeVisible({ timeout: 5_000 })
    await page.keyboard.press('Escape')

    await ctx.close()
  })
})
