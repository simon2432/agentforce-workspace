# BITÁCORA — <NombreTrabajo>

Registro **append-only** de toda acción que tocó la org o el metadata deployable.
Se agregan filas al final; **no se editan ni se borran las viejas**. Si algo salió mal,
se agrega una fila nueva con la corrección — la fila del error se queda.

Para qué sirve: saber meses después qué se le hizo a esa org, poder revertir, y que
otra persona (u otra sesión de Claude) retome sin adivinar.

## Org

| | |
|---|---|
| **Alias** | `<alias>` |
| **Tipo** | sandbox / scratch / developer / **PRODUCCIÓN** |
| **Confirmado por** | *(quién y cuándo verificó que es esa org)* |

Verificalo, no lo asumas por el alias — una org llamada `dev-cliente` puede ser producción:

```powershell
sf org list --json      # isSandbox / isScratch / orgEdition
sf data query --json -q "SELECT IsSandbox, OrganizationType FROM Organization"
```

> Si es **producción**, cada deploy necesita OK explícito del usuario para **ese** deploy.
> Reglas completas: `CLAUDE.md` §3.2 (las tres puertas) y §3.3 (rollback).

## Acciones

| Cuándo | Quién | Acción | Qué tocó | Comando o pantalla | Resultado | Reversión |
|---|---|---|---|---|---|---|
| 2026-01-01 14:32 | Claude | deploy | `ApexClass:MiClase`, `Flow:Mi_Flow` | `sf project deploy start --json --metadata ApexClass Flow -o <alias>` | OK — 2/2 componentes | `sf project delete source --metadata ApexClass:MiClase Flow:Mi_Flow` |
| | | | | | | |

### Cómo se llena cada columna

- **Cuándo** — fecha y hora reales, no "hoy".
- **Quién** — `Claude` o el nombre de la persona. Los cambios a mano en Setup también van acá.
- **Acción** — una de: `backup` · `deploy` · `retrieve` · `delete` · `publish` · `activate` ·
  `deactivate` · `assign-permset` · `apex-anon` · `data-dml` · `setup-manual` · `archivo-local`.
- **Qué tocó** — los API names concretos (`Case.Reason__c`), nunca "unos campos".
- **Comando o pantalla** — el comando copiado tal cual con su `-o <alias>`. Si fue a mano:
  la ruta exacta, p. ej. `Setup > Object Manager > Case > Fields > New`.
- **Resultado** — `OK` con el detalle, o el **mensaje de error real** recortado. Nunca "falló".
- **Reversión** — el comando o el paso que deshace esto. Si no se puede deshacer, escribí
  **IRREVERSIBLE** y por qué.

### Qué NO se registra

Los comandos de solo lectura: `sf org list`, `describe`, `sf data query` de consulta,
`sf project deploy validate`, `sf agent preview`. Ensucian la bitácora sin aportar nada.
