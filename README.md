# NursingBooster for CPRS

> **TESTING ONLY — NOT OFFICIALLY APPROVED**
>
> This software is currently in testing and is **not officially approved or condoned by the VA, CPRSBooster, or any other organization.** Use at your own risk. This is an unofficial, independently developed tool.
>
> **YOU are responsible for reviewing all charting and documentation before signing.** NursingBooster fills out checkbox templates to save time, but it does NOT replace clinical judgment. Always verify that every checkbox, radio button, and field is correct before clicking Finish or Sign. Errors in documentation are YOUR responsibility.

---

Nursing-specific automation module for [CPRSBooster](https://github.com/mAbock/CPRSBooster). Adds one-click template apply for CPRS reminder dialogs, CP Flowsheets templates, and quick action buttons.

**Opt-in only.** When disabled, CPRSBooster runs exactly as normal. NursingBooster downloads and updates automatically once enabled.

### How Updates Work

- **NursingBooster module**: Updates automatically from GitHub. When a new version is published, it downloads on the next CPRSBooster startup (30-second background check). No action needed from the user.
- **CPRSBooster integration script**: Module updates do not update the host script you pasted in Step 2. When this repository refreshes the CPRSBooster base or fixes its integration, repeat Step 2 with the current [`CPRSBooster_with_NursingBooster.ahk`](CPRSBooster_with_NursingBooster.ahk). A CPRSBooster update may also replace that file and require you to re-apply the integration.

The replacement script now incorporates the CPRSBooster production script supplied on **October 22, 2026**, including its newer BAM and helper changes. Existing NursingBooster users should also repeat Step 2 to receive this update and the fresh-install fix. Existing templates and module settings remain in place; the host migrates the older enable/channel preferences when it reads them.

## Installation

### Step 1: Install CPRSBooster

Install CPRSBooster as normal for your VA location (typically found under the Gold Star folder). If you already have CPRSBooster running, skip this step.

### Step 2: Replace CPRSBooster Script

1. Find the CPRSBooster icon in your Windows taskbar (usually in the hidden icons area near the clock)
2. **Right-click** the icon and click **"Edit This Script"**
3. A text file will open — **File > Save As** and save a backup copy somewhere safe (e.g. your Desktop). **Close that editor window after saving the backup.**
4. Right-click the CPRSBooster icon and choose **"Edit This Script"** again. This reopens the active script so you edit it instead of the backup.
5. Open [`CPRSBooster_with_NursingBooster.ahk`](CPRSBooster_with_NursingBooster.ahk) on this GitHub page, then click **Raw** to display only the script text.
6. Select all of the raw script (Ctrl+A) and copy it (Ctrl+C).
7. Return to the active CPRSBooster script editor, select all (Ctrl+A), and paste (Ctrl+V) to replace the entire content. Keep its existing filename and location.
8. Save the file (Ctrl+S).
9. **Right-click** the CPRSBooster taskbar icon again and click **"Reload This Script"**. On a fresh installation, this reload must succeed before NursingBooster has been downloaded; then continue to Step 3.

### Step 3: Enable NursingBooster

1. Press **Ctrl+H** to open the CPRSBooster settings screen
2. Scroll to the bottom — you'll see a **"Nursing Booster Module"** section
3. Check **"Enable Nursing Booster (downloads from GitHub)"**
4. Leave the Channel as **"Stable"** (or select "Beta/Dev" if you want the latest development version)
5. Click **OK**
6. CPRSBooster will download the NursingBooster module and reload automatically
7. Press **Ctrl+Shift+B** to toggle the NursingBooster panel

That's it. NursingBooster will automatically check for updates 30 seconds after each startup.

The module download requires access to GitHub. If it fails, CPRSBooster can still load; the script reports the download failure and checks again after startup. If the panel is unavailable, check GitHub access and restart CPRSBooster to retry.

## Features

- **Template Apply** — Save and replay checkbox states for CPRS reminder dialogs (e.g. VAAES Shift Assessment with 292 checkboxes applied in seconds)
- **CP Flowsheets** — Save and apply observation templates for CP Flowsheets
- **Quick Actions** — Configurable buttons for frequently used templates, labeled with the template's own name
- **Auto-Add for CPFS** — Optionally clicks "Add Data" before applying CP Flowsheets templates
- **Right-click to cancel** — Right-click during template apply to stop immediately
- **Auto-hide during sign** — Panel hides when F-keys are pressed and restores after 6 seconds

## Panel Layout

The floating panel (Ctrl+Shift+B) has one dropdown per section instead of a row
of Save/Load/Delete buttons:

| Row | Controls |
|-----|----------|
| CPRS | **CPRS** dropdown (Save / Load / Delete) - **Settings** - **Reload BP** - **Bars** |
| CP Flowsheets | **CPFS** dropdown (Save / Load / Delete) - **Add Data** - **BCMA** / **CPFS** launchers - **Auto-Add** checkbox |
| Quick Actions | Five configurable buttons plus **...** to set them up |

Picking an item runs it and the dropdown snaps back to its section name, so the
menu never sits on an action you already ran.

**NursingBooster never clicks Save in CP Flowsheets.** The old AutoSave option
did, and it was removed as unsafe — it wrote to the patient record without a
final review. Always review what was applied and save by hand.

## Channels

| Channel | Description | Who should use it |
|---------|-------------|-------------------|
| **Stable** | Tested and verified | Most users |
| **Beta/Dev** | Latest features, may have bugs | Testers and the developer |

You can switch channels anytime via Ctrl+H settings. The script downloads the selected channel's version and reloads.

## To Disable

1. Press **Ctrl+H**
2. Uncheck **"Enable Nursing Booster"**
3. Click **OK**

The panel hides immediately. No restart needed. CPRSBooster continues running normally.

## Troubleshooting: "Target label does not exist" on Reload

An older integration script could fail on a fresh installation at a line such as `SetTimer, NB_CheckCPRS, Off`. It referenced module timers before the module had been downloaded, so even the initial reload failed. An existing installation with a cached module could work normally with the same script.

Repeat Step 2 using the current replacement script. It allows the first reload without a cached module, after which you can enable NursingBooster through Ctrl+H. Updating the module alone does not fix the old host script.

## Troubleshooting: NursingBooster Option Disappeared

CPRSBooster may occasionally revert back to its regular production script (e.g. after an auto-update). When this happens, the "Enable Nursing Booster" checkbox will no longer appear in Ctrl+H settings.

**Fix:** Simply repeat Step 2 above — right-click CPRSBooster icon, Edit This Script, paste the script from this page again, save, and reload. Your NursingBooster settings and templates are preserved in OneDrive and will load right back up.

## Bugs and Feature Requests

Found a bug? Have a suggestion? Please post it on the [Issues page](https://github.com/kingpanther13/NursingBooster/issues). Bug reports and feature requests are encouraged — they help make NursingBooster better for everyone.

## To Restore Original CPRSBooster

If you want to remove NursingBooster entirely:
1. Find the backup you saved in Step 2
2. Right-click CPRSBooster icon > Edit This Script
3. Replace the content with your backup
4. Save and Reload

## For Developers

- Host script: [`CPRSBooster_with_NursingBooster.ahk`](CPRSBooster_with_NursingBooster.ahk). Its base is the unmodified `CPRSBooster_ACTIVE_PRODUCTION_SCRIPT.ahk` supplied on 2026-10-22, SHA-256 `e1b6240dd87ee8e038602ad6ad193f0eabfffdc1ffbb95cdecadd44b8d950ea9`. Both old and new bases identify themselves as `CurVersion = 90`, so that field alone does not distinguish the snapshots. No executable is bundled or changed by this update.
- The host expects the installed script in `CPRSBooster\Engine\` and includes the optional module from the parent `CPRSBooster\` folder. Optional module timer targets must use runtime expressions; an `IsLabel()` guard does not prevent AutoHotkey v1 from resolving a literal timer label during loading.
- `CPRSData.txt` slots: **83 = CPRSBooster DisableBAM**, **84 = NursingBooster enabled**, **85 = channel**. The legacy NursingBooster layout is recognized by a `stable`/`master` channel in slot 84 and an empty slot 85. Its preferences are migrated in memory and written in the new layout on the next settings save. Since that legacy layout had no BAM preference, migration uses CPRSBooster's default of BAM enabled. Existing new-base BAM preferences are preserved.
- Windows CI loads the complete host with and without a cached module, exiting before CPRS startup side effects, and exercises preference migration through the real host reader. These checks supplement module tests; they do not replace validation on a Windows CPRS installation.
- Module source: [`nursingbooster_module.ahk`](nursingbooster_module.ahk) on this repo
- Dev work happens on the `master` branch
- Stable releases are on the `stable` branch
- To promote dev to stable: see [CONTRIBUTING.md](CONTRIBUTING.md) (coming soon)
- Integration details for CPRSBooster maintainers: see the [`cprsbooster-integration-proposal`](https://github.com/kingpanther13/NursingBooster/tree/cprsbooster-integration-proposal) branch
