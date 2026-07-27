---
description: Actualiza sf-skills y el plugin agentforce-adlc, revisa cambios y deja todo commiteado
---

Actualizá las dos librerías de skills de este repo, con cuidado y mostrándome todo:

1. **Estado previo.** Corré `git status --short`. Si hay cambios sin commitear que no sean
   de skills, avisame y frená: no mezclar actualizaciones de skills con trabajo a medias.

2. **sf-skills (proyecto).** Corré `npx skills forcedotcom/sf-skills --all` desde la raíz.
   Después mostrame `git diff --stat skills-lock.json` y un resumen en lenguaje simple:
   qué skills cambiaron, cuáles son nuevas, cuáles desaparecieron.

3. **Plugin ADLC (global).** Corré `claude plugin update agentforce-adlc@agentforce-adlc`.
   Si falla porque no está instalado, decímelo y ofrecé instalarlo según SETUP.md Parte A
   (vía marketplace, NUNCA el install.sh).

4. **Verificación anti-colisión.** Confirmá que NO exista ninguna skill `agentforce-*` copiada
   en `~/.claude/skills/` (indicaría una instalación file-copy de ADLC que rompe el ruteo de
   CLAUDE.md §2). Si existe, avisame antes de tocar nada.

5. **Verificación de contenido.** Chequeá que `.agents/skills/agentforce-generate/references/`
   siga existiendo con sus archivos. Si la actualización renombró skills que CLAUDE.md
   menciona en la tabla de ruteo, proponeme la corrección de CLAUDE.md.

6. **Commit.** Si todo está bien, commiteá con mensaje
   `chore: actualizar sf-skills <fecha>` incluyendo `.agents/skills/` y `skills-lock.json`.
   Mostrame el resumen final.

7. Recordame **reiniciar Claude Code** para que las skills nuevas se carguen.
