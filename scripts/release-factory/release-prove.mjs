#!/usr/bin/env node
import { spawnSync } from 'node:child_process'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'

const repoRoot = process.cwd()
const args = new Set(process.argv.slice(2))
const mode = args.has('--doctor-only') ? 'doctor' : args.has('--ios-inspect-only') ? 'ios' : 'full'
const now = new Date()
const stamp = process.env.RELEASE_EVIDENCE_ID ?? now.toISOString().replace(/[:.]/g, '-')
const evidenceRoot = path.resolve(repoRoot, process.env.RELEASE_EVIDENCE_ROOT ?? 'release-evidence')
const evidenceDir = path.resolve(evidenceRoot, stamp)
const logsDir = path.join(evidenceDir, 'logs')
const screenshotsDir = path.join(evidenceDir, 'screenshots')
const simulatorDir = path.join(evidenceDir, 'simulator')

const expectedBundleId = 'com.eshabhoon.fairshare'
const expectedApiHost = process.env.RELEASE_API_HOST ?? 'billbandit-api.contenthelper.in'
const expectedApiUrl = `https://${expectedApiHost}`
const railwayFallbackUrl = process.env.RELEASE_RAILWAY_FALLBACK_URL ?? 'https://r0t6mi4v.up.railway.app'
const smokeIdentifier = process.env.MOBILE_AUTH_SMOKE_IDENTIFIER ?? '+15555550199'
const smokeOTP = process.env.MOBILE_AUTH_SMOKE_OTP_CODE ?? process.env.MOBILE_AUTH_TEST_CODE ?? '123456'
const strict = process.env.RELEASE_PROVE_STRICT === '1'

fs.mkdirSync(logsDir, { recursive: true })
fs.mkdirSync(screenshotsDir, { recursive: true })
fs.mkdirSync(simulatorDir, { recursive: true })

const commands = []
const gates = []
const blockers = []
const warnings = []
const manualActions = [
  'Confirm App Store Connect distribution signing/profile for com.eshabhoon.fairshare.',
  'Increment CFBundleVersion before each App Store Connect upload.',
  'Remove or intentionally retain scoped production OTP QA variables before public release.',
  'Upload/archive through an authenticated Xcode or App Store Connect API key session.',
]

function rel(filePath) {
  return path.relative(repoRoot, filePath)
}

function slugify(value) {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 72)
}

function runShell(label, command, options = {}) {
  const started = Date.now()
  const result = spawnSync('bash', ['-lc', command], {
    cwd: repoRoot,
    env: { ...process.env, ...(options.env ?? {}) },
    encoding: 'utf8',
    maxBuffer: 1024 * 1024 * 30,
  })
  const durationMs = Date.now() - started
  const logPath = path.join(logsDir, `${String(commands.length + 1).padStart(2, '0')}-${slugify(label)}.log`)
  const body = [
    `$ ${command}`,
    '',
    '--- stdout ---',
    result.stdout ?? '',
    '--- stderr ---',
    result.stderr ?? '',
    `--- exit ${result.status ?? 1}, ${durationMs}ms ---`,
    '',
  ].join('\n')
  fs.writeFileSync(logPath, body)
  const entry = {
    label,
    command,
    ok: result.status === 0,
    status: result.status ?? 1,
    durationMs,
    logPath: rel(logPath),
    stdout: result.stdout ?? '',
    stderr: result.stderr ?? '',
  }
  commands.push(entry)
  return entry
}

function addGate(id, label, status, detail, files = []) {
  gates.push({ id, label, status, detail, files })
  if (status === 'blocker') blockers.push(`${label}: ${detail}`)
  if (status === 'warning') warnings.push(`${label}: ${detail}`)
}

function parseJSON(value) {
  try {
    return JSON.parse(value)
  } catch {
    return null
  }
}

function readIfExists(filePath) {
  return fs.existsSync(filePath) ? fs.readFileSync(filePath, 'utf8') : ''
}

function writeJSON(name, value) {
  const filePath = path.join(evidenceDir, name)
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`)
  return rel(filePath)
}

function extractPlistString(plist, key) {
  const pattern = new RegExp(`<key>${key}</key>\\s*<string>([^<]+)</string>`)
  return plist.match(pattern)?.[1] ?? null
}

function dnsAndApiDoctor() {
  const fallbackHost = new URL(railwayFallbackUrl).host
  const recursive = runShell('DNS recursive CNAME', `dig +short ${expectedApiHost} CNAME`)
  const trace = runShell('DNS trace', `dig +trace ${expectedApiHost} CNAME | tail -n 80`)
  const cloudflareA = runShell('Cloudflare annabel CNAME', `dig @annabel.ns.cloudflare.com +short ${expectedApiHost} CNAME`)
  const cloudflareB = runShell('Cloudflare shane CNAME', `dig @shane.ns.cloudflare.com +short ${expectedApiHost} CNAME`)
  const verification = runShell('Cloudflare Railway verification TXT', `dig @annabel.ns.cloudflare.com +short _railway-verify.billbandit-api.contenthelper.in TXT`)
  const intendedHealth = runShell('Production custom domain health', `curl -sS --max-time 12 ${expectedApiUrl}/api/health`)
  const fallbackHealth = runShell(
    'Railway ingress fallback health',
    `curl -sS --max-time 12 --connect-to ${expectedApiHost}:443:${fallbackHost}:443 ${expectedApiUrl}/api/health`
  )

  const recursiveCname = recursive.stdout.trim()
  const cloudflareCname = [cloudflareA.stdout.trim(), cloudflareB.stdout.trim()].filter(Boolean)
  const intendedHealthJson = intendedHealth.ok ? parseJSON(intendedHealth.stdout) : null
  const fallbackHealthJson = fallbackHealth.ok ? parseJSON(fallbackHealth.stdout) : null
  const activeNs = trace.stdout.includes('annabel.ns.cloudflare.com') || trace.stdout.includes('shane.ns.cloudflare.com')
    ? ['annabel.ns.cloudflare.com', 'shane.ns.cloudflare.com']
    : []

  const doctor = {
    expectedApiHost,
    expectedApiUrl,
    railwayFallbackUrl,
    activeNameservers: activeNs,
    recursiveCname,
    cloudflareCname,
    railwayVerificationTxtVisibleAtCloudflare: verification.stdout.trim(),
    intendedHealth: {
      ok: intendedHealth.ok,
      status: intendedHealth.status,
      json: intendedHealthJson,
      logPath: intendedHealth.logPath,
    },
    fallbackHealth: {
      ok: fallbackHealth.ok,
      status: fallbackHealth.status,
      json: fallbackHealthJson,
      logPath: fallbackHealth.logPath,
    },
    commands: [recursive, trace, cloudflareA, cloudflareB, verification, intendedHealth, fallbackHealth].map(({ label, ok, status, logPath }) => ({ label, ok, status, logPath })),
  }

  const file = writeJSON('dns-api-health.json', doctor)
  if (!recursiveCname || !intendedHealth.ok) {
    addGate(
      'dns.custom-domain',
      'Custom domain DNS/API health',
      'blocker',
      `${expectedApiHost} does not currently resolve and serve /api/health through normal DNS. Active DNS appears to be Cloudflare; add the Railway CNAME/TXT there.`,
      [file]
    )
  } else {
    addGate('dns.custom-domain', 'Custom domain DNS/API health', 'pass', `${expectedApiHost} resolves and /api/health is OK.`, [file])
  }

  if (fallbackHealth.ok && fallbackHealthJson?.status === 'ok') {
    addGate('api.fallback-health', 'Railway ingress API fallback', 'pass', 'Railway ingress responds for the intended custom host via TLS/SNI fallback.', [file])
  } else {
    addGate('api.fallback-health', 'Railway ingress API fallback', 'blocker', 'Fallback health check failed; deployed production API could not be proven.', [file])
  }

  return doctor
}

function inspectIOSReleaseConfig() {
  const infoPlistPath = path.join(repoRoot, 'apps/ios/BillBanditApp/Sources/Info.plist')
  const entitlementsPath = path.join(repoRoot, 'apps/ios/BillBanditApp/Sources/BillBandit.entitlements')
  const releaseConfigPath = path.join(repoRoot, 'apps/ios/Config/Release.xcconfig')
  const debugConfigPath = path.join(repoRoot, 'apps/ios/Config/Debug.xcconfig')
  const exportOptionsPath = path.join(repoRoot, 'apps/ios/ExportOptions.plist')
  const projectYmlPath = path.join(repoRoot, 'apps/ios/project.yml')
  const pbxprojPath = path.join(repoRoot, 'apps/ios/BillBandit.xcodeproj/project.pbxproj')

  const infoPlist = readIfExists(infoPlistPath)
  const entitlements = readIfExists(entitlementsPath)
  const releaseConfig = readIfExists(releaseConfigPath)
  const debugConfig = readIfExists(debugConfigPath)
  const exportOptions = readIfExists(exportOptionsPath)
  const projectYml = readIfExists(projectYmlPath)
  const pbxproj = readIfExists(pbxprojPath)

  const checks = {
    bundleIdPreserved: projectYml.includes(`PRODUCT_BUNDLE_IDENTIFIER: ${expectedBundleId}`) && pbxproj.includes(`PRODUCT_BUNDLE_IDENTIFIER = ${expectedBundleId};`),
    appleSignInEntitlement: entitlements.includes('com.apple.developer.applesignin') && entitlements.includes('Default'),
    releaseApiUsesBuildSetting: releaseConfig.includes('API_BASE_URL = $(BILLBANDIT_API_BASE_URL)'),
    debugApiIsMock: debugConfig.includes('mock:/$()/billbandit'),
    exportUploadsToAppStoreConnect: exportOptions.includes('<string>app-store-connect</string>') && exportOptions.includes('<string>upload</string>'),
    qaPrefillDebugOnly: readIfExists(path.join(repoRoot, 'apps/ios/BillBanditApp/Sources/InkAuthFlowView.swift')).includes('#if DEBUG') &&
      readIfExists(path.join(repoRoot, 'apps/ios/BillBanditApp/Sources/InkAuthFlowView.swift')).includes('--prefill-qa-auth'),
  }
  const config = {
    expectedBundleId,
    infoPlist: {
      displayName: extractPlistString(infoPlist, 'CFBundleDisplayName'),
      bundleIdentifier: extractPlistString(infoPlist, 'CFBundleIdentifier'),
      shortVersion: extractPlistString(infoPlist, 'CFBundleShortVersionString'),
      buildNumber: extractPlistString(infoPlist, 'CFBundleVersion'),
      apiBaseUrl: extractPlistString(infoPlist, 'API_BASE_URL'),
    },
    releaseXcconfig: releaseConfig.trim(),
    debugXcconfig: debugConfig.trim(),
    checks,
    archiveEnv: {
      BILLBANDIT_API_BASE_URL: process.env.BILLBANDIT_API_BASE_URL ?? null,
    },
  }
  const jsonFile = writeJSON('ios-release-config.json', config)
  const mdFile = path.join(evidenceDir, 'ios-build-settings-summary.md')
  fs.writeFileSync(mdFile, [
    '# iOS Release Config Summary',
    '',
    `- Expected bundle id: \`${expectedBundleId}\``,
    `- Info.plist bundle id: \`${config.infoPlist.bundleIdentifier}\``,
    `- Version/build: \`${config.infoPlist.shortVersion} (${config.infoPlist.buildNumber})\``,
    `- Release API setting: \`${config.releaseXcconfig}\``,
    `- Sign in with Apple entitlement: \`${checks.appleSignInEntitlement ? 'present' : 'missing'}\``,
    `- Export method: \`${checks.exportUploadsToAppStoreConnect ? 'app-store-connect upload' : 'not proven'}\``,
    `- Debug QA prefill flag: \`${checks.qaPrefillDebugOnly ? '--prefill-qa-auth DEBUG-only' : 'not proven'}\``,
    '',
  ].join('\n'))

  const failed = Object.entries(checks).filter(([, ok]) => !ok).map(([key]) => key)
  if (failed.length) {
    addGate('ios.release-config', 'iOS release configuration', 'blocker', `Failed checks: ${failed.join(', ')}`, [jsonFile, rel(mdFile)])
  } else {
    addGate('ios.release-config', 'iOS release configuration', 'pass', 'Bundle id, Apple entitlement, release API setting, export options, and DEBUG-only QA flag are intact.', [jsonFile, rel(mdFile)])
  }
  if (!process.env.BILLBANDIT_API_BASE_URL) {
    addGate('ios.archive-env', 'Archive API environment', 'warning', 'BILLBANDIT_API_BASE_URL is not set in this shell; archive commands must provide it.', [jsonFile])
  } else if (process.env.BILLBANDIT_API_BASE_URL !== expectedApiUrl) {
    addGate('ios.archive-env', 'Archive API environment', 'blocker', `BILLBANDIT_API_BASE_URL is ${process.env.BILLBANDIT_API_BASE_URL}, expected ${expectedApiUrl}.`, [jsonFile])
  } else {
    addGate('ios.archive-env', 'Archive API environment', 'pass', 'BILLBANDIT_API_BASE_URL is set to the expected production API URL.', [jsonFile])
  }
  return config
}

function runValidationChecks(dnsDoctor) {
  if (process.env.RELEASE_PROVE_SKIP_CHECKS === '1') {
    addGate('checks.automated', 'Automated repo checks', 'warning', 'Skipped because RELEASE_PROVE_SKIP_CHECKS=1.')
    return
  }

  const typecheck = runShell('npm run typecheck', 'npm run typecheck')
  addGate('checks.typecheck', 'Typecheck', typecheck.ok ? 'pass' : 'blocker', typecheck.ok ? 'TypeScript typecheck passed.' : 'Typecheck failed.', [typecheck.logPath])

  const contract = runShell('npm run contract:check', 'npm run contract:check')
  addGate('checks.contract', 'Contract check', contract.ok ? 'pass' : 'blocker', contract.ok ? 'Contract validation passed.' : 'Contract validation failed.', [contract.logPath])

  const build = runShell('npm run build', 'npm run build')
  addGate('checks.web-build', 'Web production build', build.ok ? 'pass' : 'blocker', build.ok ? 'Next production build passed.' : 'Next production build failed.', [build.logPath])

  const fallbackHost = new URL(railwayFallbackUrl).host
  const smokeEnv = {
    MOBILE_AUTH_SMOKE_IDENTIFIER: smokeIdentifier,
    MOBILE_AUTH_SMOKE_OTP_CODE: smokeOTP,
  }
  if (!dnsDoctor.intendedHealth.ok && dnsDoctor.fallbackHealth.ok) {
    smokeEnv.TEST_URL = railwayFallbackUrl
    smokeEnv.MOBILE_AUTH_SMOKE_HOST_HEADER = expectedApiHost
    smokeEnv.MOBILE_AUTH_SMOKE_TLS_SERVERNAME = expectedApiHost
  } else {
    smokeEnv.TEST_URL = expectedApiUrl
  }
  const smoke = runShell('npm run smoke:production-mobile', 'npm run smoke:production-mobile', { env: smokeEnv })
  addGate('checks.production-mobile-smoke', 'Production mobile API smoke', smoke.ok ? 'pass' : 'blocker', smoke.ok ? 'Mobile API ledger loop passed.' : 'Mobile API ledger loop failed.', [smoke.logPath])

  if (process.env.RELEASE_PROVE_SKIP_IOS_BUILD === '1') {
    addGate('checks.ios-build', 'iOS simulator build', 'warning', 'Skipped because RELEASE_PROVE_SKIP_IOS_BUILD=1.')
    return
  }
  const destination = process.env.RELEASE_IOS_DESTINATION ?? 'platform=iOS Simulator,name=iPhone 17 Pro'
  const iosBuild = runShell(
    'iOS simulator build',
    `xcodebuild -project apps/ios/BillBandit.xcodeproj -scheme BillBandit -configuration Debug -destination '${destination}' API_BASE_URL=${expectedApiUrl} COMPILER_INDEX_STORE_ENABLE=NO build`
  )
  addGate('checks.ios-build', 'iOS simulator build', iosBuild.ok ? 'pass' : 'blocker', iosBuild.ok ? 'iOS simulator build passed.' : 'iOS simulator build failed.', [iosBuild.logPath])

  const buildSettings = runShell(
    'iOS Release build settings',
    'xcodebuild -project apps/ios/BillBandit.xcodeproj -scheme BillBandit -configuration Release -showBuildSettings'
  )
  if (buildSettings.ok) {
    fs.writeFileSync(path.join(evidenceDir, 'ios-release-build-settings.txt'), buildSettings.stdout)
  }
}

function findRecentFiles(rootDir, predicate, limit = 5) {
  const files = []
  function walk(dir) {
    let entries = []
    try {
      entries = fs.readdirSync(dir, { withFileTypes: true })
    } catch {
      return
    }
    for (const entry of entries) {
      const filePath = path.join(dir, entry.name)
      if (entry.isDirectory()) {
        walk(filePath)
      } else if (predicate(filePath)) {
        try {
          files.push({ filePath, mtimeMs: fs.statSync(filePath).mtimeMs })
        } catch {
          // ignore
        }
      }
    }
  }
  if (fs.existsSync(rootDir)) walk(rootDir)
  return files.sort((a, b) => b.mtimeMs - a.mtimeMs).slice(0, limit).map((file) => file.filePath)
}

function copyFileInto(source, targetDir) {
  const target = path.join(targetDir, path.basename(source))
  fs.copyFileSync(source, target)
  return rel(target)
}

function sanitizeAppLog(raw) {
  return raw
    .split('\n')
    .filter((line) => line.includes('[BillBandit]') || line.includes('api.request') || line.includes('ledger.') || line.includes('auth.'))
    .join('\n')
    .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, '[email]')
    .replace(/\+\d{7,15}/g, '[phone]')
    .replace(/\beyJ[A-Za-z0-9._-]+\b/g, '[token]')
    .replace(/\bcm[a-z0-9]{18,}\b/g, '[id]')
}

function attachSimulatorEvidence() {
  const attachedScreenshots = []
  const explicitScreenshots = (process.env.RELEASE_SIM_SCREENSHOT_PATHS ?? '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean)
  for (const screenshot of explicitScreenshots) {
    if (fs.existsSync(screenshot)) attachedScreenshots.push(copyFileInto(screenshot, screenshotsDir))
  }

  if (attachedScreenshots.length === 0) {
    const xcodeWorkspaceRoot = path.join(os.homedir(), 'Library/Developer/XcodeBuildMCP/workspaces')
    const recentScreenshots = findRecentFiles(
      xcodeWorkspaceRoot,
      (filePath) => /FairShare/i.test(filePath) && /\.(png|jpg|jpeg)$/i.test(filePath) && !/AppIcon|assetcatalog|Build\/Products/.test(filePath),
      6
    )
    for (const screenshot of recentScreenshots) {
      attachedScreenshots.push(copyFileInto(screenshot, screenshotsDir))
    }
  }

  const explicitLog = process.env.RELEASE_SIM_RUNTIME_LOG_PATH
  const logCandidates = explicitLog && fs.existsSync(explicitLog)
    ? [explicitLog]
    : findRecentFiles(
        path.join(os.homedir(), 'Library/Developer/XcodeBuildMCP/workspaces'),
        (filePath) => /FairShare/i.test(filePath) && /com\.eshabhoon\.fairshare_.*\.log$/.test(filePath),
        1
      )
  const sourceLog = logCandidates[0]
  let timelinePath = null
  if (sourceLog) {
    const raw = fs.readFileSync(sourceLog, 'utf8').split('\n').slice(-500).join('\n')
    const sanitized = sanitizeAppLog(raw)
    timelinePath = path.join(simulatorDir, 'app-log-timeline.txt')
    fs.writeFileSync(timelinePath, sanitized || 'No structured BillBandit log lines found in attached runtime log.\n')
  } else {
    timelinePath = path.join(simulatorDir, 'app-log-timeline.txt')
    fs.writeFileSync(timelinePath, 'No XcodeBuildMCP runtime log was found. Run an iOS simulator proof and rerun release:prove with RELEASE_SIM_RUNTIME_LOG_PATH.\n')
  }

  const sim = {
    screenshots: attachedScreenshots,
    runtimeLogSource: sourceLog ?? null,
    sanitizedTimeline: rel(timelinePath),
  }
  const jsonFile = writeJSON('simulator-evidence.json', sim)

  if (attachedScreenshots.length > 0) {
    addGate('simulator.screenshots', 'Simulator screenshots', 'pass', `${attachedScreenshots.length} screenshot artifact(s) attached.`, [jsonFile, ...attachedScreenshots])
  } else {
    addGate('simulator.screenshots', 'Simulator screenshots', 'blocker', 'No simulator screenshots were attached. Use XcodeBuildMCP screenshot and rerun with RELEASE_SIM_SCREENSHOT_PATHS.', [jsonFile])
  }
  if (sourceLog) {
    addGate('simulator.logs', 'Sanitized simulator app log timeline', 'pass', 'Structured privacy-safe app log timeline attached.', [rel(timelinePath)])
  } else {
    addGate('simulator.logs', 'Sanitized simulator app log timeline', 'warning', 'No runtime log was found to sanitize.', [rel(timelinePath)])
  }
  return sim
}

function repoInfo() {
  const branch = runShell('git branch', 'git branch --show-current')
  const commit = runShell('git commit', 'git rev-parse --short HEAD')
  const status = runShell('git status', 'git status --short')
  return {
    branch: branch.stdout.trim(),
    commit: commit.stdout.trim(),
    dirty: status.stdout.trim().length > 0,
    status: status.stdout.trim(),
  }
}

function writeReport(summary) {
  const reportPath = path.join(evidenceDir, 'report.md')
  const gateRows = summary.gates.map((gate) => `| ${gate.status} | ${gate.label} | ${gate.detail.replace(/\n/g, ' ')} |`).join('\n')
  const blockerRows = summary.blockers.length ? summary.blockers.map((item) => `- ${item}`).join('\n') : '- None'
  const warningRows = summary.warnings.length ? summary.warnings.map((item) => `- ${item}`).join('\n') : '- None'
  const manualRows = summary.manualActions.map((item) => `- ${item}`).join('\n')
  const files = [
    'summary.json',
    'dns-api-health.json',
    'ios-release-config.json',
    'ios-build-settings-summary.md',
    'simulator-evidence.json',
    'simulator/app-log-timeline.txt',
  ].filter((file) => fs.existsSync(path.join(evidenceDir, file))).map((file) => `- \`${file}\``).join('\n')

  fs.writeFileSync(reportPath, [
    '# BillBandit Release Evidence',
    '',
    `Generated: ${summary.generatedAt}`,
    `Commit: \`${summary.repo.commit}\``,
    `Branch: \`${summary.repo.branch}\``,
    `Ready for TestFlight: **${summary.readyForTestFlight ? 'yes' : 'no'}**`,
    '',
    '## Gates',
    '',
    '| Status | Gate | Detail |',
    '|---|---|---|',
    gateRows,
    '',
    '## Release Blockers',
    '',
    blockerRows,
    '',
    '## Warnings',
    '',
    warningRows,
    '',
    '## Manual App Store / Account Actions',
    '',
    manualRows,
    '',
    '## Evidence Files',
    '',
    files,
    '',
    '## Notes',
    '',
    `- Expected production API host: \`${expectedApiHost}\``,
    `- Expected iOS bundle id: \`${expectedBundleId}\``,
    '- The Railway ingress fallback can prove API behavior but does not replace fixing public DNS before release.',
    '',
  ].join('\n'))
  return rel(reportPath)
}

function main() {
  const repo = repoInfo()
  if (repo.dirty) {
    addGate('repo.clean', 'Working tree', 'warning', 'Working tree has local changes while release evidence was generated.')
  } else {
    addGate('repo.clean', 'Working tree', 'pass', 'Working tree was clean at evidence start.')
  }

  let dnsDoctor = null
  let iosConfig = null
  let simulator = null
  if (mode === 'doctor' || mode === 'full') dnsDoctor = dnsAndApiDoctor()
  if (mode === 'ios' || mode === 'full') iosConfig = inspectIOSReleaseConfig()
  if (mode === 'full') {
    runValidationChecks(dnsDoctor)
    simulator = attachSimulatorEvidence()
  }

  const readyForTestFlight = blockers.length === 0
  const summary = {
    generatedAt: now.toISOString(),
    mode,
    readyForTestFlight,
    evidenceDir: rel(evidenceDir),
    expectedBundleId,
    expectedApiHost,
    repo,
    gates,
    blockers,
    warnings,
    manualActions,
    dnsDoctor,
    iosConfig,
    simulator,
    commands: commands.map(({ stdout, stderr, ...entry }) => entry),
  }
  const summaryFile = writeJSON('summary.json', summary)
  const reportFile = writeReport(summary)
  fs.writeFileSync(path.join(evidenceRoot, 'latest.txt'), `${rel(evidenceDir)}\n`)

  console.log(JSON.stringify({
    ok: true,
    readyForTestFlight,
    evidenceDir: rel(evidenceDir),
    summary: summaryFile,
    report: reportFile,
    blockers,
  }, null, 2))

  if (strict && !readyForTestFlight) {
    process.exit(1)
  }
}

main()
