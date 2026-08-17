<#
.SYNOPSIS
    Tests Demo 2 (blob index tag condition) as the currently signed-in user.

.DESCRIPTION
    Run this while logged in AS THE TEST USER (az login). Expected results:
      - List "data" (list is never tag-filtered)  -> Allow
      - Download "cascade.txt" (Project=Cascade)   -> Allow
      - Download "baker.txt"   (Project=Baker)     -> Deny

.EXAMPLE
    az login              # sign in as the test user
    ./test-demo2.ps1 -StorageAccount <demo2-account-name>
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$StorageAccount
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot '_testHelper.ps1')
Write-TestHeader 'Demo 2 - blob index tag condition (Project=Cascade)' $StorageAccount

$out = Join-Path $env:TEMP 'abac-demo2.out'
$results = @()

$results += Assert-Access 'List data (list not tag-filtered)' 'Allow' {
    az storage blob list --account-name $StorageAccount --container-name data --auth-mode login -o none
}
$results += Assert-Access 'Download data/cascade.txt (Cascade)' 'Allow' {
    az storage blob download --account-name $StorageAccount --container-name data --name cascade.txt --file $out --auth-mode login --overwrite -o none
}
$results += Assert-Access 'Download data/baker.txt (Baker)' 'Deny' {
    az storage blob download --account-name $StorageAccount --container-name data --name baker.txt --file $out --auth-mode login --overwrite -o none
}

Remove-Item $out -ErrorAction SilentlyContinue
$failed = ($results | Where-Object { -not $_ }).Count
Write-Host ("`nSummary: {0}/{1} checks passed." -f ($results.Count - $failed), $results.Count) -ForegroundColor $(if ($failed) { 'Red' } else { 'Green' })
exit $failed
