# link-skills.ps1 — recrea los accesos directos de .claude/skills/ -> .agents/skills/
#
#   pwsh tools/link-skills.ps1
#
# Por qué existe: las skills viven versionadas en .agents/skills/, pero Claude Code
# las busca en .claude/skills/. Esos enlaces son POR MÁQUINA (gitignoreados: en Windows
# un symlink clonado sin core.symlinks queda como archivo de texto roto), así que un clon
# nuevo arranca sin ninguna skill visible hasta correr esto.
#
# En Windows usa JUNCTIONS, que no requieren Modo Desarrollador ni permisos de admin.
# En macOS/Linux usa symlinks. Es idempotente: correlo las veces que quieras.
# No descarga nada — solo enlaza lo que ya está en el repo.

$ErrorActionPreference = "Stop"

$root   = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root ".agents/skills"
$target = Join-Path $root ".claude/skills"

if (-not (Test-Path $source)) {
    Write-Host "ERROR: no existe .agents/skills/ — el clon está incompleto." -ForegroundColor Red
    Write-Host "       Ver SETUP.md: 'git config --global core.longpaths true' antes de clonar." -ForegroundColor Yellow
    exit 1
}

$onWindows = $IsWindows -or ($env:OS -eq "Windows_NT")
$linkType  = if ($onWindows) { "Junction" } else { "SymbolicLink" }

if (-not (Test-Path $target)) { New-Item -ItemType Directory -Path $target -Force | Out-Null }

$created = 0; $ok = 0; $repaired = 0; $skipped = @()

foreach ($skill in Get-ChildItem $source -Directory) {
    $link = Join-Path $target $skill.Name
    $probe = Join-Path $link "SKILL.md"

    if (Test-Path $link) {
        if (Test-Path $probe) { $ok++; continue }   # ya resuelve: no tocar

        $item = Get-Item $link -Force
        $isReparse = $item.Attributes -band [IO.FileAttributes]::ReparsePoint
        if ($isReparse) {
            # enlace roto: borra SOLO el enlace, nunca el destino
            [IO.Directory]::Delete($item.FullName, $false)
        } elseif ($item.PSIsContainer) {
            # carpeta real (copia): no la tocamos sin permiso explícito
            $skipped += $skill.Name; continue
        } else {
            # symlink clonado como archivo de texto (Windows sin core.symlinks)
            Remove-Item $item.FullName -Force
        }
        $repaired++
    }

    New-Item -ItemType $linkType -Path $link -Target $skill.FullName | Out-Null
    $created++
}

Write-Host ""
Write-Host ("  {0} enlaces nuevos · {1} ya estaban bien · {2} reparados  ({3})" -f `
    $created, $ok, $repaired, $linkType) -ForegroundColor Green

if ($skipped.Count -gt 0) {
    Write-Host ""
    Write-Host "  WARN: estas son carpetas reales, no enlaces (posible copia vieja):" -ForegroundColor Yellow
    $skipped | ForEach-Object { Write-Host "        $_" -ForegroundColor Yellow }
    Write-Host "        Borralas a mano y volvé a correr este script." -ForegroundColor DarkGray
}

# verificación funcional real
if (Test-Path (Join-Path $target "agentforce-generate/SKILL.md")) {
    Write-Host "  OK    Claude Code va a ver las skills. Reinicialo para que las cargue." -ForegroundColor Green
} else {
    Write-Host "  ERROR los enlaces no resuelven. Ver SETUP.md Parte B." -ForegroundColor Red
    exit 1
}
