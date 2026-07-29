# DECISIONS.md — registro de decisiones de arquitectura

Por qué el repo está armado así. Si algo de acá cambia, actualizá el ADR en vez de borrarlo.

---

## ADR-1 — sf-skills a nivel proyecto y versionado en git

**Decisión:** las 94 skills de `forcedotcom/sf-skills` viven en `.agents/skills/`, se commitean,
y quedan pinneadas por hash en `skills-lock.json`.

**Alternativa descartada:** instalación global (`npx skills -g`).

**Trade-off real:**

| | Proyecto + commiteado (elegido) | Global |
|---|---|---|
| Reproducibilidad | Clonás y tenés las versiones exactas | Cada máquina puede tener otra versión |
| Auto-update | ❌ manual (`npx skills update` solo trackea globales) | ✅ automático |
| Peso del repo | ~decenas de MB | 0 |
| Onboarding de un compañero | `git clone` y listo | tiene que instalar aparte |

Para un repo **plantilla**, la reproducibilidad gana. Que el update sea manual es un costo
aceptable: te obliga a mirar el `git diff` de `skills-lock.json` antes de que las skills te
cambien abajo de los pies en medio de un proyecto de cliente.

**Consecuencia:** verificar que `.gitignore` **no** excluya `.agents/`. Confirmado que no lo hace.

---

## ADR-2 — agentforce-adlc como plugin, nunca file-copy

**Decisión:** instalar ADLC con `claude plugin marketplace add` + `claude plugin install`.
**Prohibido** usar `tools/install.sh` / `install.py`.

**Motivo — hay colisión directa de nombres.** `forcedotcom/sf-skills` ya trae skills llamadas:

- `agentforce-generate`
- `agentforce-test`
- `agentforce-observe`

que son **exactamente** los mismos nombres que expone agentforce-adlc.

- Instalación **plugin**: las skills quedan namespaceadas (`agentforce-adlc:agentforce-generate`).
  Conviven sin pisarse. ✅
- Instalación **file-copy**: copia `skills/agentforce-*` a `~/.claude/skills/` con los nombres
  pelados. Colisión con las de proyecto, ruteo impredecible. ❌

Beneficios secundarios del plugin: es self-contained (no ensucia `~/.claude/`), se actualiza con
`claude plugin update`, y el sistema de plugins cablea correctamente los `hooks/` y los 4
subagentes de ADLC — cosa que el file-copy hace a mano y frágilmente.

**Costo:** requiere Python 3.9+ en la máquina. Está documentado en `SETUP.md` Parte A.

---

## ADR-3 — sf-skills es la librería primaria; ADLC aporta solo la pasada de seguridad

**Decisión:** ver la tabla de ruteo en `CLAUDE.md` §1.

Namespacear resuelve la colisión de *archivos*, pero no la de *triggering*: ambas skills
describen "trabajar con archivos .agent" y las dos van a matchear. Sin una regla explícita,
la elección es no determinística. Por eso la regla vive en `CLAUDE.md`, que Claude lee siempre.

**Por qué sf-skills gana el rol primario** — evaluado leyendo el contenido real, no el README:

`agentforce-generate` de sf-skills trae 24 archivos de referencia, entre ellos:

- `agent-metadata-and-lifecycle.md` — semántica exacta de deploy vs publish, con las trampas
- `production-gotchas.md` — tabla de consumo de créditos por operación
- `feature-validity.md` — matriz de qué propiedad funciona en qué contexto, con casos marcados
  explícitamente como "no testeado"
- `known-issues.md` — tracker de bugs **abiertos de plataforma** con workarounds
- 19 archivos `.agent` de ejemplo en `assets/`

Ese nivel de especificidad verificada es difícil de igualar, y es la librería oficial de Salesforce.

**Qué aporta ADLC que sf-skills no tiene:**

- `agentforce-secure` — assessment OWASP LLM Top 10 sobre el agente vivo, con probes
  adversariales y grading LLM-as-judge (A–F). No tiene equivalente en sf-skills.
- Hook `PostToolUse` que dispara review de seguridad en cada escritura de `.agent`.
- `scripts/discover.py` y `scripts/scaffold.py` como CLIs standalone.

**Revisión pendiente:** si en algún momento ADLC supera a sf-skills en profundidad de referencias,
invertir la tabla de ruteo. Chequear el `CHANGELOG.md` de ADLC cada tanto.

---

## ADR-4 — Repo agnóstico de org

**Decisión:** ningún alias, ID de org, retriever ID, credencial ni dato de cliente entra al repo.

- La org se resuelve por `sf config set target-org <alias>` (scope proyecto, fuera de git) o
  por `--target-org` explícito.
- Los secretos van en `.env` (gitignoreado).
- El setup de org es **Parte C** de `SETUP.md`, deliberadamente separado de A y B.

Esto es lo que hace el repo clonable para el próximo cliente sin limpiar nada.

---

## ADR-5 — `specs/` separado de `force-app/`

`specs/<Trabajo>/` guarda el **pensamiento**: PRD, decisiones de diseño, casos de prueba,
notas. `force-app/main/default/` guarda el **artefacto** deployable.

Separarlos permite que el PRD evolucione en review sin tocar metadata deployable, y que el
diff de un cambio de comportamiento sea legible.

---

## ADR-6 — Alcance genérico: dos vías, dos PRDs, 94 skills completas

**Decisión:** el repo no es solo para agentes. sf-skills cubre toda la plataforma, así que el
pipeline tiene dos vías (`RUNBOOK.md`): **A** para agentes Agentforce, **B** para trabajo
general (objetos, Flows, Apex, LWC, permisos, integraciones). Cada vía tiene su meta-prompt de
PRD (`templates/prd-agente.md` / `templates/prd-general.md`) y su plantilla de carpeta en
`specs/`.

**Consecuencia:** se conservan las 94 skills completas. Se descartó la idea de podarlas a las
~37 de agentes (hubo un script `prune-skills.mjs`, eliminado): podar contradecía el alcance
genérico. El costo es algo de ruido de triggering entre skills; lo mitiga el ruteo explícito
de `CLAUDE.md` §2.

**Punto de entrada único:** `templates/INICIAR.md` — un prompt que un usuario sin conocimientos
de código pega en Claude Code, y que clasifica el trabajo, elige el meta-prompt y arranca el
pipeline correcto.

---

## ADR-7 — Este repo nunca es el destino del trabajo

**Decisión:** ningún trabajo puntual (specs, agentes, Apex, Flows, objetos, seeds) se
commitea en este repo. Sin excepciones.

El repo es el **entorno de desarrollo**: pipeline, skills, plantillas, convenciones. El
destino de lo que se construye es **la org de Salesforce** (vía deploy/publish). El
pensamiento (`specs/<Trabajo>/`) y el artefacto (`force-app/`) viven solo en la máquina
mientras se trabaja, y al terminar se mueven a `_archive-trabajos/` (gitignoreada) o se
borran.

El `.gitignore` fuerza esta regla: `specs/*` (salvo plantillas), `force-app/main/default/*`,
scripts ad-hoc y `_archive-trabajos/`. Así, clonar el repo da siempre una plantilla limpia,
y ningún dato de un cliente puede filtrarse a GitHub por accidente.

**Validación:** el pipeline completo (vía A: 3 comandos, backing logic, preview con
acciones vivas) fue verificado de punta a punta en una org real el 29/07/2026. El informe
de esa sesión, con sus hallazgos y limitaciones de entorno, quedó en el archivo del
trabajo correspondiente — no acá, porque es historia de un desarrollo, no una decisión
del repo.

---

## Resuelto (histórico)

### Carpeta `agent/` duplicada — ELIMINADA (2026-07-27)

El instalador de `npx skills` había generado **tres** ubicaciones:

| Carpeta | Qué era | Estado |
|---|---|---|
| `.agents/skills/` | Copia canónica (formato universal, trackeada por `skills-lock.json`) | ✅ se queda |
| `.claude/skills/` | 94 symlinks hacia `.agents/skills/` — 0 bytes, no son copias | ✅ se queda |
| `agent/skills/` | Copia real (22 MB) en formato adaptado para otras herramientas (Cursor/Codex) | ❌ eliminada |

Como este repo solo usa Claude Code, `agent/` era peso muerto. Si algún día se trabaja con
otra herramienta de IA, `npx skills forcedotcom/sf-skills --all` la regenera.

## Deuda técnica pendiente

### 1. Symlinks de `.claude/skills/` no verificables desde el sandbox

Dan `Input/output error` leídos desde Linux; puede ser un artefacto del mount de Windows.
**Acción:** `pwsh tools/bootstrap.ps1` en Windows los chequea. Si están rotos: activar Modo
Desarrollador y re-correr `npx skills forcedotcom/sf-skills --all`.

### 2. Git no inicializado

`git init; git add .; git commit -m "setup inicial del workspace"`. Verificado que
`.gitignore` no excluye `.agents/` ni `skills-lock.json`.

### ~~3. `.mcp.json` pendiente de crear~~ — RESUELTO (2026-07-27)

Creado en la raíz con el servidor `salesforce-docs` (transporte HTTP, scope proyecto).
Commitearlo junto con el resto.
