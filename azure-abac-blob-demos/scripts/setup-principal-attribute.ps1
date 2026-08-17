<#
.SYNOPSIS
    Defines a Microsoft Entra custom security attribute and assigns it to a principal, so the
    Demo 4 @Principal ABAC condition has something to evaluate.

.DESCRIPTION
    Custom security attributes are Microsoft Entra directory objects and cannot be created in
    Bicep. This script (idempotently):
      1. Creates the attribute set (e.g., "abacdemo").
      2. Creates the custom security attribute definition (e.g., "Project", type String).
      3. Assigns a value (e.g., "Cascade") to the target principal.

    The condition references the attribute as "<attributeSet>_<attributeName>", e.g. abacdemo_Project.

.PREREQUISITES
    The signed-in user must hold these Microsoft Entra roles:
      - Attribute Definition Administrator  (to create the set/definition)
      - Attribute Assignment Administrator  (to assign a value to the principal)

.EXAMPLE
    ./setup-principal-attribute.ps1 -PrincipalObjectId <object-id> -AttributeValue Cascade
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PrincipalObjectId,
    [ValidateSet('users', 'servicePrincipals')][string]$PrincipalKind = 'users',
    [string]$AttributeSet = 'abacdemo',
    [string]$AttributeName = 'Project',
    [string]$AttributeValue = 'Cascade'
)

$ErrorActionPreference = 'Stop'
$graph = 'https://graph.microsoft.com/v1.0'

function Invoke-Graph {
    param([string]$Method, [string]$Url, [string]$BodyJson, [switch]$IgnoreConflict)
    # az writes to stderr for progress/errors; under $ErrorActionPreference='Stop' a 2>&1 merge
    # would throw before we can inspect the message, so relax it inside this function.
    $ErrorActionPreference = 'Continue'
    $tmp = $null
    $argsList = @('rest', '--method', $Method, '--url', $Url, '--headers', 'Content-Type=application/json')
    if ($BodyJson) {
        $tmp = New-TemporaryFile
        Set-Content -Path $tmp -Value $BodyJson -Encoding utf8
        $argsList += @('--body', "@$tmp")
    }
    $stderr = az @argsList 2>&1
    $code = $LASTEXITCODE
    if ($tmp) { Remove-Item $tmp -Force }
    if ($code -ne 0) {
        $text = ($stderr | Out-String)
        if ($IgnoreConflict -and ($text -match 'Conflict' -or $text -match 'already exists' -or $text -match 'ConflictingObjectExists')) {
            Write-Host "  already exists, continuing." -ForegroundColor DarkGray
            return
        }
        throw "Graph $Method $Url failed:`n$text"
    }
}

Write-Host "1) Creating attribute set '$AttributeSet'..." -ForegroundColor Cyan
$setBody = @{
    id                  = $AttributeSet
    description         = 'ABAC demo attribute set'
    maxAttributesPerSet = 25
} | ConvertTo-Json
Invoke-Graph -Method POST -Url "$graph/directory/attributeSets" -BodyJson $setBody -IgnoreConflict

Write-Host "2) Creating attribute definition '${AttributeSet}_${AttributeName}'..." -ForegroundColor Cyan
$defBody = @{
    attributeSet           = $AttributeSet
    description            = 'ABAC demo attribute'
    isCollection           = $false
    isSearchable           = $true
    name                   = $AttributeName
    status                 = 'Available'
    type                   = 'String'
    usePreDefinedValuesOnly = $false
} | ConvertTo-Json
Invoke-Graph -Method POST -Url "$graph/directory/customSecurityAttributeDefinitions" -BodyJson $defBody -IgnoreConflict

Write-Host "3) Assigning $AttributeName=$AttributeValue to $PrincipalKind/$PrincipalObjectId..." -ForegroundColor Cyan
$attrValue = [ordered]@{
    '@odata.type'                = '#Microsoft.DirectoryServices.CustomSecurityAttributeValue'
    "$AttributeName@odata.type"  = '#String'
    "$AttributeName"             = $AttributeValue
}
$assignBody = @{ customSecurityAttributes = @{ $AttributeSet = $attrValue } } | ConvertTo-Json -Depth 6
Invoke-Graph -Method PATCH -Url "$graph/$PrincipalKind/$PrincipalObjectId" -BodyJson $assignBody

Write-Host "`nDone. Condition attribute id: ${AttributeSet}_${AttributeName} = $AttributeValue" -ForegroundColor Green
Write-Host "Note: if you CHANGED an existing value, allow a few minutes for it to propagate," -ForegroundColor Yellow
Write-Host "      THEN run 'az login' again (fresh token) for the change to take effect." -ForegroundColor Yellow
Write-Host "      Storage caches principal attributes for the token lifetime, and a token minted" -ForegroundColor Yellow
Write-Host "      immediately after the change may still carry the old value." -ForegroundColor Yellow
