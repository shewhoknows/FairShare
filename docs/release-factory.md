# BillBandit Release Factory

The release factory generates a local evidence pack for the BillBandit iOS MVP.
It is designed to answer one question before TestFlight: can this commit prove
the real app, real mobile API, release configuration, DNS/API health, and core
ledger loop?

## Command

```sh
npm run release:prove
```

The command writes a timestamped folder under `release-evidence/<timestamp>/`.
Generated evidence is intentionally ignored by git so each run can produce fresh
logs, screenshots, and JSON without polluting the branch.

## Evidence Pack

Each run creates:

- `summary.json`: machine-readable gate result.
- `report.md`: human-readable release conclusion.
- `dns-api-health.json`: DNS, Railway ingress, and API health proof.
- `ios-release-config.json`: bundle id, entitlement, export, and release API checks.
- `ios-build-settings-summary.md`: compact iOS release config summary.
- `ios-release-build-settings.txt`: raw Release build settings when available.
- `logs/`: command logs for typecheck, contract, build, smoke, DNS, and iOS build.
- `screenshots/`: simulator screenshots attached from XcodeBuildMCP.
- `simulator/app-log-timeline.txt`: privacy-safe structured app log timeline.

The latest evidence path is also written to `release-evidence/latest.txt`.

## Gate Semantics

- `pass`: this gate is proven.
- `warning`: not blocking by itself, but must be understood before upload.
- `blocker`: do not treat the build as TestFlight-ready.

The command exits successfully by default when it produces evidence, even if the
report contains blockers. Use strict mode when wiring it into CI:

```sh
RELEASE_PROVE_STRICT=1 npm run release:prove
```

## Scoped QA OTP

The mobile API smoke uses scoped production OTP QA credentials. Defaults match
the documented internal smoke path:

```sh
MOBILE_AUTH_SMOKE_IDENTIFIER="+15555550199"
MOBILE_AUTH_SMOKE_OTP_CODE="123456"
```

Keep the matching Railway variables scoped to explicit QA identifiers. Remove
or intentionally retain them before public release.

## DNS Fallback

The preferred path uses the custom domain directly:

```sh
npm run release:prove
```

If `billbandit-api.contenthelper.in` does not resolve but Railway still has the
custom domain attached, the factory uses the Railway ingress fallback for API
proof:

```sh
RELEASE_RAILWAY_FALLBACK_URL="https://r0t6mi4v.up.railway.app" \
npm run release:prove
```

This fallback proves deployed API behavior, but it does not replace fixing DNS.
The report remains not TestFlight-ready while the custom domain fails normal
resolution.

## Simulator Evidence

The factory can attach simulator evidence produced by XcodeBuildMCP:

```sh
RELEASE_SIM_SCREENSHOT_PATHS="/path/to/screenshot.jpg" \
RELEASE_SIM_RUNTIME_LOG_PATH="/path/to/runtime.log" \
npm run release:prove
```

If these are not provided, the script searches recent XcodeBuildMCP FairShare
artifacts. Simulator screenshots and sanitized logs are evidence, while the
production mobile smoke remains the authoritative automated proof of the core
ledger write/settle loop.

## Focused Subcommands

```sh
npm run release:doctor
npm run release:ios-inspect
```

Use `release:doctor` to regenerate only DNS/API evidence. Use
`release:ios-inspect` to regenerate only bundle, entitlement, export, and release
configuration evidence.
