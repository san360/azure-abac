// DEMO 1 — Container name condition
// Grants Storage Blob Data Reader but allows reading blobs ONLY in "allowed-container".
// Reading/listing "blocked-container" is denied by the condition.
//
// Isolation: this demo uses its own dedicated storage account and a role assignment
// scoped to that account, so it never overlaps with demo 2 or demo 3.

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
param nameSuffix string = uniqueString(resourceGroup().id, 'abac-demo1')

var storageAccountName = toLower('abacd1${nameSuffix}')
var containerNames = [
  'allowed-container'
  'blocked-container'
]

// Storage Blob Data Reader
var roleDefinitionId = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'

var condition = '''
(
 (
  !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read'})
 )
 OR
 (
  @Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringEquals 'allowed-container'
 )
)
'''

module storage '../modules/storageAccount.bicep' = {
  name: 'demo1-storage'
  params: {
    name: storageAccountName
    location: location
    containerNames: containerNames
  }
}

module roleAssignment '../modules/roleAssignmentWithCondition.bicep' = {
  name: 'demo1-roleAssignment'
  params: {
    storageAccountName: storageAccountName
    principalId: testPrincipalId
    principalType: testPrincipalType
    roleDefinitionId: roleDefinitionId
    condition: condition
    conditionDescription: 'Demo1: allow blob read only in allowed-container'
  }
  dependsOn: [
    storage
  ]
}

output storageAccountName string = storageAccountName
output containers array = containerNames
