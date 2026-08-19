---
description: Verifica y actualiza las 3 piezas del toolchain (sf-skills, plugin ADLC, MCP de docs) y commitea
---

Verificá y actualizá las TRES piezas del toolchain de este repo. Mostrame cada una por
separado y no encadenes: si algo falla, frená y explicámelo.

## 1. sf-skills (proyecto, versionadas)

- `git status --short` primero. Si hay cambios sin commitear que NO sean de skills,
  avisame y frená: no mezclemos.
- `npx skills forcedotcom/sf-skills --all`
- Mostrame `git diff --stat skills-lock.json` y resumime en lenguaje simple qué cambió,
  qué es nuevo y qué desapareció.
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
  la tabla de CLAUDE.md §2.
- Commiteá con `chore: actualizar toolchain <fecha>` incluyendo `.agents/skills/` y
  `skills-lock.json`. **No** incluyas `specs/` ni `aiAuthoringBundles/`: están gitignoreados
  a propósito.
- Recordame **reiniciar Claude Code** para que las skills nuevas se carguen.
