#ifndef ReleaseDir
  #error ReleaseDir is required.
#endif
#ifndef InstallerDir
  #error InstallerDir is required.
#endif
#ifndef SetupVersion
  #error SetupVersion is required.
#endif

#define AppTitle "Nohut Falafel POS"
#define AppExe "nohut_falafel_desktop.exe"
; Keep this ID and the per-user install mode across releases.
#define ProductId "NohutFalafel.POS"
#define UninstallKey "Software\Microsoft\Windows\CurrentVersion\Uninstall\" + ProductId + "_is1"

[Setup]
AppId={#ProductId}
AppName={#AppTitle}
AppPublisher=Nohut Falafel
AppVersion={#SetupVersion}
VersionInfoVersion={#SetupVersion}
DefaultDirName={localappdata}\Programs\Nohut Falafel POS
UsePreviousAppDir=yes
DisableWelcomePage=no
DisableDirPage=auto
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
WizardImageFile=wizard-panel.png
WizardSmallImageFile=wizard-logo.png
OutputDir={#InstallerDir}
OutputBaseFilename=NohutFalafelPOS-Setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
Compression=lzma2
SolidCompression=yes
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"

[Messages]
english.WelcomeLabel1=Welcome to Nohut Falafel POS
english.WelcomeLabel2=This wizard installs or updates the point of sale. It keeps your existing orders and settings. Click Next to continue.
french.WelcomeLabel1=Bienvenue dans Nohut Falafel POS
french.WelcomeLabel2=Cet assistant installe ou met à jour le logiciel de caisse. Vos commandes et vos réglages sont conservés. Cliquez sur Suivant pour continuer.
turkish.WelcomeLabel1=Nohut Falafel POS'a hoş geldiniz
turkish.WelcomeLabel2=Bu sihirbaz kasa uygulamasını kurar veya günceller. Mevcut siparişleriniz ve ayarlarınız korunur. Devam etmek için İleri'ye tıklayın.

[Files]
Source: "{#ReleaseDir}\{#AppExe}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#ReleaseDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#ReleaseDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#ReleaseDir}\build-manifest.json"; DestDir: "{app}"; Flags: ignoreversion

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Icons]
Name: "{userdesktop}\{#AppTitle}"; Filename: "{app}\{#AppExe}"; WorkingDir: "{app}"; Tasks: desktopicon
Name: "{userprograms}\{#AppTitle}"; Filename: "{app}\{#AppExe}"; WorkingDir: "{app}"

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppTitle}}"; Flags: nowait postinstall skipifsilent

[CustomMessages]
english.NewerInstalled=A newer version of Nohut Falafel POS is already installed.
french.NewerInstalled=Une version plus récente de Nohut Falafel POS est déjà installée.
turkish.NewerInstalled=Nohut Falafel POS'un daha yeni bir sürümü zaten kurulu.

[Code]
function InitializeSetup(): Boolean;
var
  InstalledVersion: String;
  Previous, Current: Int64;
begin
  Result := True;
  if RegQueryStringValue(HKCU, '{#UninstallKey}', 'DisplayVersion', InstalledVersion)
    and StrToVersion(InstalledVersion, Previous)
    and StrToVersion('{#SetupVersion}', Current)
    and (ComparePackedVersion(Previous, Current) > 0) then
  begin
    Log('A newer POS version is installed: ' + InstalledVersion);
    if not WizardSilent then
      MsgBox(CustomMessage('NewerInstalled'), mbError, MB_OK);
    Result := False;
  end;
end;
