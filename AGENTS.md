# Project Agent Instructions

## Current requirements

Before changing panel UI or Trail behavior, read the relevant section of `docs/specification.md`. Treat `docs/plans/` as historical implementation context; when a plan conflicts with the specification or current user instruction, follow the latter and update the specification.

## Trail tab invariants

- Keep each feature on one row at the 560px minimum panel width:
  - Break Even row: label, ON/OFF, Trigger `- [value] +`, Lock `- [value] +`.
  - Trailing row: label, ON/OFF, Trigger `- [value] +`, Distance `- [value] +`.
- Keep Basis on its own row. Its initial value is `Per Position`.
- Initialize all four numeric fields with visible text `0`.
- Preserve the one-row feature layout when changing widths or adding controls. A different row structure requires an explicit current user request.

## Verification

After changing `src/UiPanel.mqh`, `src/Constants.mqh`, or Trail settings, run:

```bash
rtk proxy python3 tests/run-price-editor-tests.py
rtk proxy python3 tests/run-trailing-stop-tests.py
rtk git diff --check
```

The first command includes a source-level check for the Trail row grouping, initial Basis, and visible zero values. MT5 layout changes also require manual verification at 560px and 100%・125%・150% display scaling.
