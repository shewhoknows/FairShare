import { test, expect } from '@playwright/test'
import { AUTH_A, getCredentials } from './helpers'

let groupUrl = ''
const expenseDesc = `Comment Test ${Date.now()}`
const commentText = `Test comment ${Date.now()}`

test.use({ storageState: AUTH_A })

test.describe.serial('Comments', () => {
  test('8.0 setup — create group and add expense', async ({ page }) => {
    await page.goto('/groups')
    await page.getByRole('button', { name: /new group|create group/i }).click()
    await expect(page.getByRole('dialog')).toBeVisible()
    await page.getByRole('dialog').getByPlaceholder(/name/i).fill('Comment Test Group')
    await page.getByRole('dialog').getByRole('button', { name: /create/i }).click()
    await expect(page).toHaveURL(/\/groups\//, { timeout: 10_000 })
    groupUrl = page.url()

    await page.getByRole('button', { name: /add expense/i }).click()
    await expect(page.getByRole('dialog')).toBeVisible()
    await page.getByRole('dialog').getByPlaceholder(/description/i).fill(expenseDesc)
    await page.getByRole('dialog').getByPlaceholder(/0\.00|amount/i).fill('100')
    await page.getByRole('dialog').getByRole('button', { name: /add expense|save|create/i }).click()
    await expect(page.getByRole('dialog')).not.toBeVisible({ timeout: 8_000 })
  })

  test('8.1 expand expense shows comment section', async ({ page }) => {
    await page.goto(groupUrl)
    const card = page.locator('article, [class*="card"]').filter({ hasText: expenseDesc }).first()
    // Click the chevron (expand button — first button on the card)
    await card.locator('button').first().click()
    // Comment input should appear
    await expect(card.getByPlaceholder(/comment|write/i)).toBeVisible({ timeout: 5_000 })
  })

  test('8.2 add a comment', async ({ page }) => {
    await page.goto(groupUrl)
    const card = page.locator('article, [class*="card"]').filter({ hasText: expenseDesc }).first()
    await card.locator('button').first().click()

    const commentInput = card.getByPlaceholder(/comment|write/i)
    await commentInput.fill(commentText)
    // Submit via Enter or button
    await commentInput.press('Enter')

    await expect(card.getByText(commentText)).toBeVisible({ timeout: 8_000 })
  })

  test('8.3 comment persists after reload', async ({ page }) => {
    await page.goto(groupUrl)
    const card = page.locator('article, [class*="card"]').filter({ hasText: expenseDesc }).first()
    await card.locator('button').first().click()
    await expect(card.getByText(commentText)).toBeVisible({ timeout: 5_000 })
  })
})
