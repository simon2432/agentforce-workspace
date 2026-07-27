# <NombreAgente>

Copiá esta carpeta como `specs/<NombreAgente>/` para cada agente nuevo.

| | |
|---|---|
| **Bundle (`developer_name`)** | `<Developer_Name>` |
| **Org de desarrollo** | *(alias local, no commitear credenciales)* |
| **Estado** | PRD / en construcción / publicado / en producción |
| **Última pasada de seguridad** | *(fecha + nota A–F)* |

## Archivos

| Archivo | Qué es |
|---|---|
| `PRD.md` | Especificación. Generado con `templates/prd-agente.md`. Fuente de verdad del comportamiento. |
| `testSpec.yaml` | Casos de prueba. Se compila con `sf agent test create`. |
| `utterances.md` | Frases de prueba para el loop rápido de preview. |
| `NOTES.md` | Bitácora: qué se probó, qué falló, qué se decidió y por qué. |

El artefacto deployable **no** vive acá: está en
`force-app/main/default/aiAuthoringBundles/<Developer_Name>/`.

## Checklist

- [ ] PRD generado y **revisado por un humano**
- [ ] `.agent` escrito desde el PRD
- [ ] `sf agent validate authoring-bundle` pasa
- [ ] Backing logic real deployada (Flows/Apex) — **sin stubs**
- [ ] Permission set + Agent User configurados
- [ ] `sf agent publish authoring-bundle` OK y versión activada
- [ ] Preview con `--use-live-actions` sobre todos los subagentes
- [ ] `testSpec.yaml` con happy path + ruteo ambiguo + adversarial
- [ ] `sf agent test run` en verde
- [ ] `/agentforce-adlc:agentforce-secure` ≥ B
- [ ] `NOTES.md` al día
