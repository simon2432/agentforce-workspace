# Cómo arrancar cualquier trabajo (para todos, sepas o no de código)

Abrí Claude Code en esta carpeta y **copiá y pegá esto** — es lo único que tenés que saber:

---

```
Quiero arrancar un trabajo nuevo en Salesforce. Guiame según el proceso de este repo:

0. VERIFICACIÓN DE ENTORNO, siempre, antes de todo. Primero confirmá que las herramientas
   base de la máquina estén instaladas (Node, Salesforce CLI, Claude Code, Python) — si es
   la primera vez en esta máquina o tenés dudas, corré `pwsh tools/bootstrap.ps1` y mostrame
   qué falta antes de seguir. Después chequeá las 3 piezas del toolchain del repo:
   - sf-skills: fecha del último commit que tocó skills-lock.json
   - plugin ADLC: claude plugin list
   - MCP de docs: que .mcp.json exista y que salesforce_docs_search responda
   Si alguna falta o tiene más de una semana, ofreceme correr /actualizar-entorno antes
   de empezar, explicándome en una línea por qué conviene. Sin estas 3 piezas al día,
   Agent Script se escribe con sintaxis vieja o inventada.
1. Preguntame primero QUÉ quiero hacer, en mis palabras.
2. Clasificalo: ¿es un AGENTE Agentforce, o es TRABAJO GENERAL de Salesforce
   (objetos, campos, flows, Apex, pantallas, permisos, reportes, integraciones)?
   Decime cuál elegiste y por qué.
3. Verificá el entorno: que haya una org conectada (sf config get target-org --json).
   Si no hay, guiame para conectarla paso a paso.
4. Usá el meta-prompt que corresponda:
   - Agente  → templates/prd-agente.md
   - General → templates/prd-general.md
   Haceme las preguntas del meta-prompt y generá el PRD en specs/<NombreTrabajo>/PRD.md
   (copiá antes la plantilla specs/_TEMPLATE-agente o specs/_TEMPLATE-general).
5. Cuando yo apruebe el PRD, construí siguiendo el RUNBOOK.md — vía A para agentes,
   vía B para trabajo general. Avanzá etapa por etapa y mostrame el resultado de cada
   una antes de seguir.

Importante: explicame todo en lenguaje simple, sin asumir que sé programar.
```

---

## Qué va a pasar después de pegar eso

1. **Claude te pregunta qué necesitás** — contestás en tus palabras, como se lo contarías a un compañero.
2. **Te hace 3–5 preguntas** puntuales (canal, datos, permisos, qué NO tiene que hacer).
3. **Genera el PRD** — un documento en español que describe lo que se va a construir. **Leelo y corregilo**: es el único punto donde tu opinión cuesta cero. Todo lo que esté mal acá se construye mal después.
4. **Construye por etapas** siguiendo el RUNBOOK, mostrándote cada resultado.
5. **Testea y deploya** con tu aprobación en cada paso que toque la org.

## Las tres cosas que sí tenés que saber

- **Nunca aprobar un deploy sin entender qué hace.** Pedile a Claude "explicame qué va a cambiar en la org antes de deployar".
- **Si algo falla, no reintentes a ciegas.** Decile a Claude "leé el error y explicámelo primero".
- **Los datos de clientes y credenciales nunca van en esta carpeta.** Si Claude te pide un dato sensible para ponerlo en un archivo, frenalo.
