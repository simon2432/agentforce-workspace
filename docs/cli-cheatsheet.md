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
sf org login web --alias <ALIAS>
sf org display user --json
sf config set target-org <ALIAS>
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

```powershell
# STAGING: deja el bundle DRAFT en Studio. NO crea Bot/BotVersion/GenAiPlannerBundle.
sf project deploy start --json --metadata AiAuthoringBundle:<Developer_Name>

# RUNTIME REAL: compila y crea todo el grafo de entidades. Autosuficiente.
sf agent publish authoring-bundle --json --api-name <Developer_Name>

# backing logic
sf project deploy start --json --metadata ApexClass Flow PromptTemplate
sf project deploy start --json --metadata PermissionSet:<Name>
```

⚠️ **Nunca** `sf project deploy start --source-dir force-app` a pelo: cuelga 2+ min si hay
`AiEvaluationDefinition` bajo `force-app/` (bug abierto de plataforma).

`publish` no devuelve el número de versión creado. Para saberlo:

```powershell
sf project retrieve start --json --metadata AiAuthoringBundle:<Developer_Name>
```

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
npx skills forcedotcom/sf-skills --all     # refrescar (revisar diff de skills-lock.json antes de commitear)
claude plugin update agentforce-adlc@agentforce-adlc
```

## Costos por operación

| Operación | Créditos |
|---|---|
| `@utils.transition`, `@utils.setVariables`, `@utils.escalate` | 0 |
| `if`/`else`, `before_reasoning`, `after_reasoning` | 0 |
| turno de reasoning del LLM | 0 |
| Prompt Template | 2–16 |
| acción de Flow / Apex / cualquier otra | 20 |

→ Traé datos una vez en `before_reasoning:`, cacheá en variables, reusá entre subagentes.
