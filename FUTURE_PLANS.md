# CPRSBooster / Nursing Booster - Future Plans

## Section-by-Section Assessment Mode

The current template system applies a full assessment template all at once — every section gets the same saved state. In practice, most shift assessments have 8-10 negative/WNL systems and 1-2 abnormal ones that need specific charting. A section-by-section mode would make this faster and more flexible.

### Concept
- When applying a template, show a pre-apply dialog that lists each assessment section (Neuro, Cardiac, Respiratory, GI, GU, Skin, Musculoskeletal, Pain, Psychosocial, Safety, ADLs, etc.)
- Each section gets a dropdown or toggle:
  - **Negative** — auto-fill with saved WNL/normal defaults for that section
  - **Abnormal** — leave blank for manual charting, OR pick from a saved abnormal sub-template
  - **Skip** — don't touch this section at all
- Sections map to the top-level parent checkboxes and their corresponding TGroupBox groups in the CPRS reminder dialog

### Abnormal Sub-Templates
- Users can save per-section sub-templates for common abnormal findings
  - e.g. "Cardiac - AFib with RVR", "Respiratory - BiPAP/CPAP", "Neuro - CVA precautions", "Skin - Stage 2 sacral wound"
- The abnormal dropdown for each section would list any saved sub-templates for that body system
- Sub-templates would store just the checkboxes for that one section/group, not the whole assessment

### Implementation Notes
- Builds on the existing v5 template apply and group-matching infrastructure
- The section list can be auto-detected from the live dialog's TGroupBox structure
- Section names could be resolved from the top-level parent checkbox labels (or manually mapped for known VA assessment templates like VAAES ACUTE INPATIENT NSG SHIFT ASSESSMENT)
- Sub-templates would be small JSON files stored in a subfolder per assessment type (e.g. `NursingTemplates/Sections/Cardiac/`)
- The pre-apply dialog would be a new GUI (similar to the macro builder) with a listview of sections and per-row dropdowns

## Template & Macro Combining (Multi-Step Workflows)

Users should be able to combine templates and macros into multi-step workflows — chain them together so a single action runs an entire charting sequence.

### Concept
- Create a "combined workflow" that chains any mix of templates and macros in a user-defined order
- A workflow might look like: Apply "Negative Assessment" template → Run "Vitals entry" macro → Apply "Pain Section - Chronic" sub-template → Run "Sign note" macro
- Users can reorder the steps, enable/disable individual steps, or run the whole sequence end-to-end
- Each step can be a full template, a section sub-template, or a recorded macro

### Workflow Builder
- A GUI to build and edit workflows:
  - Add steps from saved templates, sub-templates, and macros
  - Drag-and-drop or up/down buttons to reorder
  - Checkboxes to enable/disable individual steps
  - "Run All" button to execute the full sequence, or click individual steps to run just that one
- Workflows are saved as JSON files referencing the component templates/macros by name/path

### Use Cases
- **Full shift charting**: Combine a negative assessment template with specific abnormal section templates and any follow-up macros into one workflow
- **Admission charting**: Chain admission assessment template + fall risk macro + skin assessment template + education template
- **Quick re-chart**: Run the same multi-step charting sequence across multiple patients with one click

### Implementation Notes
- Builds on the existing template apply and macro playback infrastructure
- Workflow JSON stores an ordered array of steps, each referencing a template path or macro path plus a step type ("template" or "macro")
- The runner iterates steps sequentially, calling `NB_ApplyNamedTemplate` or `NB_ExecuteMacro` for each
- Between steps, wait for CPRS to settle and dismiss any intermediate popups
- Ties into the section-by-section concept — a workflow could include section sub-templates as individual steps

## CPFS "Add Data" Shortcut

Currently, before using any CPFS quick buttons (like "Calm/Awake"), the user must scroll and search for the "Add Data" button on the CPFS home page. This is tedious since the button can be hard to find.

### Concept
- Add an "Add Data" shortcut button to the Nursing Booster window, or better yet, incorporate it into the CPFS macro/quick button flow
- Clicking a CPFS quick button (e.g. "Calm/Awake") from the home page would:
  1. Automatically find and press "Add Data" to open the data entry page
  2. Then the existing quick button logic pre-fills the data entry fields
  3. User manually saves (or auto-saves if that option is enabled)
- Eliminates the manual scroll/search for "Add Data" — the macro handles it

### Current vs. Proposed Flow
- **Current**: Navigate to CPFS home → scroll to find "Add Data" → click it → click "Calm/Awake" quick button → it fills out the form
- **Proposed**: Navigate to CPFS home → click "Calm/Awake" quick button → script presses "Add Data" automatically, data entry page opens, form is pre-filled

## Modular Architecture — Separate CPRSBooster and NursingBooster

Investigate whether NursingBooster can be split into a separate module that CPRSBooster loads on demand, so the two codebases can be updated independently.

### Concept
- CPRSBooster remains the main script — it runs standalone and handles all existing functionality (function keys, quick orders, hyperdrive bar, etc.)
- NursingBooster becomes a secondary module (separate `.ahk` or `.ahk.txt` file) that is only loaded when the user enables it
- CPRSBooster would have a setting or toggle to load/include the NursingBooster module at startup
- Each module can be versioned and updated independently — updating NursingBooster doesn't require touching CPRSBooster and vice versa

### Benefits
- Reduces risk of NursingBooster changes breaking CPRSBooster functionality
- Allows other nurses to use NursingBooster without needing the latest CPRSBooster, or vice versa
- Cleaner separation of concerns — shared variables and GUI numbering would need to be formalized into an interface

### Implementation Questions
- Can AHK v1 `#Include` a file conditionally at runtime, or does it need to be at parse time?
- How to handle shared state (e.g. `NB_ApplySpeed` used by both NB and CPFS, OneDrive paths, CPRS detection)?
- GUI numbering (67, 73, etc.) would need to be coordinated to avoid conflicts
- Would the module be loaded via `#Include`, `Run`, or a separate AHK process communicating via messages?

## AutoHotkey Tree View for CPRS Template Navigation

Add a tree view control that mirrors the CPRS reminder dialog structure, allowing users to find and jump to specific sections/checkboxes within a template without scrolling through the entire dialog.

### Concept
- When a CPRS reminder dialog is open, a tree view panel shows the hierarchical structure of all sections and checkboxes
- Users can click a section in the tree view to scroll the CPRS dialog to that section
- Could also show checked/unchecked state in the tree view for quick visual overview
- Useful for large assessments (VAAES Shift Assessment has 200+ checkboxes across many sections)

### Implementation Notes
- Build on existing `NB_EnumDescendantCheckboxes` and `NB_EnumScrollBoxGroupBoxes` which already enumerate the dialog structure with depth/hierarchy info
- Tree view would be a new AHK TreeView control (GUI) that rebuilds when a dialog is detected
- Clicking a tree node would need to scroll the CPRS dialog's TScrollBox to bring that checkbox into view — likely via `SendMessage` with `SB_THUMBPOSITION` or similar scroll control
- Could integrate with the section-by-section assessment concept — the tree view shows sections, and right-clicking a section offers "Apply sub-template" options

## Section-by-Section Charting — Additive/Non-Destructive Mode

Building on the section-by-section assessment concept above, it must be possible to fill in individual sections **after** the initial template has been applied, without disturbing already-filled sections.

### Use Case
- Nurse clicks "Negative Assessment" button — fills out most sections with WNL defaults, but leaves certain sections (e.g. IV) blank
- Nurse manually opens the IV section and selects the IV location by hand
- Nurse then clicks a button (e.g. "IV Details") that fills out only the detail fields for the IV section, leaving everything else untouched

### Key Requirement
- Section fill actions must be **additive only** — they write to their target fields and ignore everything else
- Already-charted sections must not be overwritten, cleared, or repositioned
- This allows mixing manual entry and automated fill freely across sections in any order
