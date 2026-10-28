#ifndef PublishDir
  #define PublishDir "out\publish"
#endif
#ifndef OutputDir
  #define OutputDir "out\release"
#endif
[Setup]
AppId={{F05EC4AA-C7D7-480F-86B8-B4FBB0A931A5}
AppName=桌面有点脏
AppVersion=0.11.1
AppPublisher=Peter 玩 AI
DefaultDirName={localappdata}\Programs\DesktopCritters
DefaultGroupName=桌面有点脏
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir={#OutputDir}
OutputBaseFilename=DesktopCritters-v0.11.1-Windows-x64-Setup
SetupIconFile=Assets\app.ico
UninstallDisplayIcon={app}\DesktopCritters.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
DisableProgramGroupPage=yes
CloseApplications=yes
RestartApplications=no
[Languages]
Name: "chinesesimp"; MessagesFile: "{#PublishDir}\..\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"
[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "快捷方式："; Flags: unchecked
[Files]
Source: "{#PublishDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{group}\桌面有点脏"; Filename: "{app}\DesktopCritters.exe"
Name: "{autodesktop}\桌面有点脏"; Filename: "{app}\DesktopCritters.exe"; Tasks: desktopicon
[Run]
Filename: "{app}\DesktopCritters.exe"; Description: "启动桌面有点脏"; Flags: nowait postinstall skipifsilent
