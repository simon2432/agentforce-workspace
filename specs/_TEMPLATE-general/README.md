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
| `BITACORA.md` | **Registro append-only de toda acción sobre la org.** Obligatorio: `CLAUDE.md` §5. |
| `NOTES.md` | Razonamiento: qué se probó, qué falló, qué se decidió y por qué. |

El metadata deployable **no** vive acá: está en `force-app/main/default/`.

Todo otro archivo de este trabajo (scripts, exports, notas sueltas) va en esta carpeta, que
está gitignoreada. **Nunca** dentro de `.agents/skills/`, que sí se commitea.

## Checklist

- [ ] Org confirmada con `sf org list --json` y anotada en `BITACORA.md`
      (alias + sandbox / scratch / **PRODUCCIÓN**)
- [ ] PRD generado y **revisado por un humano**
- [ ] API names de objetos/campos existentes verificados contra la org (no inventados)
- [ ] Metadata construido (objetos → campos → clases → flows → permisos)
- [ ] Tests de Apex escritos y en verde (cobertura ≥ 75%)
- [ ] Backup del estado previo (`retrieve --target-metadata-dir`) antes de pisar metadata
- [ ] `sf project deploy validate` en verde **antes** del deploy real
- [ ] Deploy explicado al usuario y **aprobado explícitamente** para ese deploy
- [ ] Deploy con `--metadata` acotado (nunca `--source-dir force-app` a pelo)
- [ ] Probado en la org con casos del PRD §6
- [ ] Permisos verificados con un usuario que NO sea admin
- [ ] `BITACORA.md` con una fila por cada acción sobre la org (incluidos los cambios
      hechos a mano en Setup), cada una con su reversión
- [ ] `NOTES.md` al día
