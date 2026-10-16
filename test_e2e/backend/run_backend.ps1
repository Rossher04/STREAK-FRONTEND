# Levanta el backend local para las e2e: BD SQLite desechable, migraciones, datos de prueba y servidor.
# Uso: powershell -File test_e2e/backend/run_backend.ps1 [-Backend C:\ruta\streak_backend_main]
#        [-Puerto 8000] [-BaseDatos C:\ruta\e2e.sqlite3] [-Media C:\ruta\media]
# Con -BaseDatos/-Media se puede correr un backend propio por worktree sin pisar la BD por defecto
# Las e2e que usan admin.py deben correr con STREAK_E2E_DB y STREAK_E2E_MEDIA apuntando a esas mismas rutas.
param(
  [string]$Backend = (Join-Path $PSScriptRoot '..\..\..\streak_backend_main'),
  [int]$Puerto = 8000,
  [string]$BaseDatos = '',
  [string]$Media = ''
)
$Backend = (Resolve-Path $Backend).Path
$here = $PSScriptRoot
$py = Join-Path $Backend 'venv\Scripts\python.exe'
$db = if ($BaseDatos) { $BaseDatos } else { Join-Path $Backend 'e2e.sqlite3' }
$media = if ($Media) { $Media } else { Join-Path $Backend 'e2e_media' }
New-Item -ItemType Directory -Force (Split-Path $db) | Out-Null
Remove-Item $db -ErrorAction SilentlyContinue
$env:DEBUG = 'True'
if (-not $env:SECRET_KEY) { $env:SECRET_KEY = 'e2e-local-key-only' }
$env:DATABASE_URL = "sqlite:///$($db.Replace('\','/'))"
$env:MEDIA_ROOT = $media
$env:PYTHONPATH = "$here;$Backend"
$env:DJANGO_SETTINGS_MODULE = 'e2e_settings'
Set-Location $Backend
& $py -B manage.py migrate --noinput | Out-Null
& $py -B (Join-Path $here 'seed.py')
& $py -B manage.py runserver "127.0.0.1:$Puerto" --noreload
