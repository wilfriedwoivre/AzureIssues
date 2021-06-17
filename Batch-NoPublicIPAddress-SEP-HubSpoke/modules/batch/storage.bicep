param prefix string

resource stg 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: '${prefix}${substring(uniqueString(resourceGroup().name), 0, 4)}sta'
  location: resourceGroup().location
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
  }
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
}

output name string = stg.name
output id string = stg.id
output primaryKey string = listKeys(stg.id, stg.apiVersion).keys[0].value
