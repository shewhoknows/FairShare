import { test, expect } from '@playwright/test'
import { AUTH_A, getCredentials } from './helpers'

test.use({ storageState: AUTH_A })

// Shared state across serial tests in this file
let groupUrl = ''

test.describe.serial('Groups', () => {
  test('4.1 create group lands on group detail page', async ({ page }) => {
    await page.goto('/groups')
    await expect(page.getByRole('button', { name: /new group/i })).toBeVisible({ timeout: 15_000 })

    await page.getByRole('button', { name: /new group/i }).click()
    await expect(page.getByRole('dialog')).toBeVisible()

    await page.getByRole('dialog').getByPlaceholder('e.g. NYC Trip, Our Apartment…').fill('E2E Test Group')
    await page.getByRole('dialog').getByRole('button', { name: 'Create group' }).click()

    await expect(page).toHaveURL(/\/groups\//, { timeout: 20_000 })
    groupUrl = page.url()
    await expect(page.getByText('E2E Test Group')).toBeVisible()
  })

  test('4.2 members tab shows current user as Admin', async ({ page }) => {
    await page.goto(groupUrl)
    await expect(page.getByRole('tab', { name: /members/i })).toBeVisible({ timeout: 15_000 })
    await page.getByRole('tab', { name: /members/i }).click()
    await expect(page.getByText(/admin/i)).toBeVisible()
  })

  test('4.3 friend picker shows User B', async ({ page }) => {
    const { userB } = getCredentials()
    await page.goto(groupUrl)
    await expect(page.getByRole('tab', { name: /members/i })).toBeVisible({ timeout: 15_000 })
    await page.getByRole('tab', { name: /members/i }).click()
    await expect(page.getByText(userB.name)).toBeVisible({ timeout: 5_000 })
  })

  test('4.4 add User B via friend picker', async ({ page }) => {
    const { userB } = getCredentials()
    await page.goto(groupUrl)
    await expect(page.getByRole('tab', { name: /members/i })).toBeVisible({ timeout: 15_000 })
    await page.getByRole('tab', { name: /members/i }).click()

    const friendRow = page.locator('button').filter({ hasText: userB.name })
    await friendRow.click()

    await expect(page.getByText(userB.email)).toBeVisible({ timeout: 8_000 })
  })

  test('4.5 adding same member again shows error', async ({ page }) => {
    const { userB } = getCredentials()
    await page.goto(groupUrl)
    await expect(page.getByRole('tab', { name: /members/i })).toBeVisible({ timeout: 15_000 })
    await page.getByRole('tab', { name: /members/i }).click()

    await page.getByPlaceholder('friend@example.com').fill(userB.email)
    await page.getByRole('button', { name: 'Add' }).click()

    await expect(page.getByText(/already a member/i)).toBeVisible({ timeout: 8_000 })
  })

  test('4.6 add by email — non-existent user shows error', async ({ page }) => {
    await page.goto(groupUrl)
    await expect(page.getByRole('tab', { name: /members/i })).toBeVisible({ timeout: 15_000 })
    await page.getByRole('tab', { name: /members/i }).click()

    await page.getByPlaceholder('friend@example.com').fill('notarealuser@nowhere.xyz')
    await page.getByRole('button', { name: 'Add' }).click()

    await expect(page.getByText(/not found|no user|doesn't exist/i)).toBeVisible({ timeout: 8_000 })
  })
})
