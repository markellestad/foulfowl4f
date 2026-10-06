# Foul Fowl: Fly, Flock, Forage, Fight

> "Foul Fowl 4X?
> Ducks.
> Pheasants for the win.
> Swans OP."

A classic Master of Orion-style 4X (with modern quality-of-life) starring rival bird empires, built for the eXplorminate Discord. Godot 4.6, web export for itch.io.

## Build and test

Commands are run from PowerShell in the repository root. Godot defaults to `$env:GODOT_EXE` or `C:\Dev\InfiniteEmpire\GodotExe\Godot_v4.6.2-stable_win64_console.exe`.

- **Import**: `& $GODOT --headless --path . --import`
- **Tests**: `python tools/run_tests.py` (all tests), or `python tools/run_tests.py --file res://test/unit/test_rng.gd`
- **Scenario**: `& $GODOT --headless --path . -s res://tools/scenario_run.gd -- --scenario=res://test/scenarios/<name>.json`
- **Web export + boot check**: `powershell -File tools/export_web.ps1`
- **Captures**: `& $GODOT --path . --resolution 1280x720 -- --capture=<id> --out=build/captures/<file>.png`
- **Gate**: `powershell -File tools/gate.ps1`
- **Local web server**: `powershell -File tools/serve_web.ps1`
