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
        Write-Host "  FALTA plugin agentforce-adlc" -ForegroundColor Red
        Write-Host "        claude plugin marketplace add SalesforceAIResearch/agentforce-adlc" -ForegroundColor Yellow
        Write-Host "        claude plugin install agentforce-adlc@agentforce-adlc" -ForegroundColor Yellow
        $issues += "plugin agentforce-adlc"
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

# duplicado agent/ (no debería existir — se eliminó, ver docs/DECISIONS.md)
if (Test-Path "agent/skills") {
    Write-Host "  WARN  reapareció agent/skills/ (copia redundante de .agents/skills/)" -ForegroundColor Yellow
    Write-Host "        es seguro borrarla; la genera npx skills para otras herramientas" -ForegroundColor DarkGray
}

# symlinks de .claude/skills (por-máquina, no versionados; test funcional real)
if (Test-Path ".claude/skills/agentforce-generate/SKILL.md") {
    Write-Host "  OK    .claude/skills resuelve (Claude Code ve las skills)" -ForegroundColor Green
} else {
    Write-Host "  FALTA .claude/skills no resuelve (clon nuevo o symlinks rotos)" -ForegroundColor Red
    Write-Host "        activá Modo Desarrollador en Windows y corré: npx skills forcedotcom/sf-skills --all" -ForegroundColor Yellow
    Write-Host "        (o /actualizar-entorno desde Claude Code)" -ForegroundColor Yellow
    $issues += ".claude/skills no resuelve -> npx skills forcedotcom/sf-skills --all"
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
