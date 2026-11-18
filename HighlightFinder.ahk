;==============================================================================
;  BTH 18/Nov/26 I asked Claude to write this as a companion to CaretFinder.ahk
;  HighlightFinder.ahk  -  ring the CURRENT search match (Find / Ctrl+F)
;==============================================================================
;
;  WHAT IT DOES
;    After searching with Find (Ctrl+F) in a web browser or LibreOffice Writer,
;    double-tap either Alt key. A ring appears around the current match (the
;    one Find moved to, not the other highlighted matches). It starts large,
;    shrinks onto the match, and fades when you press a key. If no current
;    match can be found you hear the Windows "Exclamation" sound.
;
;    The ring is click-through, never takes focus and never blocks typing,
;    so you can keep pressing Enter / F3 to step through the matches.
;
;    Tapping Alt normally opens the menu bar, so the first tap may flash the
;    menu bar open and the second tap closes it again. The script waits a
;    moment (ScanDelay) for the window to settle before it looks.
;
;  SECURITY / PERMISSIONS
;    * Needs NO administrator rights, to install or to run. Start it normally.
;    * If it finds it has been started as administrator anyway, it asks whether
;      to carry on and closes if you say No (see AllowRunAsAdmin in SETTINGS).
;    * It only looks at the screen and the selected text's position while you
;      double-tap Alt. It does not record, store or send anything and it makes
;      no network connections. (It only writes to the clipboard if you choose
;      "Show colour under mouse pointer" from its tray menu.)
;
;  HOW TO INSTALL / RUN AT STARTUP
;    Exactly as for CaretFinder.ahk (see the top of that file): AutoHotkey v2,
;    double-click HighlightFinder.ahk, and put a shortcut to it in your
;    shell:startup folder if you want it to start when you sign in. The two
;    scripts are independent; run either or both.
;
;  HOW IT FINDS THE CURRENT MATCH (tried in this order)
;    Web browsers (see BrowserApps):
;      1. Highlight colour - looks on screen for the colour the browser paints
;         the current match: orange in Chrome / Edge, green in Firefox.
;         (Other matches are yellow / pink, so they are ignored.)
;      2. UI Automation selection - after you close the Find bar (Esc), the
;         browser selects the current match, so the selection is used.
;      3. IAccessible2 selection.
;    Everything else (LibreOffice, Word, Notepad ...):
;      1. UI Automation selection  - Find selects the match in the document.
;      2. IAccessible2 selection   - LibreOffice, Firefox.
;      3. Highlight colour.
;    If the Find window is a separate dialog (e.g. LibreOffice Find & Replace,
;    Ctrl+H), the document window behind it is searched as well.
;
;  TROUBLESHOOTING
;    * Set ShowMethodTooltip := true (or use the tray menu) to see which method
;      found the match each time.
;    * Browser ring in the wrong place, or a beep while the Find bar is open:
;      your browser may use a different highlight colour (themes and dark mode
;      can change it). Right-click the tray icon > "Show colour under mouse
;      pointer", then point at the current match within 3 seconds. The colour
;      is shown and copied to the clipboard; add it to MatchColours below.
;    * LibreOffice: if it beeps, check Tools > Options > LibreOffice >
;      Accessibility and tick "Support assistive technology tools" if your
;      version shows that option, then restart LibreOffice. LibreOffice's
;      "Find All" selects every match; the ring then goes round the first
;      one it comes to.
;    * Firefox: make sure "Prevent accessibility services from accessing your
;      browser" is NOT ticked (Settings > Privacy & Security > Permissions).
;    * Like CaretFinder, it can't look inside windows running as administrator.
;==============================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

;============================== SETTINGS ======================================
RingColour        := "FF00FF"   ; Ring colour as RRGGBB hex. Ideas: FF00FF magenta,
                                ;   00FFFF cyan, FF0000 red, 0000FF blue
OutlineColour     := "000000"   ; Thin contrasting edge around the ring. "FFFFFF" = white.
OutlineWidth      := 3          ; Pixels of outline on each side of the ring. 0 = none.
RingThickness     := 8          ; Thickness of the coloured ring, in pixels.
RingShape         := "circle"   ; "circle", or "oval" (hugs long phrases more closely).
RingPadding       := 12         ; Gap in pixels between the highlighted text and the ring.
MinRingRadius     := 45         ; The ring is never smaller than this, even round one letter.
StartGrowth       := 275        ; Ring starts this many pixels bigger, then shrinks onto
                                ;   the match. 0 = no shrinking.
ShrinkTime        := 300        ; Milliseconds the shrinking takes.
StayUntilKeyPress := true       ; true  = ring stays until you press any key, then fades.
                                ; false = ring fades by itself after DisplayTime.
DisplayTime       := 800        ; Milliseconds the ring stays (only if StayUntilKeyPress is false).
FadeTime          := 500        ; Milliseconds the fade-out takes. 0 = vanish instantly.
RingOpacity       := 240        ; 0 (invisible) to 255 (solid).

DoubleTapTime     := 400        ; Max milliseconds between the two Alt taps.
MaxTapHold        := 350        ; An Alt press held longer than this isn't a "tap".
ScanDelay         := 150        ; Milliseconds to wait after the second tap before looking,
                                ;   so a menu bar opened by the first tap has closed again.
StopAltMenu       := true       ; true  = a double-tap doesn't open/close the menu bar (which
                                ;   can move focus, e.g. into LibreOffice's Find box).
                                ;   A single Alt tap still opens the menu bar, just after a
                                ;   DoubleTapTime pause. But if you tap Alt and then press a
                                ;   letter within that pause (e.g. Alt, then F for File),
                                ;   the letter is typed instead: hold Alt+F together instead.
                                ; false = leave Alt exactly as Windows normally has it.

MatchColours      := ["FF9632", "38D878"]
                                ; Colours browsers paint the CURRENT match, as RRGGBB:
                                ;   FF9632 = Chrome / Edge orange, 38D878 = Firefox green.
                                ;   Add your own with the tray menu's "Show colour under
                                ;   mouse pointer", e.g. ["FF9632", "38D878", "A0C8FF"]
ColourTolerance   := 24         ; How far (0-120) a pixel's red/green/blue may differ from
                                ;   a MatchColour and still count. Bigger finds more, but
                                ;   is more likely to pick up something that isn't a match.
BrowserApps       := ["chrome.exe", "msedge.exe", "firefox.exe", "brave.exe"
                    , "vivaldi.exe", "opera.exe"]
                                ; Programs where the highlight colour is tried first.

NotFoundSound     := A_WinDir "\Media\Windows Exclamation.wav"
                                ; Sound played when no match is found. Any .wav file works.
                                ;   Set to "" to use the simple beep below instead.
BeepFrequency     := 800        ; Simple beep (used if the sound file is missing or ""):
BeepDuration      := 200        ;   pitch in Hz and length in milliseconds.

ShowMethodTooltip := false      ; true = show which method found the match.
DebugLog          := true       ; true = write what happens on each double-tap to LogFile
                                ;   (tray menu > "Open the debug log"). Normally false.
LogFile           := A_Temp "\HighlightFinder_log.txt"

AllowRunAsAdmin   := false      ; false = if started as administrator, ask whether to
                                ;   carry on and close if you say No. Leave false.
AppResponseTimeout := 1000      ; Milliseconds to wait for a program to answer before
                                ;   giving up (so a frozen program can't freeze this).
;============================ END OF SETTINGS =================================

; Replace any missing / out-of-range settings with safe values (tells you if so).
ValidateSettings()

if (A_IsAdmin && !AllowRunAsAdmin) {
    answer := MsgBox("Highlight Finder has been started as administrator.`n`n"
        . "It doesn't need administrator rights and is meant to run normally.`n`n"
        . "Close it now? (Recommended: Yes, then start it again normally.)"
        , "Highlight Finder", "YesNo Icon! Default1")
    if (answer = "Yes")
        ExitApp
}

; Work in real screen pixels so the ring lines up on high-DPI / mixed monitors.
try DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
global gHaveOleacc := DllCall("LoadLibrary", "str", "oleacc.dll", "ptr") != 0
CoordMode("Mouse", "Screen")
CoordMode("ToolTip", "Screen")
CoordMode("Pixel", "Screen")

IID_IAccessible      := "{618736E0-3C3D-11CF-810C-00AA00389B71}"
IID_IAccessible2     := "{E89F726E-C4F4-4C19-BB19-B647D7FA8478}"
IID_IAccessibleText  := "{24FD2FFB-3AAD-4A08-8335-A3AD89C0FB4B}"
IID_UIA_TextPattern  := "{32EBA289-3583-42C9-9C59-3B6D9A1E9B6A}"

global gTapLast := 0, gAltDownAt := 0, gTapSpoiled := false, gIH := 0
global gRings := [], gAnim := 0
global gDocCache := Map()                 ; UIA document per window, for one search
global gTargets := ParseColours(MatchColours)

; Tray menu
A_IconTip := "Highlight Finder - double-tap Alt to ring the current search match"
A_TrayMenu.Add()
A_TrayMenu.Add("Test ring at mouse pointer", (*) => TestRing())
A_TrayMenu.Add("Show colour under mouse pointer (copies it)", ShowColourUnderMouse)
A_TrayMenu.Add("Show which method found the match", ToggleMethodTip)
if ShowMethodTooltip
    A_TrayMenu.Check("Show which method found the match")
A_TrayMenu.Add("Write a debug log", ToggleDebugLog)
if DebugLog
    A_TrayMenu.Check("Write a debug log")
A_TrayMenu.Add("Open the debug log", (*) => FileExist(LogFile) ? Run('notepad.exe "' LogFile '"') : MsgBox("No debug log yet.", "Highlight Finder"))

StartKeyWatcher()
return


;==============================================================================
;  Double-tap Alt detection (watches keys without blocking or altering them)
;==============================================================================
StartKeyWatcher(*) {
    global gIH
    gIH := InputHook("V L0")              ; V = keys pass through, L0 = collect no text
    gIH.KeyOpt("{All}", "N")              ; notify on every key
    gIH.OnKeyDown := WatchKeyDown
    gIH.OnKeyUp := WatchKeyUp
    gIH.OnEnd := (*) => SetTimer(StartKeyWatcher, -500)   ; restart if ever stopped
    gIH.MinSendLevel := 1                 ; ignore the keys this script sends itself
    gIH.Start()
}

; A single Alt tap was held back (StopAltMenu): send it on now, as a normal tap.
ReplayAltTap() {
    global gTapLast := 0
    Dbg("Single Alt tap - passing it on to open the menu bar")
    Send("{LAlt}")
}

IsAltVK(vk) => (vk = 0x12 || vk = 0xA4 || vk = 0xA5)

WatchKeyDown(ih, vk, sc) {
    global gTapLast, gAltDownAt, gTapSpoiled
    ; Any key press starts the fade of a ring that is waiting for one.
    if (IsObject(gAnim) && !gAnim.fadeStart && A_TickCount - gAnim.start >= 150)
        gAnim.fadeStart := A_TickCount
    if IsAltVK(vk) {
        if !gAltDownAt {                  ; ignore key auto-repeat
            gAltDownAt := A_TickCount
            ; Ctrl/Shift/Win already held (e.g. AltGr = Ctrl+Alt) = not a tap
            gTapSpoiled := GetKeyState("Ctrl") || GetKeyState("Shift")
                        || GetKeyState("LWin") || GetKeyState("RWin")
            ; An unused key "masks" Alt, so releasing it won't activate the menu bar.
            if (StopAltMenu && !gTapSpoiled)
                Send("{Blind}{vkE8}")
        }
    } else {                              ; any other key = not a double-tap
        if gTapLast
            SetTimer(ReplayAltTap, 0)     ; that tap wasn't for the menu bar after all
        gTapLast := 0
        gTapSpoiled := true
    }
}

WatchKeyUp(ih, vk, sc) {
    global gTapLast, gAltDownAt, gTapSpoiled
    if !IsAltVK(vk)
        return
    held := gAltDownAt ? A_TickCount - gAltDownAt : 99999
    spoiled := gTapSpoiled
    gAltDownAt := 0
    if (spoiled || held > MaxTapHold) {   ; Alt+key shortcut, or Alt held down
        Dbg("Alt released - not a tap (" (spoiled ? "another key was involved" : "held " held " ms") ")")
        gTapLast := 0
        return
    }
    Dbg("Alt tap")
    if (gTapLast && A_TickCount - gTapLast <= DoubleTapTime) {
        Dbg("Double-tap of Alt detected (" (A_TickCount - gTapLast) " ms apart)")
        gTapLast := 0
        SetTimer(ReplayAltTap, 0)         ; the first tap was part of this, not for the menu
        SetTimer(ShowHighlightRing, -1)   ; run outside the key callback
    } else {
        gTapLast := A_TickCount
        if StopAltMenu
            SetTimer(ReplayAltTap, -DoubleTapTime)
    }
}

; A mouse click between the taps cancels.
~*LButton::
~*RButton::
~*MButton::
{
    global gTapLast := 0
    SetTimer(ReplayAltTap, 0)
}


;==============================================================================
;  Main action
;==============================================================================
ShowHighlightRing() {
    global gDocCache
    HideRing()                            ; never let an old ring get in the way
    if ScanDelay
        Sleep(ScanDelay)
    method := ""
    gDocCache := Map()
    r := 0
    try r := FindHighlight(&method)
    gDocCache := Map()                    ; let go of the programs' objects
    Dbg(r ? "RESULT: found via " method : "RESULT: nothing found - beep")
    if !r {
        NotFoundAlert()
        if ShowMethodTooltip
            ShowTip("Highlight Finder: no current search match found")
        return
    }
    if !ShowRingAround(r) {
        NotFoundAlert()
        return
    }
    if ShowMethodTooltip
        ShowTip("Match found via: " method, r.x, r.y + r.h + MinRingRadius + 10)
}

NotFoundAlert() {
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
    if !IsSaneCoord(x) || !ShowRingAround({x: x - 40, y: y - 10, w: 80, h: 20})
        NotFoundAlert()
}

; Helps you find the colour your browser uses for the current match.
ShowColourUnderMouse(*) {
    loop 3 {
        ToolTip("Point at the current search match... " (4 - A_Index))
        Sleep(1000)
    }
    ToolTip()
    x := 0, y := 0, c := ""
    try {
        MouseGetPos(&x, &y)
        c := PixelGetColor(x, y)          ; "0xRRGGBB"
    }
    if (c = "") {
        ShowTip("Couldn't read the colour there")
        return
    }
    hex := SubStr(c, 3)
    A_Clipboard := '"' hex '"'
    ToolTip("Colour under the mouse: " hex "  (copied to the clipboard)`n"
          . "To use it, add it to MatchColours in the SETTINGS,`n"
          . 'e.g.  MatchColours := ["FF9632", "38D878", "' hex '"]', x + 20, y + 20)
    SetTimer(() => ToolTip(), -8000)
}

ToggleMethodTip(itemName, *) {
    global ShowMethodTooltip := !ShowMethodTooltip
    A_TrayMenu.ToggleCheck(itemName)
}

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

; True if the window's program answers a harmless message within the timeout.
IsResponsive(hwnd) {
    if !IsWindowHandle(hwnd)
        return false
    if DllCall("IsHungAppWindow", "ptr", hwnd)
        return false
    result := 0                                ; WM_NULL, SMTO_ABORTIFHUNG
    return DllCall("SendMessageTimeout", "ptr", hwnd, "uint", 0, "ptr", 0, "ptr", 0
                 , "uint", 0x2, "uint", AppResponseTimeout, "ptr*", &result, "ptr") != 0
}

; Rectangles: {x, y, w, h} for results, {l, t, r, b} (r/b exclusive) for regions.
UnionRects(list) {
    l := t := 100000, r := b := -100000
    for q in list {
        if !IsRect(q)
            continue
        l := Min(l, q.x), t := Min(t, q.y), r := Max(r, q.x + q.w), b := Max(b, q.y + q.h)
    }
    return (r > l && b > t) ? {x: l, y: t, w: r - l, h: b - t} : 0
}

Intersect(a, b) {
    l := Max(a.l, b.l), t := Max(a.t, b.t), r := Min(a.r, b.r), bt := Min(a.b, b.b)
    return (r > l && bt > t) ? {l: l, t: t, r: r, b: bt} : 0
}

WindowRect(hwnd) {
    try {
        WinGetPos(&x, &y, &w, &h, hwnd)
        return {l: x, t: y, r: x + w, b: y + h}
    }
    return 0
}

ClientRectOnScreen(hwnd) {
    rc := Buffer(16, 0), pt := Buffer(8, 0)
    if !DllCall("GetClientRect", "ptr", hwnd, "ptr", rc)
        return 0
    if !DllCall("ClientToScreen", "ptr", hwnd, "ptr", pt)
        return 0
    l := NumGet(pt, 0, "int"), t := NumGet(pt, 4, "int")
    r := l + NumGet(rc, 8, "int"), b := t + NumGet(rc, 12, "int")
    return (r > l && b > t) ? {l: l, t: t, r: r, b: b} : 0
}

VirtualScreen() {
    l := SysGet(76), t := SysGet(77)
    return {l: l, t: t, r: l + SysGet(78), b: t + SysGet(79)}
}

ScaleOf(hwnd) {
    dpi := 0
    try dpi := DllCall("GetDpiForWindow", "ptr", hwnd, "uint")
    return dpi ? dpi / 96 : 1
}


;==============================================================================
;  Finding the current match
;==============================================================================
FindHighlight(&method) {
    method := ""
    hActive := WinExist("A")
    if !hActive
        return 0
    exe := ""
    try exe := WinGetProcessName(hActive)
    isBrowser := false
    for name in BrowserApps
        if (name = exe)
            isBrowser := true

    Dbg("Active window: " WinInfo(hActive))
    for w in DocumentWindows(hActive) {
        if (w != hActive)
            Dbg("Also trying window behind: " WinInfo(w))
        if !IsResponsive(w) {             ; don't query a frozen program
            Dbg("  not responding - skipped")
            continue
        }
        behind := (w != hActive)
        colour := "Highlight colour", uiaSel := "UI Automation selection"
        ia2Sel := "IAccessible2 selection"
        attempts := isBrowser ? [colour, uiaSel, ia2Sel] : [uiaSel, ia2Sel, colour]
        for name in attempts {
            r := 0, t0 := A_TickCount
            try {
                switch name {
                    case colour: r := MatchFromColour(w)
                    case uiaSel: r := SelectionFromUIA(w, behind)
                    case ia2Sel: r := SelectionFromIA2(w)
                }
            } catch as e {
                Dbg("  " name ": error: " e.Message " (line " e.Line ")")
            }
            ok := r && Plausible(r, w)
            Dbg("  " name ": " (r ? "x=" r.x " y=" r.y " w=" r.w " h=" r.h (ok ? " - accepted" : " - rejected (off window)")
                                  : "nothing") "  (" (A_TickCount - t0) " ms)")
            if ok {
                method := name (behind ? " (in the window behind)" : "")
                return r
            }
        }
    }
    return 0
}

WinInfo(h) {
    s := "", r := WindowRect(h)
    try s := WinGetProcessName(h) " class=" WinGetClass(h) ' title="' SubStr(WinGetTitle(h), 1, 60) '"'
    return s (r ? " at " r.l "," r.t " size " (r.r - r.l) "x" (r.b - r.t) : "")
}

Dbg(s) {
    if !DebugLog
        return
    try FileAppend(FormatTime(, "HH:mm:ss") "." Format("{:03}", A_MSec) "  " s "`n", LogFile, "UTF-8")
}

ToggleDebugLog(itemName, *) {
    global DebugLog := !DebugLog
    A_TrayMenu.ToggleCheck(itemName)
    if DebugLog
        Dbg("---- Debug log switched on ----")
}

; The active window, plus the document window behind it when the active window
; is a Find dialog (its owner, or a much bigger window of the same program).
DocumentWindows(hActive) {
    wins := [hActive]
    owner := DllCall("GetWindow", "ptr", hActive, "uint", 4, "ptr")      ; GW_OWNER
    if owner
        owner := DllCall("GetAncestor", "ptr", owner, "uint", 2, "ptr")  ; GA_ROOT
    if (IsWindowHandle(owner) && owner != hActive && DllCall("IsWindowVisible", "ptr", owner)) {
        wins.Push(owner)
        return wins
    }
    a := WindowRect(hActive)
    if !a
        return wins
    areaActive := (a.r - a.l) * (a.b - a.t)
    pid := 0
    DllCall("GetWindowThreadProcessId", "ptr", hActive, "uint*", &pid)
    h := hActive
    loop 200 {
        h := DllCall("GetWindow", "ptr", h, "uint", 2, "ptr")            ; GW_HWNDNEXT
        if !h
            break
        if (!DllCall("IsWindowVisible", "ptr", h) || DllCall("IsIconic", "ptr", h))
            continue
        p := 0
        DllCall("GetWindowThreadProcessId", "ptr", h, "uint*", &p)
        if (p != pid)
            continue
        if !(c := WindowRect(h))
            continue
        if ((c.r - c.l) * (c.b - c.t) > 2.5 * areaActive)                ; active one is a dialog
            wins.Push(h)
        break
    }
    return wins
}

; Reject empty or off-window results (e.g. a selection scrolled out of view).
Plausible(r, hwnd) {
    if (!IsRect(r) || r.w < 1 || r.h < 1)
        return false
    if (r.x = 0 && r.y = 0)
        return false
    if !(wr := WindowRect(hwnd))
        return true
    cx := r.x + r.w / 2, cy := r.y + r.h / 2, m := 40
    return (cx >= wr.l - m && cx <= wr.r + m && cy >= wr.t - m && cy <= wr.b + m)
}

;---------- Highlight colour (screen pixels) ------------------------------------
ParseColours(list) {
    out := []
    for hex in list {
        v := Integer("0x" hex)
        out.Push({hex: hex, v: v, r: (v >> 16) & 0xFF, g: (v >> 8) & 0xFF, b: v & 0xFF})
    }
    return out
}

MatchFromColour(hwnd) {
    if !gTargets.Length
        return 0
    if !(reg := ClientRectOnScreen(hwnd))
        return 0
    ; Only look inside the web page / document itself if we can find it
    ; (keeps tab icons and toolbars out of the search).
    if ((doc := UIADocElement(hwnd, false)) && (d := UIAElementRect(doc)))
        reg := Intersect(reg, d) || reg
    if !(reg := Intersect(reg, VirtualScreen()))
        return 0

    ; Quick check (built in, fast): which match colours are on screen at all?
    present := []
    for c in gTargets {
        fx := 0, fy := 0
        found := false
        try found := PixelSearch(&fx, &fy, reg.l, reg.t, reg.r - 1, reg.b - 1, c.v, ColourTolerance)
        if found
            present.Push(c)
    }
    if !present.Length
        return 0

    if !(cap := CaptureScreen(reg))
        return 0
    best := 0
    try best := BestBlob(cap, present, ScaleOf(hwnd))
    finally DllCall("DeleteObject", "ptr", cap.hbm)
    if !best
        return 0
    return {x: reg.l + best.l, y: reg.t + best.t, w: best.r - best.l + 1, h: best.b - best.t + 1}
}

; Copies part of the screen into memory (32-bit pixels, top row first).
CaptureScreen(reg) {
    w := reg.r - reg.l, h := reg.b - reg.t
    if (w < 1 || h < 1 || w > 16000 || h > 16000)
        return 0
    hdcScreen := DllCall("GetDC", "ptr", 0, "ptr")
    if !hdcScreen
        return 0
    hdc := DllCall("CreateCompatibleDC", "ptr", hdcScreen, "ptr")
    bi := Buffer(40, 0)                          ; BITMAPINFOHEADER
    NumPut("uint", 40, bi, 0), NumPut("int", w, bi, 4), NumPut("int", -h, bi, 8)
    NumPut("ushort", 1, bi, 12), NumPut("ushort", 32, bi, 14)
    pBits := 0, hbm := 0, ok := false
    if hdc
        hbm := DllCall("CreateDIBSection", "ptr", hdc, "ptr", bi, "uint", 0
                     , "ptr*", &pBits, "ptr", 0, "uint", 0, "ptr")
    if (hbm && pBits) {
        old := DllCall("SelectObject", "ptr", hdc, "ptr", hbm, "ptr")
        ok := DllCall("BitBlt", "ptr", hdc, "int", 0, "int", 0, "int", w, "int", h
                    , "ptr", hdcScreen, "int", reg.l, "int", reg.t, "uint", 0x00CC0020)  ; SRCCOPY
        DllCall("SelectObject", "ptr", hdc, "ptr", old)
        DllCall("GdiFlush")
    }
    if hdc
        DllCall("DeleteDC", "ptr", hdc)
    DllCall("ReleaseDC", "ptr", 0, "ptr", hdcScreen)
    if !ok {
        if hbm
            DllCall("DeleteObject", "ptr", hbm)
        return 0
    }
    return {hbm: hbm, bits: pBits, w: w, h: h}
}

; Looks for patches of a match colour that are shaped like highlighted text,
; and returns the most convincing one (in captured-image coordinates).
BestBlob(cap, colours, scale) {
    p := cap.bits, W := cap.w, H := cap.h, tol := ColourTolerance
    step := Max(2, Round(3 * scale))            ; check every 3rd pixel, then look closer
    lim := {minW: Max(3, Round(4 * scale)), minH: Max(5, Round(6 * scale))
          , maxH: Round(150 * scale), lineH: Round(70 * scale), gap: Max(4, Round(10 * scale))}
    best := 0
    for col in colours {
        tr := col.r, tg := col.g, tb := col.b
        blobs := []
        y := 0
        while (y < H) {
            row := y * W * 4
            x := 0
            while (x < W) {
                c := NumGet(p, row + x * 4, "uint")
                if (Abs(((c >> 16) & 0xFF) - tr) <= tol
                 && Abs(((c >> 8) & 0xFF) - tg) <= tol
                 && Abs((c & 0xFF) - tb) <= tol) {
                    seen := 0
                    for b in blobs
                        if (x >= b.l && x <= b.r && y >= b.t && y <= b.b) {
                            seen := b
                            break
                        }
                    if !seen {
                        seen := MeasureBlob(p, W, H, x, y, col, tol, lim)
                        blobs.Push(seen)
                        if (seen.ok && (!best || seen.score > best.score))
                            best := seen
                        if (blobs.Length >= 40)  ; lots of this colour: give up on it
                            break 2
                    }
                    x := seen.r                  ; skip past this patch
                }
                x += step
            }
            y += step
        }
    }
    return best
}

; Measures the patch of colour around (sx, sy). Text inside the highlight
; breaks it up, so small gaps along a row are bridged.
MeasureBlob(p, W, H, sx, sy, col, tol, lim) {
    tr := col.r, tg := col.g, tb := col.b, gap := lim.gap

    IsMatch(x, y) {
        c := NumGet(p, (y * W + x) * 4, "uint")
        return Abs(((c >> 16) & 0xFF) - tr) <= tol
            && Abs(((c >> 8) & 0xFF) - tg) <= tol
            && Abs((c & 0xFF) - tb) <= tol
    }
    RowHas(y, L, R) {
        x := L
        while (x <= R) {
            if IsMatch(x, y)
                return true
            x++
        }
        return false
    }
    Widen(y, &L, &R) {
        x := L - 1, last := L
        while (x >= 0 && last - x <= gap) {
            if IsMatch(x, y)
                last := x
            x--
        }
        L := last
        x := R + 1, last := R
        while (x < W && x - last <= gap) {
            if IsMatch(x, y)
                last := x
            x++
        }
        R := last
    }

    L := sx, R := sx
    Widen(sy, &L, &R)
    T := sy, B := sy
    while (T > 0 && B - T <= lim.maxH && RowHas(T - 1, L, R))
        T--
    while (B < H - 1 && B - T <= lim.maxH && RowHas(B + 1, L, R))
        B++
    ; The top and bottom rows are usually plain highlight with no text on them,
    ; so they show the full width.
    for yy in [T, Min(T + 1, B), Max(B - 1, T), B]
        Widen(yy, &L, &R)

    bw := R - L + 1, bh := B - T + 1      ; (names ignore case: bw, not w, as W is in use)
    ok := (bh >= lim.minH && bh <= lim.maxH && bw >= lim.minW)
    ; How much of the box is this colour, and how much is EXACTLY it? A real
    ; highlight is one flat colour; photos and logos rarely match exactly.
    total := 0, hits := 0, exact := 0
    if ok {
        sy2 := Max(2, (bh // 40) * 2), sx2 := Max(2, (bw // 150) * 2)
        y := T
        while (y <= B) {
            x := L
            while (x <= R) {
                c := NumGet(p, (y * W + x) * 4, "uint")
                dr := Abs(((c >> 16) & 0xFF) - tr), dg := Abs(((c >> 8) & 0xFF) - tg)
                db := Abs((c & 0xFF) - tb)
                total++
                if (dr <= tol && dg <= tol && db <= tol) {
                    hits++
                    if (dr <= 4 && dg <= 4 && db <= 4)
                        exact++
                }
                x += sx2
            }
            y += sy2
        }
        ok := total && hits >= 0.35 * total
    }
    ; A patch the height of a line of text always beats a taller one (e.g. an
    ; orange button); then the one with the most exactly-matching pixels wins.
    score := (bh <= lim.lineH ? 1000000000 : 0) + exact + hits / 1000
    return {l: L, t: T, r: R, b: B, ok: ok, score: score}
}

;---------- UI Automation selection ---------------------------------------------
GetUIA() {
    static uia := 0
    if !uia
        uia := CreateUIAutomation()
    return uia
}

; Creates the UI Automation client with short timeouts, and with automatic
; focus-setting switched off so pattern calls can never move your focus.
CreateUIAutomation() {
    static IID_IUIAutomation  := "{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}"
    static IID_IUIAutomation2 := "{34723AFF-0C9D-49D0-9896-7AB52DF8CD8A}"
    uia := 0
    try uia := ComObject("{E22AD333-B25F-460C-83D0-0581107395C9}", IID_IUIAutomation)  ; CUIAutomation8
    if !uia
        uia := ComObject("{FF48DBA4-60EF-4201-AA87-54103EEF594E}", IID_IUIAutomation)  ; CUIAutomation
    try {
        uia2 := ComObjQuery(uia, IID_IUIAutomation2)
        ComCall(59, uia2, "int", 0, "int")                         ; put_AutoSetFocus(FALSE)
        ComCall(61, uia2, "uint", AppResponseTimeout, "int")       ; put_ConnectionTimeout
        ComCall(63, uia2, "uint", AppResponseTimeout, "int")       ; put_TransactionTimeout
    }
    return uia
}

; The document in a window (web page, word-processor page ...). Edit boxes are
; only accepted in a window behind a dialog: in the active window an edit box
; is usually the Find box itself.
UIADocElement(hwnd, allowEdit) {
    key := hwnd "|" allowEdit
    if gDocCache.Has(key)
        return gDocCache[key]
    el := 0
    try el := UIAFindDocument(hwnd, allowEdit)
    gDocCache[key] := el
    return el
}

UIAFindDocument(hwnd, allowEdit) {
    uia := GetUIA()
    pRoot := 0
    if (ComCall(6, uia, "ptr", hwnd, "ptr*", &pRoot, "int") < 0 || !pRoot)  ; ElementFromHandle
        return 0
    root := ComValue(13, pRoot)
    for ctype in (allowEdit ? [50030, 50004] : [50030]) {  ; Document, Edit
        if !(cond := UIAControlTypeCondition(uia, ctype))
            continue
        pEl := 0                                            ; FindFirst(TreeScope_Subtree)
        if (ComCall(5, root, "int", 7, "ptr", cond, "ptr*", &pEl, "int") >= 0 && pEl)
            return ComValue(13, pEl)
    }
    return 0
}

UIAControlTypeCondition(uia, ctype) {
    pCond := 0                                  ; CreatePropertyCondition(ControlType, type)
    if (A_PtrSize = 8) {
        v := Buffer(24, 0)                      ; VARIANT VT_I4
        NumPut("ushort", 3, v, 0), NumPut("int", ctype, v, 8)
        hr := ComCall(23, uia, "int", 30003, "ptr", v, "ptr*", &pCond, "int")
    } else {
        hr := ComCall(23, uia, "int", 30003, "int64", 3, "int64", ctype, "ptr*", &pCond, "int")
    }
    return (hr >= 0 && pCond) ? ComValue(13, pCond) : 0
}

UIAElementRect(el) {
    rc := Buffer(16, 0)
    if (ComCall(43, el, "ptr", rc, "int") < 0)   ; get_CurrentBoundingRectangle
        return 0
    l := NumGet(rc, 0, "int"), t := NumGet(rc, 4, "int")
    r := NumGet(rc, 8, "int"), b := NumGet(rc, 12, "int")
    return (r > l && b > t) ? {l: l, t: t, r: r, b: b} : 0
}

SelectionFromUIA(hwnd, allowEdit) {
    if !(doc := UIADocElement(hwnd, allowEdit))
        return 0
    pPat := 0
    try ComCall(16, doc, "int", 10014, "ptr*", &pPat)        ; GetCurrentPattern(Text)
    if !pPat
        return 0
    tp := ComObjQuery(ComValue(13, pPat), IID_UIA_TextPattern)
    pArr := 0
    if (ComCall(5, tp, "ptr*", &pArr, "int") < 0 || !pArr)   ; GetSelection
        return 0
    arr := ComValue(13, pArr)
    n := 0
    ComCall(3, arr, "int*", &n)                               ; get_Length
    if (n < 1)
        return 0
    pR := 0
    ComCall(4, arr, "int", 0, "ptr*", &pR)                    ; GetElement(0)
    if !pR
        return 0
    range := ComValue(13, pR)
    psa := 0                                                   ; GetBoundingRectangles
    if (ComCall(10, range, "ptr*", &psa, "int") < 0 || !psa)
        return 0
    rects := []
    try rects := ReadRectsFromSafeArray(psa)
    DllCall("oleaut32\SafeArrayDestroy", "ptr", psa)
    return UnionRects(rects)              ; empty selection (just a caret) gives 0
}

; The array should be 1-D doubles: left, top, width, height, (left, top, ...).
; Every step is checked before any memory is read.
ReadRectsFromSafeArray(psa) {
    out := []
    if (DllCall("oleaut32\SafeArrayGetDim", "ptr", psa, "uint") != 1)
        return out
    vt := 0
    if (DllCall("oleaut32\SafeArrayGetVartype", "ptr", psa, "ushort*", &vt, "int") != 0
        || vt != 5)                                       ; VT_R8 (double)
        return out
    if (DllCall("oleaut32\SafeArrayGetElemsize", "ptr", psa, "uint") != 8)
        return out
    lb := 0, ub := -1
    if (DllCall("oleaut32\SafeArrayGetLBound", "ptr", psa, "uint", 1, "int*", &lb, "int") != 0
        || DllCall("oleaut32\SafeArrayGetUBound", "ptr", psa, "uint", 1, "int*", &ub, "int") != 0)
        return out
    count := Min((ub - lb + 1) // 4, 500)                 ; whole rectangles only
    if (count < 1)
        return out
    pData := 0
    if (DllCall("oleaut32\SafeArrayAccessData", "ptr", psa, "ptr*", &pData, "int") != 0)
        return out
    try {
        if !pData
            return out
        loop count {
            o := (A_Index - 1) * 32
            x := NumGet(pData, o, "double"),      y := NumGet(pData, o + 8, "double")
            w := NumGet(pData, o + 16, "double"), h := NumGet(pData, o + 24, "double")
            if (IsSaneCoord(x) && IsSaneCoord(y) && IsSaneCoord(w) && IsSaneCoord(h)
                && w > 0 && h > 0)
                out.Push({x: Round(x), y: Round(y), w: Round(w), h: Round(h)})
        }
    } finally {
        DllCall("oleaut32\SafeArrayUnaccessData", "ptr", psa)
    }
    return out
}

;---------- IAccessible2 selection (LibreOffice, Firefox) -----------------------
SelectionFromIA2(hwnd) {
    if !(root := AccFromWindow(hwnd, 0xFFFFFFFC))    ; OBJID_CLIENT
        return 0
    if !(win := WindowRect(hwnd))
        return 0
    st := {budget: 600, deadline: A_TickCount + 2000, win: win}
    return SearchIA2Selection(root, 15, st)
}

; Depth-first search for an object with selected text. A deeper object is
; preferred (more precise) over a container that reports the same selection.
SearchIA2Selection(acc, depth, st) {
    if (--st.budget < 0 || A_TickCount > st.deadline)
        return 0
    own := 0
    try own := IA2SelectionRect(acc)
    if (depth > 0) {
        for child in AccChildren(acc) {
            if SkipInSearch(child, st.win)
                continue
            if (r := SearchIA2Selection(child, depth - 1, st))
                return r
        }
    }
    return own
}

; Menus, toolbars, scroll bars etc. never hold the document's selection,
; and nor does anything outside the window.
SkipInSearch(acc, win) {
    static skipRoles := Map(0x1, 1, 0x2, 1, 0x3, 1, 0xB, 1, 0x16, 1, 0x17, 1)
    role := AccRole(acc)
    if skipRoles.Has(role)
        return true
    loc := AccLocation(acc)
    if (loc && (loc.w > 0 || loc.h > 0)) {
        if (loc.x >= win.r || loc.y >= win.b || loc.x + loc.w <= win.l || loc.y + loc.h <= win.t)
            return true
    }
    return false
}

; IAccessibleText vtable (from the IAccessible2 IDL, after IUnknown's 0-2):
;   5 get_caretOffset  6 get_characterExtents  7 get_nSelections  9 get_selection
IA2SelectionRect(acc) {
    if !(text := IA2Text(acc))
        return 0
    n := 0
    if (ComCall(7, text, "int*", &n, "int") != 0 || n < 1)       ; get_nSelections
        return 0
    s := 0, e := 0
    if (ComCall(9, text, "int", 0, "int*", &s, "int*", &e, "int") != 0)  ; get_selection(0)
        return 0
    if (e < s)
        t := s, s := e, e := t
    if (e <= s || s < 0)
        return 0
    return UnionRects([IA2CharBox(text, s), IA2CharBox(text, e - 1)])
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
    r := {x: x, y: y, w: Max(w, 1), h: h}
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
    return 0
}

AccLocation(acc, childId := 0) {
    x := 0, y := 0, w := 0, h := 0
    hr := -1
    try {
        if (A_PtrSize = 8) {
            v := Buffer(24, 0)                   ; VARIANT (VT_I4 childId)
            NumPut("ushort", 3, v, 0), NumPut("int", childId, v, 8)
            hr := ComCall(22, acc, "int*", &x, "int*", &y, "int*", &w, "int*", &h, "ptr", v, "int")
        } else {
            hr := ComCall(22, acc, "int*", &x, "int*", &y, "int*", &w, "int*", &h
                        , "int64", 3, "int64", childId, "int")
        }
    }
    if (hr != 0)
        return 0
    r := {x: x, y: y, w: w, h: h}
    return IsRect(r) ? r : 0
}

AccRole(acc) {
    out := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
    hr := -1
    try {
        if (A_PtrSize = 8) {
            v := Buffer(24, 0)                   ; VARIANT (VT_I4 CHILDID_SELF)
            NumPut("ushort", 3, v, 0)
            hr := ComCall(13, acc, "ptr", v, "ptr", out, "int")          ; get_accRole
        } else {
            hr := ComCall(13, acc, "int64", 3, "int64", 0, "ptr", out, "int")
        }
    }
    role := (hr = 0 && NumGet(out, 0, "ushort") = 3) ? NumGet(out, 8, "int") : 0
    DllCall("oleaut32\VariantClear", "ptr", out)
    return role
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

; Works out a ring that surrounds rectangle r with RingPadding to spare.
ShowRingAround(r) {
    if !IsRect(r)
        return false
    cx := r.x + r.w / 2, cy := r.y + r.h / 2
    if (RingShape = "oval") {                   ; an ellipse through the corners, scaled 1.41
        rx := Max(MinRingRadius, Ceil(r.w * 0.7072) + RingPadding)
        ry := Max(MinRingRadius, Ceil(r.h * 0.7072) + RingPadding)
    } else {
        rx := ry := Max(MinRingRadius, Ceil(Sqrt(r.w ** 2 + r.h ** 2) / 2) + RingPadding)
    }
    return ShowRingAt(cx, cy, Min(rx, 4000), Min(ry, 4000))
}

ShowRingAt(cx, cy, rx, ry) {
    global gAnim
    if (!IsSaneCoord(cx) || !IsSaneCoord(cy))
        return false
    if (!gRings.Length && !CreateRingWindows())
        return false
    gAnim := {cx: cx, cy: cy, rx: rx, ry: ry, start: A_TickCount, lastG: -1, fadeStart: 0}
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
    g := 0, a := RingOpacity                    ; g = how much bigger than final size
    if (t < ShrinkTime) {
        p := t / ShrinkTime
        g := StartGrowth * (1 - p) ** 3         ; ease-out
    }
    fadeAt := StayUntilKeyPress ? gAnim.fadeStart : gAnim.start + ShrinkTime + DisplayTime
    if (fadeAt && A_TickCount >= fadeAt) {
        f := (A_TickCount - fadeAt) / Max(FadeTime, 1)
        if (f >= 1) {
            HideRing()
            return
        }
        a := RingOpacity * (1 - f)
    }
    g := Round(g)
    a := Max(0, Min(255, Round(a)))
    for ring in gRings {
        hwnd := ring.gui.Hwnd
        if !DllCall("SetLayeredWindowAttributes", "ptr", hwnd, "uint", 0, "uchar", a, "uint", 2) {
            HideRing()
            return
        }
        e := g + ring.extra
        if (g != gAnim.lastG
            && !ShapeRing(hwnd, gAnim.cx, gAnim.cy, gAnim.rx + e, gAnim.ry + e
                        , RingThickness + 2 * ring.extra)) {
            HideRing()
            return
        }
    }
    gAnim.lastG := g
}

; Cuts the window into an elliptical ring and centres it on (cx, cy).
; Returns true on success; on failure frees anything it created.
ShapeRing(hwnd, cx, cy, rx, ry, thick) {
    rx := Round(rx), ry := Round(ry), thick := Round(thick)
    if (!IsWindowHandle(hwnd) || !IsSaneCoord(cx) || !IsSaneCoord(cy))
        return false
    if (rx < 1 || ry < 1 || rx > 5000 || ry > 5000 || thick < 1)
        return false
    dx := 2 * rx, dy := 2 * ry
    outer := DllCall("CreateEllipticRgn", "int", 0, "int", 0, "int", dx + 1, "int", dy + 1, "ptr")
    if !outer
        return false
    if (thick * 2 < Min(dx, dy)) {              ; otherwise draw a solid disc
        inner := DllCall("CreateEllipticRgn", "int", thick, "int", thick
                       , "int", dx - thick + 1, "int", dy - thick + 1, "ptr")
        if !inner {
            DllCall("DeleteObject", "ptr", outer)
            return false
        }
        res := DllCall("CombineRgn", "ptr", outer, "ptr", outer, "ptr", inner, "int", 4)  ; RGN_DIFF
        DllCall("DeleteObject", "ptr", inner)
        if (res <= 1) {
            DllCall("DeleteObject", "ptr", outer)
            return false
        }
    }
    if !DllCall("SetWindowRgn", "ptr", hwnd, "ptr", outer, "int", 1) {
        DllCall("DeleteObject", "ptr", outer)
        return false
    }
    ; HWND_TOPMOST, SWP_NOACTIVATE | SWP_SHOWWINDOW
    return DllCall("SetWindowPos", "ptr", hwnd, "ptr", -1, "int", Round(cx - rx)
                 , "int", Round(cy - ry), "int", dx, "int", dy, "uint", 0x50) != 0
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
    global RingColour, OutlineColour, OutlineWidth, RingThickness, RingShape
         , RingPadding, MinRingRadius, StartGrowth, ShrinkTime, StayUntilKeyPress
         , DisplayTime, FadeTime, RingOpacity, DoubleTapTime, MaxTapHold, ScanDelay
         , MatchColours, ColourTolerance, BrowserApps, NotFoundSound, BeepFrequency
         , BeepDuration, ShowMethodTooltip, AllowRunAsAdmin, AppResponseTimeout
         , StopAltMenu, DebugLog
    fixes := []
    RingColour        := CheckColour(RingColour, "FF00FF", "RingColour", fixes)
    OutlineColour     := CheckColour(OutlineColour, "000000", "OutlineColour", fixes)
    OutlineWidth      := CheckNumber(OutlineWidth, 0, 50, 3, "OutlineWidth", fixes)
    RingThickness     := CheckNumber(RingThickness, 1, 200, 8, "RingThickness", fixes)
    RingPadding       := CheckNumber(RingPadding, 0, 200, 12, "RingPadding", fixes)
    MinRingRadius     := CheckNumber(MinRingRadius, 5, 1000, 45, "MinRingRadius", fixes)
    StartGrowth       := CheckNumber(StartGrowth, 0, 2000, 275, "StartGrowth", fixes)
    ShrinkTime        := CheckNumber(ShrinkTime, 0, 10000, 300, "ShrinkTime", fixes)
    DisplayTime       := CheckNumber(DisplayTime, 0, 600000, 800, "DisplayTime", fixes)
    FadeTime          := CheckNumber(FadeTime, 0, 10000, 500, "FadeTime", fixes)
    RingOpacity       := CheckNumber(RingOpacity, 1, 255, 240, "RingOpacity", fixes)
    DoubleTapTime     := CheckNumber(DoubleTapTime, 100, 2000, 400, "DoubleTapTime", fixes)
    MaxTapHold        := CheckNumber(MaxTapHold, 50, 2000, 350, "MaxTapHold", fixes)
    ScanDelay         := CheckNumber(ScanDelay, 0, 2000, 150, "ScanDelay", fixes)
    ColourTolerance   := CheckNumber(ColourTolerance, 0, 120, 24, "ColourTolerance", fixes)
    BeepFrequency     := CheckNumber(BeepFrequency, 37, 32767, 800, "BeepFrequency", fixes)
    BeepDuration      := CheckNumber(BeepDuration, 10, 5000, 200, "BeepDuration", fixes)
    StayUntilKeyPress := CheckBool(StayUntilKeyPress, true, "StayUntilKeyPress", fixes)
    ShowMethodTooltip := CheckBool(ShowMethodTooltip, false, "ShowMethodTooltip", fixes)
    StopAltMenu       := CheckBool(StopAltMenu, true, "StopAltMenu", fixes)
    DebugLog          := CheckBool(DebugLog, false, "DebugLog", fixes)
    AllowRunAsAdmin   := CheckBool(AllowRunAsAdmin, false, "AllowRunAsAdmin", fixes)
    AppResponseTimeout := CheckNumber(AppResponseTimeout, 200, 10000, 1000, "AppResponseTimeout", fixes)
    if (RingThickness >= MinRingRadius) {
        RingThickness := Max(1, MinRingRadius // 4)
        fixes.Push("RingThickness must be smaller than MinRingRadius; using " RingThickness)
    }
    if (IsObject(RingShape) || !(RingShape = "circle" || RingShape = "oval")) {
        fixes.Push("RingShape = " ShowValue(RingShape) ' must be "circle" or "oval"; using "circle"')
        RingShape := "circle"
    }
    if (MatchColours is Array) {
        good := []
        for c in MatchColours
            if (v := CheckColour(c, "", "A MatchColours entry", fixes))
                good.Push(v)
        MatchColours := good
    } else {
        MatchColours := ["FF9632", "38D878"]
        fixes.Push('MatchColours must be a list like ["FF9632", "38D878"]; using that')
    }
    if !(BrowserApps is Array) {
        BrowserApps := ["chrome.exe", "msedge.exe", "firefox.exe"]
        fixes.Push('BrowserApps must be a list like ["chrome.exe", "firefox.exe"]; using those')
    }
    if !(NotFoundSound is String) {
        NotFoundSound := ""
        fixes.Push("NotFoundSound must be a file name in quotes; using the simple beep")
    }
    if fixes.Length {
        msg := "Some settings in HighlightFinder.ahk were not valid, so safe values are being used:`n`n"
        for f in fixes
            msg .= "  - " f "`n"
        MsgBox(msg, "Highlight Finder", "Icon! T60")
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
    fixes.Push(name " = " ShowValue(v) " is not a colour like `"FF00FF`""
             . (default = "" ? "; ignoring it" : "; using " default))
    return default
}

CheckBool(v, default, name, fixes) {
    if (v = true || v = false) && !IsObject(v)
        return !!v
    fixes.Push(name " = " ShowValue(v) " must be true or false; using " (default ? "true" : "false"))
    return default
}
