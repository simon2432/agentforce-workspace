b# CLAUDE.md — agentforce-workspace

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

### Regla dura: nunca crees un agente que el usuario no pidió

Si el usuario dice "trabajá sobre mi agente", **listá los agentes de la org y hacé que
elija por nombre exacto antes de escribir una línea**. Un `developer_name` parecido no
alcanza: `Mi_Agente` y `Mi_Agente_Development` son agentes distintos.

Nunca marques un bundle como "descartable" por tu cuenta. Si hay más de un candidato,
preguntá. Crear un agente nuevo sin pedido explícito deja al usuario con trabajo
publicado en el lugar equivocado y una limpieza destructiva por delante.

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

### El pipeline son TRES comandos, no dos

Fuente: [blog oficial de Salesforce, mayo 2026](https://developer.salesforce.com/blogs/2026/05/new-agentforce-metadata-and-development-lifecycle).

```powershell
sf project deploy start --json --metadata AiAuthoringBundle:<Name> -o <ALIAS>   # 1. SUBIR el .agent local
sf agent publish authoring-bundle --json --api-name <Name> -o <ALIAS>           # 2. COMMIT -> runtime
sf agent activate --json --api-name <Name> -o <ALIAS>                           # 3. ACTIVAR
```

> ⚠️ **Saltear el paso 1 es el error más caro de todos.** `sf agent publish` compila el DRAFT
> **que está en la org**, no tu archivo local. Sin deploy previo, publica contenido viejo:
> el Builder sigue mostrando la versión anterior, el runtime se crea con lo que había,
> y todo parece "publicado" sin serlo.
>
> Síntoma inconfundible: en el Builder, el "Last Modified" del agente **no cambia** después
> de publicar. Si no cambió, el deploy nunca ocurrió.

Qué hace cada paso:

- **Deploy** sube el `AiAuthoringBundle` al dominio de autoría y actualiza el DRAFT. Es lo que
  ve el Builder. **No crea** `Bot` ni `BotVersion`.
- **Publish** (*commit*) traduce el `.agent` del DRAFT a `Bot` + `BotVersion` +
  `GenAiPlannerBundle`. Un agente commiteado **no se puede editar**: para cambiarlo hay que
  crear una versión nueva.
- **Activate** pone esa versión en vivo. Acepta `--version <N>` para elegir cuál.

Alternativa todo-en-uno (deja el agente vivo sin paso de commit manual):

```powershell
sf project deploy start --json --metadata AiAuthoringBundle,GenAiPlannerBundle -o <ALIAS>
```
- **`sf agent activate --json --api-name <Bot_API_Name>` es un paso SEPARADO y obligatorio.**
  Publicar no activa. Sin activar: no hay preview por `--api-name`, no hay `sf agent test run`,
  y en el Builder parece que nada cambió. Nunca reportes un agente como listo sin activarlo.
- `sf agent test run` corre **solo contra agentes publicados y activados**.

### Bundles con sufijo de versión (`MiAgente_1`, `MiAgente_2`) — leer antes de tocar

- El bundle **"pelado"** (`MiAgente`, sin sufijo) es la **copia editable**: apunta siempre al
  DRAFT más alto. **Todos los cambios van acá.**
- Los bundles **con sufijo** (`MiAgente_1`) son **snapshots congelados y de solo lectura** de
  versiones ya publicadas, marcados por un `<target>MiAgente.v1</target>` en `bundle-meta.xml`.
  Sirven para auditar y diffear historial, **nunca para editar**. Un deploy con cambios sobre
  ellos falla con "content cannot be changed on a locked version".
- Que `sf org list metadata` muestre `MiAgente_1` y no `MiAgente` **no significa que falte tu
  bundle**: lista los snapshots publicados. No lo interpretes como un agente duplicado.
- **Cada publish exitoso crea una versión nueva** (`v2`, `v3`…) y su snapshot correspondiente.

### `Metadata retrieval failed` en publish es COSMÉTICO — verificado en org real

```
MetadataTransferError: Metadata API request failed: Metadata retrieval failed:
context: AgentPublishAuthoringBundle   ·   exit code 1
```

**El publish SÍ funcionó.** Lo que falla es el retrieve automático que la CLI hace *después*
de publicar. El `Bot` y la `BotVersion` quedan creados en la org correctamente.

Reproducido 3 veces en bundles distintos, con los 4 chequeos oficiales de troubleshooting
en verde (`default_agent_user` ausente en Employee Agent, backing logic deployada,
sin `<target>` stale, sin versión activa bloqueando).

**Nunca republiques por este error.** Republicar infla versiones sin necesidad. Verificá
contra la org y seguí:

```powershell
# ¿existe el Bot y su BotVersion? -> si sí, el publish funcionó
sf data query --json -q "SELECT DeveloperName FROM BotDefinition WHERE DeveloperName = '<Name>'"
sf agent activate --json --api-name <Bot_API_Name>
```

> Corolario: **verificá el publish consultando la org, no buscando el snapshot local.**
> Como el retrieve falla, la carpeta `MiAgente_N` puede no bajar aunque la versión exista.
- Para abrir en el Builder hay **dos pantallas distintas** (sin `--json`):
  `sf org open authoring-bundle` (autoría/DRAFT) vs
  `sf org open agent --api-name <Bot_API_Name>` (agente publicado). Mandar el link equivocado
  hace creer al usuario que su agente no se actualizó.

---

## 3.1 Ciclo de vida de un agente — lo que rompe si no se sabe

### Borrar un agente en el Builder deja huérfanos — el `developer_name` queda quemado

Borrar un agente desde el Builder nuevo elimina el `AiAuthoringBundle`, pero **no** el
`Bot` ni el `GenAiPlannerDefinition` (`<Name>_v1`) asociados. Ese planner huérfano **no
se puede borrar**: `sf data delete record --sobject GenAiPlannerDefinition` falla con
`DELETE_FAILED: setup object in use`, incluso sin nada visible que lo referencie.

**Regla dura:** el `developer_name` de un agente borrado así queda **quemado** en esa
org. Cualquier deploy/publish futuro con ese mismo nombre choca con el residuo
(`"already in use by a Bot Definition"` o `"duplicate value found: GenAiPlannerDefinition"`).
No insistas — elegí un `developer_name` nuevo y limpio. **Nunca uses sufijos numéricos
ni `_v2`**: la plataforma ya usa `_N` para snapshots y `_vN` para planners: un nombre que
los tenga de entrada genera confusión con esos sufijos automáticos.

### "Renombrar un bundle" no existe — cambiar `developer_name` crea un agente nuevo

El `developer_name` es la **identidad** del agente, no una etiqueta (`agent_label` sí lo
es, y se cambia libremente). Cambiarlo no renombra nada: la próxima publicación crea un
`Bot` **distinto**, con su historial de versiones desde cero.

Si hace falta cambiarlo, **decíselo al usuario con esas palabras exactas** — "esto va a
crear un agente nuevo, no a renombrar el existente" — y esperá su OK explícito antes de
tocarlo.

Al cambiarlo, actualizá también `<agentAccesses><agentName>` en el permission set del
agente — si no, publica y activa sin errores pero **queda sin permisos y falla en
silencio** para los usuarios que lo usan. Ese campo no se puede deployar hasta que el
`Bot` ya exista (referencia circular): se corrige recién después del primer publish.

### Employee Agent — lo básico que se olvida

- Corre como el usuario logueado. **Nunca** lleva `default_agent_user` — si aparece, sacalo.
- Su permission set se asigna a los **empleados** que lo usan, no a un usuario técnico.

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
└── .claude/skills/        ← enlaces a .agents/skills/ (NO son copias; gitignoreados,
                             se recrean con `pwsh tools/link-skills.ps1`)
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
