# Contracts

`openapi.yaml` is the shared mobile/backend contract for cross-platform feature
parity. The parity fixture pack in `fixtures/parity-fixtures.json` is the single
scenario source used by:

- backend API parity tests
- web end-to-end parity coverage
- the iOS mock API scenario data

Run `npm run contract:check` from the repo root to validate the contract surface,
DTO coverage, and fixture references.
