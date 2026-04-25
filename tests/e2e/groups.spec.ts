import { test, expect } from '@playwright/test'
import { AUTH_A, getCredentials } from './helpers'

test.use({ storageState: AUTH_A })

// Shared state across serial tests in this file
let groupUrl = ''

test.describe.serial('Groups', () => {
  test('4.1 create group lands on group detail page', async ({ page }) => {
    await page.goto('/groups')

    await page.getByRole('button', { name: /new group|create group/i }).click()
    await expect(page.getByRole('dialog')).toBeVisible()

    await page.getByRole('dialog').getByPlaceholder(/name/i).fill('E2E Test Group')
    // Currency defaults to INR — just submit
    await page.getByRole('dialog').getByRole('button', { name: /create/i }).click()

    await expect(page).toHaveURL(/\/groups\//, { timeout: 10_000 })
    groupUrl = page.url()
    await expect(page.getByText('E2E Test Group')).toBeVisible()
  })

  test('4.2 members tab shows current user as Admin', async ({ page }) => {
    await page.goto(groupUrl)
    await page.getByRole('tab', { name: /members/i }).click()
    await expect(page.getByText(/admin/i)).toBeVisible()
  })

  test('4.3 friend picker shows User B', async ({ page }) => {
    const { userB } = getCredentials()
    await page.goto(groupUrl)
    await page.getByRole('tab', { name: /members/i }).click()

    // Friend picker section should list User B (added as friend in friends.spec)
    await expect(page.getByText(userB.name)).toBeVisible({ timeout: 5_000 })
  })

  test('4.4 add User B via friend picker', async ({ page }) => {
    const { userB } = getCredentials()
    await page.goto(groupUrl)
    await page.getByRole('tab', { name: /members/i }).click()

    // Click User B's row in the friend picker
    const friendRow = page.locator('button').filter({ hasText: userB.name })
    await friendRow.click()

    // B now appears in the members list (not just friend picker)
    await expect(page.getByText(userB.email)).toBeVisible({ timeout: 8_000 })
  })

  test('4.5 adding same member again shows error', async ({ page }) => {
    const { userB } = getCredentials()
    await page.goto(groupUrl)
    await page.getByRole('tab', { name: /members/i }).click()

    // Try adding via email
    await page.getByPlaceholder(/friend@example.com/i).fill(userB.email)
    await page.getByRole('button', { name: /^add$/i }).click()

    await expect(page.getByText(/already a member/i)).toBeVisible({ timeout: 8_000 })
  })

  test('4.6 add by email — non-existent user shows error', async ({ page }) => {
    await page.goto(groupUrl)
    await page.getByRole('tab', { name: /members/i }).click()

    await page.getByPlaceholder(/friend@example.com/i).fill('notarealuser@nowhere.xyz')
    await page.getByRole('button', { name: /^add$/i }).click()

    await expect(page.getByText(/not found|no user|doesn't exist/i)).toBeVisible({ timeout: 8_000 })
  })
})
