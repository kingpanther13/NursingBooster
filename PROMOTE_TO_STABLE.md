# How to Promote Dev Module to Stable

When the dev module is tested and ready for all users.

## ⚠️ Versioning rule (READ FIRST)

The two channels use **different** version labels:

| Channel | Branch   | Label style | Example |
|---------|----------|-------------|---------|
| Dev/Beta| `master` | `devXX`     | `dev20` |
| Stable  | `stable` | `X.Y`       | `1.0`   |

The version label lives in **two** spots in `nursingbooster_module.ahk`:
- panel title — the `vNB_PanelTitle` line (`... Nursing Booster <ver>  |  Ctrl+Shift+B to toggle`)
- settings line — the `vNB_VersionLine` line (`... vNB_VersionLine, <ver>`)

**Do NOT copy `master` to `stable` verbatim** — that stamps the `devXX` label onto
stable. (This happened repeatedly: `v10.0` → `dev6` → `dev18`.) Promote the **code**,
but set the label to the next **stable X.Y**.

## Procedure

1. Switch to stable: `git checkout stable`
2. Bring the code over from master: `git checkout master -- nursingbooster_module.ahk`
3. **Re-label** both version strings to the next stable `X.Y` (e.g. `1.0` → `1.1`):
   edit the `vNB_PanelTitle` and `vNB_VersionLine` lines.
4. **Verify** — stable must differ from master ONLY in those two label lines:
   ```bash
   git diff master -- nursingbooster_module.ahk | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)'
   # expect exactly 4 lines: 2 removed (devXX), 2 added (X.Y)
   ```
5. Commit: `git commit -m "Promote to stable X.Y"`
6. Push: `git push origin stable`
7. Switch back: `git checkout master`

## What This Does

- The `stable` branch's `nursingbooster_module.ahk` gets the current `master` code,
  re-labelled with stable's own `X.Y` version.
- Users on the "Stable" channel get the update on their next startup (~30-second
  background check). "Beta/Dev" users already have the master version.

## When to Promote

- After testing the dev version in your own workflow for at least a few shifts
- After confirming no regressions in template apply accuracy
- After confirming CPFS templates still work correctly
- After confirming no focus-stealing or toolbar interference
