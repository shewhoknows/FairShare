import { test, expect } from '@playwright/test'
import { AUTH_A } from './helpers'

let groupUrl = ''

test.use({ storageState: AUTH_A })

test.describe.serial('CSV Export', () => {
  test('10.0 setup — create group with an expense', async ({ page }) => {
    await page.goto('/groups')
    await expect(page.getByRole('button', { name: /new group/i })).toBeVisible({ timeout: 15_000 })
    await page.getByRole('button', { name: /new group/i }).click()
    await expect(page.getByRole('dialog')).toBeVisible()
    await page.getByRole('dialog').getByPlaceholder('e.g. NYC Trip, Our Apartment…').fill('Export Test Group')
    await page.getByRole('dialog').getByRole('button', { name: 'Create group' }).click()
    await expect(page).toHaveURL(/\/groups\//, { timeout: 20_000 })
    groupUrl = page.url()

    await expect(page.getByRole('button', { name: 'Expense' })).toBeVisible({ timeout: 10_000 })
    await page.getByRole('button', { name: 'Expense' }).click()
    await expect(page.getByRole('dialog')).toBeVisible()
    await page.getByRole('dialog').getByPlaceholder('e.g. Dinner, Uber, Groceries').fill('Export Test Expense')
    await page.getByRole('dialog').getByPlaceholder('0.00').first().fill('500')
    await page.getByRole('dialog').getByRole('button', { name: /add expense|save changes/i }).click()
    await expect(page.getByRole('dialog')).not.toBeVisible({ timeout: 8_000 })
  })

  test('10.1 clicking export triggers CSV download', async ({ page }) => {
    await page.goto(groupUrl)
    await expect(page.getByRole('button', { name: /export/i })).toBeVisible({ timeout: 15_000 })

    const [download] = await Promise.all([
      page.waitForEvent('download', { timeout: 10_000 }),
      page.getByRole('button', { name: /export/i }).click(),
    ])

    expect(download.suggestedFilename()).toMatch(/\.csv$/i)
  })

  test('10.2 exported CSV contains expense data', async ({ page }) => {
    await page.goto(groupUrl)
    await expect(page.getByRole('button', { name: /export/i })).toBeVisible({ timeout: 15_000 })

    const [download] = await Promise.all([
      page.waitForEvent('download', { timeout: 10_000 }),
      page.getByRole('button', { name: /export/i }).click(),
    ])

    const filePath = await download.path()
    const fs = await import('fs')
    const content = fs.readFileSync(filePath!, 'utf-8')

    const rows = content.trim().split('\n')
    expect(rows.length).toBeGreaterThanOrEqual(2)
    expect(content).toContain('Export Test Expense')
  })
})
