// Deploys an isolated storage account with one or more blob containers for an ABAC demo.
// StorageV2 + HNS disabled so blob index tag conditions are supported.

@description('Globally unique storage account name (3-24 lowercase alphanumeric chars).')
@minLength(3)
@maxLength(24)
param name string

@description('Azure region for the storage account.')
param location string

@description('Blob containers to create in this account.')
param containerNames array

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  tags: {
    SecurityControl: 'Ignore' // Corp-policy exemption so demo accounts can stay public; remove in production.
  }
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false // Enforce Microsoft Entra (identity-based) auth only.
    publicNetworkAccess: 'Enabled' // Demo reachable over public endpoint (tighten in production).
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    isHnsEnabled: false // Blob index tag conditions require hierarchical namespace disabled.
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
}

resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = [
  for c in containerNames: {
    parent: blobService
    name: c
    properties: {
      publicAccess: 'None'
    }
  }
]

output id string = storage.id
output name string = storage.name
