;=============================================================================
; TrayHider.ahk  —  Hide Active Window to System Tray
; Platform : Windows 10/11  |  Requires: AutoHotkey v2.0+
;
; Author  : NEvZ4u-ID  (https://github.com/NEvZ4u-ID)
; License : MIT — free and open source, use/modify/redistribute freely.
;           If you fork or reuse this, a credit link back is appreciated
;           but not required by the license.
;
; DEFAULT SHORTCUTS (changeable via the Settings GUI in the tray menu):
;   ALT+F1  : Hide the active window
;   ALT+F2  : Restore the last hidden window (LIFO)
;   ALT+F10 : Restore ALL hidden windows
;
; FEATURES:
;   - Tray menu: list of hidden windows (click one = restore just that window)
;   - Restore All / Exit (Exit automatically restores everything first)
;   - Start with Windows : checkbox toggle in the tray menu (Task Scheduler
;                           entry, /RL HIGHEST — silent elevated autostart)
;
; NOTE: TrayHider always runs elevated (UAC prompt on manual launch). Once
;       "Start with Windows" is enabled, the logon launch is silent.
;   - Bilingual UI        : Indonesian / English (submenu in the tray menu)
;   - Shortcut settings   : GUI with native Hotkey controls, applies instantly
;
; SAFETY:
;   - Taskbar / Desktop / the script's own window can never be hidden
;   - OnExit handler restores all windows on exit / logoff / shutdown
;   - Crash recovery: hidden-window state is snapshotted to disk; on the next
;     launch, any orphaned windows from a crashed session are restored
;=============================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

;-----------------------------------------------------------------------------
; CONSTANTS
;-----------------------------------------------------------------------------
CONFIG_FILE   := A_ScriptDir "\config.ini"
PERSIST_FILE  := A_ScriptDir "\hidden_windows.dat"   ; format: hwnd|pid|exStyle|title
PERSIST_HEADER := "#TRAYHIDER-STATE-V2"              ; first line; absent = legacy layout
MAX_TITLE     := 60
AUTOSTART_TASK := "TrayHider"   ; Task Scheduler task name (user scope, no admin needed)
; Command-line flag used to carry a pending "Start with Windows" toggle
; across a UAC re-launch. Kept as a constant so the string can't drift
; between the place that sends it and the place that reads it.
AUTOSTART_ARG := "--autostart-toggle"
APP_VERSION   := "1.3.1"

; After hiding a window, Windows doesn't re-evaluate what's under the mouse
; cursor until the mouse actually moves or clicks — so the cursor can look
; like it's still "floating" over where the hidden window used to be, and
; the window now revealed underneath doesn't get focus. A real left-click at
; the cursor's current position fixes this reliably. Trade-off: if there's a
; clickable element (button/link) exactly at that pixel in the window behind
; it, this WILL click it. Set to false if that ever causes an unwanted click.
CLICK_TO_REFOCUS_AFTER_HIDE := true
APP_AUTHOR    := "NEvZ4u-ID"
APP_URL       := "https://github.com/NEvZ4u-ID/TrayHider"

; Window classes that must never be hidden
PROTECTED_CLASSES := Map(
    "Shell_TrayWnd", 1,           ; Main taskbar
    "Shell_SecondaryTrayWnd", 1,  ; Taskbar on a secondary monitor
    "Progman", 1,                 ; Desktop
    "WorkerW", 1,                 ; Desktop wallpaper layer
    "NotifyIconOverflowWindow", 1) ; Tray overflow flyout

;-----------------------------------------------------------------------------
; LANGUAGE DICTIONARY (i18n)
;-----------------------------------------------------------------------------
STRINGS := Map(
  "en", Map(
    "appActive",      "TrayHider is running",
    "appActiveBody",  "Press the hotkey to hide the active window.",
    "iconTip",        "TrayHider — {1} hidden window(s)",
    "protected",      "Protected",
    "protectedBody",  "This window cannot be hidden.",
    "hidden",         "Hidden",
    "hideFail",       "Failed",
    "hideFailBody",   "Cannot hide this window (it may be elevated — run TrayHider as administrator).",
    "empty",          "Empty",
    "emptyBody",      "No hidden windows.",
    "noTitle",        "(untitled)",
    "mNoHidden",      "(no hidden windows)",
    "mRestoreAll",    "Restore All",
    "mSettings",      "Shortcut Settings...",
    "mAutostart",     "Start with Windows",
    "autostartElevPrompt", "Could not modify the startup task:`n`n{1}`n`nThis system requires administrator rights for this action. Restart TrayHider as Administrator and try again?",
    "autostartOk",    "Startup setting updated.",
    "mLanguage",      "Bahasa / Language",
    "mAbout",         "About TrayHider",
    "mExit",          "Exit",
    "aboutBody",      "TrayHider v{1}`nFree and open source (MIT License).`n`nCreated by {2}`nGitHub: {3}",
    "recovery",       "Crash Recovery",
    "recoveryBody",   "{1} window(s) from the previous session were restored.",
    "mRunAsAdmin",    "Run as Administrator",
    "alreadyAdmin",   "TrayHider is already running as Administrator.",
    "cfgErrTitle",    "TrayHider — Config Error",
    "cfgErrBody",     "Invalid hotkey:`n`n{1}={2}`n`nFunction '{1}' is disabled. Fix it via the Settings menu.",
    "gTitle",         "Shortcut Settings",
    "gHide",          "Hide active window:",
    "gRestoreLast",   "Restore last window:",
    "gRestoreAll",    "Restore all windows:",
    "gNote",          "Note: the controls above cannot capture the Win key.`nFor Win (#) combos, edit config.ini manually.",
    "gSave",          "Save",
    "gCancel",        "Cancel",
    "gEmptyWarn",     "All shortcut fields must be filled.",
    "gDupWarn",       "Shortcuts must be different from each other.",
    "gApplied",       "New shortcuts are now active.",
    "gRegFail",       "Some shortcuts failed to register (possibly conflicting with another app):`n{1}"),
  "id", Map(
    "appActive",      "TrayHider aktif",
    "appActiveBody",  "Tekan hotkey untuk menyembunyikan jendela aktif.",
    "iconTip",        "TrayHider — {1} jendela tersembunyi",
    "protected",      "Dilindungi",
    "protectedBody",  "Jendela ini tidak boleh disembunyikan.",
    "hidden",         "Disembunyikan",
    "hideFail",       "Gagal",
    "hideFailBody",   "Tidak dapat menyembunyikan jendela ini (mungkin berjalan elevated — jalankan TrayHider sebagai admin).",
    "empty",          "Kosong",
    "emptyBody",      "Tidak ada jendela tersembunyi.",
    "noTitle",        "(tanpa judul)",
    "mNoHidden",      "(tidak ada jendela tersembunyi)",
    "mRestoreAll",    "Pulihkan Semua",
    "mSettings",      "Pengaturan Shortcut...",
    "mAutostart",     "Mulai saat Windows boot",
    "autostartElevPrompt", "Tidak dapat mengubah startup task:`n`n{1}`n`nSistem ini membutuhkan hak administrator untuk aksi ini. Restart TrayHider sebagai Administrator dan coba lagi?",
    "autostartOk",    "Pengaturan startup berhasil diubah.",
    "mLanguage",      "Bahasa / Language",
    "mAbout",         "Tentang TrayHider",
    "mExit",          "Keluar",
    "aboutBody",      "TrayHider v{1}`nGratis dan open source (Lisensi MIT).`n`nDibuat oleh {2}`nGitHub: {3}",
    "recovery",       "Pemulihan Crash",
    "recoveryBody",   "{1} jendela dari sesi sebelumnya dipulihkan.",
    "mRunAsAdmin",    "Jalankan sebagai Administrator",
    "alreadyAdmin",   "TrayHider sudah berjalan sebagai Administrator.",
    "cfgErrTitle",    "TrayHider — Config Error",
    "cfgErrBody",     "Hotkey tidak valid:`n`n{1}={2}`n`nFungsi '{1}' dinonaktifkan. Perbaiki lewat menu Pengaturan.",
    "gTitle",         "Pengaturan Shortcut",
    "gHide",          "Sembunyikan jendela aktif:",
    "gRestoreLast",   "Pulihkan jendela terakhir:",
    "gRestoreAll",    "Pulihkan semua jendela:",
    "gNote",          "Catatan: kontrol di atas tidak mendukung tombol Win.`nUntuk kombinasi dengan Win (#), edit config.ini secara manual.",
    "gSave",          "Simpan",
    "gCancel",        "Batal",
    "gEmptyWarn",     "Semua kolom shortcut harus diisi.",
    "gDupWarn",       "Shortcut tidak boleh sama satu sama lain.",
    "gApplied",       "Shortcut baru sudah aktif.",
    "gRegFail",       "Sebagian shortcut gagal didaftarkan (mungkin bentrok dengan aplikasi lain):`n{1}"))

;-----------------------------------------------------------------------------
; GLOBAL STATE
;-----------------------------------------------------------------------------
hiddenWindows := []          ; stack: { hwnd, pid, title, exStyle }
currentLang   := "en"        ; default UI language
currentKeys   := Map("HideActive", "!F1", "RestoreLast", "!F2", "RestoreAll", "!F10")
settingsGui   := 0           ; reference to the settings window (0 = closed)
forceElevation := true       ; overridden by [Settings] ForceElevation in config.ini

; Translation helper: L("key") / L("key", arg1)
L(key, args*) {
    s := STRINGS[currentLang].Has(key) ? STRINGS[currentLang][key] : key
    for i, a in args
        s := StrReplace(s, "{" i "}", String(a))
    return s
}

;-----------------------------------------------------------------------------
; STARTUP
;-----------------------------------------------------------------------------
; Config is read first — the elevation decision below depends on it, and
; reading config.ini needs no special privileges.
LoadConfig()

; TrayHider runs elevated by default. This is a real trade-off, made
; explicit so it can be reversed:
;
;   ForceElevation=1 (default) — a UAC prompt on every MANUAL launch, but
;     it can hide elevated windows (Task Manager, Regedit), and enabling
;     "Start with Windows" registers a /RL HIGHEST task so the logon launch
;     afterwards is completely silent.
;   ForceElevation=0 — no prompt on manual launch, but elevated windows
;     can't be hidden, and autostart can only be registered at LIMITED run
;     level, which cannot silently elevate later.
;
; Users who only ever hide ordinary windows (Notepad, a browser, a game) do
; not need elevation at all and can set this to 0 in config.ini.
if forceElevation
    EnsureElevated()

RecoverFromCrash()
ApplyHotkeys(currentKeys, true)
RebuildTrayMenu()
OnExit(HandleExit)

; Tray icon priority:
;   1. Compiled .exe  → use the icon embedded in the exe itself (set at build time)
;   2. Running as .ahk → use icon.ico if it sits next to the script
;   3. Fallback        → a stock shell32 icon
if A_IsCompiled
    TraySetIcon(A_ScriptFullPath)
else if FileExist(A_ScriptDir "\icon.ico")
    TraySetIcon(A_ScriptDir "\icon.ico")
else
    TraySetIcon("shell32.dll", 172)

; If this instance was just relaunched elevated specifically to retry the
; "Start with Windows" toggle (see OfferAutostartElevation), finish the job
; automatically now that we have the rights it needed — the user shouldn't
; have to click the menu item a second time after approving the UAC prompt.
; If this instance was relaunched elevated specifically to retry the "Start
; with Windows" toggle, finish the job now that we have the rights it needed.
;
; The A_IsAdmin guard is what prevents a double UAC prompt: if we reach this
; line still NOT elevated, it means EnsureElevated() above already asked and
; the user declined. Running ToggleAutostart() anyway would fail to register
; and pop a second consent dialog for something they just refused, so the
; flag is dropped silently instead.
if (A_Args.Length > 0 && A_Args[1] = AUTOSTART_ARG && A_IsAdmin)
    ToggleAutostart()

TrayTip(L("appActive"), L("appActiveBody"))

;=============================================================================
; CONFIGURATION (config.ini)
;=============================================================================
LoadConfig() {
    global currentLang, currentKeys, forceElevation
    if !FileExist(CONFIG_FILE)
        SaveConfig()   ; write defaults on first run
    currentLang := IniRead(CONFIG_FILE, "Settings", "Language", "en")
    if (currentLang != "id" && currentLang != "en")
        currentLang := "en"
    forceElevation := (IniRead(CONFIG_FILE, "Settings", "ForceElevation", "1") != "0")
    for name in ["HideActive", "RestoreLast", "RestoreAll"]
        currentKeys[name] := IniRead(CONFIG_FILE, "Hotkeys", name, currentKeys[name])
}

SaveConfig() {
    global currentLang, currentKeys, forceElevation
    IniWrite(currentLang, CONFIG_FILE, "Settings", "Language")
    IniWrite(forceElevation ? "1" : "0", CONFIG_FILE, "Settings", "ForceElevation")
    for name, key in currentKeys
        IniWrite(key, CONFIG_FILE, "Hotkeys", name)
}

;=============================================================================
; ELEVATION
;=============================================================================
; By default TrayHider elevates itself at startup (ForceElevation=1 in
; config.ini — see the STARTUP section for the trade-off). The tray menu's
; "Run as Administrator" item remains as a manual retry for the case where
; the user declined the startup prompt, or is running with ForceElevation=0
; and hits a window that needs elevation after all.
;
; Shared helper: relaunches this script/exe elevated via UAC, optionally
; passing extra command-line arguments through. Exits the current process on
; success; returns normally if the user cancels the UAC prompt, so callers
; can decide how to handle that.
RelaunchElevated(extraArgs := "") {
    try {
        target := A_IsCompiled
            ? '"' A_ScriptFullPath '"'
            : '"' A_AhkPath '" "' A_ScriptFullPath '"'
        if (extraArgs != "")
            target .= " " extraArgs
        Run('*RunAs ' target)
        ExitApp()   ; the elevated instance takes over; this one closes
    }
    ; UAC cancelled → fall through, caller continues non-elevated
}

; Runs once at the very top of startup — see the STARTUP section comment.
EnsureElevated() {
    if A_IsAdmin
        return
    ; Only the known flag is forwarded across the elevation. Blindly passing
    ; whatever A_Args[1] happens to be would relay unvalidated input from
    ; whoever launched us straight into a *RunAs command line.
    RelaunchElevated((A_Args.Length > 0 && A_Args[1] = AUTOSTART_ARG) ? AUTOSTART_ARG : "")
}

; Manual retry from the tray menu, for the case where the user cancelled the
; startup UAC prompt and wants to elevate without restarting manually.
RequestElevation(*) {
    if A_IsAdmin {
        MsgBox(L("alreadyAdmin"), L("mRunAsAdmin"), "Icon!")
        return
    }
    RelaunchElevated()
}

;=============================================================================
; HOTKEY MANAGEMENT
;=============================================================================
; Registers a new hotkey set, unbinding the previous set first.
; startup=true → errors are shown as a config-error dialog (not an "apply" warning).
ApplyHotkeys(newKeys, startup := false) {
    global currentKeys
    static actions := Map(
        "HideActive",  HideActiveWindow,
        "RestoreLast", RestoreLastWindow,
        "RestoreAll",  RestoreAllWindows)
    static registered := Map()   ; key string currently bound per action

    failed := ""
    for name, cb in actions {
        ; release the old binding if present and different
        if (registered.Has(name) && registered[name] != "" && registered[name] != newKeys[name]) {
            try Hotkey(registered[name], "Off")
            registered[name] := ""
        }
        ; register the new one
        try {
            Hotkey(newKeys[name], MakeAction(cb), "On")
            registered[name] := newKeys[name]
        } catch {
            registered[name] := ""
            if startup
                MsgBox(L("cfgErrBody", name, newKeys[name]), L("cfgErrTitle"), "Icon!")
            else
                failed .= name " = " newKeys[name] "`n"
        }
    }
    currentKeys := newKeys.Clone()
    SaveConfig()
    return failed   ; empty string = all succeeded
}

MakeAction(cb) => (*) => cb()

;=============================================================================
; CORE ACTIONS
;=============================================================================

;--- Hide the active window ---------------------------------------------------
HideActiveWindow() {
    global hiddenWindows
    hwnd := WinExist("A")
    if !hwnd
        return

    ; Games and frameworks (SDL2/FNA, Electron, Unity) often focus a CHILD or
    ; owned window rather than the real top-level one. Hiding a child leaves
    ; the parent — and its taskbar button — fully visible, which looks like
    ; "it didn't work". Walk up to the true root window first.
    root := DllCall("GetAncestor", "ptr", hwnd, "uint", 2, "ptr")  ; GA_ROOT = 2
    if root
        hwnd := root

    ; --- Guard: protected window ---
    winClass := ""
    try winClass := WinGetClass(hwnd)
    if (hwnd = A_ScriptHwnd || PROTECTED_CLASSES.Has(winClass)
        || (settingsGui && hwnd = settingsGui.Hwnd)) {
        TrayTip(L("protected"), L("protectedBody"))
        return
    }

    ; Don't hide the same window twice (would corrupt the restore state)
    for entry in hiddenWindows {
        if (entry.hwnd = hwnd)
            return
    }

    ; Read identity BEFORE hiding. Both are cheap kernel reads, and doing
    ; them first means a failure here aborts cleanly — whereas failing after
    ; WinHide would leave a hidden, untracked window with no way back.
    ; GetWindowThreadProcessId is used instead of WinGetPID because it cannot
    ; throw and succeeds for any live HWND, so we never store pid=0 for a
    ; window that exists. The PID is the ONLY thing that later distinguishes
    ; our window from a recycled handle, so an entry without one is useless.
    pid := GetHwndPid(hwnd)
    if !pid
        return   ; window died between the guard checks and here

    ; Remember the original extended style so restore can put it back exactly.
    exStyle := DllCall("GetWindowLong" (A_PtrSize = 8 ? "Ptr" : ""), "ptr", hwnd, "int", -20, "ptr")

    title := ""
    try title := WinGetTitle(hwnd)
    if (title = "")
        title := L("noTitle")
    title := SanitizeTitle(title)

    ; ---- THE part the user actually perceives — do this and nothing else ----
    try WinHide(hwnd)
    catch {
        TrayTip(L("hideFail"), L("hideFailBody"))
        return
    }
    ; Apply toolwindow style; wrap in try to handle rare window death after hide
    try SetToolWindowStyle(hwnd, true)

    ; Force Windows to re-evaluate hover/focus at the cursor's current spot —
    ; without this, the window now revealed underneath the cursor can be left
    ; without focus, and the cursor visually "floats" as if still hovering
    ; the window that just disappeared.
    if CLICK_TO_REFOCUS_AFTER_HIDE
        RefocusUnderCursor()
    ; ---------------------------------------------------------------------

    ; Everything below is bookkeeping the user doesn't watch happen — disk
    ; write, tray menu rebuild, taskbar COM call. None of it needs to finish
    ; before the window is gone from view, so it's deferred by one timer tick
    ; instead of blocking the hotkey handler.
    hiddenWindows.Push({ hwnd: hwnd, pid: pid, title: title, exStyle: exStyle })
    SetTimer(FinishHideBookkeeping.Bind(hwnd, title), -1)   ; -1 = run once, ASAP, non-blocking
}

; Deferred tail end of HideActiveWindow — runs a tick after the window is
; already invisible, so none of this adds to perceived hide latency.
; We now check whether the window is still in the hidden list before doing
; the visual side effects (taskbar removal, tray tip) to avoid a race when
; the user restores it very quickly.
FinishHideBookkeeping(hwnd, title) {
    global hiddenWindows
    stillHidden := false
    for entry in hiddenWindows {
        if (entry.hwnd = hwnd) {
            stillHidden := true
            break
        }
    }
    if stillHidden {
        RemoveTaskbarButton(hwnd)
        TrayTip(L("hidden"), title)
    }
    SavePersistence()
    RebuildTrayMenu()
    StartWatchdog()
}

;--- Toggle WS_EX_TOOLWINDOW / WS_EX_APPWINDOW on a window --------------------
; WS_EX_TOOLWINDOW (0x80)    = no taskbar button, no Alt+Tab entry
; WS_EX_APPWINDOW  (0x40000) = forces a taskbar button, so it must be cleared
SetToolWindowStyle(hwnd, enable) {
    static GWL_EXSTYLE := -20, WS_EX_TOOLWINDOW := 0x80, WS_EX_APPWINDOW := 0x40000
    getFn := "GetWindowLong" (A_PtrSize = 8 ? "Ptr" : "")
    setFn := "SetWindowLong" (A_PtrSize = 8 ? "Ptr" : "")
    ex := DllCall(getFn, "ptr", hwnd, "int", GWL_EXSTYLE, "ptr")
    ex := enable ? ((ex | WS_EX_TOOLWINDOW) & ~WS_EX_APPWINDOW)
                 : (ex & ~WS_EX_TOOLWINDOW)
    DllCall(setFn, "ptr", hwnd, "int", GWL_EXSTYLE, "ptr", ex)
}

;--- Explicitly ask the shell to drop/re-add the taskbar button ---------------
; Style changes alone are sometimes ignored for a window that already owns a
; taskbar button, so we also talk to the taskbar directly via ITaskbarList.
TaskbarButton(hwnd, remove) {
    static tbl := ""
    try {
        if (tbl = "") {
            tbl := ComObject("{56FDF344-FD6D-11d0-958A-006097C9A090}"   ; CLSID_TaskbarList
                           , "{56FDF342-FD6D-11d0-958A-006097C9A090}")  ; IID_ITaskbarList
            ComCall(3, tbl)                       ; HrInit()
        }
        ComCall(remove ? 5 : 4, tbl, "ptr", hwnd) ; 5 = DeleteTab, 4 = AddTab
    }
    ; Non-fatal: the style change above is the primary mechanism.
}

RemoveTaskbarButton(hwnd) => TaskbarButton(hwnd, true)
RestoreTaskbarButton(hwnd) => TaskbarButton(hwnd, false)

;--- Simulate a left-click at the current cursor position ---------------------
; Windows only updates which window is "hovered"/focused at the cursor when
; the mouse physically moves or clicks — hiding a window doesn't trigger that
; re-evaluation on its own. A real click is the most reliable fix; a plain
; WinActivate on the window under the cursor does not consistently clear the
; stale hover state in testing.
RefocusUnderCursor() {
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    try Click(mx " " my)
}

;--- Restore the last hidden window (LIFO) ------------------------------------
RestoreLastWindow() {
    global hiddenWindows
    if (hiddenWindows.Length = 0) {
        TrayTip(L("empty"), L("emptyBody"))
        return
    }
    entry := hiddenWindows.Pop()
    ; Put it back if the restore failed on a window that still exists —
    ; otherwise the entry is gone and the window can never be recovered
    ; through the UI, even though it is still alive and hidden.
    if !ShowAndActivate(entry)
        hiddenWindows.Push(entry)
    SavePersistence()
    RebuildTrayMenu()
}

;--- Restore every hidden window -----------------------------------------------
RestoreAllWindows() {
    global hiddenWindows
    ; Pop in reverse order so the very first window hidden ends up on top again.
    ; Entries that fail to restore are collected and put back afterwards, so a
    ; single stubborn window doesn't get silently dropped from the list.
    failed := []
    while (hiddenWindows.Length > 0) {
        entry := hiddenWindows.Pop()
        if !ShowAndActivate(entry)
            failed.Push(entry)
    }
    ; Push back in REVERSE collection order. They were popped newest-first, so
    ; replaying that order directly would invert the stack and make the next
    ; "Restore Last" pick the oldest window instead of the newest — silently
    ; breaking the LIFO contract the whole hidden list is built on.
    loop failed.Length
        hiddenWindows.Push(failed[failed.Length - A_Index + 1])
    SavePersistence()
    RebuildTrayMenu()
}

;--- Restore a single entry by index (called from the tray menu) --------------
RestoreByIndex(idx) {
    global hiddenWindows
    if (idx < 1 || idx > hiddenWindows.Length)
        return
    entry := hiddenWindows.RemoveAt(idx)
    if !ShowAndActivate(entry)
        hiddenWindows.InsertAt(idx, entry)   ; keep original position
    SavePersistence()
    RebuildTrayMenu()
}

;--- Reliable PID for a window handle ----------------------------------------
; GetWindowThreadProcessId is a plain kernel read: no exceptions, no window
; enumeration, and it succeeds for any live HWND. Returns 0 only if the
; handle is already invalid.
GetHwndPid(hwnd) {
    pid := 0
    DllCall("GetWindowThreadProcessId", "ptr", hwnd, "uint*", &pid)
    return pid
}

;--- Make a title safe to store in the pipe-delimited persistence file -------
; Newlines would break the line-per-entry format outright; pipes are handled
; by field ordering (title is last) but are still normalised so the stored
; value round-trips predictably.
SanitizeTitle(title) {
    title := StrReplace(StrReplace(title, "`r", " "), "`n", " ")
    return Trim(StrReplace(title, "|", "/"))
}

;--- Is this stored entry still the SAME window we hid? -----------------------
; Windows recycles HWND values: once a process dies, its handle can be handed
; out again to a completely unrelated window. Checking IsWindow alone is
; therefore NOT enough — a recycled handle passes it while pointing at some
; innocent other application, which the watchdog would then happily hide and
; ShowAndActivate would restyle. Matching the PID as well closes that gap.
;
; An entry with no usable PID is treated as NOT ours. Hide-time now guarantees
; every stored entry has one (see GetHwndPid in HideActiveWindow), so a
; missing PID means corrupt or foreign data, and guessing in that state risks
; mutating a stranger's window.
EntryStillOurs(entry) {
    if !DllCall("IsWindow", "ptr", entry.hwnd)
        return false
    if (!entry.HasOwnProp("pid") || !entry.pid)
        return false
    return (GetHwndPid(entry.hwnd) = entry.pid)
}

;--- Show + activate. Returns true if the window was actually restored -------
; The return value lets callers decide whether to drop the entry: a window
; that is still alive but failed to restore should stay in the list so the
; user can try again, rather than becoming permanently unreachable.
ShowAndActivate(entry) {
    ; Never touch a handle that now belongs to someone else — restoring a
    ; recycled HWND would change another app's window styles. Report success
    ; so the caller discards the entry: it is genuinely gone either way.
    if !EntryStillOurs(entry) {
        StopWatchdogIfIdle()
        return true
    }
    ok := false
    try {
        ; Restore the exact extended style captured before hiding. That value
        ; already has the correct WS_EX_TOOLWINDOW/APPWINDOW bits, so calling
        ; SetToolWindowStyle first would be redundant — and would briefly put
        ; the window in a third, never-intended style state.
        if entry.HasOwnProp("exStyle")
            DllCall("SetWindowLong" (A_PtrSize = 8 ? "Ptr" : "")
                  , "ptr", entry.hwnd, "int", -20, "ptr", entry.exStyle)
        else
            SetToolWindowStyle(entry.hwnd, false)   ; legacy entry, no stored style
        WinShow(entry.hwnd)
        RestoreTaskbarButton(entry.hwnd)
        WinActivate(entry.hwnd)
        ok := true
    }
    StopWatchdogIfIdle()
    return ok
}

;=============================================================================
; WATCHDOG — keeps stubborn windows hidden
;=============================================================================
; Some applications (notably games built on SDL2/FNA such as Stardew Valley,
; and some Electron/Unity apps) call ShowWindow on themselves from their own
; render/message loop. A one-shot SW_HIDE gets silently undone a fraction of
; a second later and the window "jumps back" to the taskbar. There is no way
; to ask those frameworks to stop doing that, so we poll and re-hide.
;
; 400ms is a deliberate compromise: fast enough that a reappearing window is
; only briefly visible, slow enough that the cost is negligible (a handful of
; IsWindowVisible calls, well under 0.1% CPU).
StartWatchdog() {
    global hiddenWindows
    if (hiddenWindows.Length > 0)
        SetTimer(WatchdogTick, 400)
}

StopWatchdogIfIdle() {
    global hiddenWindows
    if (hiddenWindows.Length = 0)
        SetTimer(WatchdogTick, 0)
}

WatchdogTick() {
    global hiddenWindows
    ; Drop entries that are no longer ours (process died, or the handle was
    ; recycled). Without this the list grows stale and the timer would keep
    ; ticking forever over entries that can never do anything again.
    if PruneDeadHiddenWindows() {
        SavePersistence()
        RebuildTrayMenu()
        if (hiddenWindows.Length = 0) {
            SetTimer(WatchdogTick, 0)   ; nothing left to guard — stop the timer
            return
        }
    }
    for entry in hiddenWindows {
        if !EntryStillOurs(entry)
            continue
        if DllCall("IsWindowVisible", "ptr", entry.hwnd) {
            ; The app re-showed itself: hide it again and re-assert the style.
            try {
                WinHide(entry.hwnd)
                SetToolWindowStyle(entry.hwnd, true)
                RemoveTaskbarButton(entry.hwnd)
            }
        }
    }
}

;=============================================================================
; SYSTEM TRAY MENU
;=============================================================================
; Remove entries that are no longer the window we hid — either the process
; died, or its HWND has been recycled by an unrelated window (see
; EntryStillOurs). Dropping recycled handles here also keeps them out of the
; tray menu, so the user can't click one and restyle a stranger's window.
PruneDeadHiddenWindows() {
    global hiddenWindows
    newList := []
    changed := false
    for entry in hiddenWindows {
        if EntryStillOurs(entry)
            newList.Push(entry)
        else
            changed := true
    }
    if changed
        hiddenWindows := newList
    return changed
}

RebuildTrayMenu() {
    global hiddenWindows
    ; Clean up dead entries before building the menu
    if PruneDeadHiddenWindows()
        SavePersistence()

    tm := A_TrayMenu
    tm.Delete()   ; drop AHK's default menu + old items, rebuild from scratch

    if (hiddenWindows.Length = 0) {
        tm.Add(L("mNoHidden"), (*) => 0)
        tm.Disable(L("mNoHidden"))
    } else {
        ; Numeric prefix keeps each menu item unique even when two windows
        ; happen to share the same title.
        for idx, entry in hiddenWindows
            tm.Add(idx ". " Truncate(entry.title), MakeRestoreHandler(idx))
    }
    tm.Add()                                        ; separator
    tm.Add(L("mRestoreAll"), (*) => RestoreAllWindows())
    tm.Add()

    ; --- Shortcut settings (GUI) ---
    tm.Add(L("mSettings"), (*) => ShowSettingsGui())

    ; --- Start with Windows: checkbox toggle ---
    tm.Add(L("mAutostart"), ToggleAutostart)
    if IsAutostartEnabled()
        tm.Check(L("mAutostart"))

    ; --- Run as Administrator: on-demand only, never automatic ---
    if !A_IsAdmin
        tm.Add(L("mRunAsAdmin"), RequestElevation)

    ; --- Language submenu ---
    langMenu := Menu()
    langMenu.Add("English",          (*) => SetLanguage("en"))
    langMenu.Add("Bahasa Indonesia", (*) => SetLanguage("id"))
    langMenu.Check(currentLang = "en" ? "English" : "Bahasa Indonesia")
    tm.Add(L("mLanguage"), langMenu)

    tm.Add()
    tm.Add(L("mAbout"), (*) => ShowAboutDialog())
    tm.Add()
    tm.Add(L("mExit"), (*) => ExitApp())    ; OnExit handler restores everything
    A_IconTip := L("iconTip", hiddenWindows.Length)
}

; Closure factory — locks in the value of idx per menu item
MakeRestoreHandler(idx) => (*) => RestoreByIndex(idx)

Truncate(s) => (StrLen(s) > MAX_TITLE) ? SubStr(s, 1, MAX_TITLE - 1) "…" : s

;=============================================================================
; FEATURE: START WITH WINDOWS (Task Scheduler)
;
; A true Windows Service always requires admin rights to install (an OS-level
; restriction in the Service Control Manager, not something user-mode code
; can work around). A Task Scheduler entry is the closest equivalent — and
; for TrayHider, which always runs elevated, it is also the ONLY way to
; auto-launch elevated at logon WITHOUT a UAC prompt every time: a task
; registered with /RL HIGHEST starts with full admin rights and no consent
; prompt when triggered non-interactively (ONLOGON), because consent was
; already given when the elevated TrayHider process created the task.
; Creating a HIGHEST task requires the creating process to be elevated,
; which it is by the time this runs (see EnsureElevated at startup).
;=============================================================================
; Path and arguments for the autostart entry, kept separate because the COM
; API takes them as distinct fields — no quoting or escaping needed anywhere.
AutostartTarget() {
    return A_IsCompiled
        ? { path: A_ScriptFullPath, args: "" }
        : { path: A_AhkPath,        args: '"' A_ScriptFullPath '"' }
}

; Connects to the Task Scheduler service. Returns the root folder object, or
; throws — callers wrap in try.
;
; Everything below uses the Task Scheduler COM API rather than shelling out
; to schtasks.exe. This removes an entire class of problems: no cmd.exe, so
; no shell metacharacter handling (%, ^, &, !) in the install path; no manual
; \" escaping of the /TR argument; no temp file for output; and no process
; spawn per call, which is what made the old IsAutostartEnabled() expensive
; enough to matter on every tray-menu rebuild.
TaskSchedulerRoot() {
    svc := ComObject("Schedule.Service")
    svc.Connect()
    ; NOTE: a single backslash. AutoHotkey v2 uses the backtick as its escape
    ; character, NOT the backslash — so "\\" here would be two literal
    ; backslashes and an invalid task folder path, silently breaking every
    ; autostart operation.
    return { svc: svc, folder: svc.GetFolder("\") }
}

; Cached because RebuildTrayMenu() runs on every hide and restore, and this
; used to spawn cmd.exe + schtasks.exe each time — tens of milliseconds on
; the exact path we worked to keep fast. Held as a static rather than a
; global so it can't be read before its initialiser has run: the startup
; sequence calls RebuildTrayMenu() long before a mid-file global assignment
; would execute. ("" = not yet determined)
IsAutostartEnabled(forceRefresh := false) {
    static cache := ""
    if (!forceRefresh && cache != "")
        return cache
    enabled := false
    try {
        ts := TaskSchedulerRoot()
        ts.folder.GetTask(AUTOSTART_TASK)   ; throws if the task doesn't exist
        enabled := true
    }
    cache := enabled
    return enabled
}

ToggleAutostart(*) {
    if IsAutostartEnabled() {
        try {
            ts := TaskSchedulerRoot()
            ts.folder.DeleteTask(AUTOSTART_TASK, 0)
        } catch as e {
            OfferAutostartElevation(e.Message)
            return
        }
    } else {
        try {
            RegisterAutostartTask()
        } catch as e {
            OfferAutostartElevation(e.Message)
            return
        }
    }
    IsAutostartEnabled(true)        ; re-query and refresh the cache
    TrayTip(L("mAutostart"), L("autostartOk"))
    RebuildTrayMenu()               ; refresh the checkmark
}

; Registers the logon task at HIGHEST run level. Throws on failure so the
; caller can surface the real COM error message.
RegisterAutostartTask() {
    static TASK_TRIGGER_LOGON := 9, TASK_ACTION_EXEC := 0
    static TASK_CREATE_OR_UPDATE := 6, TASK_LOGON_INTERACTIVE_TOKEN := 3
    static TASK_RUNLEVEL_HIGHEST := 1

    target := AutostartTarget()
    ts := TaskSchedulerRoot()
    td := ts.svc.NewTask(0)

    td.RegistrationInfo.Description := "Starts TrayHider at logon."
    td.RegistrationInfo.Author := APP_AUTHOR
    td.Principal.RunLevel := TASK_RUNLEVEL_HIGHEST   ; silent elevated launch

    trigger := td.Triggers.Create(TASK_TRIGGER_LOGON)
    trigger.Enabled := true

    action := td.Actions.Create(TASK_ACTION_EXEC)
    action.Path := target.path
    if (target.args != "")
        action.Arguments := target.args
    action.WorkingDirectory := A_ScriptDir

    ; Defaults that make sense for a background utility: don't refuse to run
    ; on battery, don't kill it when unplugged, and no runtime limit.
    td.Settings.DisallowStartIfOnBatteries := false
    td.Settings.StopIfGoingOnBatteries := false
    td.Settings.ExecutionTimeLimit := "PT0S"
    td.Settings.StartWhenAvailable := true

    ts.folder.RegisterTaskDefinition(AUTOSTART_TASK, td, TASK_CREATE_OR_UPDATE
                                   , "", "", TASK_LOGON_INTERACTIVE_TOKEN)
}

; Called when registering or deleting the autostart task fails. Normally rare
; already elevated by this point — it mainly covers the case where the user
; cancelled the startup UAC prompt. Offers to relaunch as Administrator and
; automatically retries the SAME toggle action once elevated.
; If we are ALREADY elevated the failure is something else (e.g. Group
; Policy), so just show the error rather than offering another pointless
; elevation — that would be an infinite UAC loop.
OfferAutostartElevation(errorOutput) {
    if A_IsAdmin {
        MsgBox(L("autostartElevPrompt", errorOutput), L("mAutostart"), "Icon!")
        RebuildTrayMenu()
        return
    }
    if (MsgBox(L("autostartElevPrompt", errorOutput), L("mAutostart"), "YesNo Icon!") = "Yes")
        RelaunchElevated(AUTOSTART_ARG)   ; exits on success; returns if UAC cancelled
    RebuildTrayMenu()   ; restore the checkbox to its actual (unchanged) state
}

;=============================================================================
; FEATURE: LANGUAGE SWITCHING
;=============================================================================
SetLanguage(lang) {
    global currentLang, settingsGui
    if (lang = currentLang)
        return
    currentLang := lang
    SaveConfig()
    if settingsGui {              ; close the settings window so it doesn't
        settingsGui.Destroy()     ; end up showing a mix of both languages
        settingsGui := 0
    }
    RebuildTrayMenu()
}

;=============================================================================
; FEATURE: ABOUT DIALOG (author / project credit)
;=============================================================================
ShowAboutDialog(*) {
    MsgBox(L("aboutBody", APP_VERSION, APP_AUTHOR, APP_URL), L("mAbout"), "Iconi")
}

;=============================================================================
; FEATURE: SHORTCUT SETTINGS GUI
;=============================================================================
ShowSettingsGui() {
    global settingsGui, currentKeys
    if settingsGui {                       ; already open → just bring it forward
        settingsGui.Show()
        return
    }
    g := Gui("+AlwaysOnTop -MaximizeBox", L("gTitle"))
    g.SetFont("s10", "Segoe UI")
    g.Add("Text", "xm", L("gHide"))
    g.Add("Hotkey", "vHkHide x+10 w160 yp-3", currentKeys["HideActive"])
    g.Add("Text", "xm", L("gRestoreLast"))
    g.Add("Hotkey", "vHkLast x+10 w160 yp-3", currentKeys["RestoreLast"])
    g.Add("Text", "xm", L("gRestoreAll"))
    g.Add("Hotkey", "vHkAll x+10 w160 yp-3", currentKeys["RestoreAll"])
    g.SetFont("s8")
    g.Add("Text", "xm w330 cGray", L("gNote"))
    g.SetFont("s10")
    g.Add("Button", "xm w100 Default", L("gSave")).OnEvent("Click", SaveSettings)
    g.Add("Button", "x+10 w100", L("gCancel")).OnEvent("Click", (*) => CloseSettings())
    g.SetFont("s7 cGray")
    g.Add("Text", "xm y+15", "TrayHider v" APP_VERSION " — github.com/" APP_AUTHOR)
    g.OnEvent("Close", (*) => CloseSettings())
    g.Show()
    settingsGui := g

    SaveSettings(*) {
        vals := g.Submit(false)
        newKeys := Map(
            "HideActive",  vals.HkHide,
            "RestoreLast", vals.HkLast,
            "RestoreAll",  vals.HkAll)
        ; Validate: no field left empty
        for , k in newKeys {
            if (k = "") {
                MsgBox(L("gEmptyWarn"), L("gTitle"), "Icon!")
                return
            }
        }
        ; Validate: no duplicate shortcuts
        if (newKeys["HideActive"] = newKeys["RestoreLast"]
         || newKeys["HideActive"] = newKeys["RestoreAll"]
         || newKeys["RestoreLast"] = newKeys["RestoreAll"]) {
            MsgBox(L("gDupWarn"), L("gTitle"), "Icon!")
            return
        }
        failed := ApplyHotkeys(newKeys)
        CloseSettings()
        if (failed != "")
            MsgBox(L("gRegFail", failed), L("gTitle"), "Icon!")
        else
            TrayTip(L("gTitle"), L("gApplied"))
    }

    CloseSettings() {
        global settingsGui
        if settingsGui {
            settingsGui.Destroy()
            settingsGui := 0
        }
    }
}

;=============================================================================
; EXIT & CRASH RECOVERY
;=============================================================================

;--- Called on normal exit, logoff, and shutdown -------------------------------
HandleExit(reason, code) {
    RestoreAllWindows()   ; also clears the persistence file (now empty)
    return 0               ; allow the exit to proceed
}

;--- Write a snapshot of the hidden-window list to disk (for crash recovery) --
SavePersistence() {
    global hiddenWindows
    ; A version header lets the reader tell the current field order apart from
    ; the older hwnd|pid|title|exStyle layout. Without it, an old file whose
    ; title happens to be numeric ("123") would be parsed as an exStyle and
    ; silently applied to the window — a wrong style with no error.
    content := PERSIST_HEADER "`n"
    for entry in hiddenWindows
        ; Field order matters: title goes LAST because it is free-form and
        ; very often contains a "|" itself (browser tabs, editors, etc).
        ; With title last, StrSplit's MaxParts lets the remainder absorb any
        ; embedded pipes harmlessly. Putting exStyle after title would make
        ; Integer() parse a chunk of the title and throw.
        content .= entry.hwnd "|" entry.pid "|" entry.exStyle "|" entry.title "`n"
    try {
        if FileExist(PERSIST_FILE)
            FileDelete(PERSIST_FILE)
        if (content != "")
            FileAppend(content, PERSIST_FILE, "UTF-8")
    }
}

;--- On startup: a non-empty persistence file means the previous session crashed -
RecoverFromCrash() {
    if !FileExist(PERSIST_FILE)
        return
    recovered := 0
    try {
        isCurrentFormat := false
        firstLine := true
        Loop Parse, FileRead(PERSIST_FILE, "UTF-8"), "`n", "`r" {
            if (A_LoopField = "")
                continue
            if firstLine {
                firstLine := false
                if (A_LoopField = PERSIST_HEADER) {
                    isCurrentFormat := true
                    continue          ; header consumed, next line is data
                }
                ; No header → file written by an older version, whose layout
                ; was hwnd|pid|title|exStyle. Fall through and parse it as
                ; such rather than misreading a numeric title as a style.
            }
            parts := StrSplit(A_LoopField, "|", , 4)
            if (parts.Length < 2 || !IsInteger(parts[1]) || !IsInteger(parts[2]))
                continue
            hwnd := Integer(parts[1]), pid := Integer(parts[2])
            if !DllCall("IsWindow", "ptr", hwnd)
                continue
            ; Validate PID as well: prevents restoring a window whose handle
            ; has been recycled by an unrelated process since the crash.
            if (GetHwndPid(hwnd) != pid)
                continue

            ; Only the current format stores exStyle in a position we can
            ; trust. For legacy files, just clear the tool-window flag —
            ; that's the bit that actually matters for getting the window
            ; and its taskbar button back.
            styleRestored := false
            if (isCurrentFormat && parts.Length >= 3 && IsInteger(parts[3])) {
                try {
                    DllCall("SetWindowLong" (A_PtrSize = 8 ? "Ptr" : "")
                          , "ptr", hwnd, "int", -20, "ptr", Integer(parts[3]))
                    styleRestored := true
                }
            }
            if !styleRestored
                try SetToolWindowStyle(hwnd, false)

            ; Style restore is attempted separately from WinShow so that a
            ; failure there still lets the window itself come back, rather
            ; than leaving it hidden forever.
            try {
                WinShow(hwnd)
                RestoreTaskbarButton(hwnd)
                recovered++
            }
        }
        FileDelete(PERSIST_FILE)
    }
    if (recovered > 0)
        TrayTip(L("recovery"), L("recoveryBody", recovered))
}