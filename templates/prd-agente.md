# Meta-prompt: generar el PRD de un agente Agentforce

Pegá este bloque en Claude Code **debajo** de tu descripción en lenguaje natural del agente.

---

Sos un arquitecto de agentes Agentforce. Voy a describirte un agente que quiero construir.

**Antes de escribir nada**, hacéme entre 3 y 5 preguntas — solo las que realmente cambian el
diseño. Priorizá en este orden y no preguntes lo que ya te dije:

1. **Canal y usuario.** ¿Quién habla con el agente (cliente final, empleado interno, partner) y
   por dónde (Experience Site, chat embebido, WhatsApp/SMS, Agent API headless)? Esto define tono,
   verificación de identidad y qué datos podés mostrar.
2. **Alcance negativo.** ¿Qué *no* tiene que hacer? Un agente sin límites explícitos rutea mal.
3. **Datos.** ¿Qué SObjects, campos custom, DMOs o retrievers necesita tocar? ¿Existen ya en la
   org o hay que crearlos?
4. **Verificación y escalado.** ¿Necesita verificar identidad antes de mostrar datos? ¿Cuándo
   escala a humano y a dónde?
5. **Estado.** ¿Qué tiene que recordar entre turnos para que el usuario no repita cosas?

Esperá mi respuesta. **No generes el PRD hasta que conteste.**

Cuando conteste, generá `specs/<NombreAgente>/PRD.md` con exactamente estas 8 secciones.
Cada sección tiene que ser accionable — si no sabés algo, escribí `**PENDIENTE:** <la pregunta>`
en vez de inventar.

## 1. Context
Persona, tono, canal, mensaje de apertura, idioma. En qué se convierte: `system:` y el opening.

## 2. Guardrails
Qué nunca hace. Qué verifica antes de actuar. Cuándo escala y a dónde. Qué datos nunca muestra.
Marcá cuáles son determinísticos (van como `if`/`else` o `before_reasoning`) y cuáles dependen
del criterio del LLM (van como instrucción). **Preferí determinístico siempre que se pueda.**

## 3. Reasoning (Subagentes)
Un subagente por bloque de responsabilidad. Para cada uno: nombre, cuándo se activa, qué
información necesita resuelta antes de razonar, qué acciones expone, a dónde puede transicionar.
Incluí el mapa de transiciones.

## 4. Data
SObjects y campos (marcá cuáles existen y cuáles hay que crear). DMOs y retrievers de Data Cloud.
Fuentes de grounding. Variables de estado con su tipo y si son `mutable` o `linked`.

## 5. Tools (Actions)
Por cada acción: nombre, tipo (Flow / Apex / Prompt Template / API externa), inputs, outputs,
**si ya existe en la org o hay que construirla**, y su costo en créditos
(Flow/Apex = 20, Prompt Template = 2–16).
Marcá cuáles se pueden mover a `before_reasoning:` para llamarse una sola vez.

## 6. Evals (casos de prueba)
Mínimo 3 categorías: happy path, ruteo ambiguo entre subagentes, y adversarial
(prompt injection, pedidos fuera de alcance, extracción de PII).
Usá **datos que ya existan en la org**, no inventados. Cada caso: utterance, subagente esperado,
acción esperada, criterio de éxito.

## 7. Agent Script Spec
Nombre del bundle (`developer_name`, debe coincidir con la carpeta), lista de subagentes con sus
nombres finales, orden de los bloques top-level, y qué instrucciones son literales (`|`) vs
procedurales (`->`).

## 8. Permissions
Permission sets necesarios, el Agent User y su licencia, reglas de sharing, y qué habilitaciones
de org hacen falta (Einstein, Agentforce, Data Cloud).

---

**Reglas para vos al generar el PRD:**

- No escribas Agent Script todavía. Esto es la especificación, no la implementación.
- No inventes nombres de campos ni de objetos. Si no sabés si existen, marcalo `**PENDIENTE**`.
- Si el alcance que describí es demasiado amplio para un agente, decímelo y proponé un corte.
- Terminá con una sección **"Riesgos y supuestos"**: qué asumiste, qué puede salir mal,
  qué te falta confirmar antes de construir.
