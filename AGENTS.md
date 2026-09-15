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

## Entry tab invariants

- The order type is a sub-tab strip (`Market` / `Limit` / `Stop`), never a cycling button. The order price row is hidden on `Market`.
- There is no side toggle. `ENTRY_SELL` and `ENTRY_BUY` are both visible whenever the tab is, and the button pressed is the order's side.
- The side follows the prices: an unset or Pips SL/TP leaves both sides orderable; an absolute SL/TP price, a dragged line, or a pending order price enables only the side it satisfies. Disable the other button and name it in the hint — never flip or correct a value to make a side fit.
- Evaluate the draft once per side every refresh. `m_entry_snapshot`, `m_entry_result`, `m_entry_valid` and `m_entry_reason` are indexed by `PMEntrySide`; anything needing a single side uses `EntryReferenceSide()`.
- Keep the two preview rows always present so the send buttons never move.
- Keep each feature on one row at the 560px minimum width: SL and TP rows are label, mode, `- [value] +`, `Set`, `Clear`.

## Label conventions

- Action buttons drop words the row label or sub-tab already supplies (`Set`, not `Set SL`; `BUY`, not `BUY MARKET`).
- Mode buttons may drop redundant prefixes, but keep the domain vocabulary the spec uses. `Per Position` / `Average` stay spelled out.
- Close buttons stay explicit (`Close Now`, `Close Selected`). They are irreversible and show no confirmation dialog.
- `-` is the only token for a value that cannot be shown. Use `Invalid` only when a direction or price condition is known to be violated, and put the reason in the hint row.

## Verification

After changing `src/UiPanel.mqh`, `src/Constants.mqh`, or Trail settings, run:

```bash
rtk proxy python3 tests/run-price-editor-tests.py
rtk proxy python3 tests/run-trailing-stop-tests.py
rtk git diff --check
```

The first command includes source-level checks for the Entry and Trail row grouping, the Entry controls that must exist or stay removed, the initial Basis, and visible zero values. MT5 layout changes also require manual verification at 560px and 100%・125%・150% display scaling.
