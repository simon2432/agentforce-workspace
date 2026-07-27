# CLAUDE.md — agentforce-workspace

Repo plantilla, **agnóstico de org**, para todo tipo de trabajo Salesforce asistido por IA:
agentes Agentforce, objetos, Flows, Apex, LWC, permisos, integraciones, Data Cloud.
Nada acá adentro debe hardcodear un alias de org, un ID de retriever ni un dato de cliente.

El usuario puede no saber programar. Explicá en lenguaje simple, avanzá etapa por etapa,
y mostrá el resultado de cada etapa antes de seguir.

---

## 0. Los dos tipos de trabajo

Todo trabajo arranca con un PRD y una carpeta en `specs/`:

| Tipo | Meta-prompt | Plantilla de carpeta | Pipeline |
|---|---|---|---|
| **Agente Agentforce** (`.agent`, Agent Script) | `templates/prd-agente.md` | `specs/_TEMPLATE-agente/` | `RUNBOOK.md` vía A |
| **Trabajo general** (objetos, Flows, Apex, LWC, permisos, integraciones) | `templates/prd-general.md` | `specs/_TEMPLATE-general/` | `RUNBOOK.md` vía B |

Si el pedido mezcla ambos (un agente que necesita Flows/Apex de soporte), es tipo **agente**:
el backing logic se construye dentro de la vía A, usando las skills de la vía B.

**Nunca construyas sin PRD aprobado por el usuario.** El PRD es el único punto donde
corregir cuesta cero.

---

## 1. Regla cero: nunca inventes sintaxis

Agent Script se publicó en 2025 y **no está en tus datos de entrenamiento**. No es YAML, no es
Python, no es AppleScript. Antes de escribir o editar un `.agent`:

1. Leé los `references/` de la skill `agentforce-generate` (están en
   `.agents/skills/agentforce-generate/references/`).
2. Si algo no está ahí, consultá el **MCP de docs de Salesforce**
   (`salesforce_docs_search` / `salesforce_docs_fetch`). Está configurado en `.mcp.json`.
3. Si tampoco está ahí, decilo. No completes con analogía.

Lo mismo aplica en general: para API names de objetos y campos existentes, verificá contra
la org (describe / `platform-soql-query`) antes de afirmarlos.

---

## 2. Ruteo de skills (importante — hay colisión de nombres)

Este proyecto tiene **dos librerías de skills que exponen nombres idénticos**:
`forcedotcom/sf-skills` (a nivel proyecto, en `.agents/skills/`, 94 skills que cubren toda la
plataforma) y `agentforce-adlc` (plugin global, namespaceado como `agentforce-adlc:*`).

Regla dura:

| Necesidad | Usá | No uses |
|---|---|---|
| Diseñar, escribir, validar, deployar, publicar un `.agent` | `agentforce-generate` (sf-skills) | `agentforce-adlc:agentforce-generate` |
| Preview, test specs, `sf agent test` | `agentforce-test` (sf-skills) | `agentforce-adlc:agentforce-test` |
| Analizar traces / STDM de Data Cloud | `agentforce-observe` (sf-skills) | `agentforce-adlc:agentforce-observe` |
| **Red team / OWASP LLM Top 10 sobre un agente vivo** | `agentforce-adlc:agentforce-secure` | — |
| Todo lo demás de Salesforce (Apex, Flow, objetos, permisos, LWC, Data Cloud, integraciones…) | la skill de sf-skills que corresponda | — |

**Por qué:** sf-skills es la librería oficial de Salesforce y trae referencias con semántica de
CLI verificada. ADLC aporta valor único solo en la pasada de seguridad. Razonamiento completo
en `docs/DECISIONS.md`.

**Nunca** instales ADLC con `tools/install.sh` (file-copy): copia `skills/agentforce-*` a
`~/.claude/skills/` con los mismos nombres que las de proyecto y rompe el ruteo. Solo plugin.

---

## 3. Reglas de CLI que aplican siempre

1. **Siempre `--json`.** En *toda* invocación de `sf`. No pipear a `jq`, no `2>/dev/null`.
2. **Verificá la org antes de tocarla.** `sf config get target-org --json`. Si no hay ninguna,
   pará y guiá al usuario para conectarla. **Nunca elijas una org por tu cuenta.**
3. **Nunca hardcodees el alias de org** en archivos del repo. Siempre `--target-org` / `-o` por
   parámetro, o la default del entorno.
4. **Deploy siempre acotado:** `sf project deploy start --json --metadata <tipos>`.
   Nunca `--source-dir force-app` a pelo — cuelga 2+ minutos si hay `AiEvaluationDefinition`
   (bug abierto de plataforma).
5. **Antes de cualquier deploy, explicale al usuario en lenguaje simple qué va a cambiar
   en la org y esperá su OK.**
6. `sf agent preview` a secas es un REPL interactivo y **cuelga** en automatización.
   Usá `preview start` / `send` / `end` con `--json`.
7. Para validar grounding de verdad: `sf agent preview start --use-live-actions`.
   Sin ese flag el preview genera outputs simulados y el grounding no valida nada.

### Deploy ≠ Publish (el error más común con agentes)

- `sf project deploy start` sobre un `AiAuthoringBundle` es **solo staging**: deja el bundle
  DRAFT en Agentforce Studio. **No crea** `Bot`, `BotVersion` ni `GenAiPlannerBundle`.
- `sf agent publish authoring-bundle --json --api-name <Name>` es lo que compila Agent Script
  y crea el runtime. Es autosuficiente: un bundle nuevo se publica directo, sin deploy previo.
- `sf agent test run` corre **solo contra agentes publicados y activados**.

---

## 4. Convenciones

### Agent Script (vía A)

- **Indentación: 4 espacios.** Los tabs rompen el compilador.
- **Booleanos: `True` / `False`** (capitalizados).
- **Orden de bloques top-level obligatorio:**
  `system:` → `config:` → `variables:` → `connection:` → `knowledge:` → `language:` → (resto)
- **Variables:** `mutable` o `linked`. **Acciones:** dos niveles — `definitions` e `invocations`.
- **`developer_name` debe coincidir con el nombre de la carpeta** bajo `aiAuthoringBundles/`.
- **Instrucciones:** `|` literal, `->` procedural.
- **`before_reasoning:` / `after_reasoning:`**: contenido **directo** bajo el bloque, sin
  wrapper `instructions:`.
- **Subagente** = ex "topic" (renombrado abril 2026). No confundir con subagentes de Claude Code.
- **Costos:** `transition`/`set`/`if`/hooks/reasoning = gratis; Flow/Apex = 20 créditos;
  Prompt Templates 2–16. → Traé datos una vez en `before_reasoning:`, cacheá en variables.

### Plataforma (vía B)

- Apex siempre `with sharing` salvo justificación explícita en el PRD.
- Nunca SOQL ni DML dentro de loops.
- Todo Apex con su test class; cobertura ≥ 75% antes de proponer deploy a producción.
- Permission sets, no profiles.
- Preferí Flow sobre Apex cuando la lógica lo permita; documentá en el PRD por qué
  cuando elijas Apex.

---

## 5. Estructura del repo

```
agentforce-workspace/
├── CLAUDE.md              ← este archivo (convenciones + ruteo)
├── SETUP.md               ← bootstrap por máquina / por org
├── RUNBOOK.md             ← pipelines: vía A (agentes) y vía B (general)
├── .mcp.json              ← MCP de docs de Salesforce (scope proyecto)
├── docs/                  ← DECISIONS.md (ADRs), cli-cheatsheet.md
├── templates/             ← INICIAR.md, prd-agente.md, prd-general.md, testSpec-template.yaml
├── tools/                 ← bootstrap.ps1
├── specs/                 ← 1 carpeta por trabajo: PRD, tests, notas (el pensamiento)
│   ├── _TEMPLATE-agente/
│   └── _TEMPLATE-general/
├── force-app/main/default/  ← metadata deployable (el artefacto)
├── .agents/skills/        ← sf-skills, 94 skills (versionadas, ver skills-lock.json)
└── .claude/skills/        ← symlinks a .agents/skills/ (NO son copias)
```

**Separación deliberada:** `specs/<Trabajo>/` guarda el *pensamiento*; `force-app/` guarda el
*artefacto*. No los mezcles.

---

## 6. Qué NO hacer

- No uses `sf agent create` a secas: crea agentes legacy sin Agent Script.
- No uses `sf agent generate test-spec` para *crear* un spec: es interactivo y cuelga.
  Solo con `--from-definition` para ingeniería inversa.
- No metas datos de cliente, IDs de org, retriever IDs ni credenciales en el repo.
  Van en `.env` (gitignoreado) o por parámetro.
- No deployes un `.agent` sin `sf agent validate authoring-bundle` antes.
- No des por terminado un agente sin la pasada de `agentforce-adlc:agentforce-secure`.
- No aceptes stubs como acciones finales: pasan el preview y fallan en producción.
