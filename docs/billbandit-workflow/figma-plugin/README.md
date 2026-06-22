# BillBandit Native Rebuild Figma Plugin

Generated local development plugin for rebuilding the documented BillBandit screens inside the existing open Figma file.

## Files

- `manifest.json` - import this through Figma Desktop: Plugins > Development > Import plugin from manifest.
- `code.js` - plugin entrypoint with embedded screenshot backplates.

## Behavior

- Creates/reuses the requested BB pages.
- Appends timestamped rebuild frames; it does not delete existing Figma content.
- Creates BB-prefixed local components for shell, receipt, forms, content rows, chips, stamps, and barcode.
- Builds 17 fixed 368x800 editable screen frames on `BB 06 Screens`.
- Places locked screenshot backplates behind native foreground UI.
- Adds `BB 07 QA Evidence` with run details and handoff gaps.

## Verified Figma Run

- Run ID: `bb-native-rebuild-2026-06-20T07-49-47-546Z`
- Target file: existing `FairShare Receipt Mascot SVG` Figma file.
- Result: plugin completed in Figma Desktop and selected `BB QA Evidence / bb-native-rebuild-2026-06-20T07-49-47-546Z`.
- Evidence:
  - `figma-qa-evidence.png`
  - `figma-screens-page.png`
- Figma QA frame reports `Screens rebuilt: 17 / 17` and `Components created: 36`.

## Limitation

This is a free local-plugin path, not Figma MCP. It still requires running the plugin once in Figma Desktop for the actual file write.
