$ErrorActionPreference = 'Stop'
$ProjectDir = $PSScriptRoot
$RepoDir = Split-Path $ProjectDir -Parent
$OutDir = Join-Path $ProjectDir 'out'
$PublishDir = Join-Path $OutDir 'publish'
$ReleaseDir = Join-Path $OutDir 'release'
$LogDir = Join-Path $OutDir 'checks'
New-Item -ItemType Directory -Force $PublishDir,$ReleaseDir,$LogDir | Out-Null
Push-Location $RepoDir
try {
  dotnet run --project tests/WindowsCore.Tests.csproj -c Release 2>&1 | Tee-Object (Join-Path $LogDir 'core-tests.txt')
  if ($LASTEXITCODE -ne 0) { throw 'Windows core tests failed' }
  dotnet publish windows/DesktopCritters.Windows.csproj -c Release -r win-x64 --self-contained true -o $PublishDir -p:EnableCompressionInSingleFile=true
  if ($LASTEXITCODE -ne 0) { throw 'Windows publish failed' }
  $ExePath = Join-Path $PublishDir 'DesktopCritters.exe'
  $Process = Start-Process -FilePath $ExePath -ArgumentList @('--self-test') -Wait -PassThru -RedirectStandardOutput (Join-Path $LogDir 'exe-tests.txt') -RedirectStandardError (Join-Path $LogDir 'exe-tests-errors.txt')
  if ($Process.ExitCode -ne 0) { Get-Content (Join-Path $LogDir 'exe-tests-errors.txt'); throw 'Packaged executable self-test failed' }
  $SmokeDir = Join-Path $OutDir 'smoke'
  $Process = Start-Process -FilePath $ExePath -ArgumentList @('--smoke-test', $SmokeDir) -Wait -PassThru -RedirectStandardOutput (Join-Path $LogDir 'native-window-checks.txt') -RedirectStandardError (Join-Path $LogDir 'native-window-errors.txt')
  if ($Process.ExitCode -ne 0) { Get-Content (Join-Path $LogDir 'native-window-errors.txt'); throw 'WPF native smoke checks failed' }
  $Iscc = Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'
  if (!(Test-Path $Iscc)) { throw 'Install Inno Setup 6 to build the installer.' }
  # Localize the compiler's own language file without a network-only build dependency.
  $BaseLanguage = Get-Content (Join-Path (Split-Path $Iscc) 'Default.isl') -Raw
  $Translations = Get-Content (Join-Path $ProjectDir 'Assets/zh-cn.json') -Raw | ConvertFrom-Json -AsHashtable
  foreach ($Key in $Translations.Keys) {
    $Value = $Translations[$Key]
    $BaseLanguage = [regex]::Replace($BaseLanguage, '(?m)^' + [regex]::Escape($Key) + '=[^\r\n]*', { param($Match) "$Key=$Value" })
  }
  $BaseLanguage | Set-Content -Encoding utf8BOM (Join-Path $OutDir 'ChineseSimplified.isl')
  & $Iscc "/DPublishDir=$PublishDir" "/DOutputDir=$ReleaseDir" (Join-Path $ProjectDir 'installer.iss')
  if ($LASTEXITCODE -ne 0) { throw 'Installer build failed' }
  Compress-Archive -Path (Join-Path $PublishDir '*') -DestinationPath (Join-Path $ReleaseDir 'DesktopCritters-v0.9.0-Windows-x64-Portable.zip') -Force
  $Setup = Join-Path $ReleaseDir 'DesktopCritters-v0.9.0-Windows-x64-Setup.exe'
  $ProbeDir = Join-Path $env:TEMP 'DesktopCritters-Install-Probe'
  $Process = Start-Process -FilePath $Setup -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',"/DIR=$ProbeDir","/LOG=$(Join-Path $LogDir 'install.txt')") -Wait -PassThru
  if ($Process.ExitCode -ne 0 -or !(Test-Path (Join-Path $ProbeDir 'DesktopCritters.exe'))) { throw 'Installer probe failed' }
  $Process = Start-Process -FilePath (Join-Path $ProbeDir 'DesktopCritters.exe') -ArgumentList @('--self-test') -Wait -PassThru -RedirectStandardOutput (Join-Path $LogDir 'installed-tests.txt') -RedirectStandardError (Join-Path $LogDir 'installed-tests-errors.txt')
  if ($Process.ExitCode -ne 0) { throw 'Installed executable self-test failed' }
  $Process = Start-Process -FilePath (Join-Path $ProbeDir 'unins000.exe') -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART') -Wait -PassThru
  if ($Process.ExitCode -ne 0 -or (Test-Path (Join-Path $ProbeDir 'DesktopCritters.exe'))) { throw 'Uninstaller probe failed' }
  'PASS: install, installed executable, uninstall' | Set-Content (Join-Path $LogDir 'installer-checks.txt')
  Get-ChildItem $ReleaseDir -File | Where-Object Name -ne 'SHA256SUMS-Windows.txt' | ForEach-Object { "$((Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant())  $($_.Name)" } | Set-Content -Encoding utf8NoBOM (Join-Path $ReleaseDir 'SHA256SUMS-Windows.txt')
} finally { Pop-Location }
