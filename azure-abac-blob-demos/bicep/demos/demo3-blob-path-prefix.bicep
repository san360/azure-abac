// DEMO 3 — Blob path/prefix condition
// Grants Storage Blob Data Reader but allows READING a blob ONLY when its path starts with
// "readonly/". Blobs under any other path (e.g., "private/") are denied. Listing is always
// allowed because the path is not evaluated for the List sub-operation.
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
param nameSuffix string = uniqueString(resourceGroup().id, 'abac-demo3')

var storageAccountName = toLower('abacd3${nameSuffix}')
var containerNames = [
  'docs'
]

// Storage Blob Data Reader
var roleDefinitionId = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'

var condition = '''
(
 (
  !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read'} AND NOT SubOperationMatches{'Blob.List'})
 )
 OR
 (
  @Resource[Microsoft.Storage/storageAccounts/blobServices/containers/blobs:path] StringStartsWith 'readonly/'
 )
)
'''

module storage '../modules/storageAccount.bicep' = {
  name: 'demo3-storage'
  params: {
    name: storageAccountName
    location: location
    containerNames: containerNames
  }
}

module roleAssignment '../modules/roleAssignmentWithCondition.bicep' = {
  name: 'demo3-roleAssignment'
  params: {
    storageAccountName: storageAccountName
    principalId: testPrincipalId
    principalType: testPrincipalType
    roleDefinitionId: roleDefinitionId
    condition: condition
    conditionDescription: 'Demo3: allow blob read only when path starts with readonly/'
  }
  dependsOn: [
    storage
  ]
}

output storageAccountName string = storageAccountName
output containers array = containerNames
