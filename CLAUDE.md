# NursingBooster — agent notes

## Versioning (IMPORTANT — do not get this wrong)

Two release channels, **different label styles**:

| Channel  | Branch   | Label style | Current |
|----------|----------|-------------|---------|
| Dev/Beta | `master` | `devXX`     | `dev21` |
| Stable   | `stable` | `X.Y`       | `1.0`   |

The label appears in **two** lines of `nursingbooster_module.ahk`: the `vNB_PanelTitle`
line and the `vNB_VersionLine` line.

**When promoting dev → stable: copy the CODE from master, but RE-LABEL to stable's
next `X.Y` — never let the `devXX` label land on `stable`.** The stable module must
differ from master only in those two label lines. Full steps: `PROMOTE_TO_STABLE.md`.
(History: stable's label was wrongly carried as `dev6`/`dev18` from verbatim copies
before it was reset to `1.0`.)

## What ships

- `nursingbooster_module.ahk` is the live module users fetch (dev → `master` raw URL,
  stable → `stable` raw URL). It is `#Include`d into CPRSBooster on the user's machine.
- The big `CPRSBooster_*.ahk*` files are host/combined snapshots, not what users pull.

## Testing reality

- AHK v1 / Windows / CPRS only — it can't be run here. CI (`.github/workflows/ahk-ci.yml`)
  only validates **syntax**, not runtime behavior. Any behavior change must be
  smoke-tested on the Windows/CPRS box (the version label in the panel confirms which
  build is live).
