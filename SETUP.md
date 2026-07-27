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

En orden, después de clonar:

1. `npm install` — instala las herramientas de formato/lint del proyecto (husky, prettier).
   Sin esto, los commits pueden fallar por los git hooks.
2. `pwsh tools/bootstrap.ps1` — te dice qué falta y verifica los symlinks de skills.
3. Abrí Claude Code en la carpeta y corré **`/actualizar-skills`** — deja las dos librerías
   al día y commitea el cambio.
4. Reiniciá Claude Code.

**Paso 3 no es opcional la primera vez, y repetilo siempre al arrancar un trabajo nuevo.**
sf-skills y ADLC evolucionan rápido (Agent Script es de 2025); trabajar con skills viejas
significa que Claude construye con sintaxis vieja. El prompt de `templates/INICIAR.md` ya
le pide a Claude que te lo ofrezca solo al arrancar.

Las skills de `forcedotcom/sf-skills` **ya vienen versionadas** en `.agents/skills/` y
pinneadas en `skills-lock.json` — el repo funciona clonado tal cual; el paso 3 solo las
refresca a la última.

### Para mantenerlas al día: `/actualizar-skills`

En Claude Code, escribí:

```
/actualizar-skills
```

Es un comando del repo (vive en `.claude/commands/actualizar-skills.md`) que hace todo el
ciclo: actualiza sf-skills **y** el plugin ADLC, te muestra qué cambió en lenguaje simple,
verifica que no se haya roto el ruteo anti-colisión, commitea, y te recuerda reiniciar
Claude Code. Corrélo cada tanto (una vez por semana o al arrancar un trabajo nuevo).

> **Por qué no es automático:** `npx skills update` solo trackea instalaciones globales
> (`-g`), no las de proyecto. Y mejor así: el comando te muestra el diff de
> `skills-lock.json` antes de commitear, en vez de que las skills cambien abajo de tus
> pies en medio de un trabajo.

> Las 94 skills se conservan completas a propósito: este repo sirve para **todo** tipo de
> trabajo Salesforce, no solo agentes. El instalador también genera symlinks en
> `.claude/skills/` (así las encuentra Claude Code) — no son copias, no las toques a mano.
> En Windows los symlinks requieren **Modo Desarrollador** activado.

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

```powershell
sf org login web --alias <ALIAS> 
sf org display user --json
```

Habilitar en Setup (una vez por org):

- Quick Find → **Einstein Setup** → activar
- Quick Find → **Agentforce Agents** → activar
- Data Cloud → necesario si vas a usar `agentforce-observe` (traces STDM) o retrievers
- `sf org assign permset --json --name EinsteinGPTPromptTemplateManager`

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

### Setear la org activa

```powershell
sf config set target-org <ALIAS>     # scope proyecto
sf config get target-org --json      # verificar
```

Todo el resto del repo asume que esto está seteado y **nunca** hardcodea el alias.

---

## Prueba de humo (hacela antes de encarar un agente real)

Objetivo: confirmar que CLI + skills + plugin + org funcionan **juntos**, no cada uno por
separado. Ver `RUNBOOK.md` vía A, etapa A0. Para trabajo general no hace falta prueba de
humo: el primer deploy acotado con `sf project deploy validate` cumple ese rol.
