# agentforce-workspace

Plantilla **reutilizable y agnóstica de org** para trabajar cualquier cosa de Salesforce con
Claude Code como copiloto: agentes Agentforce, objetos, Flows, Apex, pantallas, permisos,
integraciones, Data Cloud.

No es un proyecto puntual. Es la fábrica: clonás, conectás una org, y trabajás.

```
                      ┌─ agentes  → .agent → validate → preview → publish → test → secure
idea → PRD aprobado ──┤
                      └─ general  → construir → tests → deploy acotado → verificar
```

## Si es tu primera vez

**En Windows, antes de clonar** (una sola vez por máquina):

```powershell
git config --global core.longpaths true
```

Sin eso el clon puede fallar a la mitad con `Filename too long` y dejarte una carpeta casi
vacía. Detalle y recuperación en [SETUP.md](SETUP.md).

Ya clonado, en orden:

1. `npm install` — herramientas de formato/lint del proyecto.
2. `pwsh tools/link-skills.ps1` — **imprescindible**: enlaza las skills para que Claude
   Code las vea. No descarga nada.
3. `pwsh tools/bootstrap.ps1` — te dice qué falta instalar y cómo (Node, Salesforce CLI,
   Claude Code, Python, el plugin de seguridad).
   *(Si no tenés `pwsh`, usá `powershell` — los scripts andan en las dos versiones.)*
4. Conectá una org: `sf org login web --alias <ALIAS>` (para una **sandbox** agregá
   `--instance-url https://test.salesforce.com`, ver [SETUP.md](SETUP.md) Parte C) y
   elegila con `pwsh tools/org.ps1 <ALIAS>`.
5. **Recién ahora** abrí Claude Code en esta carpeta. El orden importa: las skills se cargan
   al arrancar, así que si lo abrís antes del paso 2 no ve ninguna.
6. Pegá el prompt de **[templates/INICIAR.md](templates/INICIAR.md)**.
   Claude te guía por todo el resto — no necesitás saber programar. Al arrancar te va a
   ofrecer `/actualizar-entorno` para dejar las skills al día.

## Mapa del repo

| Qué | Dónde |
|---|---|
| Prompt de arranque (pegar y listo) | [templates/INICIAR.md](templates/INICIAR.md) |
| Instalación y conexión de org | [SETUP.md](SETUP.md) |
| Pipeline paso a paso (vía A: agentes · vía B: general) | [RUNBOOK.md](RUNBOOK.md) |
| Reglas que Claude lee solo (convenciones, ruteo de skills) | [CLAUDE.md](CLAUDE.md) |
| Comandos verificados con sus trampas | [docs/cli-cheatsheet.md](docs/cli-cheatsheet.md) |
| Por qué el repo está armado así | [docs/DECISIONS.md](docs/DECISIONS.md) |
| Meta-prompts de PRD (agente / general) | [templates/](templates/) |
| Un trabajo = una carpeta (PRD, bitácora, notas, tests) | [specs/](specs/) |
| Metadata deployable | `force-app/main/default/` |
| Skills oficiales de Salesforce (versionadas, lista en `skills-lock.json`) | `.agents/skills/` |

> `.claude/skills/` no es una copia: son accesos directos a `.agents/skills/` para que
> Claude Code las encuentre. Son por-máquina (gitignoreados), así que **un clon nuevo
> arranca sin ellos**: los crea `pwsh tools/link-skills.ps1`.

## Toolchain

- **[forcedotcom/sf-skills](https://github.com/forcedotcom/sf-skills)** — skills oficiales
  que cubren toda la plataforma (251 al 2026-10-05). Versionadas en `.agents/skills/`,
  pinneadas en `skills-lock.json`.
- **[agentforce-adlc](https://github.com/SalesforceAIResearch/agentforce-adlc)** — plugin de
  Claude Code. Se usa **solo** para la pasada de seguridad: `agentforce-adlc:agentforce-test`
  en Modo C (red team OWASP de agentes).
- **[Salesforce Docs MCP](https://labs.agentforce.com/docs/salesforce-docs-mcp)** — docs
  oficiales en tiempo real, para que Claude no alucine sintaxis.

⚠️ Las dos librerías exponen skills con **nombres idénticos**. El ruteo está resuelto en
[CLAUDE.md §2](CLAUDE.md). No instales ADLC por file-copy (`install.sh`) — rompe ese ruteo.

---

<details>
<summary>Referencia del proyecto Salesforce DX base</summary>

- `force-app/main/default/` — metadata source; más package directories en `sfdx-project.json`.
- `config/project-scratch-def.json` — definición de scratch org.
- `scripts/` — ejemplos de Apex anónimo y SOQL.
- Docs: [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/), [CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/)

</details>
