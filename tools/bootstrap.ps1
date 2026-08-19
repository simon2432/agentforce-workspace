# bootstrap.ps1 — verifica el entorno y te dice qué falta.
# NO instala nada ni toca la org: solo diagnostica.
#   pwsh tools/bootstrap.ps1

$ErrorActionPreference = "Continue"
$issues = @()

function Test-Cmd($name, $cmd, $fix) {
    try {
        $v = Invoke-Expression $cmd 2>&1 | Select-Object -First 1
        Write-Host ("  OK    {0,-22} {1}" -f $name, $v) -ForegroundColor Green
        return $true
    } catch {
        Write-Host ("  FALTA {0,-22} -> {1}" -f $name, $fix) -ForegroundColor Red
        $script:issues += "$name : $fix"
        return $false
    }
}

Write-Host "`n=== A. Herramientas de la máquina ===" -ForegroundColor Cyan
Test-Cmd "Node.js"        "node -v"          "https://nodejs.org (LTS, 20+)" | Out-Null
Test-Cmd "Salesforce CLI" "sf --version"     "npm install -g @salesforce/cli" | Out-Null
Test-Cmd "Claude Code"    "claude --version" "npm install -g @anthropic-ai/claude-code" | Out-Null

$py = $false
foreach ($c in @("py --version", "python3 --version", "python --version")) {
    try { $v = Invoke-Expression $c 2>&1 | Select-Object -First 1
          Write-Host ("  OK    {0,-22} {1}" -f "Python", $v) -ForegroundColor Green
          $py = $true; break } catch {}
}
if (-not $py) {
    Write-Host "  FALTA Python                 -> 3.9+ requerido por el plugin agentforce-adlc" -ForegroundColor Red
    $issues += "Python 3.9+ : https://www.python.org/downloads/"
}

Write-Host "`n=== Plugin agentforce-adlc ===" -ForegroundColor Cyan
try {
    $plugins = claude plugin list 2>&1 | Out-String
    if ($plugins -match "agentforce-adlc") {
        Write-Host "  OK    plugin instalado" -ForegroundColor Green
    } else {
        # Distinguimos los dos estados: son DOS pasos y es facil quedarse en el primero.
        # Agregar el marketplace deja carpetas ~/.claude/plugins/*/agentforce-adlc que
        # hacen parecer que esta instalado, pero installed_plugins.json sigue vacio.
        $mk = Join-Path $env:USERPROFILE ".claude/plugins/known_marketplaces.json"
        $mkAdded = (Test-Path $mk) -and ((Get-Content $mk -Raw) -match "agentforce-adlc")

        if ($mkAdded) {
            Write-Host "  FALTA plugin agentforce-adlc NO instalado (el marketplace si esta agregado)" -ForegroundColor Red
            Write-Host "        Te falta solo el segundo paso:" -ForegroundColor Yellow
            Write-Host "        claude plugin install agentforce-adlc@agentforce-adlc" -ForegroundColor Yellow
        } else {
            Write-Host "  FALTA plugin agentforce-adlc (faltan los dos pasos)" -ForegroundColor Red
            Write-Host "        claude plugin marketplace add SalesforceAIResearch/agentforce-adlc" -ForegroundColor Yellow
            Write-Host "        claude plugin install agentforce-adlc@agentforce-adlc" -ForegroundColor Yellow
        }
        Write-Host "        Verificar de verdad: claude plugin list --json  (tiene que NO dar [])" -ForegroundColor DarkGray
        $issues += "plugin agentforce-adlc no instalado"
    }
} catch { Write-Host "  ??    no pude correr 'claude plugin list'" -ForegroundColor Yellow }

Write-Host "`n=== B. Estado del repo ===" -ForegroundColor Cyan
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root

if (Test-Path ".git") { Write-Host "  OK    git inicializado" -ForegroundColor Green }
else {
    Write-Host "  FALTA git no inicializado" -ForegroundColor Red
    Write-Host "        git init; git add .; git commit -m 'setup inicial del workspace'" -ForegroundColor Yellow
    $issues += "git init"
}

if (Test-Path ".mcp.json") { Write-Host "  OK    .mcp.json presente" -ForegroundColor Green }
else {
    Write-Host "  FALTA .mcp.json (MCP de docs de Salesforce)" -ForegroundColor Red
    Write-Host "        ver SETUP.md Parte B" -ForegroundColor Yellow
    $issues += ".mcp.json"
}

if (Test-Path ".agents/skills") {
    $n = (Get-ChildItem ".agents/skills" -Directory).Count
    Write-Host "  OK    sf-skills: $n skills en .agents/skills/" -ForegroundColor Green
} else {
    Write-Host "  FALTA .agents/skills -> npx skills forcedotcom/sf-skills --all" -ForegroundColor Red
    $issues += "sf-skills"
}

# .gitignore no debe excluir .agents/
if (Test-Path ".gitignore") {
    $gi = Get-Content ".gitignore" -Raw
    if ($gi -match "(?m)^\s*\.agents") {
        Write-Host "  ERROR .gitignore excluye .agents/ -- las skills no se van a commitear" -ForegroundColor Red
        $issues += ".gitignore excluye .agents/"
    } else { Write-Host "  OK    .gitignore no excluye .agents/" -ForegroundColor Green }
}

# clon incompleto: en Windows sin core.longpaths, git no puede crear las rutas largas
# de .agents/skills/ y las deja como borradas. El repo parece estar pero le faltan archivos.
$deleted = @(git status --porcelain 2>$null | Where-Object { $_ -match '^\s?D\s' })
if ($deleted.Count -gt 0) {
    Write-Host "  ERROR clon incompleto: faltan $($deleted.Count) archivo(s) del repo" -ForegroundColor Red
    Write-Host "        Causa tipica: limite de 260 caracteres de Windows al clonar." -ForegroundColor Yellow
    Write-Host "        git config --global core.longpaths true" -ForegroundColor Yellow
    Write-Host "        git restore --source=HEAD :/" -ForegroundColor Yellow
    Write-Host "        git reset" -ForegroundColor Yellow
    $issues += "clon incompleto -> ver SETUP.md, seccion 'clon incompleto'"
} else {
    Write-Host "  OK    clon completo (sin archivos faltantes)" -ForegroundColor Green
}

# force-app debe existir: sfdx-project.json lo declara como package directory
if (Test-Path "force-app/main/default") {
    Write-Host "  OK    force-app/main/default presente" -ForegroundColor Green
} else {
    Write-Host "  FALTA force-app/main/default -> los comandos 'sf project' van a fallar" -ForegroundColor Red
    Write-Host "        mkdir force-app/main/default" -ForegroundColor Yellow
    $issues += "force-app/main/default no existe"
}

# duplicado agent/ (no debería existir — se eliminó, ver docs/DECISIONS.md)
if (Test-Path "agent/skills") {
    Write-Host "  WARN  reapareció agent/skills/ (copia redundante de .agents/skills/)" -ForegroundColor Yellow
    Write-Host "        es seguro borrarla; la genera npx skills para otras herramientas" -ForegroundColor DarkGray
}

# symlinks de .claude/skills (por-máquina, no versionados; test funcional real)
if (Test-Path ".claude/skills/agentforce-generate/SKILL.md") {
    Write-Host "  OK    .claude/skills resuelve (Claude Code ve las skills)" -ForegroundColor Green
} else {
    Write-Host "  FALTA .claude/skills no resuelve (clon nuevo o enlaces rotos)" -ForegroundColor Red
    Write-Host "        pwsh tools/link-skills.ps1    <- lo arregla, no descarga nada" -ForegroundColor Yellow
    $issues += ".claude/skills no resuelve -> pwsh tools/link-skills.ps1"
}

Write-Host "`n=== C. Org ===" -ForegroundColor Cyan
try {
    $t = sf config get target-org --json 2>&1 | ConvertFrom-Json
    $val = $t.result[0].value
    if ($val) { Write-Host "  OK    target-org: $val" -ForegroundColor Green }
    else {
        Write-Host "  ---   sin target-org (esperable en un clon nuevo)" -ForegroundColor Yellow
        Write-Host "        sf org login web --alias <ALIAS>; sf config set target-org <ALIAS>" -ForegroundColor DarkGray
    }
} catch { Write-Host "  ---   no pude leer la config de org" -ForegroundColor Yellow }

Pop-Location

Write-Host "`n=========================================" -ForegroundColor Cyan
if ($issues.Count -eq 0) {
    Write-Host " Entorno listo. Siguiente: pegar templates/INICIAR.md en Claude Code." -ForegroundColor Green
} else {
    Write-Host " $($issues.Count) cosa(s) pendientes:" -ForegroundColor Yellow
    $issues | ForEach-Object { Write-Host "   - $_" -ForegroundColor Yellow }
}
Write-Host ""
