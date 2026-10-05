# DECISIONS.md — registro de decisiones de arquitectura

Por qué el repo está armado así. Si algo de acá cambia, actualizá el ADR en vez de borrarlo.

---

## ADR-1 — sf-skills a nivel proyecto y versionado en git

**Decisión:** las skills de `forcedotcom/sf-skills` viven en `.agents/skills/`, se commitean,
y quedan pinneadas por hash en `skills-lock.json` (94 al 2026-07-27; 251 al 2026-10-05,
versión 1.59.0 del repo original).

**Regla que se desprende:** `.agents/skills/` contiene **solo** skills de sf-skills. Nada de
un trabajo puntual se guarda ahí adentro: como la carpeta se commitea entera, cualquier
archivo de un trabajo terminaría en GitHub (choca con ADR-7). Ya pasó una vez y se
detectó antes de commitear (2026-10-05).

**Alternativa descartada:** instalación global (`npx skills -g`).

**Trade-off real:**

| | Proyecto + commiteado (elegido) | Global |
|---|---|---|
| Reproducibilidad | Clonás y tenés las versiones exactas | Cada máquina puede tener otra versión |
| Auto-update | ❌ manual, con `/actualizar-entorno` | ✅ automático |
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

**Decisión:** ver la tabla de ruteo en `CLAUDE.md` §2.

Namespacear resuelve la colisión de *archivos*, pero no la de *triggering*: ambas skills
describen "trabajar con archivos .agent" y las dos van a matchear. Sin una regla explícita,
la elección es no determinística. Por eso la regla vive en `CLAUDE.md`, que Claude lee siempre.

**Por qué sf-skills gana el rol primario** — evaluado leyendo el contenido real, no el README:

`agentforce-generate` de sf-skills trae 52 archivos de referencia (eran 24 en julio), entre ellos:

- `agent-metadata-and-lifecycle.md` — semántica exacta de deploy vs publish, con las trampas
- `production-gotchas.md` — tabla de consumo de créditos por operación
- `feature-validity.md` — matriz de qué propiedad funciona en qué contexto, con casos marcados
  explícitamente como "no testeado"
- `known-issues.md` — tracker de bugs **abiertos de plataforma** con workarounds
- 24 archivos `.agent` de ejemplo en `assets/agents/` y `assets/patterns/`

Ese nivel de especificidad verificada es difícil de igualar, y es la librería oficial de Salesforce.

**Qué aporta ADLC que sf-skills no tiene:**

- **Assessment OWASP LLM Top 10** sobre el agente vivo, con probes adversariales y grading
  A–F. Cuando se tomó esta decisión no tenía equivalente en sf-skills (ver la revisión del
  2026-10-05 más abajo). **Desde ADLC 0.11.0 no es una skill propia**: era
  `agentforce-secure` y ahora es el **Modo C** de `agentforce-adlc:agentforce-test`
  (C1 = suite deployable, C2 = red team en vivo). Verificado contra el plugin instalado el
  2026-08-19: `skills/` solo contiene `agentforce-generate`, `agentforce-observe` y
  `agentforce-test`.
- Hook `PostToolUse` que dispara review de seguridad en cada escritura de `.agent`.
- `scripts/discover.py` y `scripts/scaffold.py` como CLIs standalone.

**Revisión pendiente:** si en algún momento ADLC supera a sf-skills en profundidad de referencias,
invertir la tabla de ruteo. Chequear el `CHANGELOG.md` de ADLC cada tanto.

**Lección de la actualización a 0.11.0:** ADLC movió toda la seguridad adentro de
`agentforce-test` y borró `agentforce-secure`. El repo siguió mandando a una skill inexistente
hasta que se verificó contra el plugin instalado. **Al correr `/actualizar-entorno`, no alcanza
con `claude plugin update`: hay que mirar qué skills expone realmente el plugin** y ajustar la
tabla de ruteo de `CLAUDE.md` §2 si cambiaron.

**Revisión 2026-10-05 — sf-skills 1.59.0 también trae seguridad.** El `agentforce-test` de
sf-skills ahora incluye su propio **Modo C** (OWASP LLM Top 10, C1 = suite deployable,
C2 = red team en vivo con nota A–F; referencias `security-test-design.md`,
`owasp-categories.md`, `security-scoring-methodology.md`). Con eso, lo único que justificaba
ADLC pasó a tener equivalente en la librería primaria.

- **Decisión:** mantener ADLC para la pasada de seguridad, como hasta ahora. No se cambia un
  flujo que ya funciona.
- **Consecuencia:** hay dos skills `agentforce-test`, las dos con un "Modo C", y la de
  sf-skills dispara con las mismas palabras ("OWASP", "red team", "prompt injection"). Por
  eso `CLAUDE.md` §2 obliga a nombrar la de seguridad siempre con su prefijo completo:
  `agentforce-adlc:agentforce-test`.
- **Para reevaluar:** si ADLC deja de mantenerse o el Modo C de sf-skills lo supera, pasar
  la seguridad a sf-skills y dejar ADLC como opcional.

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

## ADR-6 — Alcance genérico: dos vías, dos PRDs, todas las skills de sf-skills

**Decisión:** el repo no es solo para agentes. sf-skills cubre toda la plataforma, así que el
pipeline tiene dos vías (`RUNBOOK.md`): **A** para agentes Agentforce, **B** para trabajo
general (objetos, Flows, Apex, LWC, permisos, integraciones). Cada vía tiene su meta-prompt de
PRD (`templates/prd-agente.md` / `templates/prd-general.md`) y su plantilla de carpeta en
`specs/`.

**Consecuencia:** se conservan todas las skills de sf-skills (94 en julio, 251 desde el
2026-10-05). Se descartó la idea de podarlas a las ~37 de agentes (hubo un script
`prune-skills.mjs`, eliminado): podar contradecía el alcance genérico. El costo es algo de
ruido de triggering entre skills; lo mitiga el ruteo explícito de `CLAUDE.md` §2.

Las skills que Salesforce **retira** del repo original también se borran acá al actualizar
(así se hizo el 2026-10-05 con las 7 `data360-*`, `experience-content-media-search` y
`platform-agentsetup-categories-fetch`): conservar copias congeladas daría skills que nadie
mantiene. Si hiciera falta una, está en el historial de git.

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

## ADR-8 — Bitácora append-only por trabajo

**Decisión:** todo trabajo lleva `specs/<Trabajo>/BITACORA.md`: un registro append-only con
una fila por cada acción que escribe en la org o cambia metadata deployable. La regla vive
en `CLAUDE.md` §5, o sea en el archivo que Claude lee siempre — no en un doc opcional.

**Problema que resuelve.** El repo es agnóstico de org y ADR-7 hace que el trabajo no se
commitee: no hay historial de git de lo que se construyó. Sin bitácora, la única evidencia
de qué se le hizo a una org queda en el scrollback de una sesión de Claude Code, que se
pierde. Tres consecuencias concretas: no se puede revertir, no se puede auditar, y quien
retome el trabajo (otra persona u otra sesión) arranca a ciegas.

**Por qué archivo y no solo hook.** Un hook `PostToolUse` no puede saber a qué trabajo
pertenece la acción: el path de destino depende de `specs/<Trabajo>/`, que cambia por
trabajo y no está en el entorno. Por eso el registro real es el archivo. **Implementado
como red de seguridad:** el hook de `.claude/settings.json` llama a `tools/log-sf.ps1`, que
anota crudo (timestamp + comando) cada `sf` que escribe en `.bitacora/comandos.log`
(gitignoreado), y Claude lo consolida en la bitácora del trabajo (`CLAUDE.md` §5).

**Por qué separado de `NOTES.md`.** Son dos cosas con reglas opuestas: la bitácora es
factual y no se edita nunca; NOTES es razonamiento y se corrige libremente. Mezclarlas hace
que el registro pierda la propiedad que lo vuelve confiable — que nadie lo reescribió.

**Columna "Reversión" obligatoria.** Es lo que separa un log de un registro útil. Obliga a
pensar el deshacer **antes** de ejecutar, y hace visible lo irreversible (borrar un campo
con datos, publicar una versión de agente) mientras todavía se puede frenar.

**Consecuencia:** la bitácora es local como todo el trabajo (ADR-7). Al cerrar, se va con
la carpeta a `_archive-trabajos/`. Es la pieza del archivo que más vale conservar.

---

## Resuelto (histórico)

### Carpeta `agent/` duplicada — ELIMINADA (2026-07-27)

El instalador de `npx skills` había generado **tres** ubicaciones:

| Carpeta | Qué era | Estado |
|---|---|---|
| `.agents/skills/` | Copia canónica (formato universal, trackeada por `skills-lock.json`) | ✅ se queda |
| `.claude/skills/` | Enlaces hacia `.agents/skills/` — 0 bytes, no son copias | ✅ se queda |
| `agent/skills/` | Copia real (22 MB) en formato adaptado para otras herramientas (Cursor/Codex) | ❌ eliminada |

Como este repo solo usa Claude Code, `agent/` era peso muerto. La generaba la opción `--all`
del instalador, que instala para **todos** los agentes: por eso `/actualizar-entorno` ahora
instala solo para Claude Code (`--agent claude-code`). Si algún día se trabaja con otra
herramienta de IA, `npx skills add forcedotcom/sf-skills --all` la regenera.

## Deuda técnica pendiente

### ~~1. Symlinks de `.claude/skills/` rotos o ausentes~~ — RESUELTO (2026-08-19)

`pwsh tools/link-skills.ps1` los recrea desde `.agents/skills/` usando *junctions* en
Windows: no requiere Modo Desarrollador ni re-descargar las skills. `bootstrap.ps1` verifica
que resuelvan y apunta al script si no.

### ~~2. Git no inicializado~~ — RESUELTO

Repo inicializado con remoto en GitHub. `.gitignore` no excluye `.agents/` ni
`skills-lock.json`.

### ~~3. `.mcp.json` pendiente de crear~~ — RESUELTO (2026-07-27)

Creado en la raíz con el servidor `salesforce-docs` (transporte HTTP, scope proyecto).
Commitearlo junto con el resto.

### 4. El cheatsheet cubre solo la vía A

`docs/cli-cheatsheet.md` es casi 100% de Agentforce. No hay comandos verificados de
vía B (objetos, campos, Apex, Flows, deploy general, borrado de metadata). Quien trabaje
metadata general depende de las skills de sf-skills, sin la capa de trampas verificadas que
sí tiene la vía A.

### 5. Arreglos de scripts detectados en la revisión del 2026-10-05 (pendientes)

Detectados al analizar el repo; no se tocaron para no cambiar lo que funciona sin un PR
propio:

- `tools/org.ps1` y `tools/bootstrap.ps1` etiquetan como **PRODUCCIÓN** toda org que no sea
  sandbox ni scratch, incluidas las Developer Edition (que `CLAUDE.md` §3.2 trata como flujo
  normal). Habría que mirar también `OrganizationType`.
- `tools/log-sf.ps1` descarta un comando si contiene en **cualquier parte** un patrón de solo
  lectura: `sf project deploy start ... && sf org display` no se registra. Además trata
  `sf agent preview` como solo lectura, pero con `--use-live-actions` ejecuta Flows reales
  que pueden escribir en la org.
- El hook de `.claude/settings.json` llama a `tools/log-sf.ps1` con ruta relativa: si la
  sesión cambia de carpeta, falla en silencio.
- `tools/link-skills.ps1` enlaza cualquier carpeta de `.agents/skills/`, aunque no tenga
  `SKILL.md`.
