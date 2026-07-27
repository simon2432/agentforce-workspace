# RUNBOOK.md — el ciclo de trabajo

Dos vías, un mismo principio: **PRD primero, construir después, no avanzar de etapa sin que
la anterior pase.** El costo de descubrir un problema tarde es siempre 10x.

```
                      ┌─ vía A (agentes) ──→ .agent → validate → preview → publish → test → secure → observe
idea → PRD aprobado ──┤
                      └─ vía B (general) ──→ construir → tests → deploy acotado → verificar en org
```

¿No sabés por dónde empezar? Pegá el prompt de `templates/INICIAR.md` en Claude Code y
dejate guiar.

---

## Etapa común: el PRD

1. Copiá la plantilla: `specs/_TEMPLATE-agente/` o `specs/_TEMPLATE-general/` →
   `specs/<NombreTrabajo>/`.
2. En Claude Code: describí lo que querés en tus palabras y pegá abajo el meta-prompt
   (`templates/prd-agente.md` o `templates/prd-general.md`).
3. Claude te hace 3–5 preguntas y genera `specs/<NombreTrabajo>/PRD.md`.
4. **Leelo y corregilo vos.** Es el único punto donde cambiar de opinión cuesta cero.

---

# VÍA A — Agentes Agentforce

## A0 — Prueba de humo (una vez por org nueva)

Antes de un agente real, confirmá el toolchain entero con uno trivial:

```powershell
sf config get target-org --json
sf agent generate authoring-bundle --json --no-spec --name "Smoke Test" --api-name Smoke_Test
```

Editá el `.agent` con un subagente mínimo (base:
`.agents/skills/agentforce-generate/assets/minimal-starter.agent`), y:

```powershell
sf agent validate authoring-bundle --json --api-name Smoke_Test
sf agent publish  authoring-bundle --json --api-name Smoke_Test
sf agent preview start --json --authoring-bundle Smoke_Test --use-live-actions
sf agent preview send  --json --authoring-bundle Smoke_Test --session-id <ID> -u "cuanto es 2+2"
sf agent preview end   --json --authoring-bundle Smoke_Test --session-id <ID>
```

Si esto anda, cualquier falla futura es **tu agente**, no el setup. Eso vale oro al debuggear.

## A1 — Generar el `.agent`

```powershell
sf agent generate authoring-bundle --json --no-spec --name "<Label>" --api-name <Developer_Name>
```

Después, en Claude Code:

> Usando la skill `agentforce-generate` y el PRD en `specs/<Nombre>/PRD.md`, escribí el
> `.agent` del bundle `<Developer_Name>`. Cada topic del PRD es un subagente, cada guardrail
> como guard o `before_reasoning`, cada tool como acción. Leé los `references/` antes.

`developer_name` debe coincidir con la carpeta bajo `force-app/main/default/aiAuthoringBundles/`.

## A2 — Validar (barato, hacelo seguido)

```powershell
sf agent validate authoring-bundle --json --api-name <Developer_Name>
```

Chequea **solo** sintaxis y compilación. No valida `default_agent_user` ni que los
Flows/Apex referenciados existan — eso lo agarra `publish`.

## A3 — Backing logic (usa la vía B)

Los Flows/Apex/permisos que el agente necesita se construyen con las skills de plataforma
(`automation-flow-generate`, `platform-apex-generate`, `platform-permission-set-generate`) y:

```powershell
sf project deploy start --json --metadata ApexClass Flow PromptTemplate -o <ALIAS>
```

**No aceptes stubs**: pasan el preview y fallan en producción.
No te olvides del **Agent User** con licencia
(`.agents/skills/agentforce-generate/references/agent-user-setup.md`) — su falta hace fallar
el publish con un error poco claro.

## A4 — Publish y activar

```powershell
sf agent publish authoring-bundle --json --api-name <Developer_Name>
```

Compila Agent Script → crea `Bot` + `BotVersion` + `GenAiPlannerBundle` + `GenAiPlugins`.
`sf project deploy start` **no hace esto** (solo staging DRAFT).

`publish` no devuelve la versión creada; para verla:
`sf project retrieve start --json --metadata AiAuthoringBundle:<Developer_Name>`.
Solo una versión activa a la vez.

## A5 — Preview (el loop rápido, ~15s)

```powershell
sf agent preview start --json --authoring-bundle <Developer_Name> --use-live-actions
sf agent preview send  --json --authoring-bundle <Developer_Name> --session-id <ID> -u "<utterance>"
sf agent preview end   --json --authoring-bundle <Developer_Name> --session-id <ID>
```

- `--use-live-actions` obligatorio para validar grounding real.
- `--session-id` obligatorio en `send`.
- No existen `--context` / `--session-var` / `--variables`: lógica que dependa de `@context`
  o `@session` se valida por test spec contra el agente publicado, no por preview.
- Cada turno escribe un trace (por `PLAN_ID`): leelos, muestran ruteo e I/O de acciones.

## A6 — Test spec

```powershell
sf agent test create  --json --spec specs/<Nombre>/testSpec.yaml --api-name <Nombre>_Test --force-overwrite
sf agent test run     --json --api-name <Nombre>_Test --wait 5
sf agent test results --json --job-id <JOB_ID>    # solo si no usaste --wait
```

Plantilla: `templates/testSpec-template.yaml` (happy path + ruteo ambiguo + multi-turn +
escalado + adversarial). Corren **solo contra agentes publicados y activados**. Usá datos
que existan en la org, no inventados.

## A7 — Seguridad (no la saltees)

```
/agentforce-adlc:agentforce-secure
```

Red team OWASP LLM Top 10 contra el agente vivo, nota A–F. Menos de B → arreglar antes de
que lo vea un usuario real.

## A8 — Observar en producción

Skill `agentforce-observe`: extrae traces STDM de Data Cloud, encuentra fallas de ruteo,
reproduce con preview y propone fixes al `.agent`. **Requiere Data Cloud en la org.**

## Modificar un agente existente

```powershell
sf project retrieve start --json --metadata AiAuthoringBundle:<Developer_Name>   # NO "Agent:"
# editar el .agent → A2 validate → A5 preview → A4 publish → A6 test run
```

---

# VÍA B — Trabajo general de Salesforce

## B1 — Construir localmente

Con el PRD aprobado, pedile a Claude que construya **en el orden de dependencias**:

```
objetos → campos → clases Apex (+tests) → flows → pantallas/LWC → permission sets
```

Las skills se activan solas según la tarea (`platform-custom-object-generate`,
`automation-flow-generate`, `platform-apex-generate`, etc.). Todo queda local en
`force-app/main/default/` — la org no se toca todavía.

Reglas que Claude ya conoce por CLAUDE.md: `with sharing`, sin SOQL/DML en loops,
permission sets y no profiles, Flow antes que Apex cuando alcanza.

## B2 — Tests locales

- Apex: `sf apex test run --json --wait 10 --code-coverage` (≥ 75% para producción).
- Lint del proyecto: `npm run lint` (LWC/Aura) si tocaste UI.

## B3 — Deploy acotado

```powershell
# primero validar sin deployar (dry-run):
sf project deploy validate --json --metadata <tipos> -o <ALIAS>
# después el deploy real, siempre acotado:
sf project deploy start --json --metadata CustomObject CustomField ApexClass Flow PermissionSet -o <ALIAS>
```

Nunca `--source-dir force-app` a pelo. Antes de deployar, Claude te explica qué va a
cambiar en la org — no aprobes sin entenderlo.

## B4 — Verificar en la org

- Correr los casos de prueba del PRD §6 a mano en la org.
- Probar permisos con un usuario que **no** sea admin.
- `sf org open` para revisar visualmente lo que se creó.
- Actualizar `specs/<Nombre>/NOTES.md` con lo que quedó y lo que falta.
