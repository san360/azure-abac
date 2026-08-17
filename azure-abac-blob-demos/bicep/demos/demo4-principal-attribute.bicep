// DEMO 4 — Principal (custom security attribute) condition
// Grants Storage Blob Data Owner but allows READING a blob ONLY when the blob's Project index
// tag equals the caller's Microsoft Entra custom security attribute "abacdemo/Project".
// This shows a @Principal attribute matched against a @Resource attribute — access follows the
// USER's attribute, not a hard-coded value, so one condition serves many users.
//
// IMPORTANT: The custom security attribute itself is a Microsoft Entra directory object and
// CANNOT be created in Bicep. Run scripts/setup-principal-attribute.ps1 first (or alongside)
// to define the attribute and assign a value to the principal.
//
// Isolation: dedicated storage account + account-scoped role assignment.

@description('Object ID of the test user/principal to grant conditional access to.')
param testPrincipalId string

@allowed([
  'User'
  'Group'
  'ServicePrincipal'
])
param testPrincipalType string = 'User'

@description('Azure region.')
param location string = resourceGroup().location

@description('Suffix that keeps the storage account name globally unique.')
param nameSuffix string = uniqueString(resourceGroup().id, 'abac-demo4')

@description('Microsoft Entra custom security attribute set name.')
param attributeSet string = 'abacdemo'

@description('Microsoft Entra custom security attribute name.')
param attributeName string = 'Project'

var storageAccountName = toLower('abacd4${nameSuffix}')
var containerNames = [
  'data'
]

// Storage Blob Data Owner (tag read/write permissions are included in this role)
var roleDefinitionId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'

// Attribute reference key format is "<attributeSet>_<attributeName>".
var principalAttributeId = '${attributeSet}_${attributeName}'

// Single-quoted (interpolated) string because Bicep multi-line strings don't expand ${...}.
var condition = '((!(ActionMatches{\'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read\'} AND NOT SubOperationMatches{\'Blob.List\'})) OR (@Resource[Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags:Project<$key_case_sensitive$>] StringEquals @Principal[Microsoft.Directory/CustomSecurityAttributes/Id:${principalAttributeId}]))'

module storage '../modules/storageAccount.bicep' = {
  name: 'demo4-storage'
  params: {
    name: storageAccountName
    location: location
    containerNames: containerNames
  }
}

module roleAssignment '../modules/roleAssignmentWithCondition.bicep' = {
  name: 'demo4-roleAssignment'
  params: {
    storageAccountName: storageAccountName
    principalId: testPrincipalId
    principalType: testPrincipalType
    roleDefinitionId: roleDefinitionId
    condition: condition
    conditionDescription: 'Demo4: allow blob read only when tag Project equals principal attribute ${principalAttributeId}'
  }
  dependsOn: [
    storage
  ]
}

output storageAccountName string = storageAccountName
output containers array = containerNames
output principalAttributeId string = principalAttributeId
