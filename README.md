# NursingBooster for CPRS

Nursing-specific automation module for [CPRSBooster](https://github.com/mAbock/CPRSBooster). Adds one-click template apply for CPRS reminder dialogs, CP Flowsheets templates, and quick action buttons.

**Opt-in only.** When disabled, CPRSBooster runs exactly as normal. NursingBooster downloads and updates automatically once enabled.

## Installation

### Step 1: Install CPRSBooster

Install CPRSBooster as normal for your VA location (typically found under the Gold Star folder). If you already have CPRSBooster running, skip this step.

### Step 2: Replace CPRSBooster Script

1. Find the CPRSBooster icon in your Windows taskbar (usually in the hidden icons area near the clock)
2. **Right-click** the icon and click **"Edit This Script"**
3. A text file will open — **File > Save As** and save a backup copy somewhere safe (e.g. your Desktop)
4. Open the file [`CPRSBooster_with_NursingBooster.ahk`](CPRSBooster_with_NursingBooster.ahk) on this GitHub page
5. Click the **Copy** button (or select all with Ctrl+A and copy with Ctrl+C)
6. Go back to the CPRSBooster script you opened in Step 2
7. Select all (Ctrl+A) and paste (Ctrl+V) to replace the entire content
8. Save the file (Ctrl+S)
9. **Right-click** the CPRSBooster taskbar icon again and click **"Reload This Script"**

### Step 3: Enable NursingBooster

1. Press **Ctrl+H** to open the CPRSBooster settings screen
2. Scroll to the bottom — you'll see a **"Nursing Booster Module"** section
3. Check **"Enable Nursing Booster (downloads from GitHub)"**
4. Leave the Channel as **"Stable"** (or select "Beta/Dev" if you want the latest development version)
5. Click **OK**
6. CPRSBooster will download the NursingBooster module and reload automatically
7. Press **Ctrl+Shift+B** to toggle the NursingBooster panel

That's it. NursingBooster will automatically check for updates 30 seconds after each startup.

## Features

- **Template Apply** — Save and replay checkbox states for CPRS reminder dialogs (e.g. VAAES Shift Assessment with 292 checkboxes applied in seconds)
- **CP Flowsheets** — Save and apply observation templates for CP Flowsheets
- **Quick Actions** — Configurable buttons for frequently used templates
- **Auto-Add for CPFS** — Optionally clicks "Add Data" before applying CP Flowsheets templates
- **Right-click to cancel** — Right-click during template apply to stop immediately
- **Auto-hide during sign** — Panel hides when F-keys are pressed and restores after 6 seconds

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

## To Restore Original CPRSBooster

If you want to remove NursingBooster entirely:
1. Find the backup you saved in Step 2
2. Right-click CPRSBooster icon > Edit This Script
3. Replace the content with your backup
4. Save and Reload

## For Developers

- Module source: [`nursingbooster_module.ahk`](nursingbooster_module.ahk) on this repo
- Dev work happens on the `master` branch
- Stable releases are on the `stable` branch
- To promote dev to stable: see [CONTRIBUTING.md](CONTRIBUTING.md) (coming soon)
- Integration details for CPRSBooster maintainers: see the [`cprsbooster-integration-proposal`](https://github.com/kingpanther13/NursingBooster/tree/cprsbooster-integration-proposal) branch
