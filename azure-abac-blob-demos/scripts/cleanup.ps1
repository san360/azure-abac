<#
.SYNOPSIS
    Deletes the resource group and all demo resources.

.EXAMPLE
    ./cleanup.ps1 -ResourceGroup rg-abac-demo
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ResourceGroup
)

$ErrorActionPreference = 'Stop'
Write-Host "Deleting resource group '$ResourceGroup' (async)..." -ForegroundColor Yellow
az group delete --name $ResourceGroup --yes --no-wait
Write-Host "Delete requested. Role assignments are removed with the storage accounts." -ForegroundColor Green
