const target = process.env.WAIT_FOR_URL ?? 'http://127.0.0.1:3000/api/health'
const timeoutMs = Number(process.env.WAIT_TIMEOUT_MS ?? 90_000)
const intervalMs = 2_000
const startedAt = Date.now()

while (Date.now() - startedAt < timeoutMs) {
  try {
    const response = await fetch(target)
    if (response.ok) {
      console.log(`Ready: ${target}`)
      process.exit(0)
    }
  } catch {
    // Keep polling until the app comes up or the timeout expires.
  }

  await new Promise((resolve) => setTimeout(resolve, intervalMs))
}

console.error(`Timed out waiting for ${target}`)
process.exit(1)
