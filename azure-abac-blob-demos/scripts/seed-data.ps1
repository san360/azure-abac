<#
.SYNOPSIS
    Uploads the sample blobs used by each ABAC demo.

.DESCRIPTION
    Reads the storage account names from the 'main' deployment outputs and seeds each demo:
      Demo 1: a blob in "allowed-container" and one in "blocked-container".
      Demo 2: "cascade.txt" (tag Project=Cascade) and "baker.txt" (tag Project=Baker) in "data".
      Demo 3: "readonly/allowed.txt" and "private/secret.txt" in "docs".

    Uploads use Microsoft Entra identity (--auth-mode login) because the demo storage accounts
    disable shared-key access. The identity running this script must therefore hold an
    UNCONDITIONAL data-plane write role (Storage Blob Data Contributor or Owner) on the accounts.

    Pass -GrantSeederRole to temporarily assign the current user Storage Blob Data Owner at the
    resource group scope before seeding. IMPORTANT: if the seeder is also your ABAC test user,
    remove that assignment (or use a separate operator identity) before running the tests, or the
    unconditional role will mask the conditions.

.EXAMPLE
    ./seed-data.ps1 -ResourceGroup rg-abac-demo -GrantSeederRole
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ResourceGroup,
    [string]$DeploymentName = 'main',
    [switch]$GrantSeederRole
)

$ErrorActionPreference = 'Stop'

# Storage Blob Data Owner
$blobOwnerRoleId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'

function Set-SampleBlob {
    param(
        [string]$Account, [string]$Container,
        [string]$Name, [string]$Content, [string[]]$Tags
    )
    $tmp = New-TemporaryFile
    Set-Content -Path $tmp -Value $Content -NoNewline
    $azArgs = @(
        'storage', 'blob', 'upload',
        '--account-name', $Account, '--auth-mode', 'login',
        '--container-name', $Container, '--name', $Name,
        '--file', $tmp, '--overwrite', '--only-show-errors'
    )
    if ($Tags) { $azArgs += @('--tags') + $Tags }
    az @azArgs | Out-Null
    $code = $LASTEXITCODE
    Remove-Item $tmp -Force
    if ($code -ne 0) { throw "Upload failed for $Container/$Name (exit $code). Does the seeding identity have an unconditional Storage Blob Data Owner/Contributor role?" }
    Write-Host "  uploaded $Container/$Name" -ForegroundColor DarkGray
}

$outputs = az deployment group show -g $ResourceGroup -n $DeploymentName --query properties.outputs -o json | ConvertFrom-Json
$d1 = $outputs.demo1StorageAccount.value
$d2 = $outputs.demo2StorageAccount.value
$d3 = $outputs.demo3StorageAccount.value
$d4 = ''
if ($outputs.PSObject.Properties.Name -contains 'demo4StorageAccount') { $d4 = $outputs.demo4StorageAccount.value }

if ($GrantSeederRole) {
    $me = az ad signed-in-user show --query id -o tsv
    $rgId = az group show -n $ResourceGroup --query id -o tsv
    Write-Host "Granting current user temporary Storage Blob Data Owner at RG scope..." -ForegroundColor Cyan
    az role assignment create --assignee-object-id $me --assignee-principal-type User `
        --role $blobOwnerRoleId --scope $rgId --only-show-errors | Out-Null
    Write-Host "Waiting 120s for the role assignment to propagate to the data plane..." -ForegroundColor Yellow
    Start-Sleep -Seconds 120
}

if ($d1) {
    Write-Host "Seeding Demo 1 ($d1)..." -ForegroundColor Cyan
    Set-SampleBlob -Account $d1 -Container 'allowed-container' -Name 'hello.txt' -Content 'Readable: this container is allowed by the condition.'
    Set-SampleBlob -Account $d1 -Container 'blocked-container' -Name 'hello.txt' -Content 'Blocked: reading this container is denied by the condition.'
}

if ($d2) {
    Write-Host "Seeding Demo 2 ($d2)..." -ForegroundColor Cyan
    Set-SampleBlob -Account $d2 -Container 'data' -Name 'cascade.txt' -Content 'Tagged Project=Cascade -> readable.' -Tags @('Project=Cascade')
    Set-SampleBlob -Account $d2 -Container 'data' -Name 'baker.txt' -Content 'Tagged Project=Baker -> denied.' -Tags @('Project=Baker')
}

if ($d3) {
    Write-Host "Seeding Demo 3 ($d3)..." -ForegroundColor Cyan
    Set-SampleBlob -Account $d3 -Container 'docs' -Name 'readonly/allowed.txt' -Content 'Path readonly/ -> readable.'
    Set-SampleBlob -Account $d3 -Container 'docs' -Name 'private/secret.txt' -Content 'Path private/ -> denied.'
}

if ($d4) {
    Write-Host "Seeding Demo 4 ($d4)..." -ForegroundColor Cyan
    Set-SampleBlob -Account $d4 -Container 'data' -Name 'cascade.txt' -Content 'Tag Project=Cascade -> readable when principal attribute matches.' -Tags @('Project=Cascade')
    Set-SampleBlob -Account $d4 -Container 'data' -Name 'baker.txt' -Content 'Tag Project=Baker -> denied unless principal attribute is Baker.' -Tags @('Project=Baker')
}

Write-Host "`nSeeding complete." -ForegroundColor Green
if ($GrantSeederRole) {
    Write-Host "NOTE: The temporary Storage Blob Data Owner role is still assigned. If this identity" -ForegroundColor Yellow
    Write-Host "      is also your ABAC test user, remove it before testing so conditions apply." -ForegroundColor Yellow
}
