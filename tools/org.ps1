# org.ps1 — ver y cambiar la org activa sabiendo SIEMPRE de que tipo es.
#
#   pwsh tools/org.ps1            -> lista las orgs conectadas con su tipo
#   pwsh tools/org.ps1 <ALIAS>    -> la deja como org activa del proyecto (scope local)
#   pwsh tools/org.ps1 -Clear     -> el proyecto deja de fijar org (vuelve a tu default)
#
# Existe porque el alias no dice nada: "dev-cliente" puede ser produccion. Esta es la
# Puerta 3 de CLAUDE.md 3.2 hecha herramienta. No hardcodea ninguna org (ADR-4).

param([string]$Alias, [switch]$Clear)

$ErrorActionPreference = "Stop"

function Get-Orgs {
    $raw = sf org list --json 2>$null | ConvertFrom-Json
    $vistos = @{}
    $out = @()
    foreach ($grupo in $raw.result.PSObject.Properties) {
        if ($grupo.Value -isnot [Array]) { continue }
        foreach ($o in $grupo.Value) {
            if (-not $o.username -or $vistos.ContainsKey($o.username)) { continue }
            $vistos[$o.username] = $true
            $tipo = if ($o.isScratch) { "scratch" } elseif ($o.isSandbox) { "sandbox" } else { "PRODUCCION" }
            $out += [pscustomobject]@{
                Alias = $(if ($o.alias) { $o.alias } else { "(sin alias)" })
                Tipo = $tipo; Edicion = $o.orgEdition; Default = [bool]$o.isDefaultUsername
                Usuario = $o.username
            }
        }
    }
    return $out
}

function Get-Activa {
    # 'sf config get' dice el valor Y el scope: Local = lo fijo este proyecto,
    # Global = es tu default de siempre. La diferencia importa.
    try {
        $c = sf config get target-org --json 2>$null | ConvertFrom-Json
        $r = $c.result[0]
        if ($r.value) { return [pscustomobject]@{ Alias = $r.value; Scope = $r.location } }
    } catch { }
    return $null
}

$orgs = Get-Orgs
if (-not $orgs) { Write-Host "No hay orgs conectadas. Ver SETUP.md Parte C." -ForegroundColor Yellow; exit 1 }

if ($Clear) {
    sf config unset target-org --json | Out-Null
    Write-Host "`n  Este proyecto ya no fija ninguna org." -ForegroundColor Green
    $a = Get-Activa
    if ($a) { Write-Host "  Queda tu default $($a.Scope.ToLower()): $($a.Alias)" -ForegroundColor DarkGray }
    else    { Write-Host "  No hay ninguna org activa: elegila con pwsh tools/org.ps1 <ALIAS>" -ForegroundColor Yellow }
    Write-Host ""
    exit 0
}

if (-not $Alias) {
    Write-Host "`n  Orgs conectadas`n" -ForegroundColor Cyan
    foreach ($o in ($orgs | Sort-Object Tipo, Alias)) {
        $marca = if ($o.Default) { "->" } else { "  " }
        $color = if ($o.Tipo -eq "PRODUCCION") { "Red" } else { "Green" }
        Write-Host ("  {0} {1,-22}" -f $marca, $o.Alias) -NoNewline
        Write-Host ("{0,-12}" -f $o.Tipo) -ForegroundColor $color -NoNewline
        Write-Host ("{0}" -f $o.Edicion) -ForegroundColor DarkGray
    }
    $a = Get-Activa
    Write-Host ""
    if (-not $a) {
        Write-Host "  No hay org activa. Elegila: pwsh tools/org.ps1 <ALIAS>" -ForegroundColor Yellow
        Write-Host ""; exit 0
    }
    $act = $orgs | Where-Object { $_.Alias -eq $a.Alias }
    $origen = if ($a.Scope -eq "Local") { "la fijo este proyecto" } else { "tu default global, este proyecto no fija ninguna" }
    if ($act -and $act.Tipo -eq "PRODUCCION") {
        Write-Host "  ATENCION: la org activa ($($a.Alias)) es PRODUCCION." -ForegroundColor Red
        Write-Host "  Origen: $origen" -ForegroundColor DarkGray
        Write-Host "  Cambiala con: pwsh tools/org.ps1 <ALIAS>" -ForegroundColor Yellow
    } else {
        $t = if ($act) { $act.Tipo } else { "?" }
        Write-Host "  Org activa: $($a.Alias) ($t) - se puede trabajar normal." -ForegroundColor Green
        Write-Host "  Origen: $origen" -ForegroundColor DarkGray
    }
    Write-Host "  Al arrancar un trabajo, fijala con: pwsh tools/org.ps1 <ALIAS>" -ForegroundColor DarkGray
    Write-Host ""
    exit 0
}

$elegida = $orgs | Where-Object { $_.Alias -eq $Alias }
if (-not $elegida) {
    Write-Host "`n  No existe una org conectada con alias '$Alias'." -ForegroundColor Red
    Write-Host "  Conectadas: $(($orgs.Alias) -join ', ')" -ForegroundColor Yellow
    Write-Host "  Para conectar una nueva, ver SETUP.md Parte C.`n" -ForegroundColor DarkGray
    exit 1
}

sf config set target-org $Alias --json | Out-Null

# confirmacion autoritativa contra la org (el archivo de auth puede estar viejo)
$tipo = $elegida.Tipo
try {
    $q = sf data query --json -q "SELECT IsSandbox, OrganizationType FROM Organization" -o $Alias 2>$null | ConvertFrom-Json
    $rec = $q.result.records[0]
    if ($null -ne $rec.IsSandbox) { $tipo = if ($rec.IsSandbox) { "sandbox" } else { "PRODUCCION" } }
} catch { }

Write-Host ""
if ($tipo -eq "PRODUCCION") {
    Write-Host "  Org activa: $Alias" -ForegroundColor White
    Write-Host "  Tipo: PRODUCCION" -ForegroundColor Red
    Write-Host "  Cada deploy necesita OK explicito. Backup antes de pisar. Nada de datos de prueba." -ForegroundColor Yellow
    Write-Host "  Reglas: CLAUDE.md 3.2 (Puerta 3) y 3.3 (rollback)." -ForegroundColor DarkGray
} else {
    Write-Host "  Org activa: $Alias" -ForegroundColor White
    Write-Host "  Tipo: $tipo — flujo normal." -ForegroundColor Green
}
Write-Host "  Anotalo en la cabecera de specs/<Trabajo>/BITACORA.md.`n" -ForegroundColor DarkGray
