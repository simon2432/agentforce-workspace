# Cheatsheet de CLI (comandos verificados)

Contrastados contra `.agents/skills/agentforce-generate/references/`. Si algo acá contradice
esas referencias, **ganan las referencias** — actualizá este archivo.

> Regla: **siempre `--json`**. No pipear a `jq`, no `2>/dev/null`.

## Entorno

```powershell
sf --version
sf update
node -v
claude plugin list
```

## Org

```powershell
sf org login web --alias <ALIAS> --instance-url https://test.salesforce.com   # SANDBOX
sf org login web --alias <ALIAS>                                                # PRODUCCIÓN (login.salesforce.com)
sf org display user --json
pwsh tools/org.ps1 <ALIAS>          # fija la org del proyecto y confirma su tipo contra la org
sf config get target-org --json
sf org assign permset --json --name <PermSetName>
sf org assign permset --json --name <PermSetName> --on-behalf-of user@example.com
sf org open agent --api-name <Developer_Name>
```

## Crear el bundle

```powershell
# boilerplate sin spec (lo más común)
sf agent generate authoring-bundle --json --no-spec --name "<Label>" --api-name <Developer_Name>

# desde un spec YAML
sf agent generate authoring-bundle --json --name "<Label>" --api-name <Developer_Name>
```

## Validar

```powershell
sf agent validate authoring-bundle --json --api-name <Developer_Name>
```

Solo sintaxis + compilación de Agent Script. **No** valida `default_agent_user` ni referencias
a backing logic — eso lo agarra `publish`.

## Deploy vs Publish

**El pipeline oficial son TRES comandos** ([blog Salesforce, may 2026](https://developer.salesforce.com/blogs/2026/05/new-agentforce-metadata-and-development-lifecycle)):

```powershell
# 1. SUBIR el .agent local -> actualiza el DRAFT que muestra el Builder
sf project deploy start --json --metadata AiAuthoringBundle:<Developer_Name>

# 2. COMMIT -> compila el DRAFT DE LA ORG y crea Bot + BotVersion + GenAiPlannerBundle
sf agent publish authoring-bundle --json --api-name <Developer_Name>

# 3. ACTIVAR -> sin esto queda INACTIVO (no hay preview ni test)
sf agent activate   --json --api-name <Developer_Name>
sf agent deactivate --json --api-name <Developer_Name>

# abrir en el Builder — son DOS pantallas distintas, sin --json
sf org open authoring-bundle                    # vista de autoría (incluye DRAFT)
sf org open agent --api-name <Bot_API_Name>     # vista del agente publicado

# backing logic
sf project deploy start --json --metadata ApexClass Flow PromptTemplate
sf project deploy start --json --metadata PermissionSet:<Name>
```

⚠️ **`sf agent publish` compila el DRAFT que está en la org, NO tu archivo local.**
Si salteás el paso 1, publicás contenido viejo. Síntoma: el "Last Modified" del agente en
el Builder **no cambia** después de publicar.

Atajo todo-en-uno (queda vivo sin commit manual):
`sf project deploy start --json --metadata AiAuthoringBundle,GenAiPlannerBundle`

⚠️ **Nunca** `sf project deploy start --source-dir force-app` a pelo: cuelga 2+ min si hay
`AiEvaluationDefinition` bajo `force-app/` (bug abierto de plataforma).

`publish` no devuelve el número de versión creado. Para saberlo:

```powershell
sf project retrieve start --json --metadata AiAuthoringBundle:<Developer_Name>
```

Mirá el `<target>` en `bundle-meta.xml` (ej. `MiAgente.v2`).

### Bundles pelados vs. con sufijo

| | `MiAgente` (pelado) | `MiAgente_1` (con sufijo) |
|---|---|---|
| Qué es | Copia editable, apunta al DRAFT más alto | Snapshot congelado de la v1 publicada |
| Se edita | ✅ acá van TODOS los cambios | ❌ read-only (`<target>` lo bloquea) |
| Deploy con cambios | OK | Falla: "content cannot be changed on a locked version" |

### ⚠️ `Metadata retrieval failed` al publicar = falso negativo

```
MetadataTransferError: Metadata API request failed: Metadata retrieval failed:
context: AgentPublishAuthoringBundle
```

El publish **funcionó**; falla el retrieve automático posterior. Reproducido 3 veces con
los 4 chequeos oficiales en verde. **No republiques.** Verificá contra la org:

```powershell
sf data query --json -q "SELECT DeveloperName FROM BotDefinition WHERE DeveloperName = '<Name>'"
sf agent activate --json --api-name <Bot_API_Name>
```

**Verificá el publish consultando la org, no buscando el snapshot local** — con este bug
la carpeta `MiAgente_N` puede no bajar aunque la versión exista.

Solo una versión activa a la vez; activar una nueva desactiva la anterior.

## Preview

```powershell
sf agent preview start --json --authoring-bundle <Developer_Name> --use-live-actions
sf agent preview send  --json --authoring-bundle <Developer_Name> --session-id <ID> -u "<mensaje>"
sf agent preview end   --json --authoring-bundle <Developer_Name> --session-id <ID>
```

| Trampa | Qué pasa |
|---|---|
| `sf agent preview` a secas | REPL interactivo. **Cuelga** en automatización. |
| `send` sin `--session-id` | La sesión no persiste entre turnos. |
| sin `--use-live-actions` | Outputs simulados. El grounding no valida nada. |
| `--context` / `--session-var` / `--variables` | **No existen.** No se pueden inyectar `@context` ni `@session`. |
| `preview start --api-name <Bot>` | Requiere que el Bot tenga una versión **activada**. |

Cada turno escribe un trace por `PLAN_ID`: muestra selección de subagente, I/O de acciones y
por qué ruteó donde ruteó.

## Tests

```powershell
sf agent test create  --json --spec specs/<N>/testSpec.yaml --api-name <N>_Test --force-overwrite
sf agent test run     --json --api-name <N>_Test --wait 5
sf agent test results --json --job-id <JOB_ID>
```

- Un YAML local **no** implica que el test exista en la org. `test create` lo compila a
  `AiEvaluationDefinition`.
- Corren **solo contra agentes publicados y activados**. Un DRAFT no se testea.
- Iterar: editar YAML → `test create` mismo `--api-name --force-overwrite` → `test run`.
- `sf agent generate test-spec` es **interactivo**: no sirve para crear. Solo con
  `--from-definition` para ingeniería inversa.

## Data libraries / grounding

```powershell
sf agent adl create --source-type retriever --retriever-id <ID>
sf agent adl file add -i <library-id-1JD...> --path ./docs/manual.pdf
```

## Modificar un agente existente

```powershell
sf project retrieve start --json --metadata AiAuthoringBundle:<Developer_Name>
```

Retrieve con `AiAuthoringBundle:`, **no** con `Agent:`.

## Skills

```powershell
npx skills add forcedotcom/sf-skills -l    # listar las del repo original, sin instalar
claude plugin update agentforce-adlc@agentforce-adlc
pwsh tools/link-skills.ps1                 # recrear los enlaces de .claude/skills/
```

Para actualizar sf-skills usá **`/actualizar-entorno`**, no el instalador a mano: nunca con
`--all` (instala para todos los agentes) y en Windows hay que mover las copias que deja en
`.claude/skills/` a `.agents/skills/`. El paso a paso está en ese comando.

## Costos por operación

| Operación | Créditos |
|---|---|
| `@utils.transition`, `@utils.setVariables`, `@utils.escalate` | 0 |
| `if`/`else`, `before_reasoning`, `after_reasoning` | 0 |
| turno de reasoning del LLM | 0 |
| Prompt Template | 2–16 |
| acción de Flow / Apex / cualquier otra | 20 |

→ Traé datos una vez en `before_reasoning:`, cacheá en variables, reusá entre subagentes.
