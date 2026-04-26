import { test, expect } from '@playwright/test'
import { AUTH_A } from './helpers'

let groupUrl = ''
const expenseDesc = `Comment Test ${Date.now()}`
const commentText = `Test comment ${Date.now()}`

test.use({ storageState: AUTH_A })

test.describe.serial('Comments', () => {
  test('8.0 setup — create group and add expense', async ({ page }) => {
    await page.goto('/groups')
    await expect(page.getByRole('button', { name: /new group/i })).toBeVisible({ timeout: 15_000 })
    await page.getByRole('button', { name: /new group/i }).click()
    await expect(page.getByRole('dialog')).toBeVisible()
    await page.getByRole('dialog').getByPlaceholder('e.g. NYC Trip, Our Apartment…').fill('Comment Test Group')
    await page.getByRole('dialog').getByRole('button', { name: 'Create group' }).click()
    await expect(page).toHaveURL(/\/groups\//, { timeout: 20_000 })
    groupUrl = page.url()

    await expect(page.getByRole('button', { name: 'Expense' })).toBeVisible({ timeout: 10_000 })
    await page.getByRole('button', { name: 'Expense' }).click()
    await expect(page.getByRole('dialog')).toBeVisible()
    await page.getByRole('dialog').getByPlaceholder('e.g. Dinner, Uber, Groceries').fill(expenseDesc)
    await page.getByRole('dialog').getByPlaceholder('0.00').first().fill('100')
    await page.getByRole('dialog').getByRole('button', { name: /add expense|save changes/i }).click()
    await expect(page.getByRole('dialog')).not.toBeVisible({ timeout: 8_000 })
  })

  test('8.1 expand expense shows comment section', async ({ page }) => {
    await page.goto(groupUrl)
    await expect(page.getByText(expenseDesc)).toBeVisible({ timeout: 15_000 })
    const card = page.locator('article, [class*="card"]').filter({ hasText: expenseDesc }).first()
    await card.locator('button').first().click()
    await expect(card.getByPlaceholder('Add a comment…')).toBeVisible({ timeout: 5_000 })
  })

  test('8.2 add a comment', async ({ page }) => {
    await page.goto(groupUrl)
    await expect(page.getByText(expenseDesc)).toBeVisible({ timeout: 15_000 })
    const card = page.locator('article, [class*="card"]').filter({ hasText: expenseDesc }).first()
    await card.locator('button').first().click()

    const commentInput = card.getByPlaceholder('Add a comment…')
    await commentInput.fill(commentText)
    await commentInput.press('Enter')

    await expect(card.getByText(commentText)).toBeVisible({ timeout: 8_000 })
  })

  test('8.3 comment persists after reload', async ({ page }) => {
    await page.goto(groupUrl)
    await expect(page.getByText(expenseDesc)).toBeVisible({ timeout: 15_000 })
    const card = page.locator('article, [class*="card"]').filter({ hasText: expenseDesc }).first()
    await card.locator('button').first().click()
    await expect(card.getByText(commentText)).toBeVisible({ timeout: 5_000 })
  })
})
