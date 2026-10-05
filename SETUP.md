# SETUP.md — poner una máquina nueva a punto

Este repo es **agnóstico de org**. El setup se divide en dos:

- **Parte A — por máquina (una sola vez):** herramientas globales. No vive en el repo.
- **Parte B — por clon del repo:** skills de proyecto y MCP. Ya viene versionado.
- **Parte C — por org:** conectar la org donde vas a trabajar. Se repite por cada cliente.

Atajo: `pwsh tools/bootstrap.ps1` chequea A y B y te dice qué falta.

---

## Parte A — Por máquina (una vez)

| Requisito | Verificar | Instalar / actualizar |
|---|---|---|
| PowerShell | `pwsh -v` o `powershell -v` | Ya viene con Windows (5.1). Los scripts del repo andan en 5.1 y en 7; si `pwsh` no existe, usá `powershell`. |
| Node.js 20+ | `node -v` | https://nodejs.org (LTS) |
| Salesforce CLI 2.x | `sf --version` | `npm install -g @salesforce/cli` · actualizar: `sf update` |
| Claude Code | `claude --version` | `npm install -g @anthropic-ai/claude-code` |
| **Python 3.9+** | `python3 --version` (Windows: `py --version`) | https://www.python.org/downloads/ — **requisito del plugin ADLC** |
| Extensión Agent Script (VS Code) | Marketplace → "Agent Script" | Publicada por Salesforce (repo `salesforce/agentscript`) |

> La extensión de VS Code no es opcional en la práctica: te da diagnostics en vivo sobre `.agent`.
> Sin ella editás a ciegas y descubrís los errores recién en `sf agent validate`.

### Plugin agentforce-adlc

```powershell
claude plugin marketplace add SalesforceAIResearch/agentforce-adlc
claude plugin install agentforce-adlc@agentforce-adlc
```

Verificar: `claude plugin list`
Actualizar: `claude plugin update agentforce-adlc@agentforce-adlc`

**No uses** `tools/install.sh` de ese repo. Ver `docs/DECISIONS.md` §2.

Reiniciá Claude Code después de instalar — las skills se cargan al arranque.

---

## Parte B — Por clon del repo

### Paso 0 — ANTES de clonar (solo Windows, una vez por máquina)

```powershell
git config --global core.longpaths true
```

**No es opcional.** Las skills versionadas incluyen rutas de hasta 169 caracteres. Windows
corta en 260, así que si clonás en una carpeta con ruta larga (típico:
`OneDrive - Empresa\Escritorio\...`) el checkout **falla a la mitad** y te deja una carpeta
casi vacía con este mensaje:

```
error: unable to create file .agents/skills/...: Filename too long
warning: Clone succeeded, but checkout failed.
```

Si ya te pasó, no hace falta volver a clonar — ver *"Recuperar un clon incompleto"* abajo.

### Después de clonar, en orden

1. `npm install` — herramientas de formato/lint del proyecto (husky, prettier).
   Sin esto, los commits pueden fallar por los git hooks.
2. **`pwsh tools/link-skills.ps1`** — crea los enlaces de `.claude/skills/` hacia las skills
   ya versionadas en `.agents/skills/`. **Sin este paso Claude Code no ve ninguna skill.**
   No descarga nada y no requiere Modo Desarrollador (usa *junctions* en Windows).
3. `pwsh tools/bootstrap.ps1` — te dice qué más falta y verifica que todo resuelva.
4. Reiniciá Claude Code (las skills se cargan al arranque).
5. Ya con el entorno andando: **`/actualizar-entorno`** desde Claude Code, para llevar las
   dos librerías a la última y commitear el cambio.

**Paso 5 no es opcional la primera vez, y repetilo siempre al arrancar un trabajo nuevo.**
sf-skills y ADLC evolucionan rápido (Agent Script es de 2025); trabajar con skills viejas
significa que Claude construye con sintaxis vieja. El prompt de `templates/INICIAR.md` ya
le pide a Claude que te lo ofrezca solo al arrancar.

Las skills de `forcedotcom/sf-skills` **ya vienen versionadas** en `.agents/skills/` y
pinneadas en `skills-lock.json`: el clon trae el contenido completo y el paso 2 solo lo hace
visible para Claude Code. El paso 5 lo refresca a la última.

### Por qué hace falta el paso 2

Las skills viven una sola vez en `.agents/skills/` (versionadas). Claude Code las busca en
`.claude/skills/`, que son **enlaces**, no copias — y los enlaces son por máquina, así que
están gitignoreados: un symlink clonado en Windows sin `core.symlinks` queda como un archivo
de texto roto. `link-skills.ps1` los rehace. Es idempotente: corrélo las veces que quieras.

### Recuperar un clon incompleto

Si `pwsh tools/bootstrap.ps1` dice **"clon incompleto"**, o el clon falló con
`Filename too long`:

```powershell
git config --global core.longpaths true
git restore --source=HEAD :/
git reset
```

Verificá con `git status` — tiene que quedar limpio. Después seguí con el paso 1.

### Para mantener el toolchain al día: `/actualizar-entorno`

En Claude Code, escribí:

```
/actualizar-entorno
```

Es un comando del repo (vive en `.claude/commands/actualizar-entorno.md`) que verifica y
actualiza **las tres piezas**: sf-skills, el plugin ADLC y el MCP de docs. Te muestra qué
cambió en lenguaje simple, verifica que no se haya roto el ruteo anti-colisión, commitea y
te recuerda reiniciar Claude Code.

**Corrélo al arrancar cada trabajo nuevo.** El prompt de `templates/INICIAR.md` ya hace que
Claude te lo ofrezca solo. Agent Script cambia rápido: con skills viejas, Claude escribe
sintaxis que ya no compila.

> **Por qué no es automático:** a propósito. El comando te muestra el diff de
> `skills-lock.json` antes de commitear, en vez de que las skills cambien abajo de tus
> pies en medio de un trabajo. (Las versiones recientes del CLI de skills traen
> `npx skills update -p` para skills de proyecto, pero el repo no lo usa: el flujo probado
> es el de `/actualizar-entorno`, que además limpia las skills que Salesforce retira.)

> Las skills se conservan completas a propósito (251 al 2026-10-05): este repo sirve para
> **todo** tipo de trabajo Salesforce, no solo agentes.
>
> **Ojo con el instalador en Windows:** sin Modo Desarrollador no puede crear symlinks, así
> que en vez de actualizar `.agents/skills/` deja **copias** en `.claude/skills/`. Por eso
> `/actualizar-entorno` mueve esas copias a `.agents/skills/` y después recrea los enlaces
> con `link-skills.ps1`. No lo hagas a mano salteando ese paso: las skills se verían
> actualizadas en Claude Code pero el repo seguiría con las viejas.

### MCP de docs de Salesforce

Da acceso a las docs oficiales de Salesforce en tiempo real (`salesforce_docs_search` /
`salesforce_docs_fetch`). Sin esto, Claude alucina sintaxis de Agent Script.

**Ya está configurado**: `.mcp.json` existe en la raíz del repo (scope proyecto). Claude Code
lo detecta solo al abrir la carpeta y te pide aprobar el servidor la primera vez — decile que sí.
Está commiteado, así que todo el que clone el repo lo hereda sin hacer nada.

Si alguna vez se pierde, se regenera con:

```powershell
claude mcp add --transport http --scope project salesforce-docs https://salesforce-docs-76258744c9d7.herokuapp.com/api/mcp
```

(o copiando `docs/mcp.json.example` a `.mcp.json`).

> La URL sale del endpoint que expone Agentforce Labs. Si en algún momento falla, verificá
> contra la pestaña **Install** de https://labs.agentforce.com/docs/salesforce-docs-mcp
> (esa sección se renderiza por JavaScript y no se puede leer desde un fetch plano).

Verificar que anda — pedile a Claude:
> Buscá en las docs de Salesforce "sf agent publish authoring-bundle"

Esperado: llama a `salesforce_docs_search` y devuelve extractos con URL y score.

---

## Parte C — Por org (se repite por cada cliente/proyecto)

Nada de esto se commitea. Son credenciales de máquina.

### Opción 1 — Org propia (dev, sandbox, cliente)

**El comando NO es el mismo para sandbox que para producción.** `sfdx-project.json` declara
`sfdcLoginUrl: https://login.salesforce.com`, así que `sf org login web` a secas te manda
**siempre a producción**. Para una sandbox hay que pasar `--instance-url`, que pisa ese valor:

```powershell
# SANDBOX (lo habitual acá)
sf org login web --alias <ALIAS> --instance-url https://test.salesforce.com
# o con My Domain, que es lo que recomienda Salesforce:
sf org login web --alias <ALIAS> `
    --instance-url https://<MyDomain>--<NombreSandbox>.sandbox.my.salesforce.com

# PRODUCCIÓN
sf org login web --alias <ALIAS>

# verificar quién quedó logueado
sf org display user --json
```

> El usuario de una sandbox es `tuusuario@dominio.com.<NombreSandbox>` — el sufijo va
> incluido. Si lo escribís sin sufijo, el login falla y parece un problema de contraseña.

**Poné en el alias de qué tipo es** (`<cliente>-uat`, `<cliente>-dev`, `<cliente>-PROD`) para
no adivinar después.
Igual nunca confíes solo en el nombre: verificá con `pwsh tools/org.ps1`.

Habilitar en Setup (una vez por org):

- Quick Find → **Einstein Setup** → activar
- Quick Find → **Agentforce Agents** → activar
- Data Cloud → necesario si vas a usar `agentforce-observe` (traces STDM) o retrievers
- `sf org assign permset --json --name EinsteinGPTPromptTemplateManager`
- Feature de **Agent Testing / `AiEvaluationDefinition`** habilitada — verificalo con el
  admin de la org o Salesforce (no encontramos la ruta exacta de Setup, no la inventamos).
  Sin esto, `sf agent test create` falla con `"Not available for deploy for this
  organization"` — no es un error del repo ni del test spec.

Además hace falta un **Agent User** con licencia. Ver
`.agents/skills/agentforce-generate/references/agent-user-setup.md` — es un paso que
se olvida y hace fallar el `publish` con un error poco claro.

### Opción 2 — LabBox de Agentforce Labs (para probar el toolchain)

Org descartable ya preconfigurada (Einstein + Agentforce + Data Cloud + messaging habilitados),
con login por device flow. Sirve para validar que el pipeline funciona sin pelearte con Setup.

Pedile a Claude Code:
> Provisioname un LabBox siguiendo el device flow de https://labs.agentforce.com/llms.txt
> y logueá el SF CLI con alias `labbox` (sin `--set-default`).

Tiene fecha de expiración (`expires_at`). **No la uses para trabajo de cliente.**

### Setear la org activa — usá `tools/org.ps1`

```powershell
pwsh tools/org.ps1              # lista las orgs conectadas CON SU TIPO y marca la activa
pwsh tools/org.ps1 <ALIAS>      # la deja activa (scope proyecto) y te confirma qué tipo es
pwsh tools/org.ps1 -Clear       # el proyecto deja de fijar org (al cerrar un trabajo)
```

Al cambiar de org, el script consulta la org de verdad
(`SELECT IsSandbox FROM Organization`) en vez de confiar en el alias, y si es **producción**
te lo dice en rojo con las reglas que aplican. Es la Puerta 3 de `CLAUDE.md` §3.2 hecha
herramienta.

Equivalente a mano, si preferís:

```powershell
sf config set target-org <ALIAS>     # scope proyecto (queda en .sf/, gitignoreado)
sf config get target-org --json      # verificar
```

Trabajar con varias orgs a la vez es normal: el scope es **por proyecto**, así que cada
carpeta clonada puede apuntar a un cliente distinto. Todo el resto del repo lee la org
activa y **nunca** hardcodea el alias (ADR-4). Para una acción puntual contra otra org sin
cambiar la activa, pasá `-o <ALIAS>` en ese comando.

---

## Prueba de humo (hacela antes de encarar un agente real)

Objetivo: confirmar que CLI + skills + plugin + org funcionan **juntos**, no cada uno por
separado. Ver `RUNBOOK.md` vía A, etapa A0. Para trabajo general no hace falta prueba de
humo: el primer deploy acotado con `sf project deploy validate` cumple ese rol.
