param prefix string

resource loa 'Microsoft.OperationalInsights/workspaces@2020-10-01' = {
  name: '${prefix}-loa'
  location: resourceGroup().location
  properties:{
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}


output id string = loa.id
output workspaceId string = loa.properties.customerId
