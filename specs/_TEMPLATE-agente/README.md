# <NombreAgente>

Copiá esta carpeta como `specs/<NombreAgente>/` para cada agente nuevo.

| | |
|---|---|
| **Bundle (`developer_name`)** | `<Developer_Name>` |
| **Org de desarrollo** | *(alias local, no commitear credenciales)* |
| **Estado** | PRD / en construcción / publicado / en producción |
| **Última pasada de seguridad** | *(fecha + nota A–F)* |

## Archivos

La plantilla trae `README.md`, `BITACORA.md` y `NOTES.md`. El resto se crea durante el trabajo.

| Archivo | Qué es | De dónde sale |
|---|---|---|
| `PRD.md` | Especificación. Fuente de verdad del comportamiento. | Lo genera `templates/prd-agente.md` |
| `testSpec.yaml` | Casos de prueba. Se compila con `sf agent test create`. | Copia de `templates/testSpec-template.yaml` |
| `utterances.md` | *(opcional)* Frases de prueba para el loop rápido de preview. | Se crea a mano si hace falta |
| `BITACORA.md` | **Registro append-only de toda acción sobre la org.** Obligatorio: `CLAUDE.md` §5. | Viene en la plantilla |
| `NOTES.md` | Razonamiento: qué se probó, qué falló, qué se decidió y por qué. | Viene en la plantilla |

Todo archivo de este trabajo (versiones del `.agent`, diffs, prompts, scripts) va en esta
carpeta, que está gitignoreada. **Nunca** dentro de `.agents/skills/`, que sí se commitea.

El artefacto deployable **no** vive acá: está en
`force-app/main/default/aiAuthoringBundles/<Developer_Name>/`.

## Checklist

- [ ] Org confirmada con `sf org list --json` y anotada en `BITACORA.md`
      (alias + sandbox / scratch / **PRODUCCIÓN**)
- [ ] PRD generado y **revisado por un humano**
- [ ] `.agent` escrito desde el PRD
- [ ] `sf agent validate authoring-bundle` pasa
- [ ] Backing logic real deployada (Flows/Apex) — **sin stubs**
- [ ] Permission set + Agent User configurados
- [ ] `sf agent publish authoring-bundle` OK y versión activada
- [ ] Preview con `--use-live-actions` sobre todos los subagentes
- [ ] `testSpec.yaml` con happy path + ruteo ambiguo + adversarial
- [ ] `sf agent test run` en verde
- [ ] Pasada de seguridad `agentforce-adlc:agentforce-test --mode C2` ≥ B
- [ ] Backup del estado previo antes de pisar metadata existente
- [ ] Cada deploy validado, explicado y **aprobado explícitamente**
- [ ] `BITACORA.md` con una fila por cada acción sobre la org (incluidos los cambios
      hechos a mano en Setup), cada una con su reversión
- [ ] `NOTES.md` al día
