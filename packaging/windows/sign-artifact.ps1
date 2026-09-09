param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$FilePath
)

$ErrorActionPreference = 'Stop'

foreach ($name in @(
  'ARTIFACT_SIGNING_ENDPOINT',
  'ARTIFACT_SIGNING_ACCOUNT',
  'ARTIFACT_SIGNING_PROFILE'
)) {
  if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
    throw "Required environment variable $name is missing."
  }
}

$signTool = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\signtool.exe" |
  Sort-Object { [version]$_.Directory.Parent.Name } -Descending |
  Select-Object -First 1 -ExpandProperty FullName
$dlib = Get-ChildItem "${env:ProgramFiles(x86)}\Microsoft\Artifact Signing Client Tools" `
  -Filter Azure.CodeSigning.Dlib.dll -Recurse |
  Where-Object FullName -Match '\\x64\\' |
  Select-Object -First 1 -ExpandProperty FullName

if (-not $signTool) { throw 'A compatible Windows SDK SignTool was not found.' }
if (-not $dlib) { throw 'The Artifact Signing x64 dlib was not found.' }

$metadataPath = Join-Path $env:RUNNER_TEMP 'artifact-signing-metadata.json'
$metadata = @{
  Endpoint = $env:ARTIFACT_SIGNING_ENDPOINT
  CodeSigningAccountName = $env:ARTIFACT_SIGNING_ACCOUNT
  CertificateProfileName = $env:ARTIFACT_SIGNING_PROFILE
  CorrelationId = $env:GITHUB_RUN_ID
  ExcludeCredentials = @(
    'EnvironmentCredential'
    'WorkloadIdentityCredential'
    'ManagedIdentityCredential'
    'SharedTokenCacheCredential'
    'VisualStudioCredential'
    'VisualStudioCodeCredential'
    'AzurePowerShellCredential'
    'AzureDeveloperCliCredential'
  )
} | ConvertTo-Json
[IO.File]::WriteAllText($metadataPath, $metadata, [Text.UTF8Encoding]::new($false))

& $signTool sign /v /fd SHA256 `
  /tr 'http://timestamp.acs.microsoft.com' /td SHA256 `
  /dlib $dlib /dmdf $metadataPath $FilePath
if ($LASTEXITCODE -ne 0) {
  throw "Artifact Signing failed for $FilePath (exit code $LASTEXITCODE)."
}
