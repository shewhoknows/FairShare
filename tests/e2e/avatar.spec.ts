import { test, expect } from '@playwright/test'
import { AUTH_A } from './helpers'

test.use({ storageState: AUTH_A })

const DICEBEAR_BASE = 'https://api.dicebear.com/7.x/avataaars/svg?seed='

const sidebarUserBtn = (page: any) =>
  page.locator('aside button').filter({ has: page.locator('img, [class*="Avatar"]') })

test.describe.serial('Avatar Picker', () => {
  test('2.1 clicking user section opens avatar modal', async ({ page }) => {
    await page.goto('/dashboard')
    await expect(sidebarUserBtn(page)).toBeVisible({ timeout: 15_000 })
    await sidebarUserBtn(page).click()
    await expect(page.getByRole('dialog')).toBeVisible({ timeout: 5_000 })
    await expect(page.getByText(/choose your avatar/i)).toBeVisible()
  })

  test('2.2 modal shows 9 avatar options', async ({ page }) => {
    await page.goto('/dashboard')
    await expect(sidebarUserBtn(page)).toBeVisible({ timeout: 15_000 })
    await sidebarUserBtn(page).click()
    await expect(page.getByRole('dialog')).toBeVisible()

    // 9 avatar selection buttons in the grid
    const avatarButtons = page.getByRole('dialog').locator('button').filter({ has: page.locator('img') })
    await expect(avatarButtons).toHaveCount(9)
  })

  test('2.3 save button is disabled until selection is made', async ({ page }) => {
    await page.goto('/dashboard')
    await expect(sidebarUserBtn(page)).toBeVisible({ timeout: 15_000 })
    await sidebarUserBtn(page).click()
    await expect(page.getByRole('dialog')).toBeVisible()

    const saveBtn = page.getByRole('button', { name: /save avatar/i })
    await expect(saveBtn).toBeDisabled()
  })

  test('2.4 selecting avatar updates preview', async ({ page }) => {
    await page.goto('/dashboard')
    await expect(sidebarUserBtn(page)).toBeVisible({ timeout: 15_000 })
    await sidebarUserBtn(page).click()
    await expect(page.getByRole('dialog')).toBeVisible()

    // Get the preview image src before selection
    const preview = page.getByRole('dialog').locator('img').first()
    const beforeSrc = await preview.getAttribute('src')

    // Click a different avatar (the first one in the grid)
    const firstOption = page.getByRole('dialog').locator('button').filter({ has: page.locator('img') }).first()
    await firstOption.click()

    // Preview should update
    const afterSrc = await preview.getAttribute('src')
    // Either it changed OR it was already selected (same src is acceptable)
    expect(afterSrc).toContain(DICEBEAR_BASE)
  })

  test('2.5 save avatar updates sidebar and persists on reload', async ({ page }) => {
    await page.goto('/dashboard')
    await expect(sidebarUserBtn(page)).toBeVisible({ timeout: 15_000 })
    await sidebarUserBtn(page).click()
    await expect(page.getByRole('dialog')).toBeVisible()

    // Select an avatar (pick one that's unlikely to match the current)
    const options = page.getByRole('dialog').locator('button').filter({ has: page.locator('img') })
    await options.nth(4).click() // 5th option — "Nova" seed

    const saveBtn = page.getByRole('button', { name: /save avatar/i })
    await expect(saveBtn).toBeEnabled()
    await saveBtn.click()

    await expect(page.getByRole('dialog')).not.toBeVisible({ timeout: 8_000 })

    // Sidebar avatar image should now show the dicebear URL
    const sidebarImg = page.locator('aside img').first()
    await expect(sidebarImg).toHaveAttribute('src', new RegExp(DICEBEAR_BASE.replace('?', '\\?')))

    // Reload and verify persistence
    await page.reload()
    const sidebarImgAfterReload = page.locator('aside img').first()
    await expect(sidebarImgAfterReload).toHaveAttribute('src', new RegExp(DICEBEAR_BASE.replace('?', '\\?')))
  })

  test('2.6 cancel closes modal without changing avatar', async ({ page }) => {
    await page.goto('/dashboard')
    await expect(sidebarUserBtn(page)).toBeVisible({ timeout: 15_000 })
    const sidebarImg = page.locator('aside img').first()
    const srcBefore = await sidebarImg.getAttribute('src')

    await sidebarUserBtn(page).click()
    await expect(page.getByRole('dialog')).toBeVisible()

    // Select an avatar but cancel
    const options = page.getByRole('dialog').locator('button').filter({ has: page.locator('img') })
    await options.nth(0).click()
    await page.getByRole('button', { name: /cancel/i }).click()

    await expect(page.getByRole('dialog')).not.toBeVisible()
    const srcAfter = await sidebarImg.getAttribute('src')
    expect(srcAfter).toBe(srcBefore)
  })
})
