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
;   - Start with Windows : checkbox toggle in the tray menu (per-user Task
;                           Scheduler entry, no admin required — see below)
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
PERSIST_FILE  := A_ScriptDir "\hidden_windows.dat"   ; format: hwnd|pid|title
MAX_TITLE     := 60
AUTOSTART_TASK := "TrayHider"   ; Task Scheduler task name (user scope, no admin needed)
APP_VERSION   := "1.1.0"
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
hiddenWindows := []          ; stack: { hwnd, pid, title }
currentLang   := "en"        ; default UI language
currentKeys   := Map("HideActive", "!F1", "RestoreLast", "!F2", "RestoreAll", "!F10")
settingsGui   := 0           ; reference to the settings window (0 = closed)

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
LoadConfig()
; NOTE: elevation is no longer offered automatically at startup — that dialog
; would pop up on every single logon once autostart is enabled, which is
; exactly the kind of nag this app is supposed to avoid. Elevation is now
; available on-demand from the tray menu (see RequestElevation()) for the
; rare case where the user actually needs to hide an elevated window.
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
if (A_Args.Length > 0 && A_Args[1] = "--autostart-toggle")
    ToggleAutostart()

TrayTip(L("appActive"), L("appActiveBody"), 1)

;=============================================================================
; CONFIGURATION (config.ini)
;=============================================================================
LoadConfig() {
    global currentLang, currentKeys
    if !FileExist(CONFIG_FILE)
        SaveConfig()   ; write defaults on first run
    currentLang := IniRead(CONFIG_FILE, "Settings", "Language", "en")
    if (currentLang != "id" && currentLang != "en")
        currentLang := "en"
    for name in ["HideActive", "RestoreLast", "RestoreAll"]
        currentKeys[name] := IniRead(CONFIG_FILE, "Hotkeys", name, currentKeys[name])
}

SaveConfig() {
    global currentLang, currentKeys
    IniWrite(currentLang, CONFIG_FILE, "Settings", "Language")
    for name, key in currentKeys
        IniWrite(key, CONFIG_FILE, "Hotkeys", name)
}

;=============================================================================
; ELEVATION (on-demand only — never prompted automatically)
;=============================================================================
; Triggered manually from the tray menu ("Run as Administrator") — this is a
; real UAC prompt (unavoidable, it's how Windows elevation works), but unlike
; before it only appears if the user explicitly asks for it, not on every
; startup/logon. Most people never need this; it's only for hiding windows
; that are themselves already running elevated (Task Manager, Regedit, etc).
RequestElevation(*) {
    if A_IsAdmin {
        MsgBox(L("alreadyAdmin"), L("mRunAsAdmin"), "Icon!")
        return
    }
    try {
        if A_IsCompiled
            Run('*RunAs "' A_ScriptFullPath '"')
        else
            Run('*RunAs "' A_AhkPath '" "' A_ScriptFullPath '"')
        ExitApp()   ; the elevated instance takes over; this one closes
    }
    ; UAC cancelled by the user → stay running non-elevated, no error needed
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

    ; --- Guard: protected window ---
    winClass := ""
    try winClass := WinGetClass(hwnd)
    if (hwnd = A_ScriptHwnd || PROTECTED_CLASSES.Has(winClass)
        || (settingsGui && hwnd = settingsGui.Hwnd)) {
        TrayTip(L("protected"), L("protectedBody"), 2)
        return
    }

    title := "", pid := 0
    try {
        title := WinGetTitle(hwnd)
        pid   := WinGetPID(hwnd)
    }
    if (title = "")                     ; untitled shell component → still allow, just label it
        title := L("noTitle")

    try WinHide(hwnd)
    catch {
        TrayTip(L("hideFail"), L("hideFailBody"), 3)
        return
    }

    hiddenWindows.Push({ hwnd: hwnd, pid: pid, title: title })
    SavePersistence()
    RebuildTrayMenu()
    TrayTip(L("hidden"), title, 1)
}

;--- Restore the last hidden window (LIFO) ------------------------------------
RestoreLastWindow() {
    global hiddenWindows
    if (hiddenWindows.Length = 0) {
        TrayTip(L("empty"), L("emptyBody"), 1)
        return
    }
    ShowAndActivate(hiddenWindows.Pop())
    SavePersistence()
    RebuildTrayMenu()
}

;--- Restore every hidden window -----------------------------------------------
RestoreAllWindows() {
    global hiddenWindows
    ; Pop in reverse order so the very first window hidden ends up on top again.
    while (hiddenWindows.Length > 0)
        ShowAndActivate(hiddenWindows.Pop())
    SavePersistence()
    RebuildTrayMenu()
}

;--- Restore a single entry by index (called from the tray menu) --------------
RestoreByIndex(idx) {
    global hiddenWindows
    if (idx < 1 || idx > hiddenWindows.Length)
        return
    ShowAndActivate(hiddenWindows.RemoveAt(idx))
    SavePersistence()
    RebuildTrayMenu()
}

;--- Helper: show + activate, tolerant of windows that already closed ---------
ShowAndActivate(entry) {
    try {
        WinShow(entry.hwnd)
        WinActivate(entry.hwnd)
    }
    ; If the process died while hidden, silently ignore.
}

;=============================================================================
; SYSTEM TRAY MENU
;=============================================================================
RebuildTrayMenu() {
    global hiddenWindows
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
; FEATURE: START WITH WINDOWS (Task Scheduler, user scope — no admin required)
;
; A true Windows Service always requires admin rights to install (this is an
; OS-level restriction in the Service Control Manager, not something that can
; be worked around from user-mode code). A per-user Task Scheduler entry is
; the closest legitimate equivalent that does NOT require elevation, because
; it runs with the logged-in user's own privileges rather than as SYSTEM.
; It also allows things a plain registry Run-key can't: run-on-logon timing,
; and (via /RL LIMITED) an explicit non-elevated run level.
;=============================================================================
AutostartCommand() {
    return A_IsCompiled
        ? '"' A_ScriptFullPath '"'
        : '"' A_AhkPath '" "' A_ScriptFullPath '"'
}

; Runs schtasks.exe with the given argument string via cmd.exe, capturing
; BOTH the exit code and the actual text schtasks printed (redirected to a
; temp file). Using the full path + cmd.exe /C is more predictable than
; letting AHK resolve a bare "schtasks" via PATH, and capturing real output
; means failures are diagnosable instead of a silent no-op.
RunSchtasks(argsStr) {
    schtasksExe := A_WinDir "\System32\schtasks.exe"
    tempFile := A_Temp "\trayhider_schtasks_" A_TickCount ".txt"
    fullCmd := A_ComSpec ' /C ""' schtasksExe '" ' argsStr ' > "' tempFile '" 2>&1"'
    exitCode := RunWait(fullCmd, , "Hide")
    output := ""
    if FileExist(tempFile) {
        try output := Trim(FileRead(tempFile, "UTF-8"))
        try FileDelete(tempFile)
    }
    return { code: exitCode, output: output }
}

IsAutostartEnabled() {
    result := RunSchtasks('/Query /TN "' AUTOSTART_TASK '"')
    return (result.code = 0)
}

ToggleAutostart(*) {
    if IsAutostartEnabled() {
        result := RunSchtasks('/Delete /TN "' AUTOSTART_TASK '" /F')
        if (result.code != 0) {
            OfferAutostartElevation(result.output)
            return
        }
        TrayTip(L("mAutostart"), L("autostartOk"), 1)
    } else {
        ; AutostartCommand() already wraps each path in "quotes"; schtasks'
        ; /TR needs the WHOLE command line wrapped in one outer pair of
        ; quotes, so the inner quotes must be escaped as \" to survive that.
        innerCmd := StrReplace(AutostartCommand(), '"', '\"')
        result := RunSchtasks('/Create /TN "' AUTOSTART_TASK '" /TR "' innerCmd '" /SC ONLOGON /RL LIMITED /F')
        if (result.code != 0) {
            OfferAutostartElevation(result.output)
            return
        }
        TrayTip(L("mAutostart"), L("autostartOk"), 1)
    }
    RebuildTrayMenu()   ; refresh the checkmark
}

; Called when a schtasks operation fails (typically Access Denied on systems
; where policy requires elevation even for /RL LIMITED). Offers to relaunch
; TrayHider as Administrator and automatically retries the SAME toggle action
; once elevated — the user doesn't have to click the menu item again.
OfferAutostartElevation(errorOutput) {
    if (MsgBox(L("autostartElevPrompt", errorOutput), L("mAutostart"), "YesNo Icon!") = "Yes") {
        try {
            if A_IsCompiled
                Run('*RunAs "' A_ScriptFullPath '" --autostart-toggle')
            else
                Run('*RunAs "' A_AhkPath '" "' A_ScriptFullPath '" --autostart-toggle')
            ExitApp()   ; the elevated instance takes over and retries the toggle
        }
        ; UAC cancelled by the user → stay running non-elevated, nothing changed
    }
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
            TrayTip(L("gTitle"), L("gApplied"), 1)
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
    content := ""
    for entry in hiddenWindows
        content .= entry.hwnd "|" entry.pid "|" entry.title "`n"
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
        Loop Parse, FileRead(PERSIST_FILE, "UTF-8"), "`n", "`r" {
            if (A_LoopField = "")
                continue
            parts := StrSplit(A_LoopField, "|", , 3)
            if (parts.Length < 2)
                continue
            hwnd := Integer(parts[1]), pid := Integer(parts[2])
            ; Validate: the HWND is still alive AND its PID still matches
            ; (prevents restoring the wrong window if Windows recycled the HWND)
            if WinExist("ahk_id " hwnd) {
                curPid := 0
                try curPid := WinGetPID(hwnd)
                if (curPid = pid) {
                    try {
                        WinShow(hwnd)
                        recovered++
                    }
                }
            }
        }
        FileDelete(PERSIST_FILE)
    }
    if (recovered > 0)
        TrayTip(L("recovery"), L("recoveryBody", recovered), 2)
}
