$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Say($m) { Write-Output ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m) }

New-Item -ItemType Directory -Force -Path 'C:\dev' | Out-Null

# ---------------------------------------------------------------- JDK 17
if (-not (Test-Path 'C:\dev\jdk')) {
  Say 'downloading Temurin JDK 17...'
  $jdkUrl = 'https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse'
  curl.exe -s -L --retry 3 --max-time 900 -o 'C:\dev\jdk17.zip' $jdkUrl
  if ($LASTEXITCODE -ne 0) { throw "jdk download failed $LASTEXITCODE" }
  Say ("jdk zip = {0:N1} MB" -f ((Get-Item 'C:\dev\jdk17.zip').Length/1MB))
  tar.exe -xf 'C:\dev\jdk17.zip' -C 'C:\dev'
  $extracted = Get-ChildItem 'C:\dev' -Directory | Where-Object { $_.Name -like 'jdk-17*' } | Select-Object -First 1
  if (-not $extracted) { throw 'jdk extraction produced no directory' }
  Move-Item -Force $extracted.FullName 'C:\dev\jdk'
  Say 'JDK ready at C:\dev\jdk'
} else { Say 'JDK already present' }

$env:JAVA_HOME = 'C:\dev\jdk'
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
$javaVer = (Get-Command java).Source
Say "java = $javaVer"

# -------------------------------------------------------- Android cmd tools
$sdk = 'C:\dev\android-sdk'
if (-not (Test-Path "$sdk\cmdline-tools\latest\bin\sdkmanager.bat")) {
  Say 'downloading Android command-line tools...'
  $urls = @(
    'https://dl.google.com/android/repository/commandlinetools-win-13114758_latest.zip',
    'https://dl.google.com/android/repository/commandlinetools-win-12266719_latest.zip',
    'https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip'
  )
  $ok = $false
  foreach ($u in $urls) {
    curl.exe -s -L --retry 2 --max-time 600 -o 'C:\dev\cmdtools.zip' $u
    $sz = (Get-Item 'C:\dev\cmdtools.zip' -ErrorAction SilentlyContinue).Length
    if ($sz -gt 100000) { Say "got cmdline-tools from $u ({0:N1} MB)" -f ($sz/1MB); $ok = $true; break }
    Say "  $u -> failed, trying next"
  }
  if (-not $ok) { throw 'all cmdline-tools URLs failed' }

  New-Item -ItemType Directory -Force -Path "$sdk\cmdline-tools" | Out-Null
  tar.exe -xf 'C:\dev\cmdtools.zip' -C "$sdk\cmdline-tools"
  Move-Item -Force "$sdk\cmdline-tools\cmdline-tools" "$sdk\cmdline-tools\latest"
  Say 'cmdline-tools extracted'
} else { Say 'cmdline-tools already present' }

$sdkmanager = "$sdk\cmdline-tools\latest\bin\sdkmanager.bat"

# ------------------------------------------------------------- licenses
Say 'accepting SDK licenses...'
1..30 | ForEach-Object { 'y' } | & $sdkmanager --sdk_root=$sdk --licenses 2>&1 | Select-Object -Last 3

# ---------------------------------------------------------------- packages
Say 'installing platform-tools / platform 36 / build-tools 36...'
& $sdkmanager --sdk_root=$sdk 'platform-tools' 'platforms;android-36' 'build-tools;36.0.0' 2>&1 | Select-Object -Last 15
if ($LASTEXITCODE -ne 0) { Say "sdkmanager exit=$LASTEXITCODE" }

Say '--- installed ---'
Get-ChildItem "$sdk" -Directory | ForEach-Object { "  $($_.Name)" }
Get-ChildItem "$sdk\platforms" -Directory -ErrorAction SilentlyContinue | ForEach-Object { "  platforms/$($_.Name)" }
Get-ChildItem "$sdk\build-tools" -Directory -ErrorAction SilentlyContinue | ForEach-Object { "  build-tools/$($_.Name)" }

# 持久化环境变量
[Environment]::SetEnvironmentVariable('JAVA_HOME', 'C:\dev\jdk', 'User')
[Environment]::SetEnvironmentVariable('ANDROID_HOME', $sdk, 'User')
[Environment]::SetEnvironmentVariable('ANDROID_SDK_ROOT', $sdk, 'User')
$userPath = [Environment]::GetEnvironmentVariable('Path','User')
foreach ($add in @("$sdk\platform-tools","$sdk\cmdline-tools\latest\bin","C:\dev\jdk\bin")) {
  if ($userPath -notlike "*$add*") { $userPath = "$userPath;$add" }
}
[Environment]::SetEnvironmentVariable('Path', $userPath, 'User')
Say 'ANDROID_HOME / JAVA_HOME / PATH persisted for current user'
Say 'DONE'