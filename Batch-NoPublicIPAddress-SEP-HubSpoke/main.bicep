targetScope = 'subscription'

param region string = 'westeurope'

resource hubrg 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: 'hub-rg'
  location: region
}

resource spokerg 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: 'spoke-rg'
  location: region
}

module hubVNET 'modules/hubspoke/vnet.bicep' = {
  name: 'hub-vnet'
  scope: resourceGroup(hubrg.name)
  params: {
    prefix: 'hub'
    addressSpaces: [
      '192.168.0.0/24'
    ]
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: '192.168.0.0/25'
        }
      }
    ]
  }
}

module spokeVNET 'modules/hubspoke/vnet.bicep' = {
  name: 'spoke-vnet'
  scope: resourceGroup(spokerg.name)
  params: {
    prefix: 'spoke'
    addressSpaces: [
      '192.168.1.0/24'
      '10.0.0.0/23'
    ]
    subnets: [
      {
        name: 'batch-rot-onlyfwl-subnet'
        properties: {
          addressPrefix: '10.0.0.0/27'
          routeTable: {
            id: routeHubSpoke.outputs.id
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
              locations: [
                '*'
              ]
            }
          ]
          serviceEndpointPolicies: [
            {
              id: sep.outputs.sepIds[0]
            }
            {
              id: sep.outputs.sepIds[1]
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'batch-rot-fwlandbatchnodemanagement-subnet'
        properties: {
          addressPrefix: '10.0.0.32/27'
          routeTable: {
            id: routeBatch.outputs.id
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
              locations: [
                '*'
              ]
            }
          ]
          serviceEndpointPolicies: [
            {
              id: sep.outputs.sepIds[0]
            }
            {
              id: sep.outputs.sepIds[1]
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

module hubLoa 'modules/hubspoke/loa.bicep' = {
  name: 'hub-loa'
  scope: resourceGroup(hubrg.name)
  params: {
    prefix: 'hub'
  }
}

module Hubfwl 'modules/hubspoke/fwl.bicep' = {
  name: 'hub-fwl'
  scope: resourceGroup(hubrg.name)
  params: {
    prefix: 'hub'
    hubId: hubVNET.outputs.id
    workspaceId: hubLoa.outputs.id
  }
}

module HubToSpokePeering 'modules/hubspoke/peering.bicep' = {
  name: 'hub-to-spoke-peering'
  scope: resourceGroup(hubrg.name)
  params: {
    localVnetName: hubVNET.outputs.name
    remoteVnetName: 'spoke'
    remoteVnetId: spokeVNET.outputs.id
  }
}

module SpokeToHubPeering 'modules/hubspoke/peering.bicep' = {
  name: 'spoke-to-hub-peering'
  scope: resourceGroup(spokerg.name)
  params: {
    localVnetName: spokeVNET.outputs.name
    remoteVnetName: 'hub'
    remoteVnetId: hubVNET.outputs.id
  }
}

module routeHubSpoke 'modules/hubspoke/rot.bicep' = {
  name: 'spoke-rot'
  scope: resourceGroup(spokerg.name)
  params: {
    prefix: 'spoke'
    azFwlIp: Hubfwl.outputs.privateIp
  }
}

module routeBatch 'modules/batch/rot.bicep' = {
  name: 'batch-rot'
  scope: resourceGroup(spokerg.name)
  params: {
    prefix: 'batch'
    azFwlIp: Hubfwl.outputs.privateIp
  }
}

module sep 'modules/batch/sep.bicep' = {
  name: 'batch-sep'
  scope: resourceGroup(spokerg.name)
  params: {
    prefix: 'spoke'
  }
}

module batch 'modules/batch/batch.bicep' = {
  name: 'batch'
  scope: resourceGroup(spokerg.name)
  params: {
    prefix: 'spokebatch'
  }
}


module workingpool 'modules/batch/pool.bicep' = {
  name: 'pool-rotfwl'
  dependsOn: [
    batch
  ]
  scope: resourceGroup(spokerg.name)
  params: {
    batchName: batch.outputs.name
    poolName: 'pool-fwl-rot'
    subnetId: '${spokeVNET.outputs.id}/subnets/batch-rot-onlyfwl-subnet'
    vmSize: 'Standard_D2_v3'
  }
}

module failedpool 'modules/batch/pool.bicep' = {
  name: 'pool-rotfwlbatch'
  dependsOn: [
    batch
  ]
  scope: resourceGroup(spokerg.name)
  params: {
    batchName: batch.outputs.name
    poolName: 'pool-fwlbatch-rot'
    subnetId: '${spokeVNET.outputs.id}/subnets/batch-rot-fwlandbatchnodemanagement-subnet'
    vmSize: 'Standard_D2_v3'
  }
}


module stg 'modules/batch/storage.bicep' = {
  name: 'spoke-stg'
  scope: resourceGroup(spokerg.name)
  params: {
    prefix: 'batchbug'
  }
}

output storageName string = stg.outputs.name
output storageKey string = stg.outputs.primaryKey
output batchName string = batch.outputs.name
output batchKey string = batch.outputs.batchKey

