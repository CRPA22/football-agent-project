# ADR 0004: Terraform como herramienta de infraestructura como código

- **Estado:** Aceptada
- **Fecha:** 2026-09-26

## Contexto

Toda la infraestructura de Azure del proyecto debe definirse como código: prod se crea y se destruye en cada sesión de práctica (`prod-up` / `prod-down`), así que tiene que poder recrearse de forma idéntica, revisarse en PRs y previsualizarse antes de aplicarse.

Además del objetivo técnico, el proyecto es de aprendizaje con enfoque profesional: la herramienta elegida debe ser valiosa fuera de este proyecto.

Todavía no se había escrito código de infraestructura, así que elegir la herramienta ahora no tiene costo de migración.

## Decisión

Usar **Terraform** (lenguaje HCL) con:

- Providers `azurerm` (recursos de Azure) y `azuread` (identidad OIDC de GitHub en Entra ID). Versiones fijadas con `.terraform.lock.hcl`, que se sube al repo.
- **Estado remoto** en Azure Blob Storage (backend `azurerm`), en un resource group propio, `rg-football-tfstate`, creado por un script de bootstrap. Autenticación con Entra ID, sin access keys; bloqueo por lease; versionado de blobs y soft-delete.
- **Un estado por capa** (`shared`, `devsvc` y `prod`), cada una como un *root module* en `infra/stacks/`.
- En CI: `terraform fmt -check`, `terraform validate`, `tflint` y `terraform plan` en cada PR.

## Alternativas consideradas

- **Bicep:** nativo de Azure, más simple (sin estado que gestionar) y con soporte inmediato de los servicios nuevos. Se descarta porque solo sirve para Azure y tiene mucha menos demanda en el mercado laboral; tampoco puede gestionar recursos fuera de Azure, como la configuración de GitHub.
- **OpenTofu:** fork open source de Terraform, compatible con el mismo código HCL. Se elige Terraform por ser el más extendido; cambiar a OpenTofu más adelante requeriría cambios mínimos.
- **Pulumi:** usa lenguajes de programación generales (Python), pero su adopción es mucho menor.
- **HCP Terraform (Terraform Cloud) para el estado:** innecesario; Azure Storage + GitHub Actions cubren lo mismo sin otra cuenta ni otro proveedor.

## Consecuencias

**Positivas:**
- Conocimiento transferible a AWS y GCP (donde Terraform es la herramienta oficial de IaC).
- `terraform plan` muestra con precisión qué cambiará, y detecta cambios hechos a mano fuera de Terraform (*drift*).
- `terraform destroy` borra exactamente lo que Terraform creó, y el provider purga los recursos con soft-delete (Azure OpenAI, Content Safety) al destruirlos.
- Una sola herramienta para Azure y Entra ID, con la opción de gestionar también GitHub (rulesets, configuración del repo) más adelante.

**Negativas (aceptadas):**
- El **estado** es un activo crítico que hay que proteger: si se pierde o se corrompe, Terraform deja de saber qué gestiona. Mitigación: versionado de blobs, soft-delete, bloqueo por lease y acceso restringido por RBAC.
- El estado puede contener valores sensibles: nunca se sube al repo y solo lo leen tu usuario y la identidad de CI.
- El backend del estado debe crearse **antes** que Terraform (bootstrap por script): es la única pieza de infraestructura que no está en Terraform.
- Mayor curva de aprendizaje que Bicep (estado, backends, providers).
- Soporte de servicios nuevos de Azure a veces con retraso; se cubre con el provider `azapi` si hace falta.
- El ADR 0003 menciona "parámetros de Bicep": con esta decisión pasan a ser **variables de Terraform**. El resto del ADR 0003 sigue vigente.
