# Shared helper for ABAC test scripts. Dot-sourced by test-demo*.ps1.
# Runs a data-plane action as the CURRENTLY signed-in identity and compares the
# outcome (allowed vs. denied) against what the ABAC condition should produce.

function Assert-Access {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('Allow', 'Deny')][string]$Expected,
        [Parameter(Mandatory)][scriptblock]$Action
    )

    $succeeded = $true
    try {
        & $Action *> $null
        if ($LASTEXITCODE -ne 0) { $succeeded = $false }
    }
    catch {
        $succeeded = $false
    }

    $actual = if ($succeeded) { 'Allow' } else { 'Deny' }
    $pass = $actual -eq $Expected
    $status = if ($pass) { 'PASS' } else { 'FAIL' }
    $color = if ($pass) { 'Green' } else { 'Red' }
    Write-Host ("[{0}] {1,-42} expected={2,-5} actual={3}" -f $status, $Name, $Expected, $actual) -ForegroundColor $color
    return $pass
}

function Write-TestHeader([string]$Title, [string]$Account) {
    Write-Host "`n=== $Title ===" -ForegroundColor Cyan
    Write-Host "Storage account: $Account" -ForegroundColor DarkGray
    $who = az ad signed-in-user show --query userPrincipalName -o tsv 2>$null
    if ($who) { Write-Host "Signed in as:    $who" -ForegroundColor DarkGray }
    Write-Host "All operations below use --auth-mode login (Microsoft Entra identity).`n" -ForegroundColor DarkGray
}
