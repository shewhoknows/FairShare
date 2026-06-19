import { test, expect, Browser } from '@playwright/test'
import { AUTH_A, AUTH_B, getCredentials, waitForAppReady } from './helpers'

let groupUrl = ''
let expenseDescription = `E2E Dinner ${Date.now()}`

test.use({ storageState: AUTH_A })

test.describe.serial('Expenses', () => {
  test('5.0 setup — create group with User B', async ({ page }) => {
    const { userB } = getCredentials()

    await page.goto('/groups')
    await waitForAppReady(page)
    await expect(page.getByRole('button', { name: /new group/i })).toBeVisible({ timeout: 15_000 })
    await page.getByRole('button', { name: /new group/i }).click()
    await expect(page.getByRole('dialog')).toBeVisible()
    await page.getByRole('dialog').getByPlaceholder('e.g. NYC Trip, Our Apartment…').fill('Expense Test Group')
    await page.getByRole('dialog').getByRole('button', { name: 'Create group' }).click()
    await expect(page).toHaveURL(/\/groups\//, { timeout: 20_000 })
    groupUrl = page.url()

    await expect(page.getByRole('tab', { name: /members/i })).toBeVisible({ timeout: 10_000 })
    await page.getByRole('tab', { name: /members/i }).click()
    await page.getByPlaceholder('friend@example.com').fill(userB.email)
    await page.getByRole('button', { name: 'Add' }).click()
    await expect(page.getByText(userB.email)).toBeVisible({ timeout: 8_000 })
  })

  test('5.1 add expense modal defaults to INR', async ({ page }) => {
    await page.goto(groupUrl)
    await expect(page.getByRole('button', { name: 'Expense', exact: true })).toBeVisible({ timeout: 15_000 })
    await page.getByRole('button', { name: 'Expense', exact: true }).click()
    await expect(page.getByRole('dialog')).toBeVisible()
    await expect(page.getByRole('dialog').getByRole('combobox').first()).toContainText(/INR|₹/)
    await page.keyboard.press('Escape')
  })

  test('5.2 add expense (equal split)', async ({ page }) => {
    await page.goto(groupUrl)
    await expect(page.getByRole('button', { name: 'Expense', exact: true })).toBeVisible({ timeout: 15_000 })
    await page.getByRole('button', { name: 'Expense', exact: true }).click()
    await expect(page.getByRole('dialog')).toBeVisible()

    await page.getByRole('dialog').getByPlaceholder('e.g. Dinner, Uber, Groceries').fill(expenseDescription)
    await page.getByRole('dialog').getByPlaceholder('0.00').first().fill('600')

    await page.getByRole('dialog').getByRole('button', { name: /add expense|save changes/i }).click()
    await expect(page.getByRole('dialog')).not.toBeVisible({ timeout: 8_000 })

    await expect(page.getByText(expenseDescription)).toBeVisible({ timeout: 8_000 })
    const card = page.getByTestId('expense-card').filter({ hasText: expenseDescription }).first()
    await expect(card).toContainText(/₹600|600\.00/)
  })

  test('5.3 User A (payer) sees edit button', async ({ page }) => {
    await page.goto(groupUrl)
    await expect(page.getByText(expenseDescription)).toBeVisible({ timeout: 15_000 })
    const card = page.getByTestId('expense-card').filter({ hasText: expenseDescription }).first()
    await expect(card.getByRole('button', { name: 'Edit expense' })).toBeVisible()
  })

  test('5.4 edit expense as payer (User A)', async ({ page }) => {
    await page.goto(groupUrl)
    await expect(page.getByText(expenseDescription)).toBeVisible({ timeout: 15_000 })
    const card = page.getByTestId('expense-card').filter({ hasText: expenseDescription }).first()
    await card.getByRole('button', { name: 'Edit expense' }).click()

    await expect(page.getByRole('dialog')).toBeVisible()
    const descInput = page.getByRole('dialog').getByPlaceholder('e.g. Dinner, Uber, Groceries')
    await descInput.clear()
    await descInput.fill(`${expenseDescription} edited`)
    await page.getByRole('dialog').getByRole('button', { name: /add expense|save changes/i }).click()
    await expect(page.getByRole('dialog')).not.toBeVisible({ timeout: 8_000 })

    await expect(page.getByText(`${expenseDescription} edited`)).toBeVisible({ timeout: 5_000 })
    expenseDescription = `${expenseDescription} edited`
  })

  test('5.5 User B (non-payer) sees read-only expense details', async ({ browser }: { browser: Browser }) => {
    const ctx = await browser.newContext({ storageState: AUTH_B })
    const page = await ctx.newPage()

    await page.goto(groupUrl)
    await expect(page.getByText(expenseDescription)).toBeVisible({ timeout: 10_000 })

    const card = page.getByTestId('expense-card').filter({ hasText: expenseDescription }).first()
    await expect(card.getByRole('button', { name: 'Edit expense' })).toHaveCount(0)
    await card.getByRole('button', { name: 'Expand expense details' }).click()
    await expect(card.getByText('SPLIT BREAKDOWN')).toBeVisible({ timeout: 5_000 })

    await ctx.close()
  })
})
