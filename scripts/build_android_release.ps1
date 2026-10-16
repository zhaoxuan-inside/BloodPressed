param([string]$FlutterPath = 'flutter', [switch]$Legacy)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'release_version.ps1')
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
$previousJavaOptions = $env:JAVA_TOOL_OPTIONS
$buildLock = $null
try {
    $lockDirectory = Join-Path $projectRoot '.dart_tool'
    New-Item -ItemType Directory -Path $lockDirectory -Force | Out-Null
    try {
        $buildLock = [IO.File]::Open((Join-Path $lockDirectory 'android-release.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    } catch { throw 'Another Android release build is running in this project.' }
    $release = Reserve-AndroidReleaseVersion -ProjectRoot $projectRoot
    Write-Output "Version: $($release.VersionName) (Android code $($release.BuildNumber))"
    $javaTmp = Join-Path $projectRoot 'build/java-tmp'
    New-Item -ItemType Directory -Path $javaTmp -Force | Out-Null
    $env:JAVA_TOOL_OPTIONS = "$previousJavaOptions -Djdk.net.unixdomain.tmpdir=$javaTmp".Trim()
    $legacyValue = if ($Legacy) { 'true' } else { 'false' }
    & $FlutterPath --no-version-check build apk --release --target-platform android-arm64 --no-pub "--android-project-arg=bloodPressedLegacy=$legacyValue" "--build-name=$($release.VersionName)" "--build-number=$($release.BuildNumber)"
    if ($LASTEXITCODE -ne 0) { throw 'APK build failed.' }
    # Keep Flutter-generated Windows paths valid for Android Lint.
    $localPropertiesPath = Join-Path $projectRoot 'android/local.properties'
    $localProperties = Get-Content -LiteralPath $localPropertiesPath -Raw
    $localProperties = [regex]::Replace(
        $localProperties,
        '(?m)^((?:flutter\.sdk|sdk\.dir)=)([A-Za-z]):',
        '$1$2\:'
    )
    [System.IO.File]::WriteAllText(
        $localPropertiesPath, $localProperties, [System.Text.UTF8Encoding]::new($false)
    )
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
    $packageLine = ($badging | Where-Object { $_ -match '^package:' }) -join ''
    if ($packageLine -notmatch "versionCode='$($release.BuildNumber)'" -or
        $packageLine -notmatch "versionName='$([regex]::Escape($release.VersionName))'") {
        throw 'APK manifest version differs from the reserved release version.'
    }

    $certificate = & (Join-Path $buildTools.FullName 'apksigner.bat') verify --print-certs 'build/app/outputs/flutter-apk/app-release.apk'
    if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
    $hasLegacyCert = [bool]($certificate -match 'd5808be7cb8879b13bd3a98c149aa5d3fa7ef3451d412ab4dc9cea583b1670f8')
    if (($Legacy -and -not $hasLegacyCert) -or (-not $Legacy -and $hasLegacyCert)) { throw 'Built APK signing identity is incorrect.' }
    $suffix = if ($Legacy) { '-legacy-test' } else { '-store' }
    $filename = "BloodPressed-v$($release.VersionName)-android-arm64$suffix.apk"
    $outputDirectory = Join-Path $projectRoot 'output/mobile'
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    $destination = Join-Path $outputDirectory $filename
    if ((Test-Path -LiteralPath $destination) -or (Test-Path -LiteralPath "$destination.json") -or (Test-Path -LiteralPath "$destination.sha256")) {
        throw 'Versioned release artifact already exists; refusing to overwrite it.'
    }
    [IO.File]::Copy((Join-Path $projectRoot 'build/app/outputs/flutter-apk/app-release.apk'), $destination, $false)
    $hash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLower()
    Set-Content -LiteralPath "$destination.sha256" -Value "$hash  $filename" -Encoding ascii
    $sourceCommit = (& git rev-parse HEAD).Trim()
    $workingTree = @(& git status --porcelain)
    $receipt = [ordered]@{
        versionName = $release.VersionName
        versionCode = $release.BuildNumber
        flutterVersion = $release.FlutterVersion
        reservedAtUtc = $release.ReservedAt
        reservedAtShanghai = $release.LocalTime
        buildSource = $release.BuildSource
        packageName = $expectedId
        abi = 'arm64-v8a'
        sourceCommit = $sourceCommit
        workingTreeDirty = ($workingTree.Count -gt 0)
        artifact = $filename
        sha256 = $hash
    }
    $receipt | ConvertTo-Json | Set-Content -LiteralPath "$destination.json" -Encoding utf8
    $mappingDirectory = Join-Path $projectRoot 'build/app/outputs/mapping/release'
    if (Test-Path -LiteralPath $mappingDirectory) {
        New-Item -ItemType Directory -Path (Join-Path $outputDirectory 'symbols') -Force | Out-Null
        $symbolsDirectory = Join-Path $outputDirectory "symbols/$($release.VersionName)$suffix"
        if (Test-Path -LiteralPath $symbolsDirectory) { throw 'Versioned symbol directory already exists.' }
        Copy-Item -LiteralPath $mappingDirectory -Destination $symbolsDirectory -Recurse
    }
    Write-Output "APK: $destination"
    Write-Output "SHA256: $hash"
} finally {
    if ($null -ne $buildLock) { $buildLock.Dispose() }
    $env:JAVA_TOOL_OPTIONS = $previousJavaOptions
    Pop-Location
}
