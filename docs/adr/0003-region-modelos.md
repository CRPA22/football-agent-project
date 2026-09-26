# ADR 0003: Región y modelos de Azure OpenAI

- **Estado:** Aceptada
- **Fecha:** 2026-09-26

## Contexto

El agente necesita dos modelos de Azure OpenAI:

- **Chat con tool calling:** decide qué tool usar (reglamento, API de football-data.org o cálculo) y redacta la respuesta. Una pregunta típica consume ~8.000 tokens de entrada y ~500 de salida, repartidos en 2 o más llamadas al modelo.
- **Embeddings:** convierten el PDF del reglamento y las preguntas en vectores para la búsqueda del RAG.

Requisitos: cuota suficiente, costo compatible con un presupuesto de ~5–10 USD/mes y un modelo con soporte durante la vida del proyecto.

Se verificó en `eastus` (2026-09-26):

| Modelo | Cuota GlobalStandard | Entrada (1M tokens) | Salida (1M tokens) | Retiro |
|---|---|---|---|---|
| `gpt-4.1-mini` (2025-04-14) | 5.000 K TPM | 0,40 USD | 1,60 USD | 2027-04-14 |
| `gpt-5.4-mini` (2026-03-17) | 1.000 K TPM | 0,75 USD | 4,50 USD | 2027-09-21 |
| `gpt-5-mini` (2025-08-07) | 1.000 K TPM | — | — | 2027-02-09 |
| `text-embedding-3-small` (1) | 1.000 K TPM | 0,02 USD | — | 2028-02-09 |

Fuentes: `az cognitiveservices model list`, `az cognitiveservices usage list` y la Azure Retail Prices API (`prices.azure.com`).

## Decisión

- **Región:** `eastus`.
- **Tipo de despliegue:** GlobalStandard.
- **Modelo de chat:** `gpt-4.1-mini`, versión `2025-04-14` (fijada).
- **Modelo de embeddings:** `text-embedding-3-small`, versión `1` (fijada).

El nombre y la versión de cada modelo son **parámetros de Bicep**, no valores escritos en el código.

## Alternativas consideradas

- **`gpt-5.4-mini`:** el más reciente y con soporte hasta septiembre de 2027, pero cuesta ~2 veces más en la entrada y ~3 en la salida. Además es un modelo de razonamiento: genera tokens de razonamiento que se cobran como salida y aumentan la latencia. Costo estimado: ~0,013 USD por pregunta frente a ~0,004 USD de `gpt-4.1-mini`.
- **`gpt-5-mini`:** se retira en febrero de 2027, antes que `gpt-4.1-mini`.
- **`text-embedding-3-large`:** más preciso, pero más caro y con vectores el doble de grandes (más almacenamiento en AI Search). Para un único PDF de reglas, `text-embedding-3-small` es suficiente.
- **Despliegue Standard (regional) o DataZone:** garantizan que los datos se procesan en una región o zona concreta, pero cuestan ~10 % más y tienen menos cuota. No hay requisitos de residencia: el proyecto maneja datos públicos de fútbol y un reglamento público.

## Consecuencias

**Positivas:**
- Costo estimado de ~2 USD/mes para ~500 preguntas (práctica y evaluaciones de CI), antes del descuento por entrada en caché.
- Latencia baja: `gpt-4.1-mini` no es un modelo de razonamiento.
- Cuota muy por encima de lo necesario (5.000 K TPM frente a unos pocos K TPM de uso real).

**Negativas (aceptadas):**
- **`gpt-4.1-mini` se retira el 2027-04-14.** Hay que migrar a otro modelo antes de esa fecha. **Tarea:** evaluar el reemplazo a partir de enero de 2027, validándolo con las evaluaciones de CI (Fase 5), y registrar el cambio en un ADR que reemplace a este.
- Con GlobalStandard, Azure puede procesar las peticiones en cualquier región; aceptable por no haber datos sensibles.
- Los precios y las fechas de retiro pueden cambiar: se revisan al planificar la migración.
