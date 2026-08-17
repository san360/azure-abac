<#
.SYNOPSIS
    Acquires an Azure AD access token for a target resource and prints it encoded + decoded,
    to demonstrate what is (and isn't) in the JWT when using ABAC.

.DESCRIPTION
    Key teaching points this script makes visible:
      - ABAC condition attributes (resource/request/environment) are NOT in the token.
      - Custom security attributes (principal attributes) are NOT token claims by default.
      - One token (audience = the service, e.g. https://storage.azure.com) authorizes ALL
        storage accounts, so the token is identical across Demo 1-4. The token changes by
        target service (audience), not by ABAC scenario.

.PARAMETER Resource
    The target resource/audience. Defaults to Azure Storage.

.PARAMETER Mask
    Redacts the raw token and sensitive claim values (oid/tid/upn/sub) so the output is safe
    to share. Omit -Mask to see the full token in YOUR OWN terminal.

.EXAMPLE
    ./inspect-token.ps1                 # full token (your terminal only) for Azure Storage
    ./inspect-token.ps1 -Mask           # safe-to-share, redacted
    ./inspect-token.ps1 -Resource https://vault.azure.net -Mask   # compare a Key Vault token
#>
[CmdletBinding()]
param(
    [string]$Resource = 'https://storage.azure.com',
    [switch]$Mask
)

$ErrorActionPreference = 'Stop'

function ConvertFrom-Base64Url([string]$s) {
    $s = $s.Replace('-', '+').Replace('_', '/')
    switch ($s.Length % 4) { 2 { $s += '==' } 3 { $s += '=' } }
    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($s))
}

function Hide-Value([string]$v) {
    if (-not $v) { return $v }
    if ($v.Length -le 6) { return '****' }
    return $v.Substring(0, 6) + '...(redacted)'
}

Write-Host "Acquiring access token for: $Resource" -ForegroundColor Cyan
$token = az account get-access-token --resource $Resource --query accessToken -o tsv
if ($LASTEXITCODE -ne 0 -or -not $token) { throw "Failed to acquire token." }

$parts = $token.Split('.')
if ($parts.Count -lt 2) { throw "Token is not a JWT (opaque token)." }

$header = ConvertFrom-Base64Url $parts[0] | ConvertFrom-Json
$payload = ConvertFrom-Base64Url $parts[1] | ConvertFrom-Json

# --- Encoded ---
Write-Host "`n===== ENCODED (JWT: header.payload.signature) =====" -ForegroundColor Yellow
if ($Mask) {
    $hPreview = $parts[0].Substring(0, [Math]::Min(16, $parts[0].Length)) + '...'
    $pPreview = '...' + $parts[1].Substring($parts[1].Length - 8)
    Write-Host "$hPreview.$pPreview.<signature redacted>"
    Write-Host "  header=$($parts[0].Length)B  payload=$($parts[1].Length)B  signature=$($parts[2].Length)B" -ForegroundColor DarkGray
    Write-Host "(run without -Mask in your own terminal to see the full token)" -ForegroundColor DarkGray
}
else {
    Write-Warning "The following is a LIVE bearer credential. Do not share or paste it anywhere."
    Write-Host $token
}

# --- Decoded header ---
Write-Host "`n===== DECODED HEADER =====" -ForegroundColor Yellow
$header | ConvertTo-Json

# --- Decoded payload ---
if ($Mask) {
    foreach ($c in 'oid', 'tid', 'sub', 'upn', 'unique_name', 'email', 'puid', 'ipaddr', 'name') {
        if ($payload.PSObject.Properties.Name -contains $c) { $payload.$c = Hide-Value ([string]$payload.$c) }
    }
}
Write-Host "`n===== DECODED PAYLOAD (claims) =====" -ForegroundColor Yellow
$payload | ConvertTo-Json -Depth 5

# --- ABAC-relevant analysis ---
Write-Host "`n===== ABAC CHECK =====" -ForegroundColor Yellow
Write-Host ("Audience (aud): {0}" -f $payload.aud)
Write-Host "-> One token for this audience authorizes ALL accounts/resources of the service."
$abacHints = $payload.PSObject.Properties.Name | Where-Object { $_ -match 'attribute|customsec|abac|xms_(csa|edov)' }
if ($abacHints) {
    Write-Host ("Attribute-like claims present: {0}" -f ($abacHints -join ', ')) -ForegroundColor Magenta
}
else {
    Write-Host "No custom-security-attribute / ABAC-condition claims are present in this token." -ForegroundColor Green
}
Write-Host "Claim names: $(( $payload.PSObject.Properties.Name | Sort-Object ) -join ', ')" -ForegroundColor DarkGray
