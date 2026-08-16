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
Name: "autostart"; Description: "Start TrayHider automatically when you log on"; GroupDescription: "Additional options:"; Flags: unchecked
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
; Launch the app right after install finishes
Filename: "{app}\{#MyAppExeName}"; Description: "Launch TrayHider now"; Flags: nowait postinstall skipifsilent

; If the user checked "Start automatically", register a per-user Task
; Scheduler entry — same mechanism the app's own tray toggle uses, so it
; stays consistent whether enabled from the installer or from the tray menu
; later. /RL LIMITED = runs with the user's own rights, no admin needed.
Filename: "{cmd}"; Parameters: "/C schtasks /Create /TN ""TrayHider"" /TR ""\""{app}\{#MyAppExeName}\"""" /SC ONLOGON /RL LIMITED /F"; Flags: runhidden; Tasks: autostart

[UninstallRun]
; Clean up the scheduled task on uninstall, if it was created
Filename: "{cmd}"; Parameters: "/C schtasks /Delete /TN ""TrayHider"" /F"; Flags: runhidden; RunOnceId: "RemoveAutostartTask"
