// Creates a role assignment WITH an ABAC condition, scoped to a single storage account.
// Scoping each demo's assignment to its own account keeps demos fully isolated from one another.

@description('Name of the existing storage account to scope the role assignment to.')
param storageAccountName string

@description('Object ID of the principal (user/group/service principal) receiving access.')
param principalId string

@allowed([
  'User'
  'Group'
  'ServicePrincipal'
])
@description('Type of the principal. Setting this avoids replication-delay errors.')
param principalType string = 'User'

@description('Built-in role definition GUID (e.g., Storage Blob Data Reader).')
param roleDefinitionId string

@description('The ABAC condition expression.')
param condition string

@description('Condition schema version. Current version is 2.0.')
param conditionVersion string = '2.0'

@description('Human-readable description of what the condition does.')
param conditionDescription string = ''

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, principalId, roleDefinitionId)
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: principalId
    principalType: principalType
    condition: condition
    conditionVersion: conditionVersion
    description: conditionDescription
  }
}

output roleAssignmentId string = roleAssignment.id
