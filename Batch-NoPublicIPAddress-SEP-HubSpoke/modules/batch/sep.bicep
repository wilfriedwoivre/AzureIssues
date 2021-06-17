param prefix string

resource batchsep 'Microsoft.Network/serviceEndpointPolicies@2020-11-01' = {
  name: '${prefix}-batch-sep'
  location: resourceGroup().location
  properties: {
    serviceEndpointPolicyDefinitions:[
      {
        name: 'ExternalSubscription'
        properties:{
          service: 'Microsoft.Storage'
          serviceResources: [
            '/subscriptions/925a7a40-39eb-4723-9d60-9551f1fc80d2'
            '/subscriptions/65ca18f7-ea16-4cb4-87ef-28d7352519bf'
            '/subscriptions/e0b5f51c-493d-4fd0-b7fd-a9793ab44750'
            '/subscriptions/ab1880e6-46fc-4344-bbd8-fc3520237d01'
          ]
        }
      }
      
    ]
  }
}

resource currentsep 'Microsoft.Network/serviceEndpointPolicies@2020-11-01' = {
  name: '${prefix}-current-sep'
  location: resourceGroup().location
  properties: {
    serviceEndpointPolicyDefinitions: [
      {
        name: 'CurrentSubscription'
        properties: {
          service: 'Microsoft.Storage'
          serviceResources: [
            subscription().id
          ]
        }
      }
    ]
  }
}

output sepIds array = [
  batchsep.id
  currentsep.id
]
