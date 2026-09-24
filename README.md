# Agente de Fútbol con Tools (Proyecto de Práctica Azure + IA)

Proyecto de aprendizaje para practicar el despliegue de agentes de IA **en producción** sobre Azure. El objetivo es construir el **mismo agente dos veces**, con dos enfoques distintos, para comparar arquitectura, control y costos.

## Qué hace el agente

Un asistente conversacional sobre fútbol con 3 tools:

1. **RAG (reglas del juego)**: responde preguntas sobre el reglamento oficial (offside, tarjetas, VAR, etc.) indexando el PDF de las Reglas de Juego 2025/26 en Azure AI Search + Azure OpenAI.
2. **API externa (datos en vivo)**: consulta resultados, tabla de posiciones y próximos partidos vía [football-data.org](https://www.football-data.org/documentation/quickstart) (free tier, 10 req/min).
3. **Función definida (lógica pura)**: cálculos deterministas sin llamar a ningún servicio externo. Por ejemplo: diferencia de goles necesaria para clasificar, puntos posibles restantes o simulación de tabla.

El modelo decide automáticamente qué tool usar según la pregunta del usuario (function calling / tool routing).

## Las dos versiones a construir

### Versión 1: Semantic Kernel (orquestación propia)
La orquestación del agente vive en tu propio código (Python en Azure Container Apps). Tú controlas el loop de decisión de tools.

### Versión 2: Azure AI Foundry Agent Service (managed)
La orquestación la gestiona el servicio de Azure. Tu API es solo un cliente delgado que llama al Agent Service.

**Se empieza por la Versión 1**, para entender a fondo el mecanismo de function calling antes de usar la versión "caja negra" administrada por Azure. Luego se migra la misma lógica a la Versión 2 para comparar.

## Decisiones

| Tema | Decisión |
|---|---|
| Lenguaje | Python (Semantic Kernel) |
| Host | Azure Container Apps (escala a 0) |
| Ramas | Solo `master` (trunk-based), con cambios vía PR |
| Entornos | Solo **prod**, efímero: se crea para cada sesión de práctica y se destruye al terminar |
| Pruebas antes de prod | Local (tests + emuladores) y gates de CI con evaluaciones del agente |
| Autenticación | Managed Identity + RBAC; el único secreto (API key de football-data.org) vive en Key Vault |
| IaC | Bicep |
| CI/CD | GitHub Actions con OIDC (sin secretos de Azure en GitHub) |
| Registro de imágenes | ACR Basic efímero (dentro de prod) |
| Presupuesto | ~5–7 USD/mes |

## Arquitectura de recursos

| Resource group | Vida | Contenido |
|---|---|---|
| `rg-football-shared` | Permanente | Key Vault, Log Analytics + App Insights, Managed Identities, budget |
| `rg-football-devsvc` | Permanente, sin cómputo | Azure OpenAI + AI Search Free, usados en local y en las evaluaciones de CI |
| `rg-football-prod` | **Efímero** | VNet, private endpoints, ACR Basic, Azure OpenAI, AI Search Basic, Cosmos DB, Storage, Container Apps + job de ingesta, Content Safety |

Lo que debe sobrevivir al teardown va en `shared`: el Key Vault (tiene soft-delete y guarda el secreto), la telemetría histórica y las identidades. El ACR es efímero: se cobra por día que existe, así que nace y muere con prod.

El detalle técnico (stack, diagramas, red, identidades, fases) está en [PLAN.md](PLAN.md).

## Desarrollo local

- `DefaultAzureCredential`: en local usa tu `az login` y en Azure la Managed Identity. El código es el mismo en ambos casos.
- `docker compose` con Azurite (Blob), el emulador de Cosmos DB y la API con el mismo `Dockerfile` de producción.
- Azure OpenAI y AI Search no tienen emulador: en local se usan los de `rg-football-devsvc`.
- El `.env` solo guarda configuración no sensible.

## CI/CD

| Workflow | Cuándo corre | Qué hace |
|---|---|---|
| `ci.yml` | En cada PR | Lint, tipos, tests, validación + `what-if` de Bicep, build de la imagen, evaluaciones del agente |
| `cd.yml` | Push a `master` | Construye y sube la imagen (etiquetada con el SHA). Si prod está encendido, despliega con canary, corre smoke tests y promueve o hace rollback |
| `prod-up.yml` | Manual | Crea la infraestructura de prod, corre la ingesta y despliega la última imagen |
| `prod-down.yml` | Manual y cada noche | Destruye prod y purga los recursos con soft-delete |

## Plan (Versión 1)

- [ ] **Fase 0: fundamentos.** Estructura del repo, `uv`, ruff, mypy, pre-commit, convenciones de nombres y tags, ADRs.
- [ ] **Fase 1: walking skeleton.** Bicep de `shared` y `devsvc`, agente de Semantic Kernel sin tools detrás de FastAPI, `docker compose`, OpenTelemetry y los workflows de CI/CD. El primer `prod-up` deja el agente vivo en Azure.
- [ ] **Fase 2: tool de cálculo.** Lógica pura, tests unitarios y property-based, primer set de evaluación.
- [ ] **Fase 3: tool de football-data.org.** Timeouts, reintentos, circuit breaker, caché con TTL en Cosmos DB, degradación elegante y tests de contrato.
- [ ] **Fase 4: RAG del reglamento.** Ingesta como Container Apps Job, chunking por regla, búsqueda híbrida + semantic ranker, índice versionado con alias, evaluación de retrieval.
- [ ] **Fase 5: agente endurecido.** Loop manual y luego automático, límites de iteraciones y tokens, historial en Cosmos DB, Content Safety y Prompt Shields, streaming, evaluaciones como gate de CI.
- [ ] **Fase 6: red privada de prod.** VNet, private endpoints y acceso público deshabilitado, autenticación con Entra ID en la API.
- [ ] **Fase 7: operación.** Dashboards, alertas, canary y rollback, prueba de carga y runbook.
- [ ] *(Opcional)* APIM como AI gateway.

Después vienen la migración a Azure AI Foundry Agent Service (Versión 2) y la comparación final de código, control y costos.

## Costos

| Concepto | Costo aproximado |
|---|---|
| Tokens de Azure OpenAI (local, CI y prod) | ~1–3 USD/mes |
| Sesión de prod (AI Search Basic + private endpoints por hora, ACR por día) | ~0,80 USD por sesión de 4 horas |

Controles: budget con alertas, límite diario en Log Analytics, `max_tokens` y límite de iteraciones en el agente, teardown nocturno de prod.
