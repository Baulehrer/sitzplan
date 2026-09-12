param(
  [string]$BuildDirectory = 'build\windows\x64\runner\Release',
  [string]$AppVersion = $env:APP_VERSION
)

$ErrorActionPreference = 'Stop'
if ($AppVersion -notmatch '^\d+\.\d+\.\d+$') { throw 'APP_VERSION must contain major.minor.patch.' }
$repo = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$source = Join-Path $repo $BuildDirectory
foreach ($file in @('sitzplan.exe', 'flutter_windows.dll', 'ffmpeg.exe', 'FFMPEG-LICENSE.txt', 'FFMPEG-README.txt')) {
  if (-not (Test-Path (Join-Path $source $file))) { throw "Required runtime file missing: $file" }
}

$staging = Join-Path ([IO.Path]::GetTempPath()) ('sitzplan-msix-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $staging | Out-Null
Copy-Item "$source\*" $staging -Recurse

# Include the desktop C++ runtime instead of requiring a separately installed VC redistributable.
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$visualStudio = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if ($LASTEXITCODE -ne 0 -or -not $visualStudio) { throw 'Visual Studio C++ runtime location could not be determined.' }
$crt = Get-ChildItem "$visualStudio\VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT" -Directory |
  Sort-Object FullName -Descending | Select-Object -First 1
if (-not $crt) { throw 'The x64 Visual C++ runtime was not found.' }
Copy-Item "$($crt.FullName)\*.dll" $staging

[xml]$manifest = Get-Content (Join-Path $PSScriptRoot 'AppxManifest.xml') -Raw
# The Store reserves the fourth version component; leave it at zero.
$manifest.Package.Identity.Version = "$AppVersion.0"
$manifest.Save((Join-Path $staging 'AppxManifest.xml'))

Add-Type -AssemblyName System.Drawing
$assets = New-Item -ItemType Directory -Path (Join-Path $staging 'Assets') -Force
$icon = [Drawing.Image]::FromFile((Join-Path $repo 'assets\icon\app_icon.png'))
try {
  foreach ($item in @(@('StoreLogo.png', 50), @('Square150x150Logo.png', 150), @('Square44x44Logo.png', 44))) {
    $size = [int]$item[1]
    $bitmap = [Drawing.Bitmap]::new($size, $size)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
      $graphics.Clear([Drawing.Color]::Transparent)
      $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $graphics.DrawImage($icon, 0, 0, $size, $size)
      $bitmap.Save((Join-Path $assets.FullName $item[0]), [Drawing.Imaging.ImageFormat]::Png)
    } finally { $graphics.Dispose(); $bitmap.Dispose() }
  }
} finally { $icon.Dispose() }

$makeAppx = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\makeappx.exe" |
  Sort-Object { [version]$_.Directory.Parent.Name } -Descending |
  Select-Object -First 1 -ExpandProperty FullName
if (-not $makeAppx) { throw 'Windows SDK MakeAppx was not found.' }
$dist = New-Item -ItemType Directory -Path (Join-Path $repo 'dist') -Force
$output = Join-Path $dist.FullName "Sitzplan-$AppVersion-Store.msix"
& $makeAppx pack /d $staging /p $output /o
if ($LASTEXITCODE -ne 0) { throw "MSIX packaging or manifest validation failed: $LASTEXITCODE" }

# Verify the actual archive rather than only the input manifest.
$unpacked = Join-Path ([IO.Path]::GetTempPath()) ('sitzplan-msix-check-' + [guid]::NewGuid())
& $makeAppx unpack /p $output /d $unpacked /o
if ($LASTEXITCODE -ne 0) { throw "MSIX extraction failed: $LASTEXITCODE" }
[xml]$packed = Get-Content (Join-Path $unpacked 'AppxManifest.xml') -Raw
if ($packed.Package.Identity.Name -ne 'Ferdinand-Braun-Schule.KaufisSitzplan-App' -or
    $packed.Package.Identity.Publisher -ne 'CN=C4279560-AB23-4B63-9A2C-5EA6A16A977F' -or
    $packed.Package.Identity.Version -ne "$AppVersion.0") { throw 'Store package identity mismatch.' }
foreach ($file in @('sitzplan.exe', 'ffmpeg.exe', 'flutter_windows.dll', 'msvcp140.dll', 'vcruntime140.dll', 'data\flutter_assets\AssetManifest.bin')) {
  if (-not (Test-Path (Join-Path $unpacked $file))) { throw "Runtime missing from MSIX: $file" }
}
if (Test-Path (Join-Path $unpacked 'AppxSignature.p7x')) { throw 'The Store upload package must not carry a local test signature.' }
Write-Host "Verified unsigned Store submission package: $output"
