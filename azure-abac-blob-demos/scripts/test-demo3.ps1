<#
.SYNOPSIS
    Tests Demo 3 (blob path/prefix condition) as the currently signed-in user.

.DESCRIPTION
    Run this while logged in AS THE TEST USER (az login). Expected results:
      - List "docs" (list is never path-filtered)   -> Allow
      - Download "readonly/allowed.txt"             -> Allow
      - Download "private/secret.txt"               -> Deny

.EXAMPLE
    az login              # sign in as the test user
    ./test-demo3.ps1 -StorageAccount <demo3-account-name>
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$StorageAccount
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot '_testHelper.ps1')
Write-TestHeader 'Demo 3 - blob path/prefix condition (readonly/)' $StorageAccount

$out = Join-Path $env:TEMP 'abac-demo3.out'
$results = @()

$results += Assert-Access 'List docs (list not path-filtered)' 'Allow' {
    az storage blob list --account-name $StorageAccount --container-name docs --auth-mode login -o none
}
$results += Assert-Access 'Download docs/readonly/allowed.txt' 'Allow' {
    az storage blob download --account-name $StorageAccount --container-name docs --name readonly/allowed.txt --file $out --auth-mode login --overwrite -o none
}
$results += Assert-Access 'Download docs/private/secret.txt' 'Deny' {
    az storage blob download --account-name $StorageAccount --container-name docs --name private/secret.txt --file $out --auth-mode login --overwrite -o none
}

Remove-Item $out -ErrorAction SilentlyContinue
$failed = ($results | Where-Object { -not $_ }).Count
Write-Host ("`nSummary: {0}/{1} checks passed." -f ($results.Count - $failed), $results.Count) -ForegroundColor $(if ($failed) { 'Red' } else { 'Green' })
exit $failed
