# Auditoría del repo — 28/07/2026

Revisión completa después de la primera sesión real de desarrollo, que expuso varios
huecos del pipeline.

---

## 1. Las tres piezas del toolchain: ¿están bien?

### `forcedotcom/sf-skills` — ✅ correcto

94 skills oficiales de Salesforce, versionadas en `.agents/skills/`, pinneadas en
`skills-lock.json`. Las instaló el usuario con `npx skills forcedotcom/sf-skills --all`
antes de esta sesión. Cubren toda la plataforma, no solo agentes: Apex, Flow, LWC, Data
Cloud, permisos, integraciones, Commerce, OmniStudio.

Claude Code las levanta solo por los symlinks de `.claude/skills/`. **Verificación:** que
`.claude/skills/agentforce-generate/SKILL.md` sea legible. Si no, activar Modo Desarrollador
en Windows y re-correr `npx skills forcedotcom/sf-skills --all`.

### `agentforce-adlc` como plugin global — ✅ decisión correcta, ❌ NO instalado

**La decisión de que sea plugin y no skills de proyecto es correcta y deliberada.** Las dos
librerías exponen skills con **nombres idénticos** (`agentforce-generate`, `agentforce-test`,
`agentforce-observe`). Como plugin quedan namespaceadas (`agentforce-adlc:*`) y conviven.
Con el file-copy (`tools/install.sh`) se copian a `~/.claude/skills/` con los nombres pelados
y rompen el ruteo. Ver ADR-2 y ADR-3 en `DECISIONS.md`.

**Estado real: `claude plugin list` devuelve "No plugins are currently installed".**
O sea que `/agentforce-adlc:agentforce-secure` **no existe hoy**. El pipeline funciona
igual, pero la pasada de seguridad OWASP (etapa A7) no se puede correr.

```powershell
claude plugin marketplace add SalesforceAIResearch/agentforce-adlc
claude plugin install agentforce-adlc@agentforce-adlc
```

Requiere Python 3.9+. Reiniciar Claude Code después.

### MCP de docs de Salesforce — ✅ configurado

`.mcp.json` en la raíz, scope proyecto. Claude Code lo levanta al abrir la carpeta.
Expone `salesforce_docs_search` y `salesforce_docs_fetch`.

**Las tres piezas se usan en momentos distintos:** sf-skills para construir, el MCP para
verificar sintaxis y comandos contra la doc oficial, ADLC solo para el red team final.

---

## 2. El hueco grave que se corrigió: el pipeline eran TRES comandos

**El repo documentaba dos pasos (`publish` → `activate`). Faltaba el `deploy`.**

```powershell
sf project deploy start --json --metadata AiAuthoringBundle:<Name> -o <ALIAS>   # ← FALTABA
sf agent publish authoring-bundle --json --api-name <Name> -o <ALIAS>
sf agent activate --json --api-name <Name> -o <ALIAS>
```

`sf agent publish` compila el DRAFT **que está en la org**, no el archivo local. Sin el
deploy previo se publica contenido viejo: el Builder nunca cambia, el runtime se crea con
lo que hubiera, y todo parece publicado sin serlo.

La afirmación anterior del repo — *"publish es autosuficiente, no requiere deploy previo"* —
venía de las referencias de sf-skills y **es falsa en la práctica**. La fuente correcta es el
[blog oficial de Salesforce (may 2026)](https://developer.salesforce.com/blogs/2026/05/new-agentforce-metadata-and-development-lifecycle).

Costo de este error: un agente publicado en el lugar equivocado, un `Bot` residual que
bloqueó el nombre por conflicto, y un borrado destructivo manual.

---

## 3. Otros hallazgos incorporados

| Hallazgo | Dónde quedó documentado |
|---|---|
| `Metadata retrieval failed` en publish es **cosmético** — el publish funciona, falla el retrieve posterior. Reproducido 3 veces. No republicar. | CLAUDE.md, RUNBOOK A4, cheatsheet |
| Bundles con sufijo (`MiAgente_1`) son **snapshots read-only**, no agentes duplicados | CLAUDE.md, cheatsheet |
| Un `Bot` residual bloquea el `developer_name`: *"already in use by a Bot Definition"* | RUNBOOK A1 |
| Borrar el agente en el Builder elimina el `AiAuthoringBundle` pero **no** el `Bot` | RUNBOOK A1 |
| Qué determina Builder nuevo vs legacy (presencia de `AiAuthoringBundle`) | RUNBOOK A1, tabla nueva |
| Publicar ≠ activar | CLAUDE.md, RUNBOOK A4 |
| Nunca crear un agente que el usuario no pidió; hacer elegir por nombre exacto | CLAUDE.md §0 |
| Checklist visual de verificación post-deploy | RUNBOOK A4 |

---

## 4. Estado de git

- GitHub (`simon2432/agentforce-workspace`) tiene la **v1 del 27/07 16:53**, anterior a
  todas estas correcciones.
- El trabajo específico del agente (`specs/MesaAyudaInterna/`, los bundles) **nunca estuvo
  trackeado** — correcto.
- Se agregó al `.gitignore` para que no se cuele por accidente: `specs/*` (salvo las
  plantillas) y `force-app/main/default/aiAuthoringBundles/`.
- **Corrección 29/07:** esa nota original sugería "si usás esto para un proyecto real,
  borrá esas líneas y commiteá tu trabajo" — es un error de concepto. Este repo es un
  entorno de desarrollo, no el destino del trabajo: todo lo que se construye se
  despliega a la org de Salesforce, nunca se commitea acá. Se amplió el `.gitignore`
  a todo `force-app/main/default/*` (no solo `aiAuthoringBundles/`) y a los scripts
  ad-hoc bajo `scripts/apex/` y `scripts/soql/`, sin excepción para "proyecto real".

**Pendiente: commitear y pushear las correcciones.**

---

## 5. Qué falta para poder decir que el repo está probado

- [ ] Instalar el plugin ADLC
- [ ] Commit + push de las correcciones
- [ ] **Desplegar un agente de cero con los 3 comandos y verificar que aparece en el
      Builder nuevo con "Last Modified" de hoy.** Hasta que esto pase, el pipeline
      corregido es teoría.
- [ ] Correr `sf agent test run` contra ese agente
- [ ] Correr `/agentforce-adlc:agentforce-secure`

El punto 3 es el que convierte este repo de "documentado" a "verificado".
