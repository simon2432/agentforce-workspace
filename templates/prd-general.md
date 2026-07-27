# Meta-prompt: generar el PRD de un trabajo general de Salesforce

Para todo lo que NO es un agente Agentforce: objetos y campos, Flows, Apex, LWC/pantallas,
permisos y sharing, reportes, integraciones, Data Cloud. Pegá este bloque en Claude Code
**debajo** de tu descripción en lenguaje natural de lo que necesitás.

---

Sos un arquitecto Salesforce. Voy a describirte algo que necesito construir o cambiar en una org.

**Antes de escribir nada**, hacéme entre 3 y 5 preguntas — solo las que cambian el diseño.
Priorizá en este orden y no preguntes lo que ya te dije:

1. **Usuario y proceso.** ¿Quién usa esto y en qué momento de su trabajo? ¿Qué hace hoy
   (proceso manual, otra herramienta) y qué cambia con esto?
2. **Datos.** ¿Sobre qué objetos opera? ¿Existen o hay que crearlos? ¿Volúmenes aproximados?
3. **Automatización vs configuración.** ¿Hay reglas de negocio (cuándo se dispara qué)?
   ¿Necesita lógica compleja o alcanza con configuración declarativa?
4. **Acceso.** ¿Quién puede ver/editar qué? ¿Hay datos sensibles?
5. **Integraciones.** ¿Habla con algo externo? ¿En qué dirección y con qué frecuencia?

Esperá mi respuesta. **No generes el PRD hasta que conteste.**

Cuando conteste, generá `specs/<NombreTrabajo>/PRD.md` con exactamente estas 8 secciones.
Si no sabés algo, escribí `**PENDIENTE:** <la pregunta>` en vez de inventar.

## 1. Contexto
Qué problema resuelve, para quién, y cómo se ve el éxito. En una página o menos.

## 2. Modelo de datos
Objetos y campos: cuáles existen, cuáles se crean, tipos, relaciones. Para campos nuevos:
API name, tipo, requerido o no, valores de picklist. Diagrama de relaciones si hay más de
dos objetos (skill `external-diagram-mermaid-generate`).

## 3. Automatización y lógica
Cada regla de negocio como: **disparador → condición → acción**. Marcá qué va en Flow
(preferido si alcanza) y qué exige Apex, y por qué. Regla dura del repo: Apex siempre
`with sharing` salvo justificación explícita, nunca SOQL/DML dentro de loops.

## 4. Interfaz
Pantallas, LWC, list views, page layouts, apps. Solo si aplica — si no, "N/A".

## 5. Permisos y acceso
Permission sets (no profiles), reglas de sharing, visibilidad de campos sensibles.
Quién puede crear/leer/editar/borrar qué.

## 6. Plan de pruebas
Cómo se verifica que funciona: tests de Apex (cobertura ≥ 75% obligatoria para deploy a
producción), casos de prueba manuales para Flows y pantallas, datos de prueba necesarios.

## 7. Plan de deploy
Qué metadata se deploya y en qué orden (dependencias primero: objetos → campos → clases →
flows → permisos). Comando `sf project deploy start --json --metadata <tipos acotados>`.
Qué se configura a mano en Setup porque no es deployable.

## 8. Riesgos y supuestos
Qué asumiste, qué puede romper cosas existentes (validation rules, automatizaciones que ya
tocan los mismos objetos), qué falta confirmar antes de construir.

---

**Reglas para vos al generar el PRD:**

- No escribas código todavía. Esto es la especificación.
- No inventes API names de campos u objetos existentes: verificalos contra la org con
  `platform-soql-query` / describe antes de afirmarlos.
- Si lo que pedí se resuelve con configuración estándar sin construir nada, decímelo.
- Si el alcance es demasiado grande para una sola pasada, proponé un corte por fases.
