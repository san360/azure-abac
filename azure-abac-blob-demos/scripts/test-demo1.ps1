<#
.SYNOPSIS
    Tests Demo 1 (container-name condition) as the currently signed-in user.

.DESCRIPTION
    Run this while logged in AS THE TEST USER (az login). Expected results:
      - List/read "allowed-container"  -> Allow
      - List/read "blocked-container"  -> Deny

.EXAMPLE
    az login              # sign in as the test user
    ./test-demo1.ps1 -StorageAccount <demo1-account-name>
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$StorageAccount
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot '_testHelper.ps1')
Write-TestHeader 'Demo 1 - container name condition' $StorageAccount

$out = Join-Path $env:TEMP 'abac-demo1.out'
$results = @()

$results += Assert-Access 'List allowed-container' 'Allow' {
    az storage blob list --account-name $StorageAccount --container-name allowed-container --auth-mode login -o none
}
$results += Assert-Access 'List blocked-container' 'Deny' {
    az storage blob list --account-name $StorageAccount --container-name blocked-container --auth-mode login -o none
}
$results += Assert-Access 'Download allowed-container/hello.txt' 'Allow' {
    az storage blob download --account-name $StorageAccount --container-name allowed-container --name hello.txt --file $out --auth-mode login --overwrite -o none
}
$results += Assert-Access 'Download blocked-container/hello.txt' 'Deny' {
    az storage blob download --account-name $StorageAccount --container-name blocked-container --name hello.txt --file $out --auth-mode login --overwrite -o none
}

Remove-Item $out -ErrorAction SilentlyContinue
$failed = ($results | Where-Object { -not $_ }).Count
Write-Host ("`nSummary: {0}/{1} checks passed." -f ($results.Count - $failed), $results.Count) -ForegroundColor $(if ($failed) { 'Red' } else { 'Green' })
exit $failed
