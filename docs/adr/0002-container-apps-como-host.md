# ADR 0002: Azure Container Apps como host del agente

- **Estado:** Aceptada
- **Fecha:** 2026-09-23

## Contexto

La API del agente (FastAPI + Semantic Kernel) necesita un host en Azure que cumpla estos requisitos:

- **Peticiones largas y con streaming:** un turno del agente puede encadenar varias llamadas al modelo y a las tools, y la respuesta se envía por Server-Sent Events.
- **Costo casi nulo sin tráfico:** es un proyecto de práctica con uso esporádico.
- **Integración con VNet:** en prod, los backends (Azure OpenAI, AI Search, Cosmos DB…) solo son accesibles por private endpoints.
- **Mismo artefacto en local y en prod:** la imagen Docker que se prueba en local es la que se despliega.
- **Despliegues seguros sin entorno dev:** hace falta canary y rollback, porque los cambios van directo a prod.
- **Tareas batch:** la ingesta del reglamento debe correr dentro de la misma red que la API.

## Decisión

Usar **Azure Container Apps** en un entorno con perfiles de carga de trabajo (*workload profiles*), perfil **Consumption** y **escala a 0**. La API corre como Container App y la ingesta como **Container Apps Job** dentro del mismo entorno.

## Alternativas consideradas

- **Azure Functions:** su modelo está pensado para funciones cortas disparadas por eventos, no para un servicio HTTP de larga duración como una app FastAPI. El plan serverless (Flex Consumption) no admite contenedores propios, así que no se podría usar el mismo `Dockerfile` en local y en prod. Además, no ofrece revisiones con reparto de tráfico para canary.
- **Azure App Service:** no escala a 0: el plan mínimo que admite integración con VNet (Basic) cuesta ~13 USD/mes aunque no haya tráfico, y los *deployment slots* para canary requieren el tier Standard, más caro.

## Consecuencias

**Positivas:**
- Costo ~0 sin tráfico, gracias a la escala a 0 y a la cuota gratuita mensual de Container Apps.
- Las revisiones con reparto de tráfico permiten canary y rollback sin infraestructura adicional.
- La misma imagen Docker corre en local, en CI y en prod.
- La API y el job de ingesta comparten entorno, red e identidad.

**Negativas (aceptadas):**
- **Cold start** de varios segundos en la primera petición tras escalar a 0. Mitigación: imagen pequeña y `minReplicas: 1` durante las sesiones si hace falta.
- Hay que mantener la imagen Docker (imagen base, parches de seguridad) y un registro de contenedores (ACR).
- Más conceptos que aprender que en una plataforma más simple: entorno, revisiones, ingress, scaling rules.
