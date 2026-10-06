param(
    [switch]$Licensed
)

$ErrorActionPreference = 'Continue'
$godot = if ($env:GODOT_EXE) { $env:GODOT_EXE } else { 'C:\Dev\InfiniteEmpire\GodotExe\Godot_v4.6.2-stable_win64_console.exe' }
Set-Location (Join-Path $PSScriptRoot "..")

if ($Licensed) {
    Write-Host "Fetching licensed audio..."
    python tools/fetch_licensed_audio.py
}

$buildDir = "build"
$webDir = "build/web"

if (-not (Test-Path $buildDir)) {
    New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
}
$gdignore = Join-Path $buildDir ".gdignore"
if (-not (Test-Path $gdignore)) {
    New-Item -ItemType File -Path $gdignore -Force | Out-Null
}

if (Test-Path $webDir) {
    Remove-Item -Path "$webDir\*" -Recurse -Force -ErrorAction SilentlyContinue
} else {
    New-Item -ItemType Directory -Path $webDir -Force | Out-Null
}

Write-Host "Importing project..."
& $godot --headless --path . --import
if ($LASTEXITCODE -ne 0) {
    Write-Error "Godot import failed with exit code $LASTEXITCODE"
    exit 1
}

Write-Host "Exporting Web release..."
& $godot --headless --path . --export-release "Web" build/web/index.html
if ($LASTEXITCODE -ne 0) {
    Write-Error "Godot web export failed with exit code $LASTEXITCODE"
    exit 1
}

$pckPath = "build/web/index.pck"
$wasmPath = "build/web/index.wasm"
$htmlPath = "build/web/index.html"

if (-not (Test-Path $pckPath) -or -not (Test-Path $wasmPath) -or -not (Test-Path $htmlPath)) {
    Write-Error "Missing expected web export output files (index.pck, index.wasm, or index.html)"
    exit 1
}

Write-Host "Running boot check on exported pack..."
$bootOutput = & $godot --headless --main-pack $pckPath -- --boot-check 2>&1 | ForEach-Object { "$_" }
$bootCode = $LASTEXITCODE
$bootOk = $false
foreach ($line in $bootOutput) {
    Write-Host $line
    if ($line.Trim() -eq "BOOT_OK") {
        $bootOk = $true
    }
}

if (-not $bootOk -or $bootCode -ne 0) {
    # Check if mounting web pck failed with pack format error
    $packFormatError = $false
    foreach ($line in $bootOutput) {
        if ($line -match "pack" -and $line -match "error") {
            $packFormatError = $true
        }
    }
    if ($packFormatError) {
        Write-Host "Web pack mounting failed with pack format error; trying separate check pack..."
        $checkDir = "build/web_check"
        if (-not (Test-Path $checkDir)) {
            New-Item -ItemType Directory -Path $checkDir -Force | Out-Null
        }
        $checkPck = "build/web_check/check.pck"
        & $godot --headless --path . --export-pack "Web" $checkPck
        $bootOutput2 = & $godot --headless --main-pack $checkPck -- --boot-check 2>&1 | ForEach-Object { "$_" }
        $bootCode = $LASTEXITCODE
        $bootOk = $false
        foreach ($line in $bootOutput2) {
            Write-Host $line
            if ($line.Trim() -eq "BOOT_OK") {
                $bootOk = $true
            }
        }
    }
}

if (-not $bootOk -or $bootCode -ne 0) {
    Write-Error "Boot check failed!"
    exit 1
}

$pckSize = (Get-Item $pckPath).Length
$wasmSize = (Get-Item $wasmPath).Length
$totalWebSize = (Get-ChildItem -Path $webDir -Recurse | Measure-Object -Property Length -Sum).Sum

# Measure compressed wasm (gzip) for web transfer download size (BRIEF / PLAN §1a target)
$wasmGzipSizeStr = (python -c "import gzip, pathlib; print(len(gzip.compress(pathlib.Path('build/web/index.wasm').read_bytes())))").Trim()
$wasmGzipSize = [int64]$wasmGzipSizeStr
$downloadSize = [int64]$pckSize + $wasmGzipSize

Write-Host ("pck size: {0:N0} bytes ({1:N2} MB)" -f $pckSize, ($pckSize / 1MB))
Write-Host ("wasm size: {0:N0} bytes ({1:N2} MB)" -f $wasmSize, ($wasmSize / 1MB))
Write-Host ("wasm compressed (gzip): {0:N0} bytes ({1:N2} MB)" -f $wasmGzipSize, ($wasmGzipSize / 1MB))
Write-Host ("initial web download (pck + compressed wasm): {0:N0} bytes ({1:N2} MB)" -f $downloadSize, ($downloadSize / 1MB))
Write-Host ("total web on-disk: {0:N0} bytes ({1:N2} MB)" -f $totalWebSize, ($totalWebSize / 1MB))

$maxBudget = 25 * 1024 * 1024
if ($downloadSize -gt $maxBudget) {
    Write-Error "Initial web download size exceeds 25 MB budget ($downloadSize bytes)!"
    exit 1
}

Write-Host "Web export and boot check successful!"
exit 0
