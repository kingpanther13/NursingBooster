# How to Promote Dev Module to Stable

When the dev module is tested and ready for all users:

## Quick Version (one command)

```bash
git checkout stable && git checkout master -- nursingbooster_module.ahk && git commit -m "Promote dev module to stable" && git push origin stable && git checkout master
```

## Step by Step

1. Switch to stable branch: `git checkout stable`
2. Copy module from master: `git checkout master -- nursingbooster_module.ahk`
3. Commit: `git commit -m "Promote devX to stable"`
4. Push: `git push origin stable`
5. Switch back: `git checkout master`

## What This Does

- The `stable` branch's `nursingbooster_module.ahk` gets replaced with the current `master` version
- Users on the "Stable" channel will get the update on their next startup (30-second background check)
- Users on "Beta/Dev" channel are unaffected (they already have the master version)

## When to Promote

- After testing the dev version in your own workflow for at least a few shifts
- After confirming no regressions in template apply accuracy
- After confirming CPFS templates still work correctly
- After confirming no focus-stealing or toolbar interference
