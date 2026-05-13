# API Boundary

FairShare keeps the production API inside the Next.js app for now:

- Runtime location: `apps/web/app/api`
- Shared cross-platform contract: `packages/contracts/openapi.yaml`
- Shared parity scenarios: `packages/contracts/fixtures/parity-fixtures.json`

This keeps the current deployment model intact while drawing a clear backend
boundary. A future extraction to a standalone `services/api` runtime should
preserve the OpenAPI contract and fixture-backed parity checks first, then move
the handlers behind that same interface.
