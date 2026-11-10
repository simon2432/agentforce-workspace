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

# Python: los hooks de ADLC llaman a `python3`, no a `py`. En Windows `python3` suele ser el
# atajo de la Microsoft Store: el comando existe pero responde "Python was not found", y
# los hooks fallan en silencio. Por eso se prueba python3 de verdad (salida + exit code).
function Get-PyVersion($exe) {
    try {
        $out = (& $exe --version 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -eq 0 -and $out -match '^Python 3\.(\d+)') { return $out }
    } catch { }
    return $null
}
$py3 = Get-PyVersion "python3"
if ($py3 -and ($py3 -match '^Python 3\.(\d+)') -and [int]$Matches[1] -ge 9) {
    Write-Host ("  OK    {0,-22} {1}" -f "Python (python3)", $py3) -ForegroundColor Green
} elseif ($py3) {
    Write-Host "  FALTA Python 3.9+            -> python3 es $py3; el plugin agentforce-adlc pide 3.9+" -ForegroundColor Red
    $issues += "Python 3.9+ : https://www.python.org/downloads/"
} elseif (Get-PyVersion "py") {
    Write-Host "  FALTA python3                -> Python esta instalado ('py' anda) pero 'python3' no responde" -ForegroundColor Red
    Write-Host "        Los hooks de ADLC llaman a python3. En Windows suele ser el atajo de la" -ForegroundColor Yellow
    Write-Host "        Microsoft Store: ver SETUP.md Parte A, nota de Windows." -ForegroundColor Yellow
    $issues += "python3 no responde (lo usan los hooks de ADLC) -> SETUP.md Parte A"
} else {
    Write-Host "  FALTA Python                 -> 3.9+ invocable como python3, requerido por el plugin agentforce-adlc" -ForegroundColor Red
    $issues += "Python 3.9+ : https://www.python.org/downloads/"
}

Write-Host "`n=== Plugin agentforce-adlc ===" -ForegroundColor Cyan
try {
    $plugins = claude plugin list 2>&1 | Out-String
    if ($plugins -match "agentforce-adlc@salesforce") {
        Write-Host "  OK    plugin instalado (marketplace oficial de Salesforce)" -ForegroundColor Green
    } elseif ($plugins -match "agentforce-adlc@agentforce-adlc") {
        # Fuente vieja (SalesforceAIResearch/agentforce-adlc, congelada en 0.12.0): 'update'
        # no llega a las versiones del marketplace oficial. Ver docs/DECISIONS.md ADR-2.
        Write-Host "  WARN  plugin agentforce-adlc instalado desde la FUENTE VIEJA (congelada)" -ForegroundColor Yellow
        Write-Host "        Migrar (se llaman igual: primero sacar la vieja):" -ForegroundColor Yellow
        Write-Host "        claude plugin uninstall agentforce-adlc@agentforce-adlc" -ForegroundColor Yellow
        Write-Host "        claude plugin marketplace remove agentforce-adlc" -ForegroundColor Yellow
        Write-Host "        claude plugin marketplace add forcedotcom/sf-skills" -ForegroundColor Yellow
        Write-Host "        claude plugin install agentforce-adlc@salesforce" -ForegroundColor Yellow
        $issues += "plugin agentforce-adlc desde la fuente vieja -> migrar (SETUP.md Parte A)"
    } else {
        # Distinguimos los dos estados: son DOS pasos y es facil quedarse en el primero.
        # Agregar el marketplace deja carpetas en ~/.claude/plugins/ que hacen parecer que
        # esta instalado, pero installed_plugins.json sigue vacio.
        $mk = Join-Path $env:USERPROFILE ".claude/plugins/known_marketplaces.json"
        $mkAdded = (Test-Path $mk) -and ((Get-Content $mk -Raw) -match "forcedotcom/sf-skills")

        if ($mkAdded) {
            Write-Host "  FALTA plugin agentforce-adlc NO instalado (el marketplace si esta agregado)" -ForegroundColor Red
            Write-Host "        Te falta solo el segundo paso:" -ForegroundColor Yellow
            Write-Host "        claude plugin install agentforce-adlc@salesforce" -ForegroundColor Yellow
        } else {
            Write-Host "  FALTA plugin agentforce-adlc (faltan los dos pasos)" -ForegroundColor Red
            Write-Host "        claude plugin marketplace add forcedotcom/sf-skills" -ForegroundColor Yellow
            Write-Host "        claude plugin install agentforce-adlc@salesforce" -ForegroundColor Yellow
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
    Write-Host "  FALTA .agents/skills -> clon incompleto: git restore --source=HEAD :/ (ver SETUP.md)" -ForegroundColor Red
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
# Si skills-lock.json tiene cambios sin commitear, hay una actualizacion de skills en curso
# (/actualizar-entorno): los borrados son skills retiradas, no un clon roto. En ese caso
# NO hay que sugerir 'git restore', que desharia la actualizacion entera.
$lockCambiado = @(git status --porcelain -- skills-lock.json 2>$null).Count -gt 0
if ($deleted.Count -gt 0 -and $lockCambiado) {
    Write-Host "  WARN  actualizacion de skills sin commitear ($($deleted.Count) archivo(s) borrados a proposito)" -ForegroundColor Yellow
    Write-Host "        Terminala con /actualizar-entorno y commitea. NO corras 'git restore': la deshace." -ForegroundColor DarkGray
} elseif ($deleted.Count -gt 0) {
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

# hook de bitacora (CLAUDE.md 5): settings.json + script
if ((Test-Path ".claude/settings.json") -and (Test-Path "tools/log-sf.ps1")) {
    Write-Host "  OK    hook de bitacora cableado" -ForegroundColor Green
} else {
    Write-Host "  FALTA hook de bitacora (.claude/settings.json / tools/log-sf.ps1)" -ForegroundColor Red
    Write-Host "        sin el, los comandos sf no quedan registrados automaticamente" -ForegroundColor Yellow
    $issues += "hook de bitacora ausente"
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
    if ($val) {
        # el alias no dice el tipo: lo resolvemos contra el registro de auth
        $tipo = "?"
        try {
            $lst = sf org list --json 2>$null | ConvertFrom-Json
            foreach ($g in $lst.result.PSObject.Properties) {
                if ($g.Value -isnot [Array]) { continue }
                foreach ($o in $g.Value) {
                    if ($o.alias -eq $val) {
                        $tipo = if ($o.isScratch) { "scratch" } elseif ($o.isSandbox) { "sandbox" } else { "PRODUCCION" }
                    }
                }
            }
        } catch { }
        if ($tipo -eq "PRODUCCION") {
            Write-Host "  OK    target-org: $val" -ForegroundColor Green
            Write-Host "  AVISO esa org es PRODUCCION -> pwsh tools/org.ps1 para cambiarla" -ForegroundColor Red
        } else {
            Write-Host "  OK    target-org: $val ($tipo)" -ForegroundColor Green
        }
    }
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
