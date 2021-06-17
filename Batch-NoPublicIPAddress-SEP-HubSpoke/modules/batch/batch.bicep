param prefix string

resource batch 'Microsoft.Batch/batchAccounts@2021-01-01' = {
  name: '${prefix}${substring(uniqueString(resourceGroup().name), 0, 6)}aba'
  location: resourceGroup().location
  properties: {
    poolAllocationMode: 'BatchService'
    publicNetworkAccess: 'Enabled'
  }
}

output name string = batch.name
output id string = batch.id
output batchKey string = listKeys(batch.id, batch.apiVersion).primary
