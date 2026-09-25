<#
.SYNOPSIS
    Registra en la suscripción activa los resource providers que usa el proyecto.

.DESCRIPTION
    Se ejecuta una vez por suscripción, antes del primer despliegue.
    Es idempotente: registrar un provider ya registrado no hace nada.

.EXAMPLE
    just bootstrap-providers
#>
$ErrorActionPreference = 'Stop'

$providers = @(
    'Microsoft.App',                  # Container Apps y Jobs
    'Microsoft.ContainerRegistry',    # ACR (imágenes Docker)
    'Microsoft.CognitiveServices',    # Azure OpenAI y Content Safety
    'Microsoft.Search',               # AI Search
    'Microsoft.DocumentDB',           # Cosmos DB
    'Microsoft.Storage',              # Blob Storage
    'Microsoft.KeyVault',             # Key Vault
    'Microsoft.ManagedIdentity',      # Managed Identities
    'Microsoft.OperationalInsights',  # Log Analytics
    'Microsoft.Insights',             # App Insights y alertas
    'Microsoft.Network',              # VNet y private endpoints
    'Microsoft.Consumption'           # Budgets
)

$subscription = az account show --query name --output tsv
if ($LASTEXITCODE -ne 0) {
    throw 'No hay sesión activa de Azure. Ejecuta: az login'
}
Write-Host "Suscripción: $subscription"

foreach ($provider in $providers) {
    Write-Host "Registrando $provider..."
    az provider register --namespace $provider --wait --output none
    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo registrar $provider"
    }
}

Write-Host 'Todos los resource providers están registrados.' -ForegroundColor Green
