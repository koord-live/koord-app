; Inno Setup 6 or later is required for this script to work.

[Setup]
AppID=Koord
AppName=Koord
AppVerName=Koord
AppVersion={#ApplicationVersion}
VersionInfoVersion={#ApplicationVersion}
AppPublisher=Koord.Live
AppPublisherURL=https://koord.live
AppSupportURL=https://github.com/koord-live/koord-app/issues
AppUpdatesURL=https://github.com/koord-live/koord-app/releases
AppContact=contact@koord.live
WizardStyle=modern
DefaultDirName={autopf}\Koord
DefaultGroupName=Koord
AppendDefaultDirName=no
ArchitecturesInstallIn64BitMode=x64
; disk space isn't calculated accurately - set here to 230Mb x 1024 x 1024 bytes
ExtraDiskSpaceRequired=241172480

; for 100% dpi setting should be 164x314 - https://jrsoftware.org/ishelp/
WizardImageFile=windows\koord-rt.bmp
; for 100% dpi setting should be 55x55 
WizardSmallImageFile=windows\koord-rt-small.bmp

[Files]
; Source:"deploy\x86_64\KoordASIO.dll"; DestDir: "{app}"; Flags: ignoreversion regserver 64bit; Check: Is64BitInstallMode
; install everything else in deploy dir, including portaudio.dll, KoordASIOControl.exe and all Qt dll deps
Source:"deploy\x86_64\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs 64bit; Check: Is64BitInstallMode

[Icons]
Name: "{group}\Koord"; Filename: "{app}\Koord.exe"; WorkingDir: "{app}"
; Name: "{group}\KoordASIO Control"; Filename: "{app}\KoordASIOControl.exe"; WorkingDir: "{app}"

[Run]
; FIXME - remove cruft
; make sure we have SOME working default configuration after installation
; Filename: "{app}\KoordASIOControl.exe"; Parameters: "-defaults"; Description: "Set KoordASIO defaults"; Flags: nowait
; also allow user to configure immediately after installation ?
; Filename: "{app}\KoordASIOControl.exe"; Description: "Run KoordASIO Control"; Flags: postinstall nowait skipifsilent
; Launch Koord by default after installation
Filename: "{app}\Koord.exe"; Description: "Launch Koord"; Flags: postinstall nowait skipifsilent

; install reg key to locate KoordASIOControl.exe at runtime
; [Registry]
; Root: HKLM64; Subkey: "Software\Koord"; Flags: uninsdeletekeyifempty
; Root: HKLM64; Subkey: "Software\Koord\KoordASIO"; Flags: uninsdeletekey
; Root: HKLM64; Subkey: "Software\Koord\KoordASIO\Install"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"

; install reg keys to setup custom "koord://" or "koord:" URL handling
[Registry]
Root: HKCU; Subkey: "Software\Classes\koord"; ValueType: "string"; ValueData: "URL:Koord Protocol"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\koord"; ValueType: "string"; ValueName: "URL Protocol"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\koord\DefaultIcon"; ValueType: "string"; ValueData: "{app}\Koord.exe,0"
Root: HKCU; Subkey: "Software\Classes\koord\shell\open\command"; ValueType: "string"; ValueData: """{app}\Koord.exe"" ""%1"""