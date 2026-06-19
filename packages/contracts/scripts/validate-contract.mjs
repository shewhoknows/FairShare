import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptDir = path.dirname(fileURLToPath(import.meta.url))
const repoRoot = path.resolve(scriptDir, '../../..')

const contractPath = path.join(repoRoot, 'packages/contracts/openapi.yaml')
const fixturePath = path.join(repoRoot, 'packages/contracts/fixtures/parity-fixtures.json')
const iosFixturePath = path.join(repoRoot, 'apps/ios/BillBanditApp/Sources/ParityFixtures.swift')
const iosModelsPath = path.join(repoRoot, 'apps/ios/BillBanditApp/Sources/Models.swift')
const webDtoPath = path.join(repoRoot, 'apps/web/lib/mobile-dto.ts')
const webValidationsPath = path.join(repoRoot, 'apps/web/lib/validations.ts')
const mobileAuthRouteRoot = path.join(repoRoot, 'apps/web/app/api/mobile/auth')

const contract = fs.readFileSync(contractPath, 'utf8')
const fixture = JSON.parse(fs.readFileSync(fixturePath, 'utf8'))
const iosFixtureSource = fs.readFileSync(iosFixturePath, 'utf8')
const iosModels = fs.readFileSync(iosModelsPath, 'utf8')
const webDto = fs.readFileSync(webDtoPath, 'utf8')
const webValidations = fs.readFileSync(webValidationsPath, 'utf8')

assert.match(contract, /^openapi:\s*3\.1\.0/m)

function yamlBlock(source, header, siblingIndent) {
  const start = source.indexOf(header)
  assert.notEqual(start, -1, `Missing YAML block: ${header.trim()}`)

  const rest = source.slice(start + header.length)
  const siblingPattern = new RegExp(`\\n {${siblingIndent}}\\S[^\\n]*:\\n`)
  const next = rest.search(siblingPattern)
  return next === -1 ? rest : rest.slice(0, next)
}

const requiredPaths = [
  '/api/mobile/auth/login',
  '/api/mobile/auth/register',
  '/api/mobile/auth/me',
  '/api/mobile/auth/otp/start',
  '/api/mobile/auth/otp/verify',
  '/api/mobile/auth/apple',
  '/api/mobile/auth/profile',
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

for (const { route, method } of [
  { route: '/api/mobile/auth/otp/start', method: 'post' },
  { route: '/api/mobile/auth/otp/verify', method: 'post' },
  { route: '/api/mobile/auth/apple', method: 'post' },
  { route: '/api/mobile/auth/profile', method: 'put' },
]) {
  const routeBlock = yamlBlock(contract, `  ${route}:\n`, 2)
  assert.ok(routeBlock.includes(`    ${method}:`), `Missing ${method.toUpperCase()} for ${route}`)
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
  'OTPStartRequest',
  'OTPChallengeResponse',
  'OTPVerifyRequest',
  'AppleSignInRequest',
  'CompleteProfileRequest',
  'CreateGroupRequest',
  'CreateExpenseRequest',
  'CreateTransactionRequest',
]

for (const schema of requiredSchemas) {
  assert.ok(contract.includes(`    ${schema}:`), `Missing contract schema: ${schema}`)
}

const userSchema = yamlBlock(contract, '    User:\n', 4)
for (const field of ['phone', 'preferredName', 'upiID', 'isProfileComplete']) {
  assert.ok(userSchema.includes(`        ${field}:\n`), `User schema is missing ${field}`)
  assert.ok(webDto.includes(`${field}:`), `mobileUser DTO is missing ${field}`)
  assert.ok(iosModels.includes(`let ${field}:`), `UserDTO is missing ${field}`)
}

for (const { relativePath, method } of [
  { relativePath: 'otp/start/route.ts', method: 'POST' },
  { relativePath: 'otp/verify/route.ts', method: 'POST' },
  { relativePath: 'apple/route.ts', method: 'POST' },
  { relativePath: 'profile/route.ts', method: 'PUT' },
]) {
  const routePath = path.join(mobileAuthRouteRoot, relativePath)
  assert.ok(fs.existsSync(routePath), `Missing mobile auth route file: ${relativePath}`)
  const routeSource = fs.readFileSync(routePath, 'utf8')
  assert.ok(
    routeSource.includes(`export async function ${method}`),
    `Mobile auth route ${relativePath} is missing ${method}`
  )
}

for (const validationSchema of [
  'otpStartSchema',
  'otpVerifySchema',
  'appleSignInSchema',
  'completeMobileProfileSchema',
]) {
  assert.ok(
    webValidations.includes(`export const ${validationSchema}`),
    `Missing web validation schema ${validationSchema}`
  )
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

for (const dto of [
  'AuthResponse',
  'UserResponse',
  'OTPStartRequest',
  'OTPChallengeResponse',
  'OTPVerifyRequest',
  'AppleSignInRequest',
  'CompleteProfileRequest',
]) {
  assert.ok(iosModels.includes(`struct ${dto}`), `Missing iOS auth DTO ${dto}`)
}

for (const transformer of ['mobileUser', 'mobileMember', 'mobileExpense', 'mobileGroup']) {
  assert.ok(webDto.includes(`export function ${transformer}`), `Missing web DTO transformer ${transformer}`)
}

console.log('Contract routes, schemas, DTO mirrors, and shared fixture references are intact.')
