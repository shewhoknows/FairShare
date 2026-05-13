import { expect, test } from '@playwright/test'
import fixtures from '../../../../packages/contracts/fixtures/parity-fixtures.json'
import { waitForAppReady } from './helpers'

const alice = fixtures.users.find((user) => user.id === fixtures.expectedDashboard.userId)

if (!alice) {
  throw new Error('Parity fixture is missing the dashboard user.')
}

test('shared parity fixture scenario renders through the web dashboard', async ({ page }) => {
  await page.goto('/sign-in')
  await waitForAppReady(page)
  await page.getByPlaceholder('you@example.com').fill(alice.email)
  await page.getByPlaceholder('••••••••').fill(alice.password)
  await page.getByRole('button', { name: 'Sign in' }).click()
  await expect(page).toHaveURL(/\/dashboard/, { timeout: 15_000 })

  await expect(page.getByRole('heading', { name: /Hi, Alice/i })).toBeVisible()
  await expect(page.getByText('Bob Smith', { exact: true }).first()).toBeVisible()
  await expect(page.getByText('Carol White', { exact: true }).first()).toBeVisible()
  await expect(page.getByText('Dave Brown', { exact: true }).first()).toBeVisible()
  await expect(page.getByText('Hotel - 3 nights')).toBeVisible()
  await expect(page.getByText('Dinner at Carbone')).toBeVisible()

  await page.goto('/groups')
  await expect(page.getByText('NYC Trip')).toBeVisible()
  await expect(page.getByText('Our Apartment')).toBeVisible()
})
