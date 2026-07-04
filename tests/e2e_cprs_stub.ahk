; ===========================================================================
; e2e_cprs_stub.ahk - high-fidelity fake CPRS reminder dialog.
;
; Run with a copy of AutoHotkeyU64.exe RENAMED to CPRSChart.exe.
;
; Modeled on the REAL VAAES dialog: the window tree in
; logs/CPRS Booster logs (not cpfs)/dialog_dump_*.txt and the build logic in
; CPRS source (uReminders.pas TRemDlgElement.BuildControls, fReminderDialog.pas).
; Faithful behaviors reproduced (with source citations in comments):
;   - chrome: TPanel>TPanel>TGridPanel[Cancel/Finish/&Visit Info] + 2 TRichEdits;
;     reText carries the note text incl. "Version N.N" (read via WM_GETTEXT)
;   - TWO TScrollBox siblings, first Visible=N and empty (sb1/sb2 double buffer,
;     fReminderDialog.pas GetBox ~836; swap never fires from a checkbox click)
;   - repeating [TDlgFieldPanel, TCPRSDialogParentCheckBox] sibling pairs with
;     the panel's HWND created FIRST (dump ground truth), BOTH with empty
;     window text (labels are non-windowed TLabels - unreadable via Win32;
;     checkbox caption is ' ', uReminders.pas:5753-5754)
;   - TGroupBox nesting directly inside TGroupBox; one panel-only groupbox and
;     an empty display-only box level so checkbox depths SKIP a level
;     (observed 0,1,2,4-without-3 histogram mechanism)
;   - leaf TCPRSDialogCheckBox clusters INSIDE a TDlgFieldPanel, real captions,
;     created in reverse visual order (dump: Z-order is reverse of idx order)
;   - prompt-control noise the enumerator must skip: TCPRSDialogRichEdit,
;     TCPRSTemplateFieldLabel, TCPRSDialogFieldEdit, TCPRSDialogComboBox,
;     TCPRSDialogButton, TCPRSDialogHyperlinkLabel, orphan panels
;   - HideChildren parents create their children DEFERRED after the check
;     (posted-rebuild semantics, fReminderDialog.pas:1393-1397), children
;     insert directly below the parent and everything after shifts DOWN by
;     Top reassignment on REUSED HWNDs (partial rebuild, BuildAll=False frees
;     nothing: uReminders.pas:5693-5703,5727-5731)
;
; On startup the stub SAVES the template fixture (MockNeg.json) the way a real
; user save would - from the fully-expanded dialog, one item per checkbox in
; Y-order, labels only on leaves - plus expect.ini with the exact counts the
; driver must observe. Paths: %A_Temp%\nb_e2e_mock\.
; ===========================================================================
#NoEnv
#SingleInstance force
#Persistent
SetBatchLines, -1

global WS_CHILD := 0x40000000, WS_VISIBLE := 0x10000000
global WS_CLIPCHILDREN := 0x02000000, WS_BORDER := 0x00800000, WS_VSCROLL := 0x00200000
global WS_OVERLAPPEDWINDOW := 0x00CF0000
global BS_AUTOCHECKBOX := 0x3, BS_GROUPBOX := 0x7, ES_MULTILINE := 0x4
global gHInst := DllCall("GetModuleHandleW", "Ptr", 0, "Ptr")

; VISUAL MODE (opt-in, human inspection only): when the env var
; NB_E2E_VISUAL=1 is set, parent checkboxes get a readable caption + width so
; a person watching an apply can see which boxes toggle. The automated e2e
; NEVER sets this, so the default path (parent caption ' ', unreadable like
; real CPRS) is byte-identical - do not rely on captions in any assertion.
global gVisual := false
EnvGet, nbVisEnv, NB_E2E_VISUAL
if (nbVisEnv = "1")
    gVisual := true
global gVisCounter := 0
global gVisNames := ["Neuro WNL", "Cardiac WNL", "Respiratory WNL", "GI WNL"
    , "GU WNL", "Skin intact", "Musculoskeletal WNL", "Pain denied", "Psychosocial WNL"
    , "Safety addressed", "ADLs independent", "Fall risk assessed", "Education given"
    , "Lines/drains WNL", "Nutrition WNL", "Mobility WNL", "Sleep WNL", "Comfort WNL"]

global DIALOG_TITLE := "Reminder Dialog Template: MOCK NSG SHIFT ASSESSMENT"
global OutDir := A_Temp . "\nb_e2e_mock"
FileCreateDir, %OutDir%
; Clear any prior readiness/fixture BEFORE the dialog window exists, so the
; driver (which waits for the window then polls ready=1) can never latch a
; stale or half-written ready=1 from an earlier state and race ahead of this
; build. ready=1 is (re)written only at the very end of the build below.
FileDelete, %OutDir%\expect.ini
FileDelete, %OutDir%\MockNeg.json

; --- register the fake VCL classes (superclassed Button / plain containers) ---
SuperClass("Button", "TCPRSDialogParentCheckBox")
SuperClass("Button", "TCPRSDialogCheckBox")
SuperClass("Button", "TGroupBox")
SuperClass("Edit", "TRichEdit")
SuperClass("Edit", "TCPRSDialogFieldEdit")
SuperClass("ComboBox", "TCPRSDialogComboBox")
SuperClass("Button", "TCPRSDialogButton")
SuperClass("Button", "TButton")
SuperClass("Static", "TCPRSTemplateFieldLabel")
SuperClass("Static", "TCPRSDialogHyperlinkLabel")
PlainClass("TfrmRemDlg")
PlainClass("TScrollBox")
PlainClass("TDlgFieldPanel")
PlainClass("TPanel")
PlainClass("TGridPanel")
SuperClass("Edit", "TCPRSDialogRichEdit")

; ===========================================================================
; ELEMENT TREE (the "reminder definition"). Node kinds:
;   pair        - TDlgFieldPanel + TCPRSDialogParentCheckBox sibling pair
;   cluster     - pair whose panel contains leaf TCPRSDialogCheckBox controls
;   box         - display-only Box element: a TGroupBox only (no pnl/cb),
;                 children recurse inside (uReminders.pas:5704-5710 display-only
;                 with empty text emits nothing but its groupbox)
;   headedbox   - Box element WITH its own pair, groupbox follows as sibling
;   noise       - non-checkbox windowed control(s), skipped by the module
; Flags per node: chk (checked in the saved template), hide (HideChildren:
; children only exist after the parent is checked), lbl (leaf labels).
; ===========================================================================
global Tree := []
BuildTreeSpec()

; --- window tree state ---
global gDlg, gSbHidden, gSb, gReText
global gNodeById := {}          ; id -> node object (hwnds live on nodes)
global gExpandPending := []     ; nodes awaiting deferred child creation

; --- build chrome + collapsed dialog, then save fixture + expectations ---
BuildChrome()
LayoutDialog()                  ; creates collapsed-state windows
RealizeDialog()                 ; pump until the visible TScrollBox is a
                                ; findable direct child (the way the module
                                ; picks it) BEFORE advertising ready=1
WriteFixtureAndExpectations()   ; template = fully-expanded save, Y-order

; --- deferred-rebuild watcher: mirrors the posted UM_RESYNCREM partial
;     rebuild (runs strictly after the click's WM_COMMAND returns).
;     150ms is comfortably inside the module's 400ms leaf-speed window,
;     while keeping this thread mostly idle: an aggressive poll makes the
;     stub contend with the cross-process SendMessages the module's
;     enumeration sends it, which can abort EnumChildWindows mid-walk (a
;     harness artifact - real Delphi CPRS has a dedicated pump and no
;     such timer). The watcher switches itself OFF once every hide-parent
;     is built, so post-apply enumerations run against a silent stub. ---
SetTimer, WatchHideParents, 150
; Failsafe self-close only for the automated run (so a hung CI run cannot
; wedge). In visual/interactive mode the dialog must stay open until the
; user closes it, so no timed self-destruct there.
if (!gVisual)
    SetTimer, StubSelfDestruct, -240000
return

WatchHideParents:
    rebuildNeeded := false
    unbuilt := 0
    for i, node in gNodeById {
        if (node.hide && !node.built && node.cbHwnd) {
            unbuilt++
            SendMessage, 0xF0, 0, 0,, % "ahk_id " . node.cbHwnd
            if (ErrorLevel = 1)
                rebuildNeeded := true
        }
    }
    if (rebuildNeeded) {
        LayoutDialog()   ; partial rebuild: reuses HWNDs, creates missing children, shifts Tops
        ; recount after the rebuild marked nodes built
        unbuilt := 0
        for i, node in gNodeById {
            if (node.hide && !node.built)
                unbuilt++
        }
    }
    ; Automated mode: once all deferred content is built, go silent so
    ; nothing contends with the driver's post-apply enumerations.
    ; Visual/interactive mode: keep watching so a human clicking a
    ; HideChildren parent still spawns its children live.
    if (unbuilt = 0 && !gVisual)
        SetTimer, WatchHideParents, Off
return

StubSelfDestruct:
    ExitApp
return

; ===========================================================================
; TREE SPEC - scaled ~1/4 of the real VAAES dialog, same structural motifs.
; Leaf labels are national-template clinical texts (no user identifiers).
; ===========================================================================
BuildTreeSpec() {
    global Tree
    ; --- 5 flat sections: pairs at depth 1 ---
    Tree.Push(Box([P(1), P(0), P(0), P(0)]))
    Tree.Push(Box([P(1), P(1), P(0)]))
    Tree.Push(Box([P(0), P(1), P(0), P(0), P(0)]))
    Tree.Push(Box([P(0), P(0), P(1), P(0)]))
    Tree.Push(Box([P(1), P(0), P(0)]))

    ; --- section with one sub-groupbox (pairs at depth 2) ---
    Tree.Push(Box([P(1), P(0), Box([P(1), P(0), P(0), P(0)])]))

    ; --- section with a DEFERRED sub-box: checked parent creates a new
    ;     TGroupBox + 3 pairs at depth 2 (the +gb/+children delta seen
    ;     between the (actual) and (intended) dumps) ---
    hp := P(1)
    hp.hide := true
    hp.box := true
    hp.children := [P(1), P(0), P(0)]
    Tree.Push(Box([P(0), hp, P(0)]))

    ; --- leaf-heavy section: cluster panels with labeled leaf checkboxes ---
    cl1 := Cluster(1, ["Soft", "Non-tender", "Firm", "Guarding"], [1, 1, 0, 0], true)
    Tree.Push(Box([P(0), Box([P(0)]), cl1, ClusterStatic()]))

    ; --- deferred leaf cluster: checking its parent creates panel+4 leaves ---
    cl2 := Cluster(1, ["Warm", "Cool", "Cold", "Hot"], [1, 0, 0, 0], true)
    cl2.hide := true
    Tree.Push(Box([P(1), cl2]))

    ; --- deep chain: gbA(d2) holds ONLY gbB(d3) which holds ONLY gbC content
    ;     at d4 -> checkbox depths skip 3 entirely (real 0,1,2,4 histogram) ---
    gbC := Box([P(1), P(0), P(0), PanelOnlyBox()])
    gbB := Box([gbC])
    gbA := Box([gbB])
    Tree.Push(Box([P(1), P(0), gbA]))

    ; --- prompt-noise section: windowed non-checkbox controls the module
    ;     enumeration must ignore ---
    Tree.Push(Box([Noise("richedit"), P(1), P(0), Noise("fieldlabels")
        , CaptionBox("Select Result Category", [P(1), P(0), P(0)])
        , Noise("button"), Box([Noise("combo"), Noise("orphanpanel")])
        , Noise("orphanpanel"), Noise("hyperlink")]))

    ; --- loose tail at depth 0 (scrollbox-direct pairs, real dump lines
    ;     561-613): includes a deferred NON-box parent whose 2 child pairs
    ;     land at the SAME depth (non-box children share the container,
    ;     uReminders.pas:5829-5835) ---
    lt := P(1)
    lt.hide := true
    lt.children := [P(1), P(0)]
    Tree.Push(lt)
    Tree.Push(P(1))
    Tree.Push(P(0))
    Tree.Push(P(0))
    Tree.Push(Noise("orphanpanel"))
    Tree.Push(P(0))
}

P(chk) {
    return {kind: "pair", chk: chk, hide: false, box: false, children: []}
}

Box(children) {
    return {kind: "box", chk: 0, hide: false, box: true, children: children}
}

CaptionBox(caption, children) {
    n := Box(children)
    n.caption := caption
    return n
}

PanelOnlyBox() {
    return {kind: "box", chk: 0, hide: false, box: true, children: [Noise("orphanpanel")]}
}

Cluster(chk, labels, leafChk, hasEdit) {
    return {kind: "cluster", chk: chk, hide: false, box: false, children: []
        , labels: labels, leafChk: leafChk, hasEdit: hasEdit}
}

ClusterStatic() {
    return Cluster(0, ["Intact", "Impaired"], [0, 0], false)
}

Noise(what) {
    return {kind: "noise", what: what, chk: 0, hide: false, box: false, children: []}
}

; ===========================================================================
; CHROME (fReminderDialog.dfm: pnlFrmBottom > pnlBottom > gpButtons + reText/
; reData; template mode shows exactly Cancel / Finish / &Visit Info)
; ===========================================================================
BuildChrome() {
    global
    gDlg := MakeWin(0, "TfrmRemDlg", DIALOG_TITLE
        , WS_OVERLAPPEDWINDOW | WS_VISIBLE | WS_CLIPCHILDREN, 60, 60, 620, 760, 0, 0)

    pnlFrm := MakeWin(0, "TPanel", "", WS_CHILD | WS_VISIBLE, 0, 540, 600, 180, gDlg, 0)
    pnlBot := MakeWin(0, "TPanel", "", WS_CHILD | WS_VISIBLE, 0, 0, 600, 180, pnlFrm, 0)
    grid := MakeWin(0, "TGridPanel", "", WS_CHILD | WS_VISIBLE, 0, 0, 600, 24, pnlBot, 0)
    MakeWin(0, "TButton", "Cancel", WS_CHILD | WS_VISIBLE, 8, 1, 90, 22, grid, 2001)
    MakeWin(0, "TButton", "Finish", WS_CHILD | WS_VISIBLE, 104, 1, 90, 22, grid, 2002)
    MakeWin(0, "TButton", "&Visit Info", WS_CHILD | WS_VISIBLE, 200, 1, 90, 22, grid, 2003)
    gReText := MakeWin(0, "TRichEdit", "", WS_CHILD | WS_VISIBLE | ES_MULTILINE, 0, 26, 600, 110, pnlBot, 0)
    MakeWin(0, "TRichEdit", "", WS_CHILD | WS_VISIBLE | ES_MULTILINE, 0, 138, 600, 40, pnlBot, 0)
    ; reText carries the note text; the module greps it for "Version N.N"
    ; (real CPRS: template text flows into reText, fReminderDialog.pas:983+)
    verText := "Clinical Reminder Activity`r`nMOCK NSG SHIFT ASSESSMENT Version 3.2`r`n"
    ControlSetText,, %verText%, ahk_id %gReText%

    ; sb1 hidden+empty, sb2 visible with all content (double buffer)
    gSbHidden := MakeWin(0, "TScrollBox", "", WS_CHILD | WS_BORDER | WS_CLIPCHILDREN, 0, 0, 600, 540, gDlg, 0)
    gSb := MakeWin(0, "TScrollBox", ""
        , WS_CHILD | WS_VISIBLE | WS_BORDER | WS_VSCROLL | WS_CLIPCHILDREN, 0, 0, 600, 540, gDlg, 0)
}

; ===========================================================================
; LAYOUT ENGINE - mirrors TReminderDialog.BuildControls: one Y cursor walks
; ALL root elements (uReminders.pas:2906-2920); partial rebuild reuses HWNDs
; and reassigns Tops; expanded hide-parents get children created in place.
; Constants: Gap=3, IndentGap=18, gbTopIndent=9/16 (uReminders.pas:781-790).
; ===========================================================================
LayoutDialog() {
    global Tree, gSb
    y := 0
    for i, node in Tree
        y := BuildNode(node, gSb, 580, 6, y)
}

BuildNode(node, parentHwnd, parentWidth, x, y) {
    global gNodeById
    if (node.kind = "noise")
        return BuildNoise(node, parentHwnd, parentWidth, x, y)

    y += 3   ; Gap before every element

    if (node.kind = "pair" || node.kind = "cluster") {
        pnlH := (node.kind = "cluster") ? 46 : 20
        pnlW := parentWidth - x - 6 - 18
        if (!node.pnlHwnd) {
            ; panel HWND first, checkbox second (dump enumeration order);
            ; BOTH have empty window text (checkbox caption is ' ')
            node.pnlHwnd := MakeWin(0, "TDlgFieldPanel", ""
                , WS_CHILD | WS_VISIBLE, x + 18, y, pnlW, pnlH, parentHwnd, 0)
            ; default caption ' ' (unreadable, like real CPRS); visual mode
            ; only: readable caption + width so a human can watch the apply
            cbCap := " "
            cbW := 17
            if (gVisual && node.kind = "pair") {
                gVisCounter += 1
                idx := Mod(gVisCounter - 1, gVisNames.Length()) + 1
                cbCap := gVisNames[idx]
                cbW := pnlW
            }
            node.cbHwnd := MakeWin(0, "TCPRSDialogParentCheckBox", cbCap
                , WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX, x, y, cbW, 17, parentHwnd, 0)
            gNodeById.Push(node)
        } else {
            MoveWin(node.pnlHwnd, x + 18, y)
            MoveWin(node.cbHwnd, x, y)
        }
        ; cluster leaves defer like real HideChildren content: a hidden
        ; cluster's PAIR exists from the start, its leaves only after check
        if (node.kind = "cluster" && !node.built && (!node.hide || IsChecked(node))) {
            BuildClusterContents(node)
            node.built := true
        }
        y += pnlH
    }

    ; children: box elements wrap them in a TGroupBox SIBLING (parent = same
    ; container, uReminders.pas:5806-5816); non-box children continue in the
    ; same container at the same depth (uReminders.pas:5829-5835)
    hasChildren := node.children.Length() > 0
    expanded := hasChildren && (!node.hide || IsChecked(node))
    if (node.hide && expanded)
        node.built := true
    if (expanded) {
        if (node.box) {
            capIndent := (node.caption != "") ? 16 : 9
            if (!node.gbHwnd) {
                node.gbHwnd := MakeWin(0, "TGroupBox", node.caption != "" ? node.caption : ""
                    , WS_CHILD | WS_VISIBLE | BS_GROUPBOX, x + 9, y, parentWidth - (x + 9) - 3, 40, parentHwnd, 0)
            } else {
                MoveWin(node.gbHwnd, x + 9, y)
            }
            y1 := capIndent
            for i, child in node.children
                y1 := BuildNode(child, node.gbHwnd, parentWidth - (x + 9) - 3 - 6, 6, y1)
            SizeWin(node.gbHwnd, parentWidth - (x + 9) - 3, y1 + 9)
            y += y1 + 12
        } else {
            for i, child in node.children
                y := BuildNode(child, parentHwnd, parentWidth, x, y)
        }
    }
    return y
}

; leaf checkboxes live INSIDE the TDlgFieldPanel, flowing left-to-right,
; created in REVERSE visual order (dump Z-order ground truth); a
; TCPRSDialogFieldEdit rides along in one cluster
BuildClusterContents(node) {
    n := node.labels.Length()
    lx := 4
    xs := []
    if (node.hasEdit) {
        MakeWin(0, "TCPRSDialogFieldEdit", "", WS_CHILD | WS_VISIBLE | WS_BORDER
            , lx, 24, 60, 18, node.pnlHwnd, 0)
    }
    Loop, %n%
    {
        xs.Push(lx)
        lx += 100
    }
    node.leafHwnds := []
    Loop, %n%
        node.leafHwnds.Push(0)
    Loop, %n%
    {
        i := n - A_Index + 1   ; reverse creation order
        node.leafHwnds[i] := MakeWin(0, "TCPRSDialogCheckBox", node.labels[i]
            , WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX, xs[i], 3, 96, 18, node.pnlHwnd, 0)
    }
}

BuildNoise(node, parentHwnd, parentWidth, x, y) {
    y += 3
    if (node.hwnd) {
        MoveWin(node.hwnd, x + 18, y)
        return y + node.h
    }
    node.h := 20
    if (node.what = "richedit") {
        node.hwnd := MakeWin(0, "TDlgFieldPanel", "", WS_CHILD | WS_VISIBLE, x + 18, y, 300, 24, parentHwnd, 0)
        MakeWin(0, "TCPRSDialogRichEdit", "", WS_CHILD | WS_VISIBLE | ES_MULTILINE, 2, 2, 280, 20, node.hwnd, 0)
        node.h := 24
    } else if (node.what = "fieldlabels") {
        node.hwnd := MakeWin(0, "TDlgFieldPanel", "", WS_CHILD | WS_VISIBLE, x + 18, y, 300, 22, parentHwnd, 0)
        MakeWin(0, "TCPRSTemplateFieldLabel", "", WS_CHILD | WS_VISIBLE, 2, 2, 120, 16, node.hwnd, 0)
        MakeWin(0, "TCPRSTemplateFieldLabel", "", WS_CHILD | WS_VISIBLE, 130, 2, 120, 16, node.hwnd, 0)
        node.h := 22
    } else if (node.what = "button") {
        node.hwnd := MakeWin(0, "TCPRSDialogButton", "Scoring Information"
            , WS_CHILD | WS_VISIBLE, x + 18, y, 180, 22, parentHwnd, 0)
        node.h := 22
    } else if (node.what = "combo") {
        node.hwnd := MakeWin(0, "TCPRSDialogComboBox", ""
            , WS_CHILD | WS_VISIBLE | 0x2, x + 18, y, 160, 120, parentHwnd, 0)  ; CBS_DROPDOWN
        node.h := 24
    } else if (node.what = "hyperlink") {
        node.hwnd := MakeWin(0, "TDlgFieldPanel", "", WS_CHILD | WS_VISIBLE, x + 18, y, 300, 20, parentHwnd, 0)
        MakeWin(0, "TCPRSDialogHyperlinkLabel", "", WS_CHILD | WS_VISIBLE, 2, 2, 200, 16, node.hwnd, 0)
    } else {   ; orphanpanel
        node.hwnd := MakeWin(0, "TDlgFieldPanel", "", WS_CHILD | WS_VISIBLE, x + 18, y, 260, 20, parentHwnd, 0)
    }
    return y + node.h
}

IsChecked(node) {
    if (!node.cbHwnd)
        return false
    SendMessage, 0xF0, 0, 0,, % "ahk_id " . node.cbHwnd
    return (ErrorLevel = 1)
}

; Force the dialog's window tree to realize before we advertise ready=1.
; The build above runs entirely in the auto-execute thread, which has not
; pumped a single message yet; a Sleep here pumps this thread's queue so the
; children (notably the visible TScrollBox the driver picks cross-process)
; are fully created/shown. Confirm the scrollbox is findable the exact way
; the module finds it (GW_CHILD walk + WS_VISIBLE) so ready=1 truly means
; "the pickable scrollbox exists". Bounded so a pathological runner still
; proceeds and lets the driver's own stabilization report the failure.
RealizeDialog() {
    global gDlg
    DllCall("UpdateWindow", "Ptr", gDlg)
    Loop, 100 {
        if (FindVisibleScrollBoxLikeModule(gDlg))
            return
        Sleep, 20   ; pumps this thread's message queue
    }
}

FindVisibleScrollBoxLikeModule(dlgHwnd) {
    child := DllCall("GetWindow", "Ptr", dlgHwnd, "UInt", 5, "Ptr")   ; GW_CHILD
    while (child) {
        VarSetCapacity(buf, 256, 0)
        DllCall("GetClassName", "Ptr", child, "Str", buf, "Int", 256)
        if (buf = "TScrollBox") {
            style := DllCall("GetWindowLong", "Ptr", child, "Int", -16, "Int")   ; GWL_STYLE
            if (style & 0x10000000)   ; WS_VISIBLE
                return child
        }
        child := DllCall("GetWindow", "Ptr", child, "UInt", 2, "Ptr")   ; GW_HWNDNEXT
    }
    return 0
}

; ===========================================================================
; FIXTURE + EXPECTATIONS - the template a real user save would produce:
; one item per checkbox of the FULLY-EXPANDED dialog in Y-order (parents
; before their children; cluster leaves left-to-right), format 7, labels
; ONLY on leaf items, UTF-8 BOM like real AHK-written templates.
; ===========================================================================
WriteFixtureAndExpectations() {
    global Tree, OutDir, DIALOG_TITLE
    items := []
    for i, node in Tree
        CollectItems(node, 0, items)

    q := """"
    tpl := "{`n  " . q . "name" . q . ": " . q . "MockNeg" . q . ",`n"
    tpl .= "  " . q . "format" . q . ": 7,`n  " . q . "matching" . q . ": " . q . "flat-sequential" . q . ",`n"
    tpl .= "  " . q . "speed" . q . ": 600,`n  " . q . "leaf_speed" . q . ": 50,`n"
    tpl .= "  " . q . "source_dialogue" . q . ": " . q . DIALOG_TITLE . q . ",`n"
    tpl .= "  " . q . "source_version" . q . ": " . q . "3.2" . q . ",`n"
    tpl .= "  " . q . "checkboxes" . q . ": ["
    checkedCount := 0
    deferredCount := 0
    for i, it in items {
        tpl .= (i > 1 ? "," : "") . "`n    {" . q . "idx" . q . ": " . (i - 1)
            . ", " . q . "cls" . q . ": " . q . it.cls . q
            . ", " . q . "checked" . q . ": " . (it.chk ? "true" : "false")
            . ", " . q . "depth" . q . ": " . it.depth
        if (it.lbl != "")
            tpl .= ", " . q . "label" . q . ": " . q . it.lbl . q
        tpl .= "}"
        checkedCount += it.chk ? 1 : 0
        deferredCount += it.deferred ? 1 : 0
    }
    tpl .= "`n  ]`n}"
    FileDelete, %OutDir%\MockNeg.json
    FileAppend, %tpl%, %OutDir%\MockNeg.json, UTF-8   ; writes BOM like real saves

    total := items.Length()
    collapsed := total - deferredCount
    IniWrite, %total%, %OutDir%\expect.ini, expect, total
    IniWrite, %collapsed%, %OutDir%\expect.ini, expect, collapsed
    IniWrite, %checkedCount%, %OutDir%\expect.ini, expect, toggled
    IniWrite, 0, %OutDir%\expect.ini, expect, notfound
    ; cluster pairs can "bleed" a leaf caption into the parent's resolved
    ; label (module reads the panel's windowed children) - the real VAAES
    ; dump shows the same quirk (single labeled parent 'Other:')
    clusters := 0
    for i, it in items
        clusters += (it.leafIdx = 1) ? 1 : 0
    IniWrite, %clusters%, %OutDir%\expect.ini, expect, clusters
    ; depth histogram of the EXPANDED dialog (module semantics: TGroupBox
    ; ancestors below the scrollbox) - depth 3 must be ABSENT
    hist := {}
    for i, it in items
        hist[it.depth] := (hist[it.depth] ? hist[it.depth] : 0) + 1
    Loop, 6
    {
        d := A_Index - 1
        v := hist[d] ? hist[d] : 0
        IniWrite, %v%, %OutDir%\expect.ini, depth, d%d%
    }
    IniWrite, 1, %OutDir%\expect.ini, expect, ready
}

; walk the tree the same way the layout engine does, collecting template
; items in Y-order; depth = TGroupBox nesting; deferred = under a hide parent
CollectItems(node, depth, items, deferred := false) {
    if (node.kind = "noise")
        return
    if (node.kind = "pair" || node.kind = "cluster") {
        items.Push({cls: "TCPRSDialogParentCheckBox", chk: node.chk, depth: depth
            , lbl: "", deferred: deferred, node: node, leafIdx: 0})
        if (node.kind = "cluster") {
            ; a hidden cluster's leaves are deferred even though its pair exists
            for i, lbl in node.labels
                items.Push({cls: "TCPRSDialogCheckBox", chk: node.leafChk[i]
                    , depth: depth, lbl: lbl, deferred: (deferred || node.hide)
                    , node: node, leafIdx: i})
        }
    }
    childDeferred := deferred || node.hide
    childDepth := node.box ? depth + 1 : depth
    for i, child in node.children
        CollectItems(child, childDepth, items, childDeferred)
}

; ===========================================================================
; win32 helpers (superclass recipe: GetClassInfoExW -> overwrite hInstance +
; lpszClassName -> RegisterClassExW; 1410 = already registered on re-run)
; ===========================================================================
SuperClass(baseClass, newName) {
    global gHInst
    VarSetCapacity(wc, 80, 0)
    NumPut(80, wc, 0, "UInt")
    if !DllCall("GetClassInfoExW", "Ptr", 0, "WStr", baseClass, "Ptr", &wc, "Int")
        throw Exception("GetClassInfoExW(" . baseClass . ") failed, err=" . A_LastError)
    NumPut(gHInst, wc, 24, "Ptr")
    NumPut(0, wc, 56, "Ptr")
    VarSetCapacity(nameBuf, 128, 0)
    StrPut(newName, &nameBuf, "UTF-16")
    NumPut(&nameBuf, wc, 64, "Ptr")
    atom := DllCall("RegisterClassExW", "Ptr", &wc, "UShort")
    if (!atom && A_LastError != 1410)
        throw Exception("RegisterClassExW(" . newName . ") failed, err=" . A_LastError)
}

PlainClass(newName) {
    global gHInst
    hUser := DllCall("GetModuleHandleW", "Str", "user32", "Ptr")
    defProc := DllCall("GetProcAddress", "Ptr", hUser, "AStr", "DefWindowProcW", "Ptr")
    hCursor := DllCall("LoadCursorW", "Ptr", 0, "Ptr", 32512, "Ptr")
    VarSetCapacity(wc, 80, 0)
    NumPut(80, wc, 0, "UInt")
    NumPut(defProc, wc, 8, "Ptr")
    NumPut(gHInst, wc, 24, "Ptr")
    NumPut(hCursor, wc, 40, "Ptr")
    NumPut(16, wc, 48, "Ptr")
    VarSetCapacity(nameBuf, 128, 0)
    StrPut(newName, &nameBuf, "UTF-16")
    NumPut(&nameBuf, wc, 64, "Ptr")
    atom := DllCall("RegisterClassExW", "Ptr", &wc, "UShort")
    if (!atom && A_LastError != 1410)
        throw Exception("RegisterClassExW(" . newName . ") failed, err=" . A_LastError)
}

MakeWin(exStyle, cls, title, style, x, y, w, h, parent, id) {
    global gHInst
    hwnd := DllCall("CreateWindowExW", "UInt", exStyle, "WStr", cls, "WStr", title
        , "UInt", style, "Int", x, "Int", y, "Int", w, "Int", h
        , "Ptr", parent, "Ptr", id, "Ptr", gHInst, "Ptr", 0, "Ptr")
    if (!hwnd)
        throw Exception("CreateWindowExW(" . cls . ") failed, err=" . A_LastError)
    return hwnd
}

MoveWin(hwnd, x, y) {
    ; SWP_NOSIZE|SWP_NOZORDER|SWP_NOACTIVATE = 0x1|0x4|0x10
    DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", x, "Int", y, "Int", 0, "Int", 0, "UInt", 0x15)
}

SizeWin(hwnd, w, h) {
    ; SWP_NOMOVE|SWP_NOZORDER|SWP_NOACTIVATE = 0x2|0x4|0x10
    DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", w, "Int", h, "UInt", 0x16)
}
