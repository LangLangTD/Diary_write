$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Say($m) { Write-Output ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m) }

$sdk = 'C:\dev\android-sdk'
$sdkmanager = "$sdk\cmdline-tools\latest\bin\sdkmanager.bat"

if (-not (Test-Path $sdkmanager)) { throw "sdkmanager not found at $sdkmanager" }

$env:JAVA_HOME = 'C:\dev\jdk'
$env:ANDROID_HOME = $sdk
$env:ANDROID_SDK_ROOT = $sdk
$env:Path = "$env:JAVA_HOME\bin;$env:Path"

# .bat 读 stdin 必须走 cmd 的重定向，PowerShell 管道喂不进去
$yesFile = 'C:\dev\yes.txt'
Set-Content -Path $yesFile -Value (('y') * 60) -NoNewline -Encoding ASCII
Set-Content -Path $yesFile -Value ((1..60 | ForEach-Object { 'y' }) -join "`r`n") -Encoding ASCII

Say 'accepting licenses...'
$out = cmd /c "`"$sdkmanager`" --sdk_root=`"$sdk`" --licenses < `"$yesFile`"" 2>&1
$out | Select-Object -Last 5
Say ("licenses exit=" + $LASTEXITCODE)

Say 'installing SDK packages...'
$out2 = cmd /c "`"$sdkmanager`" --sdk_root=`"$sdk`" `"platform-tools`" `"platforms;android-36`" `"build-tools;36.0.0`" < `"$yesFile`"" 2>&1
$out2 | Select-Object -Last 12
Say ("install exit=" + $LASTEXITCODE)

Say '--- installed ---'
foreach ($d in @('platform-tools','platforms','build-tools')) {
  $p = Join-Path $sdk $d
  if (Test-Path $p) {
    Get-ChildItem $p -Directory -ErrorAction SilentlyContinue | ForEach-Object { "  $d/$($_.Name)" }
  }
}
Say 'DONE'