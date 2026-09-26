<#
.SYNOPSIS
    Crea el backend remoto del estado de Terraform.

.DESCRIPTION
    Crea rg-football-tfstate, una Storage Account endurecida y el contenedor tfstate.
    Es la única infraestructura que no gestiona Terraform: tiene que existir antes
    de que Terraform pueda guardar su estado.
    Es idempotente: se puede ejecutar varias veces sin efectos secundarios.

.EXAMPLE
    just bootstrap-tfstate
#>
$ErrorActionPreference = 'Stop'
# az.cmd ejecuta Python en modo aislado (-I) y escribe en la codificación ANSI de Windows:
# leemos su salida con esa misma codificación para que las tildes se vean bien.
[Console]::OutputEncoding = [System.Text.Encoding]::Default

$location      = 'eastus'
$resourceGroup = 'rg-football-tfstate'
$container     = 'tfstate'
$tags          = @('project=football-agent', 'layer=tfstate', 'managed-by=bootstrap', 'ephemeral=false')

# Ejecuta az y detiene el script si falla
function Invoke-Az {
    az @args
    if ($LASTEXITCODE -ne 0) {
        throw "Falló el comando: az $args"
    }
}

$subscriptionId   = Invoke-Az account show --query id --output tsv
$subscriptionName = Invoke-Az account show --query name --output tsv

# Sufijo determinista: los 4 primeros caracteres del SHA-256 del ID de la suscripción.
# Terraform calcula el mismo valor con substr(sha256(subscription_id), 0, 4).
$sha256 = [System.Security.Cryptography.SHA256]::Create()
$hash   = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($subscriptionId))
$suffix = (($hash | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0, 4)
$storageAccount = "stfootballtfstate$suffix"

Write-Host "Suscripción:     $subscriptionName"
Write-Host "Storage Account: $storageAccount"

Write-Host '1/5 Resource group...'
Invoke-Az group create --name $resourceGroup --location $location --tags @tags --output none

Write-Host '2/5 Storage Account...'
Invoke-Az storage account create `
    --name $storageAccount `
    --resource-group $resourceGroup `
    --location $location `
    --sku Standard_LRS `
    --kind StorageV2 `
    --min-tls-version TLS1_2 `
    --https-only true `
    --allow-blob-public-access false `
    --allow-shared-key-access false `
    --tags @tags `
    --output none

Write-Host '3/5 Versionado y soft-delete...'
Invoke-Az storage account blob-service-properties update `
    --account-name $storageAccount `
    --resource-group $resourceGroup `
    --enable-versioning true `
    --enable-delete-retention true `
    --delete-retention-days 30 `
    --enable-container-delete-retention true `
    --container-delete-retention-days 30 `
    --output none

Write-Host '4/5 Contenedor tfstate...'
# container-rm usa Azure Resource Manager (control plane): no necesita permisos de datos
$exists = Invoke-Az storage container-rm exists `
    --storage-account $storageAccount `
    --resource-group $resourceGroup `
    --name $container `
    --query exists --output tsv
if ($exists -ne 'true') {
    Invoke-Az storage container-rm create `
        --storage-account $storageAccount `
        --resource-group $resourceGroup `
        --name $container `
        --output none
}

Write-Host '5/5 Permiso de datos para tu usuario...'
$userId = Invoke-Az ad signed-in-user show --query id --output tsv
$scope  = Invoke-Az storage account show --name $storageAccount --resource-group $resourceGroup --query id --output tsv
Invoke-Az role assignment create `
    --assignee-object-id $userId `
    --assignee-principal-type User `
    --role 'Storage Blob Data Contributor' `
    --scope $scope `
    --output none

Write-Host ''
Write-Host 'Backend del estado listo. Configuración para Terraform:' -ForegroundColor Green
Write-Host "  resource_group_name  = `"$resourceGroup`""
Write-Host "  storage_account_name = `"$storageAccount`""
Write-Host "  container_name       = `"$container`""
Write-Host '  use_azuread_auth     = true'
Write-Host ''
Write-Host 'Nota: el permiso de datos puede tardar unos minutos en aplicarse.'
