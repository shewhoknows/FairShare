import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptDir = path.dirname(fileURLToPath(import.meta.url))
const repoRoot = path.resolve(scriptDir, '../../..')

const contractPath = path.join(repoRoot, 'packages/contracts/openapi.yaml')
const fixturePath = path.join(repoRoot, 'packages/contracts/fixtures/parity-fixtures.json')
const iosFixturePath = path.join(repoRoot, 'apps/ios/FairShareApp/Sources/ParityFixtures.swift')
const iosModelsPath = path.join(repoRoot, 'apps/ios/FairShareApp/Sources/Models.swift')
const webDtoPath = path.join(repoRoot, 'apps/web/lib/mobile-dto.ts')

const contract = fs.readFileSync(contractPath, 'utf8')
const fixture = JSON.parse(fs.readFileSync(fixturePath, 'utf8'))
const iosFixtureSource = fs.readFileSync(iosFixturePath, 'utf8')
const iosModels = fs.readFileSync(iosModelsPath, 'utf8')
const webDto = fs.readFileSync(webDtoPath, 'utf8')

assert.match(contract, /^openapi:\s*3\.1\.0/m)

const requiredPaths = [
  '/api/mobile/auth/login',
  '/api/mobile/auth/register',
  '/api/mobile/auth/me',
  '/api/mobile/dashboard',
  '/api/mobile/groups',
  '/api/mobile/groups/{id}',
  '/api/mobile/groups/{id}/members',
  '/api/mobile/expenses',
  '/api/mobile/expenses/{id}',
  '/api/mobile/transactions',
]

for (const route of requiredPaths) {
  assert.ok(contract.includes(`  ${route}:`), `Missing contract route: ${route}`)
}

const requiredSchemas = [
  'User',
  'Member',
  'Group',
  'Expense',
  'ExpenseSplit',
  'Balance',
  'GroupBalances',
  'Transaction',
  'AuthResponse',
  'DashboardResponse',
  'CreateGroupRequest',
  'CreateExpenseRequest',
  'CreateTransactionRequest',
]

for (const schema of requiredSchemas) {
  assert.ok(contract.includes(`    ${schema}:`), `Missing contract schema: ${schema}`)
}

assert.equal(fixture.scenario, 'baseline-shared-expenses')
assert.equal(fixture.users.length, 4)
assert.equal(fixture.groups.length, 2)
assert.equal(fixture.expenses.length, 3)
assert.equal(fixture.expectedDashboard.totalOwed, 240)
assert.equal(fixture.expectedDashboard.totalOwe, 1200)

for (const id of [
  'user-alice',
  'user-bob',
  'user-carol',
  'user-dave',
  'group-nyc',
  'group-home',
  'expense-hotel',
  'expense-dinner',
  'expense-rent',
]) {
  assert.ok(iosFixtureSource.includes(id), `iOS fixture source is missing ${id}`)
}

for (const dto of [
  'UserDTO',
  'MemberDTO',
  'GroupDTO',
  'ExpenseDTO',
  'ExpenseSplitDTO',
  'BalanceDTO',
  'GroupBalancesDTO',
  'TransactionDTO',
]) {
  assert.ok(iosModels.includes(`struct ${dto}`), `Missing iOS DTO ${dto}`)
}

for (const transformer of ['mobileUser', 'mobileMember', 'mobileExpense', 'mobileGroup']) {
  assert.ok(webDto.includes(`export function ${transformer}`), `Missing web DTO transformer ${transformer}`)
}

console.log('Contract routes, schemas, DTO mirrors, and shared fixture references are intact.')
