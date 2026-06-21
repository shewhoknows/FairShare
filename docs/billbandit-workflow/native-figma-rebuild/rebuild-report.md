# BillBandit Native Figma Rebuild

Generated: 2026-06-20T07:32:20.578Z

## Output

- SVG: `docs/billbandit-workflow/native-figma-rebuild/billbandit-native-rebuild.svg`
- Brave import evidence: `docs/billbandit-workflow/native-figma-rebuild/brave-figma-imported-atlas.png`
- Screens rebuilt: 17
- Frame size: 368x800

## Figma Import Result

- Brave Browser with the Do Browser extension was able to inspect the open Figma canvas and start an automation session.
- The Do Browser automation stalled at the bulk `Build BB UI system` step and did not complete the requested native component/page write itself.
- Manual clipboard paste through Brave succeeded: Figma accepted this SVG into the existing open file and selected a new imported frame sized `2128x4520`.
- No existing Figma content was deleted.

## What This Provides

- A Figma-importable native SVG atlas with BB-prefixed groups.
- Locked-reference intent via `LOCKED BACKPLATE ...` image layers behind each native rebuild.
- Editable SVG text, rectangles, paths, circles, and grouped component proxies.
- Component catalog proxies for shell, receipt card, fields, buttons, chips, tab bar, and mascot.

## Limits

- This fallback cannot create true Figma variables, pages, variants, constraints, or component instances without a working Figma write API/plugin execution path.
- After import, lock the `LOCKED BACKPLATE ...` layers manually in Figma.
- Convert repeated BB groups into real Figma components if deeper Figma automation becomes available.
