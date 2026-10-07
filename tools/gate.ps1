$ErrorActionPreference = 'Continue'
$godot = if ($env:GODOT_EXE) { $env:GODOT_EXE } else { 'C:\Dev\InfiniteEmpire\GodotExe\Godot_v4.6.2-stable_win64_console.exe' }
Set-Location (Join-Path $PSScriptRoot "..")

$branch = (git rev-parse --abbrev-ref HEAD 2>$null)
if (-not $branch) { $branch = "unknown" } else { $branch = $branch.Trim() }
$commit = (git rev-parse --short HEAD 2>$null)
if (-not $commit) { $commit = "unknown" } else { $commit = $commit.Trim() }

$gatePass = $true
$testsLine = "not run"
$testsStatus = "FAIL"
$scenariosLine = "none"
$scenariosStatus = "PASS"
$soakLine = "not run"
$soakStatus = "FAIL"
$probesLine = "not run"
$probesStatus = "FAIL"
$exportLine = "not run"
$capturesLine = "0/0"

# Step 1: Run tests
Write-Host "Running tests..."
$testOutput = python tools/run_tests.py 2>&1 | ForEach-Object { "$_" }
$testCode = $LASTEXITCODE

foreach ($line in $testOutput) {
    Write-Host $line
    if ($line -match "^run_tests:\s+(Scripts=.*)") {
        $testsLine = $matches[1]
    }
}

if ($testCode -eq 0) {
    $testsStatus = "GREEN"
} elseif ($testCode -eq 2) {
    $testsStatus = "RED"
    $gatePass = $false
} else {
    $testsStatus = "INSTRUMENT FAIL"
    $gatePass = $false
}

# Step 2: Scenarios (if gate still ok)
if ($gatePass) {
    $scenarios = @(Get-ChildItem -Path "test/scenarios/*.json" -ErrorAction SilentlyContinue)
    if ($scenarios.Count -eq 0) {
        $scenariosLine = "none"
        $scenariosStatus = "PASS"
    } else {
        $passed = 0
        foreach ($sc in $scenarios) {
            $scPath = $sc.FullName
            $scOut = & $godot --headless --path . -s res://tools/scenario_run.gd -- "--scenario=$scPath" 2>&1 | ForEach-Object { "$_" }
            if ($LASTEXITCODE -eq 0) {
                $passed++
            }
        }
        $scenariosLine = "$passed/$($scenarios.Count)"
        if ($passed -eq $scenarios.Count) {
            $scenariosStatus = "PASS"
        } else {
            $scenariosStatus = "FAIL"
            $gatePass = $false
        }
    }
}

# Step 2b: Soak (smoke20)
if ($gatePass) {
    Write-Host "Running soak (smoke20)..."
    $soakOutput = python tools/soak/run_soak.py --design smoke20 --procs 4 2>&1 | ForEach-Object { "$_" }
    $soakCode = $LASTEXITCODE
    foreach ($line in $soakOutput) {
        Write-Host $line
        if ($line -match "SOAK (PASS|FAIL)") {
            $soakLine = $line.Trim()
        }
    }
    if ($soakCode -eq 0) {
        $soakStatus = "PASS"
    } else {
        $soakStatus = "FAIL"
        $gatePass = $false
    }
}

# Step 2c: Probes
if ($gatePass) {
    Write-Host "Running probes..."
    $probeOutput = python tools/soak/run_soak.py --probes --only p1a,p2,p3,p4,p5,p10 2>&1 | ForEach-Object { "$_" }
    $probeCode = $LASTEXITCODE
    $probePassCount = 0
    foreach ($line in $probeOutput) {
        Write-Host $line
        if ($line -match "PROBE PASS") {
            $probePassCount++
        }
    }
    if ($probeCode -eq 0) {
        $probesLine = "$probePassCount passed"
        $probesStatus = "PASS"
    } else {
        $probesLine = "$probePassCount passed (exit $probeCode)"
        $probesStatus = "FAIL"
        $gatePass = $false
    }
}

# Step 3: Web export
if ($gatePass) {
    Write-Host "Running web export..."
    $exportOutput = powershell -File tools/export_web.ps1 2>&1 | ForEach-Object { "$_" }
    $exportCode = $LASTEXITCODE
    
    $pckSizeStr = ""
    $wasmSizeStr = ""
    $bootOkFound = $false
    $bootAiOkFound = $false
    foreach ($line in $exportOutput) {
        Write-Host $line
        if ($line.Trim() -eq "BOOT_OK") {
            $bootOkFound = $true
        }
        if ($line -match "BOOT_AI_OK") {
            $bootAiOkFound = $true
        }
        if ($line -match "pck size:\s+([^\(]+)") {
            $pckSizeStr = $matches[1].Trim()
        }
        if ($line -match "wasm size:\s+([^\(]+)") {
            $wasmSizeStr = $matches[1].Trim()
        }
    }

    if ($exportCode -eq 0 -and $bootOkFound -and $bootAiOkFound) {
        $exportLine = "BOOT_OK + BOOT_AI_OK ; pck $pckSizeStr wasm $wasmSizeStr"
    } else {
        $exportLine = "BOOT_FAIL export exit $exportCode ; pck $pckSizeStr wasm $wasmSizeStr"
        $gatePass = $false
    }
}

# Step 4: Captures
if ($gatePass) {
    Write-Host "Running captures..."
    $capturesJsonPath = "tools/captures.json"
    if (Test-Path $capturesJsonPath) {
        $capturesData = Get-Content $capturesJsonPath -Raw | ConvertFrom-Json
        $capList = $capturesData.captures
        $capPassed = 0
        $capTotal = $capList.Count
        $capPaths = @()

        New-Item -ItemType Directory -Path "build/captures" -Force | Out-Null

        foreach ($cap in $capList) {
            $capId = $cap.id
            $capOut = $cap.out
            $fullOut = Join-Path (Get-Location) $capOut
            if (Test-Path $fullOut) {
                Remove-Item $fullOut -Force
            }

            Write-Host "Capturing $capId to $capOut..."
            $proc = Start-Process $godot -ArgumentList '--path', '.', '--resolution', '1280x720', '--', "--capture=$capId", "--out=$capOut" -PassThru -NoNewWindow
            try {
                $proc | Wait-Process -Timeout 60 -ErrorAction Stop
            } catch {
                $proc.Kill()
                Write-Host "Capture $capId timed out after 60s!"
            }

            if ((Test-Path $fullOut) -and (Get-Item $fullOut).Length -gt 0) {
                $capPassed++
                $capPaths += $capOut
            } else {
                Write-Host "Capture $capId failed to generate $capOut"
            }
        }
        $capturesLine = "$capPassed/$capTotal  $($capPaths -join ' ')"
        if ($capPassed -ne $capTotal) {
            $gatePass = $false
        }
    }
}

# Summary Block
Write-Host ""
Write-Host "=== GATE $branch $commit"
Write-Host "tests:     $testsLine  -> $testsStatus"
Write-Host "scenarios: $scenariosLine                -> $scenariosStatus"
Write-Host "soak:      $soakLine                     -> $soakStatus"
Write-Host "probes:    $probesLine                   -> $probesStatus"
Write-Host "export:    $exportLine"
Write-Host "captures:  $capturesLine"
if ($gatePass) {
    Write-Host "=== GATE PASS"
    exit 0
} else {
    Write-Host "=== GATE FAIL"
    exit 1
}

