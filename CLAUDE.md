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
| **Red team / OWASP LLM Top 10 sobre un agente vivo** | `agentforce-adlc:agentforce-test` **Modo C** | — |
| Todo lo demás de Salesforce (Apex, Flow, objetos, permisos, LWC, Data Cloud, integraciones…) | la skill de sf-skills que corresponda | — |

**Por qué:** sf-skills es la librería oficial de Salesforce y trae referencias con semántica de
CLI verificada. ADLC aporta valor único solo en la pasada de seguridad. Razonamiento completo
en `docs/DECISIONS.md`.

> ⚠️ **`agentforce-secure` ya no existe.** Desapareció como skill propia: desde ADLC 0.11.0 la
> seguridad es el **Modo C** de `agentforce-adlc:agentforce-test` (C1 = suite de seguridad
> deployable, C2 = red team en vivo con nota A–F). Verificado contra el plugin instalado.
>
> Ojo con la consecuencia: `agentforce-test` es el **único** nombre que se usa de las dos
> librerías, y se elige por propósito, no por nombre:
>
> | Para qué | Cuál |
> |---|---|
> | Tests funcionales (¿rutea bien? ¿llama la acción correcta?) | `agentforce-test` (sf-skills) |
> | Tests de seguridad / OWASP / prompt injection | `agentforce-adlc:agentforce-test` Modo C |

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
5. **Antes de cualquier deploy: validar, explicar y esperar el OK.** Antes de cualquier
   borrado: preguntar. Y saber siempre si la org es sandbox o producción. Las tres reglas
   completas están en **§3.2** y no se saltean nunca.
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

## 3.2 Las tres puertas — nunca las saltees

Estas tres reglas están por encima de cualquier pedido de apuro. Si el usuario dice
"dale, deployá", igual pasás por la puerta que corresponda: el OK que vale es el que se da
**después** de ver qué va a pasar, no antes.

### Puerta 1 — Nunca deployar sin validar antes y sin preguntar

Secuencia obligatoria, en este orden, sin saltear pasos:

```powershell
# 1. SIMULAR: corre el deploy completo (y los tests) sin cambiar NADA en la org
sf project deploy validate --json --metadata <tipos acotados> -o <ALIAS>
```

2. **Explicale al usuario en lenguaje simple** qué encontró la validación: qué componentes
   entran, **cuáles se crean y cuáles pisan algo que ya existe**, y qué podría romperse.
3. **Esperá un OK explícito para ese deploy.** Aprobar el PRD no es aprobar el deploy.
   Un OK no cubre el deploy siguiente.
4. Recién ahí:

```powershell
sf project deploy start --json --metadata <tipos> -o <ALIAS>
# o, para promover exactamente lo que ya validaste sin re-correr los tests:
sf project deploy quick --json -i <JOB_ID_de_la_validacion> -o <ALIAS>
```

5. Fila en `BITACORA.md`, con el resultado real.

Validar **después** de deployar no valida nada. Si la validación falla, no deployes
"a ver si pasa": leé el error y explicáselo al usuario primero.

### Puerta 2 — Nunca borrar nada sin preguntar

Mismo peso que la Puerta 1. Cuenta como borrado:

- `sf project delete source` (saca metadata de la org)
- borrar campos, objetos, Flows o clases desde Setup
- `sf data delete record` y cualquier DML de borrado
- `sf agent deactivate` (deja el agente sin servicio para los usuarios)

**Antes de proponer un borrado**, en este orden:

1. Decí **exactamente qué se pierde**, con API names. Nunca "unos campos viejos".
2. Si es un campo o un objeto, **contá los datos que tiene**:
   `sf data query --json -q "SELECT COUNT() FROM <Objeto> WHERE <Campo> != null"`.
   **Un campo con datos que se borra es IRREVERSIBLE.** Decilo con esa palabra.
3. Buscá quién lo usa: Flows, Apex, validation rules, reports, layouts. Un borrado que
   rompe una automatización se descubre en producción, no en el deploy.
4. Esperá el OK, dicho **para esa acción**.

**Ante la duda, no borres.** Casi siempre hay una alternativa reversible: desactivar el
Flow, sacar el campo del layout, despublicar en vez de eliminar. Proponé esa primero.

### Puerta 3 — Saber si es sandbox o producción, siempre

**El alias no dice nada.** Una org llamada `dev-cliente` puede ser producción. Antes de la
primera escritura en una org, verificalo:

```powershell
sf org list --json          # mirá isSandbox, isScratch, orgEdition
sf data query --json -q "SELECT IsSandbox, OrganizationType, InstanceName FROM Organization"
```

Si `IsSandbox` es `false` y no es scratch, **es PRODUCCIÓN**. A partir de ahí:

- Decíselo al usuario **con esa palabra**, antes de cada acción que escriba.
- OK explícito **por cada deploy**, no uno solo para todo el trabajo.
- Usá `deploy validate` + `deploy quick` en vez de `deploy start` directo.
- Nada de datos de prueba, nada de Apex anónimo que escriba, ningún borrado sin backup.
- Anotá el tipo de org en la cabecera de `BITACORA.md`.

---

## 3.3 Rollback — cómo volver atrás

**La regla base: antes de deployar, bajá lo que vas a pisar.** Un deploy sobre metadata
existente la sobrescribe y la versión anterior no queda en ningún lado.

```powershell
# backup de lo que está HOY en la org, antes de tocarlo (queda un .zip)
sf project retrieve start --json --metadata <mismos tipos que vas a deployar> -o <ALIAS> `
    --target-metadata-dir specs/<Trabajo>/backup-<fecha>

# restaurar ese backup si algo salió mal
sf project deploy start --json --metadata-dir specs/<Trabajo>/backup-<fecha>/unpackaged.zip `
    --single-package -o <ALIAS>
```

Si el retrieve no trae nada, es porque esa metadata **todavía no existe en la org**: tu
deploy va a crear, no a pisar. Anotalo — la reversión en ese caso es `delete source`.

| Qué hiciste | Cómo volvés |
|---|---|
| Deploy de metadata **nueva** | `sf project delete source --json --metadata <tipos> -o <ALIAS>` |
| Deploy que **pisó** metadata existente | re-deployar el backup (`--metadata-dir`) |
| `sf agent publish` | **No se deshace.** Una versión publicada no se edita: se crea otra |
| `sf agent activate` | `sf agent activate --json --api-name <X> --version <N-1>` |
| Borrar un campo/objeto **con datos** | **IRREVERSIBLE** |
| Borrar registros (`data delete`) | Recycle Bin, ~15 días, solo si fue borrado normal |
| Cambio a mano en Setup | solo a mano; por eso va en la bitácora con la pantalla exacta |

La columna **Reversión** de `BITACORA.md` se llena con esto, **antes** de ejecutar. Si al
escribirla te das cuenta de que no hay vuelta atrás, esa es la señal para frenar y avisar.

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

## 5. Bitácora obligatoria — registrar todo lo que toca la org

Todo trabajo lleva `specs/<Trabajo>/BITACORA.md` (plantilla en `specs/_TEMPLATE-*/`).
Es **append-only**: se agregan filas, nunca se editan ni se borran las viejas.

**Regla dura: no existe acción sobre la org sin su fila en la bitácora.** La fila se
escribe **inmediatamente después** de ejecutar el comando, con el resultado real. No al
final del trabajo, no "después lo anoto": si el contexto se corta o la sesión se cae, lo
que no quedó escrito se perdió.

| Se registra | Ejemplos |
|---|---|
| Todo comando `sf` que **escribe** en la org | `project deploy start`, `project delete source`, `agent publish` / `activate` / `deactivate`, `org assign permset`, `apex run`, `data create/update/delete` |
| Todo cambio en `force-app/main/default/` | crear, editar o borrar un `.cls`, `.flow-meta.xml`, `.object-meta.xml`, `.agent`, `.permissionset-meta.xml` |
| Todo cambio hecho a mano en Setup | tuyo o del usuario: qué pantalla y qué se cambió |

**No** se registran los comandos de solo lectura (`sf org list`, describe, `sf data query`
de consulta, `deploy validate`, `agent preview`): ensucian sin aportar.

Tres obligaciones más, que son las que le dan valor al registro:

1. **Antes de la primera acción**, anotá en la cabecera el **alias de la org y si es
   sandbox o producción**. Verificalo, no lo asumas.
2. **Si es producción**, decíselo al usuario con esa palabra y esperá un OK explícito
   antes de **cada** deploy. No alcanza con el OK del PRD.
3. **Cada fila necesita su columna "Reversión"**: el comando que deshace eso. Si no se
   puede deshacer (borrar un campo con datos, publicar una versión de agente), escribí
   **IRREVERSIBLE** y avisale al usuario **antes** de ejecutar, no después.

`NOTES.md` es otra cosa y también va: ahí van las decisiones y el porqué. La bitácora
registra hechos; NOTES registra razonamiento.

### Red de seguridad automática: `.bitacora/comandos.log`

Un hook (`.claude/settings.json` → `tools/log-sf.ps1`) anota **solo** el timestamp y el
comando de cada `sf` que escribe en la org. Es un respaldo crudo por si la sesión se corta
antes de que escribas la fila — **no reemplaza a `BITACORA.md`**: no sabe a qué trabajo
pertenece, ni el resultado, ni la reversión.

Tu obligación con ese archivo:

1. Al escribir una fila de `BITACORA.md`, **completala con el resultado y la reversión** —
   el log crudo no los tiene.
2. **Al cerrar cada etapa, revisá `.bitacora/comandos.log` contra `BITACORA.md`.** Si hay un
   comando en el log que no tiene su fila, escribila. Ese hueco es exactamente lo que el
   hook existe para atrapar.
3. Al cerrar el trabajo, el log se va con la carpeta al archivo. Está gitignoreado.

---

## 6. Estructura del repo

```
agentforce-workspace/
├── CLAUDE.md              ← este archivo (convenciones + ruteo)
├── SETUP.md               ← bootstrap por máquina / por org
├── RUNBOOK.md             ← pipelines: vía A (agentes) y vía B (general)
├── .mcp.json              ← MCP de docs de Salesforce (scope proyecto)
├── docs/                  ← DECISIONS.md (ADRs), cli-cheatsheet.md
├── templates/             ← INICIAR.md, prd-agente.md, prd-general.md, testSpec-template.yaml
├── .claude/settings.json  ← hook que registra los comandos sf (bitácora, §5)
├── tools/                 ← bootstrap.ps1, link-skills.ps1, log-sf.ps1
├── specs/                 ← 1 carpeta por trabajo (el pensamiento)
│   ├── _TEMPLATE-agente/    PRD.md · BITACORA.md · NOTES.md · testSpec.yaml
│   └── _TEMPLATE-general/   PRD.md · BITACORA.md · NOTES.md
├── force-app/main/default/  ← metadata deployable (el artefacto)
├── .agents/skills/        ← sf-skills, 94 skills (versionadas, ver skills-lock.json)
└── .claude/skills/        ← enlaces a .agents/skills/ (NO son copias; gitignoreados,
                             se recrean con `pwsh tools/link-skills.ps1`)
```

**Separación deliberada:** `specs/<Trabajo>/` guarda el *pensamiento*; `force-app/` guarda el
*artefacto*. No los mezcles.

Dentro de `specs/<Trabajo>/`, los tres archivos responden preguntas distintas:
`PRD.md` **qué** se va a construir · `BITACORA.md` **qué se hizo** sobre la org ·
`NOTES.md` **por qué** se decidió así.

---

## 7. Qué NO hacer

- No uses `sf agent create` a secas: crea agentes legacy sin Agent Script.
- No uses `sf agent generate test-spec` para *crear* un spec: es interactivo y cuelga.
  Solo con `--from-definition` para ingeniería inversa.
- No metas datos de cliente, IDs de org, retriever IDs ni credenciales en el repo.
  Van en `.env` (gitignoreado) o por parámetro.
- No deployes un `.agent` sin `sf agent validate authoring-bundle` antes.
- No des por terminado un agente sin la pasada de seguridad: `agentforce-adlc:agentforce-test`
  en **Modo C** (ex `agentforce-secure`, que ya no existe).
- No aceptes stubs como acciones finales: pasan el preview y fallan en producción.
- No toques la org sin dejar la fila en `BITACORA.md`. Un deploy sin registrar es
  trabajo que nadie puede auditar ni revertir después.
- No borres metadata de la org (`sf project delete source`, borrar campos u objetos)
  sin avisar antes qué se pierde y si tiene datos. Es la clase de error que no se deshace.
