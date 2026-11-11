;==============================================================================
;  BTH 11/Nov/26 I asked Claude to write this based on cursor_finding_nov26.rtf
;  CaretFinder.ahk  -  "Find My Mouse", but for the TEXT cursor (caret)
;==============================================================================
;
;  WHAT IT DOES
;    Double-tap either Shift key and a ring appears around the text cursor in
;    the document you are typing in. It starts large, shrinks onto the cursor
;    (movement is easy to catch with peripheral vision), stays briefly, then
;    fades when you press a key. If no text cursor can be found you hear the
;    Windows "Exclamation" sound (changeable in SETTINGS).
;
;    The ring is click-through, never takes focus and never blocks typing:
;    you can carry on typing while it is on screen.
;
;  SECURITY / PERMISSIONS
;    * This script needs NO administrator rights, to install or to run.
;      It runs as your normal user account and should always be started
;      normally (double-click, or the Startup shortcut below).
;    * It never asks Windows for administrator rights itself. If it finds it
;      has been started as administrator anyway, it asks whether to carry on
;      and closes if you say No (see AllowRunAsAdmin in SETTINGS).
;    * It only reads the text cursor position. It does not record, store or
;      send what you type, and it makes no network connections.
;
;  HOW TO INSTALL (no administrator rights needed)
;    1. Get AutoHotkey **version 2** from https://www.autohotkey.com
;       ("Download v2.0"). Either:
;         - run the installer and, if it offers a choice, install for the
;           "Current user" only (this does not need administrator rights), or
;         - download the .zip version instead, unzip it into a folder of
;           your own, and open CaretFinder.ahk with AutoHotkey64.exe from it.
;           This needs no installation at all.
;    2. Put this file (CaretFinder.ahk) anywhere you like, e.g. Documents.
;    3. Double-click CaretFinder.ahk. A green "H" icon appears in the
;       system tray (bottom-right, by the clock). It is now running.
;    4. Click in a document and tap Shift twice quickly.
;
;  HOW TO MAKE IT RUN AT STARTUP
;    1. Right-click CaretFinder.ahk and choose "Create shortcut".
;    2. Press Windows+R, type   shell:startup   and press Enter.
;       Your personal Startup folder opens.
;    3. Move the shortcut you just made into that folder.
;       Do NOT tick "Run as administrator" in the shortcut's properties.
;    It will now start automatically each time you sign in to Windows.
;    (To stop that, delete the shortcut from the Startup folder.)
;
;  HOW TO CHANGE THE SETTINGS
;    Right-click the tray icon > "Edit Script" (or open this file in Notepad),
;    change the values in the SETTINGS section below, save, then right-click
;    the tray icon > "Reload Script".
;    Tray menu also has "Test ring at mouse pointer" for trying settings out.
;
;  HOW IT FINDS THE CURSOR (tried in this order)
;    1. Standard Windows caret (GetGUIThreadInfo)   - WordPad, Notepad, most
;                                                     classic Windows apps.
;    2. MSAA caret object (OBJID_CARET)             - many apps incl. browsers.
;    3. UI Automation text pattern                  - modern apps, Word, Edge.
;    4. IAccessible2 text interface                 - LibreOffice, Firefox.
;    The first method that gives a sensible position wins.
;
;  TROUBLESHOOTING
;    * Set ShowMethodTooltip := true (below) to see which method found the
;      cursor each time.
;    * If the ring appears in the WRONG place in one program, add that
;      program's file name to SkipStandardMethodFor below, e.g.
;      ["soffice.bin"] for LibreOffice or ["firefox.exe"] for Firefox.
;    * Firefox: make sure "Prevent accessibility services from accessing your
;      browser" is NOT ticked (Settings > Privacy & Security > Permissions).
;      The very first double-tap after Firefox starts can occasionally beep
;      while Firefox switches its accessibility support on; just try again.
;    * LibreOffice: if it beeps, check Tools > Options > LibreOffice >
;      Accessibility and tick "Support assistive technology tools" if your
;      version shows that option, then restart LibreOffice.
;    * Windows doesn't let normal programs read windows that are running "as
;      administrator", so the ring can't find the cursor in those (you'll
;      hear the not-found sound). This is a Windows safety feature, so leave
;      it in place. Ordinary documents, browsers and editors are not affected.
;      Do not run this script as administrator just to get around it.
;==============================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

;============================== SETTINGS ======================================
RingColour        := "FF00FF"   ; Ring colour as RRGGBB hex. Ideas: FF00FF magenta,
                                ;   FFFF00 yellow, 00FFFF cyan, FF0000 red, 00FF00 green
OutlineColour     := "000000"   ; Thin contrasting edge around the ring (helps on any
                                ;   background). "FFFFFF" = white edge.
OutlineWidth      := 3          ; Pixels of outline on each side of the ring. 0 = none.
RingThickness     := 8          ; Thickness of the coloured ring, in pixels.
RingRadius        := 45         ; Final radius of the ring around the cursor, pixels.
StartRadius       := 320        ; Ring starts this big and shrinks to RingRadius.
                                ;   Set equal to RingRadius for no shrinking.
ShrinkTime        := 300        ; Milliseconds the shrinking takes.
StayUntilKeyPress := true       ; true  = ring stays until you press any key, then fades.
                                ; false = ring fades by itself after DisplayTime.
DisplayTime       := 800        ; Milliseconds the ring stays (only if StayUntilKeyPress is false).
FadeTime          := 500        ; Milliseconds the fade-out takes. 0 = vanish instantly.
RingOpacity       := 240        ; 0 (invisible) to 255 (solid).

DoubleTapTime     := 400        ; Max milliseconds between the two Shift taps.
MaxTapHold        := 350        ; A Shift press held longer than this isn't a "tap".

NotFoundSound     := A_WinDir "\Media\Windows Exclamation.wav"
                                ; Sound played when no cursor is found. Any .wav file
                                ;   works, e.g. A_WinDir "\Media\Windows Ding.wav".
                                ;   Set to "" to use the simple beep below instead.
BeepFrequency     := 800        ; Simple beep (used if the sound file is missing or ""):
BeepDuration      := 200        ;   pitch in Hz and length in milliseconds.

SkipStandardMethodFor := []     ; Program files to skip methods 1-2 for, e.g.
                                ;   ["soffice.bin", "firefox.exe"]
ShowMethodTooltip := false      ; true = show which method found the cursor.

AllowRunAsAdmin   := false      ; false = if started as administrator, ask whether to
                                ;   carry on and close if you say No. Leave false.
;============================ END OF SETTINGS =================================

; Replace any missing / out-of-range settings with safe values (tells you if so).
ValidateSettings()

; Safety check: this script is designed to run as a normal user only.
if (A_IsAdmin && !AllowRunAsAdmin) {
    answer := MsgBox("Caret Finder has been started as administrator.`n`n"
        . "It doesn't need administrator rights and is meant to run normally.`n`n"
        . "Close it now? (Recommended: Yes, then start it again normally.)"
        , "Caret Finder", "YesNo Icon! Default1")
    if (answer = "Yes")
        ExitApp
}


; Work in real screen pixels so the ring lines up on high-DPI / mixed monitors.
try DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
; oleacc provides the MSAA / IAccessible2 methods. If it can't load, those
; methods simply fail (each call is guarded) and the others still work.
global gHaveOleacc := DllCall("LoadLibrary", "str", "oleacc.dll", "ptr") != 0
CoordMode("Mouse", "Screen")
CoordMode("ToolTip", "Screen")

IID_IAccessible      := "{618736E0-3C3D-11CF-810C-00AA00389B71}"
IID_IAccessible2     := "{E89F726E-C4F4-4C19-BB19-B647D7FA8478}"
IID_IAccessibleText  := "{24FD2FFB-3AAD-4A08-8335-A3AD89C0FB4B}"
IID_UIA_TextPattern  := "{32EBA289-3583-42C9-9C59-3B6D9A1E9B6A}"
IID_UIA_TextPattern2 := "{506A921A-FCC9-409F-B23B-37EB74106872}"

global gTapLast := 0, gShiftDownAt := 0, gTapSpoiled := false, gIH := 0
global gRings := [], gAnim := 0
global gLastFocus := {hwnd: 0, id: 0, child: 0}

; Tray menu
A_IconTip := "Caret Finder - double-tap Shift to find the text cursor"
A_TrayMenu.Add()
A_TrayMenu.Add("Test ring at mouse pointer", (*) => TestRing())
A_TrayMenu.Add("Show which method found the cursor", ToggleMethodTip)
if ShowMethodTooltip
    A_TrayMenu.Check("Show which method found the cursor")

; Remember which accessible object last got keyboard focus (helps LibreOffice).
; If the hook can't be set, IAccessible2 still works via its second route.
global gFocusCallback := CallbackCreate(OnFocusEvent, , 7)
global gFocusHook := DllCall("SetWinEventHook", "uint", 0x8005, "uint", 0x8005, "ptr", 0
      , "ptr", gFocusCallback, "uint", 0, "uint", 0, "uint", 0, "ptr")
if !gFocusHook {
    CallbackFree(gFocusCallback)
    gFocusCallback := 0
}
OnExit(CleanUp)

StartKeyWatcher()
return


;==============================================================================
;  Double-tap Shift detection (watches keys without blocking or altering them)
;==============================================================================
StartKeyWatcher(*) {
    global gIH
    gIH := InputHook("V L0")              ; V = keys pass through, L0 = collect no text
    gIH.KeyOpt("{All}", "N")              ; notify on every key
    gIH.OnKeyDown := WatchKeyDown
    gIH.OnKeyUp := WatchKeyUp
    gIH.OnEnd := (*) => SetTimer(StartKeyWatcher, -500)   ; restart if ever stopped
    gIH.Start()
}

IsShiftVK(vk) => (vk = 0x10 || vk = 0xA0 || vk = 0xA1)

WatchKeyDown(ih, vk, sc) {
    global gTapLast, gShiftDownAt, gTapSpoiled
    ; Any key press starts the fade of a ring that is waiting for one.
    if (IsObject(gAnim) && !gAnim.fadeStart && A_TickCount - gAnim.start >= 150)
        gAnim.fadeStart := A_TickCount
    if IsShiftVK(vk) {
        if !gShiftDownAt {                ; ignore key auto-repeat
            gShiftDownAt := A_TickCount
            gTapSpoiled := false
        }
    } else {                              ; any other key = not a double-tap
        gTapLast := 0
        gTapSpoiled := true
    }
}

WatchKeyUp(ih, vk, sc) {
    global gTapLast, gShiftDownAt, gTapSpoiled
    if !IsShiftVK(vk)
        return
    held := gShiftDownAt ? A_TickCount - gShiftDownAt : 99999
    spoiled := gTapSpoiled
    gShiftDownAt := 0
    if (spoiled || held > MaxTapHold) {   ; Shift+letter, or Shift held down
        gTapLast := 0
        return
    }
    if (gTapLast && A_TickCount - gTapLast <= DoubleTapTime) {
        gTapLast := 0
        SetTimer(ShowCaretRing, -1)       ; run outside the key callback
    } else {
        gTapLast := A_TickCount
    }
}

; A mouse click between the taps (e.g. Shift+click selecting) cancels.
~*LButton::
~*RButton::
~*MButton::
{
    global gTapLast := 0
}


;==============================================================================
;  Main action
;==============================================================================
ShowCaretRing() {
    method := ""
    r := FindCaret(&method)
    if !r {
        NotFoundAlert()
        if ShowMethodTooltip
            ShowTip("Caret Finder: no text cursor found")
        return
    }
    cx := r.x + r.w / 2, cy := r.y + r.h / 2
    if !ShowRingAt(cx, cy) {
        NotFoundAlert()                    ; couldn't draw: tell the user anyway
        return
    }
    if ShowMethodTooltip
        ShowTip("Caret found via: " method, cx - 60, cy + RingRadius + 15)
}

NotFoundAlert() {
    ; A .wav plays through the normal speakers at normal volume; the simple
    ; beep is a fallback because it can be hard to hear on some speakers.
    if (NotFoundSound != "" && FileExist(NotFoundSound)) {
        try {
            SoundPlay(NotFoundSound)
            return
        }
    }
    SoundBeep(BeepFrequency, BeepDuration)
}

ShowTip(text, x?, y?) {
    ToolTip(text, x?, y?)
    SetTimer(() => ToolTip(), -2500)
}

TestRing() {
    x := "", y := ""
    try MouseGetPos(&x, &y)
    if !ShowRingAt(x, y)
        NotFoundAlert()
}

CleanUp(*) {
    if gFocusHook
        DllCall("UnhookWinEvent", "ptr", gFocusHook)
    if gFocusCallback
        CallbackFree(gFocusCallback)
}

; A screen coordinate that is a real number of sensible size (rejects text,
; NaN, infinity and absurd values from misbehaving apps).
IsSaneCoord(v) => IsNumber(v) && v > -100000 && v < 100000

IsRect(r) {
    if !IsObject(r)
        return false
    for k in ["x", "y", "w", "h"]
        if (!r.HasOwnProp(k) || !IsSaneCoord(r.%k%))
            return false
    return r.w >= 0 && r.h >= 0
}

IsWindowHandle(hwnd) => IsInteger(hwnd) && hwnd != 0 && DllCall("IsWindow", "ptr", hwnd)

ToggleMethodTip(itemName, *) {
    global ShowMethodTooltip := !ShowMethodTooltip
    A_TrayMenu.ToggleCheck(itemName)
}


;==============================================================================
;  Finding the caret
;==============================================================================
FindCaret(&method) {
    method := ""
    hActive := WinExist("A")
    if !hActive
        return 0
    exe := ""
    try exe := WinGetProcessName(hActive)
    gti := GuiThreadInfo(hActive)
    hFocus := (gti && gti.focus) ? gti.focus : hActive

    skipStandard := false
    for name in SkipStandardMethodFor
        if (name = exe)
            skipStandard := true

    attempts := []
    if !skipStandard {
        attempts.Push(["Standard Windows caret", () => CaretFromGTI(gti)])
        attempts.Push(["MSAA caret object", () => CaretFromMSAACaret(hFocus)])
    }
    attempts.Push(["UI Automation", () => CaretFromUIA()])
    attempts.Push(["IAccessible2", () => CaretFromIA2(hFocus, hActive)])

    for a in attempts {
        r := 0
        try r := a[2]()
        if (r && Plausible(r, hActive)) {
            method := a[1]
            return r
        }
    }
    return 0
}

; Reject empty / off-window results (e.g. a stale hidden caret).
Plausible(r, hActive) {
    if (!IsRect(r) || r.h <= 0 || r.h > 600)
        return false
    if (r.x = 0 && r.y = 0)
        return false
    cx := r.x + r.w / 2, cy := r.y + r.h / 2
    try {
        WinGetPos(&wx, &wy, &ww, &wh, hActive)
    } catch {
        return true
    }
    m := 40
    return (cx >= wx - m && cx <= wx + ww + m && cy >= wy - m && cy <= wy + wh + m)
}

;---------- 1. Standard method: GetGUIThreadInfo -------------------------------
GuiThreadInfo(hwnd) {
    if !IsWindowHandle(hwnd)
        return 0
    tid := DllCall("GetWindowThreadProcessId", "ptr", hwnd, "ptr", 0, "uint")
    if !tid
        return 0
    gti := Buffer(8 + 6 * A_PtrSize + 16, 0)
    NumPut("uint", gti.Size, gti, 0)
    if !DllCall("GetGUIThreadInfo", "uint", tid, "ptr", gti)
        return 0
    rc := 8 + 6 * A_PtrSize
    return { focus:     NumGet(gti, 8 + A_PtrSize, "ptr")
           , caretHwnd: NumGet(gti, 8 + 5 * A_PtrSize, "ptr")
           , l: NumGet(gti, rc, "int"),     t: NumGet(gti, rc + 4, "int")
           , r: NumGet(gti, rc + 8, "int"), b: NumGet(gti, rc + 12, "int") }
}

CaretFromGTI(gti) {
    if (!gti || !IsWindowHandle(gti.caretHwnd) || gti.b <= gti.t || gti.r < gti.l)
        return 0
    pt := Buffer(8)
    NumPut("int", gti.l, "int", gti.t, pt)
    if !DllCall("ClientToScreen", "ptr", gti.caretHwnd, "ptr", pt)
        return 0
    return {x: NumGet(pt, 0, "int"), y: NumGet(pt, 4, "int")
          , w: Max(gti.r - gti.l, 0), h: gti.b - gti.t}
}

;---------- 2. MSAA caret object -----------------------------------------------
CaretFromMSAACaret(hwnd) {
    acc := AccFromWindow(hwnd, 0xFFFFFFF8)      ; OBJID_CARET
    if !acc
        return 0
    r := AccLocation(acc)
    return (r && r.h > 0) ? r : 0
}

;---------- 3. UI Automation ---------------------------------------------------
CaretFromUIA() {
    static uia := 0
    if !uia
        uia := ComObject("{FF48DBA4-60EF-4201-AA87-54103EEF594E}"   ; CUIAutomation
                       , "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}")  ; IUIAutomation
    pEl := 0
    if (ComCall(8, uia, "ptr*", &pEl, "int") < 0 || !pEl)   ; GetFocusedElement
        return 0
    el := ComValue(13, pEl)
    range := UIACaretRange(el)
    return range ? UIARangeToCaret(range) : 0
}

UIACaretRange(el) {
    ; Preferred: TextPattern2.GetCaretRange
    pPat := 0
    try ComCall(16, el, "int", 10024, "ptr*", &pPat)        ; GetCurrentPattern
    if pPat {
        pat := ComValue(13, pPat)
        try {
            tp2 := ComObjQuery(pat, IID_UIA_TextPattern2)
            active := 0, pR := 0
            ComCall(10, tp2, "int*", &active, "ptr*", &pR)  ; GetCaretRange
            if pR
                return ComValue(13, pR)
        }
    }
    ; Fallback: TextPattern.GetSelection (an empty selection is the caret)
    pPat := 0
    try ComCall(16, el, "int", 10014, "ptr*", &pPat)
    if pPat {
        pat := ComValue(13, pPat)
        try {
            tp := ComObjQuery(pat, IID_UIA_TextPattern)
            pArr := 0
            ComCall(5, tp, "ptr*", &pArr)                   ; GetSelection
            if pArr {
                arr := ComValue(13, pArr)
                n := 0
                ComCall(3, arr, "int*", &n)                 ; get_Length
                if (n > 0) {
                    pR := 0
                    ComCall(4, arr, "int", 0, "ptr*", &pR)  ; GetElement(0)
                    if pR
                        return ComValue(13, pR)
                }
            }
        }
    }
    return 0
}

UIARangeToCaret(range) {
    if (r := UIARangeBox(range))
        return {x: r.x, y: r.y, w: 0, h: r.h}
    ; Empty range has no box: measure the character after the caret ...
    if (c := UIACloneRange(range)) {
        if (ComCall(6, c, "int", 0, "int") >= 0       ; ExpandToEnclosingUnit(Character)
            && (r := UIARangeBox(c)))
            return {x: r.x, y: r.y, w: 0, h: r.h}
    }
    ; ... or the character before it (caret at end of line/document)
    if (c := UIACloneRange(range)) {
        moved := 0                                    ; MoveEndpointByUnit(Start, Character, -1)
        if (ComCall(14, c, "int", 0, "int", 0, "int", -1, "int*", &moved, "int") >= 0
            && moved != 0 && (r := UIARangeBox(c)))
            return {x: r.x + r.w, y: r.y, w: 0, h: r.h}
    }
    return 0
}

UIACloneRange(range) {
    pC := 0
    if (ComCall(3, range, "ptr*", &pC, "int") < 0 || !pC)  ; Clone
        return 0
    return ComValue(13, pC)
}

UIARangeBox(range) {
    psa := 0
    if (ComCall(10, range, "ptr*", &psa, "int") < 0 || !psa)  ; GetBoundingRectangles
        return 0
    box := 0
    try box := ReadFirstRectFromSafeArray(psa)
    DllCall("oleaut32\SafeArrayDestroy", "ptr", psa)
    return box
}

; The array should be 1-D doubles: left, top, width, height, (left, top, ...).
; Every step is checked before any memory is read.
ReadFirstRectFromSafeArray(psa) {
    if (DllCall("oleaut32\SafeArrayGetDim", "ptr", psa, "uint") != 1)
        return 0
    vt := 0
    if (DllCall("oleaut32\SafeArrayGetVartype", "ptr", psa, "ushort*", &vt, "int") != 0
        || vt != 5)                                       ; VT_R8 (double)
        return 0
    if (DllCall("oleaut32\SafeArrayGetElemsize", "ptr", psa, "uint") != 8)
        return 0
    lb := 0, ub := -1
    if (DllCall("oleaut32\SafeArrayGetLBound", "ptr", psa, "uint", 1, "int*", &lb, "int") != 0
        || DllCall("oleaut32\SafeArrayGetUBound", "ptr", psa, "uint", 1, "int*", &ub, "int") != 0)
        return 0
    if (ub - lb + 1 < 4)                                  ; need one whole rectangle
        return 0
    pData := 0
    if (DllCall("oleaut32\SafeArrayAccessData", "ptr", psa, "ptr*", &pData, "int") != 0)
        return 0
    try {
        if !pData
            return 0
        x := NumGet(pData, 0, "double"),  y := NumGet(pData, 8, "double")
        w := NumGet(pData, 16, "double"), h := NumGet(pData, 24, "double")
    } finally {
        DllCall("oleaut32\SafeArrayUnaccessData", "ptr", psa)
    }
    if (!IsSaneCoord(x) || !IsSaneCoord(y) || !IsSaneCoord(w) || !IsSaneCoord(h)
        || w < 0 || h <= 0)
        return 0
    return {x: Round(x), y: Round(y), w: Round(w), h: Round(h)}
}

;---------- 4. IAccessible2 (LibreOffice, Firefox) -----------------------------
OnFocusEvent(hHook, event, hwnd, idObject, idChild, idThread, eventTime) {
    global gLastFocus := {hwnd: hwnd, id: idObject & 0xFFFFFFFF, child: idChild & 0xFFFFFFFF}
}

CaretFromIA2(hFocus, hActive) {
    ; a) The object that most recently received keyboard focus
    f := gLastFocus
    if (IsWindowHandle(f.hwnd) && DllCall("GetAncestor", "ptr", f.hwnd, "uint", 2, "ptr") = hActive) {
        acc := AccFromEvent(f)
        if (acc && (r := IA2CaretRect(acc)))
            return r
    }
    ; b) Follow accFocus down from the focused window, then search nearby
    ;    children (e.g. the paragraphs of a LibreOffice document).
    if (acc := FocusedAccessible(hFocus)) {
        budget := 150
        if (r := SearchIA2Caret(acc, 3, &budget))
            return r
    }
    return 0
}

SearchIA2Caret(acc, depth, &budget) {
    if (--budget < 0)
        return 0
    r := 0
    try r := IA2CaretRect(acc)
    if r
        return r
    if (depth <= 0)
        return 0
    for child in AccChildren(acc)
        if (r := SearchIA2Caret(child, depth - 1, &budget))
            return r
    return 0
}

IA2CaretRect(acc) {
    text := IA2Text(acc)
    if !text
        return 0
    off := -1
    if (ComCall(5, text, "int*", &off, "int") != 0 || off < 0)    ; get_caretOffset
        return 0
    if (r := IA2CharBox(text, off))
        return {x: r.x, y: r.y, w: 0, h: r.h}
    if (off > 0 && (r := IA2CharBox(text, off - 1)))
        return {x: r.x + r.w, y: r.y, w: 0, h: r.h}
    ; Empty line/paragraph: use the object's own box if it is line-sized
    if ((r := AccLocation(acc)) && r.h > 0 && r.h < 100)
        return {x: r.x, y: r.y, w: 0, h: r.h}
    return 0
}

IA2Text(acc) {
    try {
        ia2 := ComObjQuery(acc, IID_IAccessible, IID_IAccessible2)  ; QueryService
        return ComObjQuery(ia2, IID_IAccessibleText)
    }
    try return ComObjQuery(acc, IID_IAccessible, IID_IAccessibleText)
    try return ComObjQuery(acc, IID_IAccessibleText)
    return 0
}

IA2CharBox(text, off) {
    x := 0, y := 0, w := 0, h := 0
    ; get_characterExtents(offset, IA2_COORDTYPE_SCREEN_RELATIVE, ...)
    if (ComCall(6, text, "int", off, "int", 0, "int*", &x, "int*", &y
                , "int*", &w, "int*", &h, "int") != 0)
        return 0
    r := {x: x, y: y, w: w, h: h}
    return (IsRect(r) && h > 0) ? r : 0
}

;---------- MSAA helpers -------------------------------------------------------
GuidBuf(str) {
    buf := Buffer(16)
    DllCall("ole32\CLSIDFromString", "wstr", str, "ptr", buf, "hresult")
    return buf
}

AccFromWindow(hwnd, objId) {
    static iid := GuidBuf("{618736E0-3C3D-11CF-810C-00AA00389B71}")
    if (!gHaveOleacc || !IsWindowHandle(hwnd))
        return 0
    p := 0
    if (DllCall("oleacc\AccessibleObjectFromWindow", "ptr", hwnd, "uint", objId
              , "ptr", iid, "ptr*", &p) != 0 || !p)
        return 0
    return ComValue(13, p)
}

AccFromEvent(f) {
    if (!gHaveOleacc || !IsWindowHandle(f.hwnd))
        return 0
    p := 0, v := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
    hr := DllCall("oleacc\AccessibleObjectFromEvent", "ptr", f.hwnd, "uint", f.id
                , "uint", f.child, "ptr*", &p, "ptr", v)
    DllCall("oleaut32\VariantClear", "ptr", v)   ; free whatever came back in varChild
    if (hr != 0 || !p)
        return 0
    return ComValue(13, p)
}

; Reads one VARIANT from a buffer we own. Returns an IAccessible wrapper if it
; holds an object, otherwise frees it and returns 0.
AccFromVariant(buf, offset) {
    vt := NumGet(buf, offset, "ushort")
    if (vt = 9 || vt = 13) {                     ; VT_DISPATCH / VT_UNKNOWN
        p := NumGet(buf, offset + 8, "ptr")
        if !p
            return 0
        wrapped := ComValue(13, p)               ; takes ownership, releases later
        try return ComObjQuery(wrapped, IID_IAccessible)
        return 0
    }
    DllCall("oleaut32\VariantClear", "ptr", buf.Ptr + offset)
    return 0                                     ; a child ID, or empty
}

AccLocation(acc, childId := 0) {
    x := 0, y := 0, w := 0, h := 0
    if (A_PtrSize = 8) {
        v := Buffer(24, 0)                       ; VARIANT (VT_I4 childId)
        NumPut("ushort", 3, v, 0), NumPut("int", childId, v, 8)
        hr := ComCall(22, acc, "int*", &x, "int*", &y, "int*", &w, "int*", &h, "ptr", v, "int")
    } else {
        hr := ComCall(22, acc, "int*", &x, "int*", &y, "int*", &w, "int*", &h
                    , "int64", 3, "int64", childId, "int")
    }
    if (hr != 0)
        return 0
    r := {x: x, y: y, w: w, h: h}
    return IsRect(r) ? r : 0
}

FocusedAccessible(hwnd) {
    acc := AccFromWindow(hwnd, 0xFFFFFFFC)       ; OBJID_CLIENT
    if !acc
        return 0
    loop 25 {
        child := 0
        try child := AccFocusedChild(acc)
        if (!child || child.Ptr = acc.Ptr)
            break
        acc := child
    }
    return acc
}

AccFocusedChild(acc) {
    v := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
    if (ComCall(18, acc, "ptr", v, "int") != 0)  ; get_accFocus
        return 0
    return AccFromVariant(v, 0)                  ; 0 = itself, a simple child, or nothing
}

AccChildren(acc, maxCount := 300) {
    out := [], n := 0
    if !gHaveOleacc
        return out
    hr := -1
    try hr := ComCall(8, acc, "int*", &n, "int") ; get_accChildCount
    if (hr != 0 || !IsInteger(n) || n <= 0)
        return out
    n := Min(n, maxCount)
    vsz := A_PtrSize = 8 ? 24 : 16
    buf := Buffer(n * vsz, 0), got := 0
    if (DllCall("oleacc\AccessibleChildren", "ptr", acc, "int", 0, "int", n
              , "ptr", buf, "int*", &got) < 0)
        return out
    got := Max(0, Min(got, n))                   ; never read past our buffer
    loop got {
        if (child := AccFromVariant(buf, (A_Index - 1) * vsz))
            out.Push(child)
    }
    return out
}


;==============================================================================
;  Drawing the ring (click-through, never activated, fades out)
;==============================================================================
CreateRingWindows() {
    ; E0x80000 layered, E0x20 click-through, E0x08000000 never activate
    opts := "+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x80000 +E0x20 +E0x08000000"
    rings := []
    try {
        if (OutlineWidth > 0) {
            g := Gui(opts), g.BackColor := OutlineColour
            rings.Push({gui: g, extra: OutlineWidth})
        }
        g := Gui(opts), g.BackColor := RingColour   ; created last = drawn on top
        rings.Push({gui: g, extra: 0})
    } catch {
        for ring in rings
            try ring.gui.Destroy()
        return false
    }
    for ring in rings
        gRings.Push(ring)
    return true
}

ShowRingAt(cx, cy) {
    global gAnim
    if (!IsSaneCoord(cx) || !IsSaneCoord(cy))
        return false
    if (!gRings.Length && !CreateRingWindows())
        return false
    gAnim := {cx: cx, cy: cy, start: A_TickCount, lastR: -1, fadeStart: 0}
    RingFrame()
    if !gAnim                                   ; first frame failed and hid the ring
        return false
    SetTimer(RingFrame, 15)
    return true
}

RingFrame() {
    global gAnim
    if !gAnim {
        SetTimer(RingFrame, 0)
        return
    }
    t := A_TickCount - gAnim.start
    r := RingRadius, a := RingOpacity
    if (t < ShrinkTime) {
        p := t / ShrinkTime
        p := 1 - (1 - p) ** 3                    ; ease-out
        r := StartRadius + (RingRadius - StartRadius) * p
    }
    ; When does the fade begin? At a key press, or after DisplayTime.
    fadeAt := StayUntilKeyPress ? gAnim.fadeStart : gAnim.start + ShrinkTime + DisplayTime
    if (fadeAt && A_TickCount >= fadeAt) {
        f := (A_TickCount - fadeAt) / Max(FadeTime, 1)
        if (f >= 1) {
            HideRing()
            return
        }
        a := RingOpacity * (1 - f)
    }
    r := Round(r)
    a := Max(0, Min(255, Round(a)))             ; alpha must fit in a byte
    for ring in gRings {
        hwnd := ring.gui.Hwnd
        if !DllCall("SetLayeredWindowAttributes", "ptr", hwnd, "uint", 0, "uchar", a, "uint", 2) {
            HideRing()                          ; can't control it: don't leave it stuck
            return
        }
        if (r != gAnim.lastR
            && !ShapeRing(hwnd, gAnim.cx, gAnim.cy, r + ring.extra, RingThickness + 2 * ring.extra)) {
            HideRing()
            return
        }
    }
    gAnim.lastR := r
}

; Cuts the window into a ring shape and places it centred on (cx, cy).
; Returns true on success; on failure frees anything it created.
ShapeRing(hwnd, cx, cy, radius, thick) {
    radius := Round(radius), thick := Round(thick)
    if (!IsWindowHandle(hwnd) || !IsSaneCoord(cx) || !IsSaneCoord(cy))
        return false
    if (radius < 1 || radius > 5000 || thick < 1)
        return false
    d := 2 * radius
    outer := DllCall("CreateEllipticRgn", "int", 0, "int", 0, "int", d + 1, "int", d + 1, "ptr")
    if !outer
        return false
    if (thick * 2 < d) {                        ; otherwise draw a solid disc
        inner := DllCall("CreateEllipticRgn", "int", thick, "int", thick
                       , "int", d - thick + 1, "int", d - thick + 1, "ptr")
        if !inner {
            DllCall("DeleteObject", "ptr", outer)
            return false
        }
        res := DllCall("CombineRgn", "ptr", outer, "ptr", outer, "ptr", inner, "int", 4)  ; RGN_DIFF
        DllCall("DeleteObject", "ptr", inner)
        if (res <= 1) {                         ; ERROR (0) or NULLREGION (1)
            DllCall("DeleteObject", "ptr", outer)
            return false
        }
    }
    if !DllCall("SetWindowRgn", "ptr", hwnd, "ptr", outer, "int", 1) {
        DllCall("DeleteObject", "ptr", outer)   ; still ours if Windows refused it
        return false
    }
    ; (Windows now owns the region and frees it.)
    ; HWND_TOPMOST, SWP_NOACTIVATE | SWP_SHOWWINDOW
    return DllCall("SetWindowPos", "ptr", hwnd, "ptr", -1, "int", Round(cx - radius)
                 , "int", Round(cy - radius), "int", d, "int", d, "uint", 0x50) != 0
}

HideRing() {
    global gAnim := 0
    SetTimer(RingFrame, 0)
    for ring in gRings
        try ring.gui.Hide()
}


;==============================================================================
;  Settings validation
;==============================================================================
ValidateSettings() {
    global RingColour, OutlineColour, OutlineWidth, RingThickness, RingRadius
         , StartRadius, ShrinkTime, StayUntilKeyPress, DisplayTime, FadeTime
         , RingOpacity, DoubleTapTime, MaxTapHold, NotFoundSound, BeepFrequency
         , BeepDuration, SkipStandardMethodFor, ShowMethodTooltip, AllowRunAsAdmin
    fixes := []
    RingColour        := CheckColour(RingColour, "FF00FF", "RingColour", fixes)
    OutlineColour     := CheckColour(OutlineColour, "000000", "OutlineColour", fixes)
    OutlineWidth      := CheckNumber(OutlineWidth, 0, 50, 3, "OutlineWidth", fixes)
    RingThickness     := CheckNumber(RingThickness, 1, 200, 8, "RingThickness", fixes)
    RingRadius        := CheckNumber(RingRadius, 5, 1000, 45, "RingRadius", fixes)
    StartRadius       := CheckNumber(StartRadius, 5, 2000, 320, "StartRadius", fixes)
    ShrinkTime        := CheckNumber(ShrinkTime, 0, 10000, 300, "ShrinkTime", fixes)
    DisplayTime       := CheckNumber(DisplayTime, 0, 600000, 800, "DisplayTime", fixes)
    FadeTime          := CheckNumber(FadeTime, 0, 10000, 500, "FadeTime", fixes)
    RingOpacity       := CheckNumber(RingOpacity, 1, 255, 240, "RingOpacity", fixes)
    DoubleTapTime     := CheckNumber(DoubleTapTime, 100, 2000, 400, "DoubleTapTime", fixes)
    MaxTapHold        := CheckNumber(MaxTapHold, 50, 2000, 350, "MaxTapHold", fixes)
    BeepFrequency     := CheckNumber(BeepFrequency, 37, 32767, 800, "BeepFrequency", fixes)
    BeepDuration      := CheckNumber(BeepDuration, 10, 5000, 200, "BeepDuration", fixes)
    StayUntilKeyPress := CheckBool(StayUntilKeyPress, true, "StayUntilKeyPress", fixes)
    ShowMethodTooltip := CheckBool(ShowMethodTooltip, false, "ShowMethodTooltip", fixes)
    AllowRunAsAdmin   := CheckBool(AllowRunAsAdmin, false, "AllowRunAsAdmin", fixes)
    if (RingThickness >= RingRadius) {
        RingThickness := Max(1, RingRadius // 4)
        fixes.Push("RingThickness must be smaller than RingRadius; using " RingThickness)
    }
    if !(NotFoundSound is String) {
        NotFoundSound := ""
        fixes.Push("NotFoundSound must be a file name in quotes; using the simple beep")
    }
    if !(SkipStandardMethodFor is Array) {
        SkipStandardMethodFor := []
        fixes.Push('SkipStandardMethodFor must be a list like ["soffice.bin"]; using []')
    }
    if fixes.Length {
        msg := "Some settings in CaretFinder.ahk were not valid, so safe values are being used:`n`n"
        for f in fixes
            msg .= "  - " f "`n"
        MsgBox(msg, "Caret Finder", "Icon! T60")
    }
}

ShowValue(v) => IsObject(v) ? "(a list or object)" : '"' v '"'

CheckNumber(v, lo, hi, default, name, fixes) {
    if (IsObject(v) || !IsNumber(v)) {
        fixes.Push(name " = " ShowValue(v) " is not a number; using " default)
        return default
    }
    n := Round(v)
    if (n < lo || n > hi) {
        c := Max(lo, Min(hi, n))
        fixes.Push(name " = " n " must be " lo " to " hi "; using " c)
        return c
    }
    return n
}

CheckColour(v, default, name, fixes) {
    if (v is String) {
        s := LTrim(Trim(v), "#")
        if RegExMatch(s, "^[0-9A-Fa-f]{6}$")
            return s
    }
    fixes.Push(name " = " ShowValue(v) " is not a colour like `"FF00FF`"; using " default)
    return default
}

CheckBool(v, default, name, fixes) {
    if (v = true || v = false) && !IsObject(v)
        return !!v
    fixes.Push(name " = " ShowValue(v) " must be true or false; using " (default ? "true" : "false"))
    return default
}
