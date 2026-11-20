param(
    [Parameter(Mandatory)] [string] $ReleaseDir,
    [Parameter(Mandatory)] [string] $InstallerDir,
    [switch] $VerifyUpgrade
)

$ErrorActionPreference = 'Stop'
$release = (Resolve-Path -LiteralPath $ReleaseDir).Path
$output = (New-Item -ItemType Directory -Path $InstallerDir -Force).FullName
$exeName = 'nohut_falafel_desktop.exe'
$exe = Join-Path $release $exeName
$versionInfo = (Get-Item -LiteralPath $exe).VersionInfo
$version = '{0}.{1}.{2}.{3}' -f $versionInfo.FileMajorPart, $versionInfo.FileMinorPart,
    $versionInfo.FileBuildPart, $versionInfo.FilePrivatePart
$compiler = (Get-Command ISCC.exe -ErrorAction SilentlyContinue).Source
if (-not $compiler) {
    $compiler = Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'
}
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) {
    throw 'Inno Setup compiler (ISCC.exe) was not found.'
}

function New-Setup([string] $Source, [string] $Destination, [string] $Version) {
    & $compiler "/DReleaseDir=$Source" "/DInstallerDir=$Destination" "/DSetupVersion=$Version" (
        Join-Path $PSScriptRoot 'NohutFalafelPOS.iss'
    )
    if ($LASTEXITCODE -ne 0) { throw "ISCC failed for $Version ($LASTEXITCODE)." }
}

New-Setup $release $output $version
$setup = Join-Path $output 'NohutFalafelPOS-Setup.exe'
if (-not (Test-Path -LiteralPath $setup -PathType Leaf)) { throw 'Missing setup executable.' }
$hash = (Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath (Join-Path $output 'SHA256SUMS.txt') -Encoding ascii -Value "$hash  NohutFalafelPOS-Setup.exe"

if (-not $VerifyUpgrade) { return }
if ($env:GITHUB_ACTIONS -ne 'true' -or -not $env:RUNNER_TEMP) {
    throw 'Installation smoke tests run only on an isolated GitHub Actions runner.'
}

$test = New-Item -ItemType Directory -Path (Join-Path $env:RUNNER_TEMP ('nohut-setup-' + [guid]::NewGuid()))
$baseline = New-Item -ItemType Directory -Path (Join-Path $test.FullName 'baseline')
New-Setup $release $baseline.FullName '0.0.0.0'
$oldSetup = Join-Path $baseline.FullName 'NohutFalafelPOS-Setup.exe'
$installDir = Join-Path $test.FullName 'Installed POS'
$appData = Join-Path $env:APPDATA 'NohutFalafel'
$database = Join-Path $appData 'nohut-pos.sqlite3'
$desktopLink = Join-Path ([Environment]::GetFolderPath('DesktopDirectory')) 'Nohut Falafel POS.lnk'
$menuLink = Join-Path ([Environment]::GetFolderPath('Programs')) 'Nohut Falafel POS.lnk'
$uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\NohutFalafel.POS_is1'
foreach ($path in @($desktopLink, $menuLink, $uninstallKey)) {
    if (Test-Path -LiteralPath $path) { throw "Smoke test requires a clean user profile: $path" }
}

$silent = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/LANG=english')
function Invoke-Setup([string] $File, [string[]] $Arguments) {
    $process = Start-Process -FilePath $File -ArgumentList $Arguments -Wait -PassThru -WindowStyle Hidden
    if ($process.ExitCode -ne 0) { throw "Setup failed ($($process.ExitCode)): $File" }
}

New-Item -ItemType Directory -Path $appData -Force | Out-Null
if (-not (Test-Path -LiteralPath $database -PathType Leaf)) {
    [IO.File]::WriteAllText($database, 'installer database preservation fixture')
}
$dbHash = (Get-FileHash -LiteralPath $database).Hash
Invoke-Setup $oldSetup ($silent + @('/TASKS=desktopicon', "/DIR=`"$installDir`""))
$installedExe = Join-Path $installDir $exeName
if ((Get-ItemProperty -LiteralPath $uninstallKey).DisplayVersion -ne '0.0.0.0') {
    throw 'First installation is missing from Windows Installed Apps.'
}
$shell = New-Object -ComObject WScript.Shell
foreach ($link in @($desktopLink, $menuLink)) {
    if (-not (Test-Path -LiteralPath $link -PathType Leaf) -or
        $shell.CreateShortcut($link).TargetPath -ne $installedExe) {
        throw "Missing or incorrect shortcut: $link"
    }
}

# A stale installed file must be replaced. Leave the app directory implicit on upgrade.
$installedManifest = Join-Path $installDir 'build-manifest.json'
[IO.File]::WriteAllText($installedManifest, 'stale previous manifest')
Invoke-Setup $setup $silent
if ((Get-ItemProperty -LiteralPath $uninstallKey).DisplayVersion -ne $version -or
    (Get-FileHash -LiteralPath $installedManifest).Hash -ne
    (Get-FileHash -LiteralPath (Join-Path $release 'build-manifest.json')).Hash -or
    (Get-FileHash -LiteralPath $installedExe).Hash -ne (Get-FileHash -LiteralPath $exe).Hash -or
    $shell.CreateShortcut($desktopLink).TargetPath -ne $installedExe -or
    (Get-FileHash -LiteralPath $database).Hash -ne $dbHash) {
    throw 'Upgrade changed the shortcut or database, or did not replace the installed files.'
}
$downgrade = Start-Process -FilePath $oldSetup -ArgumentList $silent -Wait -PassThru -WindowStyle Hidden
if ($downgrade.ExitCode -eq 0 -or (Get-ItemProperty -LiteralPath $uninstallKey).DisplayVersion -ne $version) {
    throw 'An older installer was allowed to overwrite the current version.'
}

$uninstall = Get-ChildItem -LiteralPath $installDir -Filter 'unins*.exe' -File
if (@($uninstall).Count -ne 1) { throw 'Expected exactly one uninstaller after upgrading.' }
Invoke-Setup $uninstall.FullName @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART')
if ((Test-Path -LiteralPath $installedExe) -or (Test-Path -LiteralPath $desktopLink) -or
    (Test-Path -LiteralPath $menuLink) -or (Test-Path -LiteralPath $uninstallKey) -or
    (Get-FileHash -LiteralPath $database).Hash -ne $dbHash) {
    throw 'Uninstall did not remove the app and shortcuts while preserving its database.'
}
Write-Host 'Verified first installation, desktop and Start shortcuts, in-place upgrade, downgrade protection, and data preservation on uninstall.'
