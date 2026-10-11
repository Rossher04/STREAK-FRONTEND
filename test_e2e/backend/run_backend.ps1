# Levanta el backend local para las e2e: BD SQLite desechable, migraciones, datos de prueba y servidor.
# Uso: powershell -File test_e2e/backend/run_backend.ps1 [-Backend C:\ruta\streak_backend_main]
param([string]$Backend = (Join-Path $PSScriptRoot '..\..\..\streak_backend_main'))
$Backend = (Resolve-Path $Backend).Path
$here = $PSScriptRoot
$py = Join-Path $Backend 'venv\Scripts\python.exe'
$db = Join-Path $Backend 'e2e.sqlite3'
Remove-Item $db -ErrorAction SilentlyContinue
$env:DEBUG = 'True'
$env:SECRET_KEY = 'e2e-local-key-only'
$env:DATABASE_URL = "sqlite:///$($db.Replace('\','/'))"
$env:MEDIA_ROOT = Join-Path $Backend 'e2e_media'
$env:PYTHONPATH = "$here;$Backend"
$env:DJANGO_SETTINGS_MODULE = 'e2e_settings'
Set-Location $Backend
& $py -B manage.py migrate --noinput | Out-Null
& $py -B (Join-Path $here 'seed.py')
& $py -B manage.py runserver 127.0.0.1:8000 --noreload

