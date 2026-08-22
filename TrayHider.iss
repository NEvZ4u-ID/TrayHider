; TrayHider Installer Script (Inno Setup)
; ---------------------------------------
; Installs to the CURRENT USER's profile (%LocalAppData%\TrayHider), NOT
; Program Files — this is what makes the installer itself run without any
; admin/UAC prompt. PrivilegesRequired=lowest tells Windows explicitly that
; no elevation is needed or wanted for this install.
;
; Build with: iscc TrayHider.iss   (Inno Setup Compiler, run from repo root)
; Requires TrayHider.exe and icon.ico to already exist in the same folder.

#define MyAppName "TrayHider"
#define MyAppVersion "1.1.0"
#define MyAppPublisher "NEvZ4u-ID"
#define MyAppURL "https://github.com/NEvZ4u-ID/TrayHider"
#define MyAppExeName "TrayHider.exe"

[Setup]
AppId={{8F2A1C4E-7B3D-4E9A-9C1F-3D5E6A7B8C9D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; --- Install to the user profile, not Program Files ---
DefaultDirName={localappdata}\{#MyAppName}
DisableProgramGroupPage=yes
; --- The key line: no admin/UAC prompt for install or uninstall ---
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=commandline

OutputDir=installer_output
OutputBaseFilename=TrayHider-Setup
SetupIconFile=icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
; NOTE: there is deliberately NO "start with Windows" option here.
; TrayHider runs elevated, and a silent (prompt-free) elevated autostart
; requires a Task Scheduler entry registered with /RL HIGHEST — which can
; only be created BY an already-elevated process. This installer runs
; non-elevated by design (PrivilegesRequired=lowest, installs to the user
; profile), so any task it created would be /RL LIMITED and would trigger a
; UAC prompt on every single logon. Enabling autostart from TrayHider's own
; tray menu after first launch creates the correct HIGHEST task instead.
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional options:"; Flags: unchecked

[Files]
Source: "TrayHider.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "icon.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "LICENSE"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Remove any stale autostart task left over from a previous install or an
; older version. Without this, a leftover "TrayHider" task makes the tray
; menu's "Start with Windows" checkbox appear already ticked after a fresh
; install — even though the task may point at an old path or use the wrong
; run level. [Run] entries execute top-to-bottom, so this clears the task
; before the app launches, and the checkbox then honestly reflects "off".
; The task usually doesn't exist; runhidden keeps the error invisible.
Filename: "{sys}\schtasks.exe"; Parameters: "/Delete /TN ""TrayHider"" /F"; Flags: runhidden runascurrentuser

; Launch the app right after install finishes
Filename: "{app}\{#MyAppExeName}"; Description: "Launch TrayHider now"; Flags: nowait postinstall skipifsilent

; Autostart is intentionally NOT registered here — see the note in [Tasks].
; The user enables it from TrayHider's tray menu, which creates the correct
; /RL HIGHEST task so the logon launch stays silent.

[UninstallRun]
; Clean up the scheduled task on uninstall, if it was created. Uses the same
; direct schtasks.exe invocation as the [Run] cleanup above rather than going
; through cmd.exe, for consistency and to avoid PATH surprises.
Filename: "{sys}\schtasks.exe"; Parameters: "/Delete /TN ""TrayHider"" /F"; Flags: runhidden runascurrentuser; RunOnceId: "RemoveAutostartTask"
