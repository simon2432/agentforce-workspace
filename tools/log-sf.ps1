# log-sf.ps1 — red de seguridad de la bitácora.
#
# Lo invoca el hook PostToolUse de .claude/settings.json: recibe por stdin el JSON
# del comando que se acaba de ejecutar y anota en .bitacora/comandos.log todo
# comando `sf` que ESCRIBE en la org.
#
# NO reemplaza a specs/<Trabajo>/BITACORA.md. Ese es el registro real, con org,
# resultado y reversión. Esto es el respaldo crudo para que nada se pierda si la
# sesión se corta antes de que Claude escriba la fila. Claude consolida desde acá.

$ErrorActionPreference = "SilentlyContinue"

$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $j = $raw | ConvertFrom-Json } catch { exit 0 }

$cmd = $j.tool_input.command
if (-not $cmd) { exit 0 }
$cmd = ($cmd -replace '\s+', ' ').Trim()

# solo comandos sf (al principio o encadenados con ; && ||)
if ($cmd -notmatch '(^|[;&|]\s*)sf\s') { exit 0 }

# los de solo lectura no van: ensucian sin aportar (regla de CLAUDE.md §5).
# Se buscan en cualquier posicion: el subcomando real puede llevar prefijo
# (`sf project deploy validate`, no `sf deploy validate`).
$soloLectura = @(
    'org list', 'org display', 'org open', 'config get', 'config list',
    'data query', 'sobject describe', 'sobject list', 'project list', 'alias list',
    'deploy validate', 'deploy report', 'agent preview',
    'plugins', '--version', '--help'
)
foreach ($p in $soloLectura) { if ($cmd -match [regex]::Escape($p)) { exit 0 } }

$dir = Join-Path (Get-Location) ".bitacora"
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

$linea = "{0}`t{1}`r`n" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $cmd
$utf8 = New-Object System.Text.UTF8Encoding($false)      # sin BOM
[IO.File]::AppendAllText((Join-Path $dir "comandos.log"), $linea, $utf8)
exit 0
