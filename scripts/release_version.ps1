function Reserve-AndroidReleaseVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [DateTimeOffset]$Now = [DateTimeOffset]::UtcNow
    )
    # Flutter keeps a three-part semantic version plus an integer build number.
    # The Android packaging command maps it to MAJOR.FEATURE.PATCH.BUILD.
    $pubspecPath = Join-Path $ProjectRoot 'pubspec.yaml'
    $content = [System.IO.File]::ReadAllText($pubspecPath)
    $pattern = '(?m)^version:[ \t]*(?<base>\d+\.\d+\.\d+)\+(?<build>\d+)[ \t]*(?=\r?$)'
    $versionMatch = [regex]::Match($content, $pattern)
    if (-not $versionMatch.Success) { throw 'pubspec.yaml must contain version: MAJOR.FEATURE.PATCH+BUILD.' }
    $baseVersion = $versionMatch.Groups['base'].Value
    $previousBuild = [long]::Parse($versionMatch.Groups['build'].Value)
    $localTime = [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($Now, 'China Standard Time')
    $timestamp = $localTime.ToString('MMddHHmmss', [Globalization.CultureInfo]::InvariantCulture)
    $buildNumber = [Math]::Max([long]::Parse($timestamp), $previousBuild + 1)
    if ($buildNumber -gt [int]::MaxValue) { throw 'Android build number exceeds the signed integer limit.' }
    # Same-second builds, clock rollback, and year rollover must never reuse/decrease a code.
    $buildText = $buildNumber.ToString('D10', [Globalization.CultureInfo]::InvariantCulture)
    $flutterVersion = "$baseVersion+$buildNumber"
    $newContent = $content.Substring(0, $versionMatch.Index) + "version: $flutterVersion" + $content.Substring($versionMatch.Index + $versionMatch.Length)
    [System.IO.File]::WriteAllText($pubspecPath, $newContent, [Text.UTF8Encoding]::new($false))
    [pscustomobject]@{
        BaseVersion = $baseVersion
        BuildNumber = $buildNumber
        VersionName = "$baseVersion.$buildText"
        FlutterVersion = $flutterVersion
        ReservedAt = $Now.ToUniversalTime().ToString('o')
        LocalTime = $localTime.ToString('o')
        BuildSource = if ($buildNumber -eq [long]::Parse($timestamp)) { 'Shanghai-MMddHHmmss' } else { 'monotonic-fallback' }
    }
}
