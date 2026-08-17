// DEMO 2 — Blob index tag condition
// Grants Storage Blob Data Owner (required for tag operations) but allows READING a blob
// ONLY when it carries the index tag Project=Cascade. Listing is always allowed because
// tags are not evaluated for the List sub-operation.
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
param nameSuffix string = uniqueString(resourceGroup().id, 'abac-demo2')

var storageAccountName = toLower('abacd2${nameSuffix}')
var containerNames = [
  'data'
]

// Storage Blob Data Owner (tag read/write permissions are included in this role)
var roleDefinitionId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'

var condition = '''
(
 (
  !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read'} AND NOT SubOperationMatches{'Blob.List'})
 )
 OR
 (
  @Resource[Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags:Project<$key_case_sensitive$>] StringEquals 'Cascade'
 )
)
'''

module storage '../modules/storageAccount.bicep' = {
  name: 'demo2-storage'
  params: {
    name: storageAccountName
    location: location
    containerNames: containerNames
  }
}

module roleAssignment '../modules/roleAssignmentWithCondition.bicep' = {
  name: 'demo2-roleAssignment'
  params: {
    storageAccountName: storageAccountName
    principalId: testPrincipalId
    principalType: testPrincipalType
    roleDefinitionId: roleDefinitionId
    condition: condition
    conditionDescription: 'Demo2: allow blob read only when tag Project=Cascade'
  }
  dependsOn: [
    storage
  ]
}

output storageAccountName string = storageAccountName
output containers array = containerNames
