<#
.SYNOPSIS
    Tests Demo 4 (principal custom security attribute condition) as the signed-in user.

.DESCRIPTION
    The condition allows reading a blob only when its Project tag equals the caller's
    custom security attribute abacdemo/Project. With the attribute set to "Cascade":
      - List "data" (list is never tag-filtered)     -> Allow
      - Download "cascade.txt" (tag Project=Cascade)  -> Allow  (matches principal attribute)
      - Download "baker.txt"   (tag Project=Baker)    -> Deny   (does not match)

    Run scripts/setup-principal-attribute.ps1 first and sign in AS THE TEST USER.

.EXAMPLE
    az login
    ./test-demo4.ps1 -StorageAccount <demo4-account-name>
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$StorageAccount
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot '_testHelper.ps1')
Write-TestHeader 'Demo 4 - principal attribute condition (abacdemo/Project == blob Project tag)' $StorageAccount

$out = Join-Path $env:TEMP 'abac-demo4.out'
$results = @()

$results += Assert-Access 'List data (list not tag-filtered)' 'Allow' {
    az storage blob list --account-name $StorageAccount --container-name data --auth-mode login -o none
}
$results += Assert-Access 'Download data/cascade.txt (matches principal)' 'Allow' {
    az storage blob download --account-name $StorageAccount --container-name data --name cascade.txt --file $out --auth-mode login --overwrite -o none
}
$results += Assert-Access 'Download data/baker.txt (no match)' 'Deny' {
    az storage blob download --account-name $StorageAccount --container-name data --name baker.txt --file $out --auth-mode login --overwrite -o none
}

Remove-Item $out -ErrorAction SilentlyContinue
$failed = ($results | Where-Object { -not $_ }).Count
Write-Host ("`nSummary: {0}/{1} checks passed." -f ($results.Count - $failed), $results.Count) -ForegroundColor $(if ($failed) { 'Red' } else { 'Green' })
exit $failed
