param([string]$FlutterPath = 'flutter', [switch]$Legacy)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
$previousJavaOptions = $env:JAVA_TOOL_OPTIONS
try {
    $javaTmp = Join-Path $projectRoot 'build/java-tmp'
    New-Item -ItemType Directory -Path $javaTmp -Force | Out-Null
    $env:JAVA_TOOL_OPTIONS = "$previousJavaOptions -Djdk.net.unixdomain.tmpdir=$javaTmp".Trim()
    $legacyValue = if ($Legacy) { 'true' } else { 'false' }
    & $FlutterPath --no-version-check build apk --release --target-platform android-arm64 --no-pub "--android-project-arg=bloodPressedLegacy=$legacyValue"
    if ($LASTEXITCODE -ne 0) { throw 'APK build failed.' }
    # Validate the actual output identity before naming it for distribution.
    $sdkDirectory = $env:ANDROID_SDK_ROOT
    if (-not $sdkDirectory) {
        $sdkLine = Select-String -LiteralPath 'android/local.properties' -Pattern '^sdk.dir=(.+)$'
        $sdkDirectory = $sdkLine.Matches[0].Groups[1].Value.Replace('\\', '\').Replace('\:', ':')
    }
    $buildTools = Get-ChildItem -LiteralPath (Join-Path $sdkDirectory 'build-tools') -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'aapt.exe') } |
        Sort-Object Name -Descending | Select-Object -First 1
    $badging = & (Join-Path $buildTools.FullName 'aapt.exe') dump badging 'build/app/outputs/flutter-apk/app-release.apk'
    if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect APK identity.' }
    $expectedId = if ($Legacy) { 'com.example.blood_pressed' } else { 'com.zhaoxuan.bloodpressed' }
    if (-not ($badging -match "package: name='$([regex]::Escape($expectedId))'")) { throw 'Built APK has the wrong application ID.' }
    if (-not ($badging -match "^native-code: 'arm64-v8a'$")) { throw 'Built APK ABI is incorrect.' }
    $certificate = & (Join-Path $buildTools.FullName 'apksigner.bat') verify --print-certs 'build/app/outputs/flutter-apk/app-release.apk'
    if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
    $hasLegacyCert = [bool]($certificate -match 'd5808be7cb8879b13bd3a98c149aa5d3fa7ef3451d412ab4dc9cea583b1670f8')
    if (($Legacy -and -not $hasLegacyCert) -or (-not $Legacy -and $hasLegacyCert)) { throw 'Built APK signing identity is incorrect.' }
    $versionLine = Select-String -LiteralPath 'pubspec.yaml' -Pattern '^version:\s*(\S+)'
    $version = $versionLine.Matches[0].Groups[1].Value
    $suffix = if ($Legacy) { '-legacy-test' } else { '-store' }
    $filename = "BloodPressed-$version-arm64-v8a$suffix.apk"
    $destination = Join-Path 'build/app/outputs/flutter-apk' $filename
    Copy-Item -LiteralPath 'build/app/outputs/flutter-apk/app-release.apk' -Destination $destination
    $hash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLower()
    Set-Content -LiteralPath "$destination.sha256" -Value "$hash  $filename" -Encoding ascii
    Write-Output "APK: $destination"
    Write-Output "SHA256: $hash"
} finally {
    $env:JAVA_TOOL_OPTIONS = $previousJavaOptions
    Pop-Location
}
