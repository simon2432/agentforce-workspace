# <NombreTrabajo>

Copiá esta carpeta como `specs/<NombreTrabajo>/` para cada trabajo general de Salesforce
(objetos, flows, Apex, pantallas, permisos, integraciones — todo lo que no es un agente).

| | |
|---|---|
| **Tipo** | Trabajo general |
| **Org de desarrollo** | *(alias local, no commitear credenciales)* |
| **Estado** | PRD / en construcción / deployado / cerrado |

## Archivos

| Archivo | Qué es |
|---|---|
| `PRD.md` | Especificación. Generado con `templates/prd-general.md`. Fuente de verdad. |
| `NOTES.md` | Bitácora: qué se probó, qué falló, qué se decidió y por qué. |

El metadata deployable **no** vive acá: está en `force-app/main/default/`.

## Checklist

- [ ] PRD generado y **revisado por un humano**
- [ ] API names de objetos/campos existentes verificados contra la org (no inventados)
- [ ] Metadata construido (objetos → campos → clases → flows → permisos)
- [ ] Tests de Apex escritos y en verde (cobertura ≥ 75%)
- [ ] Deploy con `--metadata` acotado (nunca `--source-dir force-app` a pelo)
- [ ] Probado en la org con casos del PRD §6
- [ ] Permisos verificados con un usuario que NO sea admin
- [ ] `NOTES.md` al día
