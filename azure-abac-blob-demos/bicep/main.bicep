// Orchestrator — deploys the ABAC demos into one resource group.
// Each demo provisions its OWN storage account and its OWN account-scoped role assignment,
// so the demos are fully isolated and their conditions never interact.
//
// Toggle individual demos with the deployDemoN switches. Demo 4 (principal attribute) is off by
// default because it requires a Microsoft Entra custom security attribute to exist first.

@description('Object ID of the test user/principal to grant conditional access to.')
param testPrincipalId string

@allowed([
  'User'
  'Group'
  'ServicePrincipal'
])
param testPrincipalType string = 'User'

@description('Azure region for all resources.')
param location string = resourceGroup().location

param deployDemo1 bool = true
param deployDemo2 bool = true
param deployDemo3 bool = true

@description('Demo 4 requires a Microsoft Entra custom security attribute (set up separately). Off by default.')
param deployDemo4 bool = false

module demo1 'demos/demo1-container-name.bicep' = if (deployDemo1) {
  name: 'abac-demo1'
  params: {
    testPrincipalId: testPrincipalId
    testPrincipalType: testPrincipalType
    location: location
  }
}

module demo2 'demos/demo2-blob-index-tags.bicep' = if (deployDemo2) {
  name: 'abac-demo2'
  params: {
    testPrincipalId: testPrincipalId
    testPrincipalType: testPrincipalType
    location: location
  }
}

module demo3 'demos/demo3-blob-path-prefix.bicep' = if (deployDemo3) {
  name: 'abac-demo3'
  params: {
    testPrincipalId: testPrincipalId
    testPrincipalType: testPrincipalType
    location: location
  }
}

module demo4 'demos/demo4-principal-attribute.bicep' = if (deployDemo4) {
  name: 'abac-demo4'
  params: {
    testPrincipalId: testPrincipalId
    testPrincipalType: testPrincipalType
    location: location
  }
}

output demo1StorageAccount string = demo1.?outputs.storageAccountName ?? ''
output demo2StorageAccount string = demo2.?outputs.storageAccountName ?? ''
output demo3StorageAccount string = demo3.?outputs.storageAccountName ?? ''
output demo4StorageAccount string = demo4.?outputs.storageAccountName ?? ''
