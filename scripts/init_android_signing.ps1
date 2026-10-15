param([string]$JdkPath = $env:JAVA_HOME)
$ErrorActionPreference = 'Stop'
if (-not $JdkPath) { throw 'Set JAVA_HOME or pass -JdkPath.' }
$signingDirectory = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.bloodpressed-signing'
$keystorePath = Join-Path $signingDirectory 'bloodpressed-release.p12'
$propertiesPath = Join-Path $signingDirectory 'signing.properties'
if ((Test-Path -LiteralPath $keystorePath) -or (Test-Path -LiteralPath $propertiesPath)) {
    if ((Test-Path -LiteralPath $keystorePath) -and (Test-Path -LiteralPath $propertiesPath)) {
        Write-Output "Existing signing identity retained: $signingDirectory"
        exit 0
    }
    throw 'Incomplete signing directory; restore its backup before continuing.'
}
New-Item -ItemType Directory -Path $signingDirectory -Force | Out-Null
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
& icacls.exe $signingDirectory /inheritance:r /grant:r "${identity}:(OI)(CI)F" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Unable to restrict signing directory permissions.' }
$secretBytes = New-Object byte[] 32
$random = [Security.Cryptography.RandomNumberGenerator]::Create()
$random.GetBytes($secretBytes)
$random.Dispose()
$env:BP_SIGNING_PASSWORD = [Convert]::ToBase64String($secretBytes)
try {
    & (Join-Path $JdkPath 'bin/keytool.exe') -genkeypair -keystore $keystorePath -storetype PKCS12 -alias bloodpressed -keyalg RSA -keysize 3072 -validity 10000 -dname 'CN=Zhao Xuan, O=BloodPressed, C=CN' -storepass:env BP_SIGNING_PASSWORD -keypass:env BP_SIGNING_PASSWORD -noprompt
    if ($LASTEXITCODE -ne 0) { throw 'Key generation failed.' }
    $storeFile = $keystorePath.Replace('\', '/')
    $properties = "storeFile=$storeFile`nstorePassword=$env:BP_SIGNING_PASSWORD`nkeyAlias=bloodpressed`nkeyPassword=$env:BP_SIGNING_PASSWORD`n"
    [IO.File]::WriteAllText($propertiesPath, $properties, [Text.UTF8Encoding]::new($false))
    & (Join-Path $JdkPath 'bin/keytool.exe') -exportcert -rfc -keystore $keystorePath -alias bloodpressed -storepass:env BP_SIGNING_PASSWORD -file (Join-Path $signingDirectory 'bloodpressed-certificate.pem')
    if ($LASTEXITCODE -ne 0) { throw 'Certificate export failed.' }
} finally {
    Remove-Item Env:BP_SIGNING_PASSWORD -ErrorAction SilentlyContinue
    $properties = $null
    [Array]::Clear($secretBytes, 0, $secretBytes.Length)
}
Write-Output "Signing identity created outside the repository. Back up this directory securely: $signingDirectory"
