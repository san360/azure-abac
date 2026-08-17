<#
.SYNOPSIS
    Deploys the Azure ABAC blob-storage demos into a resource group.

.DESCRIPTION
    Creates the resource group (if needed) and deploys bicep/main.bicep, which provisions
    three isolated demos (each with its own storage account + conditional role assignment).

.EXAMPLE
    ./deploy.ps1 -ResourceGroup rg-abac-demo -Location eastus -TestPrincipalId <object-id>

.NOTES
    The signed-in identity needs permission to create role assignments
    (Owner, User Access Administrator, or Role Based Access Control Administrator)
    at the resource group scope.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ResourceGroup,
    [string]$Location = 'eastus',
    [Parameter(Mandatory)][string]$TestPrincipalId,
    [ValidateSet('User', 'Group', 'ServicePrincipal')][string]$TestPrincipalType = 'User'
)

$ErrorActionPreference = 'Stop'
$templateFile = Join-Path $PSScriptRoot '..\bicep\main.bicep'

Write-Host "Creating resource group '$ResourceGroup' in '$Location'..." -ForegroundColor Cyan
az group create --name $ResourceGroup --location $Location | Out-Null

Write-Host "Deploying ABAC demos (deployment name: 'main')..." -ForegroundColor Cyan
$outputsJson = az deployment group create `
    --resource-group $ResourceGroup `
    --name main `
    --template-file $templateFile `
    --parameters testPrincipalId=$TestPrincipalId testPrincipalType=$TestPrincipalType location=$Location `
    --query properties.outputs -o json

if ($LASTEXITCODE -ne 0) { throw "Deployment failed." }

$outputs = $outputsJson | ConvertFrom-Json

Write-Host "`nDeployment complete." -ForegroundColor Green
Write-Host "Demo 1 (container-name)  storage account: $($outputs.demo1StorageAccount.value)"
Write-Host "Demo 2 (blob-index-tags) storage account: $($outputs.demo2StorageAccount.value)"
Write-Host "Demo 3 (blob-path-prefix) storage account: $($outputs.demo3StorageAccount.value)"
if ($outputs.PSObject.Properties.Name -contains 'demo4StorageAccount' -and $outputs.demo4StorageAccount.value) {
    Write-Host "Demo 4 (principal-attr)  storage account: $($outputs.demo4StorageAccount.value)"
}
Write-Host "`nNext: run ./seed-data.ps1 -ResourceGroup $ResourceGroup to upload sample blobs." -ForegroundColor Yellow
Write-Host "Role assignments can take a few minutes to propagate before tests pass." -ForegroundColor Yellow
