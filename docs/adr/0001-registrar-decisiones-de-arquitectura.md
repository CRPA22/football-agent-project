# ADR 0001: Registrar las decisiones de arquitectura

- **Estado:** Aceptada
- **Fecha:** 2026-09-23

## Contexto

El proyecto toma decisiones de arquitectura (servicios de Azure, entornos, herramientas) cuyo motivo no queda reflejado en el código. Sin registro, esas razones se pierden y las decisiones se vuelven a discutir o se revierten sin entenderlas.

## Decisión

Registrar cada decisión de arquitectura significativa como un ADR en `docs/adr/`, numerado y en Markdown, con las secciones: Contexto, Decisión, Alternativas consideradas y Consecuencias.

Los ADRs son inmutables: si una decisión cambia, se crea un ADR nuevo y el anterior pasa a estado "Reemplazada por ADR XXXX".

## Alternativas consideradas

- **No documentar:** el conocimiento queda solo en la memoria de quien decidió.
- **Wiki externa:** se desincroniza del código y no se revisa en los PRs.

## Consecuencias

- Cada decisión importante requiere unos minutos de escritura.
- El historial de decisiones queda versionado junto al código y se revisa en los PRs.
