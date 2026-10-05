---
description: Verifica y actualiza las 3 piezas del toolchain (sf-skills, plugin ADLC, MCP de docs) y commitea
---

Verificá y actualizá las TRES piezas del toolchain de este repo. Mostrame cada una por
separado y no encadenes: si algo falla, frená y explicámelo.

## 1. sf-skills (proyecto, versionadas)

- `git status --short` primero. Si hay cambios sin commitear que NO sean de skills,
  avisame y frená: no mezclemos.
- **Chequeo anti-filtración:** toda carpeta de `.agents/skills/` tiene que ser una skill
  (tener `SKILL.md` y figurar en `skills-lock.json`). Si hay algo más (archivos de un
  trabajo, versiones de `.agent`, diffs), **frená y avisame antes de seguir**: esa carpeta
  se commitea entera y eso terminaría en GitHub. Lo de un trabajo va en `specs/<Trabajo>/`.
- **Comparar contra el original:** `npx skills add forcedotcom/sf-skills -l` lista las
  skills del repo original sin instalar nada. Comparala con las carpetas de
  `.agents/skills/` y mostrame cuáles son **nuevas** y cuáles **retiró Salesforce**.
  Esperá mi OK antes de instalar.
- **Quitar las retiradas:** `npx skills remove -s <nombres> -y`. Ojo: esto borra las
  carpetas pero **no** las saca de `skills-lock.json` (se limpia más abajo).
- **Instalar solo para Claude Code:**
  `npx skills add forcedotcom/sf-skills --skill '*' --agent claude-code -y`.
  **Nunca `--all`**: instala para todos los agentes y vuelve a crear la carpeta `agent/`
  duplicada (`docs/DECISIONS.md`, histórico).
- **Dejar las skills en su lugar.** En Windows sin Modo Desarrollador el instalador no
  puede crear symlinks y deja **copias reales en `.claude/skills/`** en vez de actualizar
  `.agents/skills/`. Si pasa eso (las entradas de `.claude/skills/` son carpetas, no
  enlaces): por cada una, reemplazá `.agents/skills/<nombre>` con esa copia, vaciá
  `.claude/skills/` y corré `pwsh tools/link-skills.ps1` para recrear los enlaces.
- **Limpiar el lock:** sacá de `skills-lock.json` toda entrada sin carpeta en
  `.agents/skills/`, y verificá que toda carpeta tenga su entrada y que todas digan
  `"source": "forcedotcom/sf-skills"`.
- Verificá que las rutas que citan los docs del repo sigan existiendo (las de
  `.agents/skills/...` en `RUNBOOK.md`, `SETUP.md`, `CLAUDE.md` y `templates/`). Si alguna
  desapareció, proponeme la corrección.
- Mostrame `git diff --stat -- .agents/skills skills-lock.json` y resumime en lenguaje
  simple qué cambió, qué es nuevo y qué desapareció.
- Verificá que `.claude/skills/agentforce-generate/SKILL.md` sea legible. Si no, los
  enlaces están rotos o faltan (pasa siempre en un clon nuevo): arreglalo con
  `pwsh tools/link-skills.ps1`. No requiere Modo Desarrollador.

## 2. Plugin agentforce-adlc (global)

- `claude plugin list`
- Si NO está instalado:
  ```
  claude plugin marketplace add SalesforceAIResearch/agentforce-adlc
  claude plugin install agentforce-adlc@agentforce-adlc
  ```
  Requiere Python 3.9+ (`py --version`). Verificalo antes.
- Si SÍ está: `claude plugin update agentforce-adlc@agentforce-adlc`
- **Después de actualizar, listá qué skills expone realmente el plugin:**
  `ls ~/.claude/plugins/cache/agentforce-adlc/agentforce-adlc/<version>/skills`
  ADLC renombra y fusiona skills entre versiones (en 0.11.0 borró `agentforce-secure` y
  movió la seguridad al Modo C de `agentforce-test`). Si la lista no coincide con la tabla
  de ruteo de `CLAUDE.md` §2, avisame y proponé la corrección.
- **Nunca** uses `tools/install.sh` ni `install.py` de ese repo: copian
  `skills/agentforce-*` a `~/.claude/skills/` con los mismos nombres que las de proyecto
  y rompen el ruteo de CLAUDE.md §2.
- **Chequeo anti-colisión:** confirmá que NO exista ninguna carpeta `agentforce-*` dentro
  de `~/.claude/skills/`. Si existe, avisame antes de tocar nada.

## 3. MCP de docs de Salesforce

- Confirmá que `.mcp.json` existe en la raíz con el servidor `salesforce-docs`.
- Probalo de verdad: buscá en las docs "sf agent publish authoring-bundle" y mostrame que
  la herramienta `salesforce_docs_search` respondió con resultados.
- Si no responde, regenerá con:
  ```
  claude mcp add --transport http --scope project salesforce-docs https://salesforce-docs-76258744c9d7.herokuapp.com/api/mcp
  ```

## 4. Cierre

- Si el ruteo de skills cambió (nombres nuevos o renombrados), proponeme la corrección de
  la tabla de CLAUDE.md §2. Mirá también las descripciones de `agentforce-generate`,
  `agentforce-test` y `agentforce-observe` de sf-skills: si empezaron a cubrir algo que
  CLAUDE.md §2 asigna a ADLC (pasó en 1.59.0 con la seguridad), avisame.
- Pedime OK antes de commitear. Commiteá con `chore: actualizar toolchain <fecha>`
  agregando **por ruta explícita** solo `.agents/skills/` y `skills-lock.json`
  (nunca `git add .`). **No** incluyas `specs/` ni `aiAuthoringBundles/`: están
  gitignoreados a propósito.
- Recordame **reiniciar Claude Code** para que las skills nuevas se carguen.
