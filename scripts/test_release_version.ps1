$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'release_version.ps1')
# Independent filesystem fixtures: tests do not reserve versions in the actual project.
$testRoot = Join-Path $PSScriptRoot ("../output/version-tests/" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$fixture = Join-Path $testRoot 'pubspec.yaml'
function Assert-Equal($Actual, $Expected) {
    if ($Actual -ne $Expected) { throw "Expected '$Expected', got '$Actual'." }
}
try {
    [IO.File]::WriteAllText($fixture, "name: test`r`nversion: 1.3.0+6`r`n# preserved`r`n")
    $fixedTime = [DateTimeOffset]::Parse('2026-10-16T10:10:10Z')
    $first = Reserve-AndroidReleaseVersion -ProjectRoot $testRoot -Now $fixedTime
    Assert-Equal $first.VersionName '1.3.0.1016181010'
    Assert-Equal $first.BuildNumber 1016181010
    Assert-Equal ([IO.File]::ReadAllText($fixture)) "name: test`r`nversion: 1.3.0+1016181010`r`n# preserved`r`n"
    $second = Reserve-AndroidReleaseVersion -ProjectRoot $testRoot -Now $fixedTime
    Assert-Equal $second.BuildNumber 1016181011
    Assert-Equal $second.VersionName '1.3.0.1016181011'
    $rollback = Reserve-AndroidReleaseVersion -ProjectRoot $testRoot -Now $fixedTime.AddDays(-1)
    Assert-Equal $rollback.BuildNumber 1016181012
    Assert-Equal $rollback.BuildSource 'monotonic-fallback'
    [IO.File]::WriteAllText($fixture, "version: 1.3.0+1231235959`n")
    $year = Reserve-AndroidReleaseVersion -ProjectRoot $testRoot -Now ([DateTimeOffset]::Parse('2027-01-01T00:00:00Z'))
    Assert-Equal $year.BuildNumber 1231235960
    [IO.File]::WriteAllText($fixture, "version: 1.3.0+2147483647`n")
    $overflowRejected = $false
    try { Reserve-AndroidReleaseVersion -ProjectRoot $testRoot -Now $fixedTime | Out-Null } catch { $overflowRejected = $true }
    Assert-Equal $overflowRejected $true
    Assert-Equal ([IO.File]::ReadAllText($fixture)) "version: 1.3.0+2147483647`n"
    [IO.File]::WriteAllText($fixture, "version: invalid`n")
    $invalidRejected = $false
    try { Reserve-AndroidReleaseVersion -ProjectRoot $testRoot -Now $fixedTime | Out-Null } catch { $invalidRejected = $true }
    Assert-Equal $invalidRejected $true
    Assert-Equal ([IO.File]::ReadAllText($fixture)) "version: invalid`n"
} finally {
    # Keep intentionally invalid YAML fixtures out of the workspace analyzer.
    if (Test-Path -LiteralPath $fixture) { Rename-Item -LiteralPath $fixture -NewName 'pubspec.fixture.txt' }
}
Write-Output 'PASS: timestamp, same-second builds, rollback, year rollover, overflow, invalid input, and source preservation.'
