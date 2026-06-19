import assert from 'node:assert/strict'

const baseUrl = process.env.TEST_URL ?? 'http://127.0.0.1:3000'
const otpCode = process.env.MOBILE_AUTH_TEST_CODE ?? '123456'
const runId = `${Date.now()}-${Math.random().toString(16).slice(2)}`

async function requestJson<T>(
  pathname: string,
  init: RequestInit = {}
): Promise<T> {
  const response = await fetch(`${baseUrl}${pathname}`, {
    ...init,
    headers: {
      accept: 'application/json',
      ...(init.body ? { 'content-type': 'application/json' } : {}),
      ...(init.headers ?? {}),
    },
  })

  const payload = await response.json().catch(() => null)
  assert.ok(response.ok, `${pathname} failed with ${response.status}: ${JSON.stringify(payload)}`)
  return payload as T
}

type OTPStartResponse = {
  challengeId: string
  maskedIdentifier: string
  deliveryChannel: 'email' | 'phone'
}

type AuthResponse = {
  token: string
  user: {
    id: string
    email: string | null
    phone: string | null
    preferredName: string | null
    upiID: string | null
    isProfileComplete: boolean
  }
}

type UserResponse = {
  user: AuthResponse['user']
}

async function startOTP(identifier: string) {
  return requestJson<OTPStartResponse>('/api/mobile/auth/otp/start', {
    method: 'POST',
    body: JSON.stringify({ identifier }),
  })
}

async function verifyOTP(challengeId: string) {
  return requestJson<AuthResponse>('/api/mobile/auth/otp/verify', {
    method: 'POST',
    body: JSON.stringify({ challengeId, code: otpCode }),
  })
}

async function main() {
  const phone = `+1555${String(Date.now()).slice(-7)}`
  const phoneChallenge = await startOTP(phone)
  assert.equal(phoneChallenge.deliveryChannel, 'phone')
  assert.ok(phoneChallenge.challengeId)

  const phoneAuth = await verifyOTP(phoneChallenge.challengeId)
  assert.equal(phoneAuth.user.phone, phone)
  assert.ok(phoneAuth.token.length > 20)

  const profile = await requestJson<UserResponse>('/api/mobile/auth/profile', {
    method: 'PUT',
    headers: { authorization: `Bearer ${phoneAuth.token}` },
    body: JSON.stringify({
      name: 'Meera Kapoor',
      preferredName: 'Meera',
      upiID: `meera.${runId}@upi`,
    }),
  })
  assert.equal(profile.user.preferredName, 'Meera')
  assert.equal(profile.user.isProfileComplete, true)

  const me = await requestJson<UserResponse>('/api/mobile/auth/me', {
    headers: { authorization: `Bearer ${phoneAuth.token}` },
  })
  assert.equal(me.user.upiID, profile.user.upiID)

  const email = `mobile-auth-${runId}@billbandit-test.com`
  const emailChallenge = await startOTP(email)
  assert.equal(emailChallenge.deliveryChannel, 'email')

  const emailAuth = await verifyOTP(emailChallenge.challengeId)
  assert.equal(emailAuth.user.email, email)
  assert.ok(emailAuth.token.length > 20)

  const appleToken = process.env.MOBILE_AUTH_MOCK_APPLE_TOKEN
  if (appleToken) {
    const appleAuth = await requestJson<AuthResponse>('/api/mobile/auth/apple', {
      method: 'POST',
      body: JSON.stringify({
        identityToken: appleToken,
        name: 'Apple Tester',
        email: `apple-${runId}@billbandit-test.com`,
      }),
    })
    assert.ok(appleAuth.token.length > 20)
    assert.equal(appleAuth.user.email, process.env.MOBILE_AUTH_MOCK_APPLE_EMAIL)
  }

  console.log('Mobile auth API checks passed.')
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
