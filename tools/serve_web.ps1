# Serve exported web build locally
Set-Location (Join-Path $PSScriptRoot "..")
python -m http.server 8060 --directory build/web
