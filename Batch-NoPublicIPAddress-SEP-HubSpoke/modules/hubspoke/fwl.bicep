param prefix string
param hubId string
param workspaceId string


var spokeAddressSpace = [
  '192.168.1.0/24'
  '10.0.0.0/23'
]
resource publicIp 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
  name: '${prefix}-fwl-ip'
  location: resourceGroup().location
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
  sku: {
    name: 'Standard'
  }
}

resource fwl 'Microsoft.Network/azureFirewalls@2020-11-01' = {
  name: '${prefix}-fwl'
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        name: '${prefix}-fwl-ipconf'
        properties: {
          subnet: {
            id: '${hubId}/subnets/AzureFirewallSubnet'
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    networkRuleCollections: [
      {
        name: 'standardrules'
        properties: {
          action: {
            type: 'Allow'
          }
          priority: 200
          rules: [
            {
              name: 'NTP'
              sourceAddresses: spokeAddressSpace
              protocols: [
                'UDP'
              ]
              destinationAddresses: [
                '*'
              ]
              destinationPorts: [
                '123'
              ]
            }
            {
              name: 'DNS'
              sourceAddresses: spokeAddressSpace
              protocols: [
                'TCP'
              ]
              destinationAddresses: [
                '*'
              ]
              destinationPorts: [
                '53'
              ]
            }
            {
              name: 'KMS'
              sourceAddresses: spokeAddressSpace
              protocols: [
                'TCP'
              ]
              destinationAddresses:[
                '23.102.135.246/32'
              ]
              destinationPorts:[
                '1688'
              ]
            }
          ]
        }
      }
    ]
    applicationRuleCollections: [
      {
        name: 'standardrules'
        properties: {
          action: {
            type: 'Allow'
          }
          priority: 200
          rules:[
            {
              name: 'tags'
              sourceAddresses: spokeAddressSpace
              protocols: [
                {
                  protocolType:'Http'
                  port: 80
                }
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              fqdnTags: [
                'WindowsDiagnostics'
                'WindowsUpdate'
                'AzureKubernetesService'
                'HDInsight'
                'AzureBackup'
              ]
            }
          ]
        }
      }
      {
        name: 'batch'
        properties: {
          action: {
            type: 'Allow'            
          }
          priority: 300
          rules: [
            {
              name: 'azuremanagement'
              sourceAddresses: spokeAddressSpace
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                'management.azure.com'
              ]
            }
            {
              name: 'batch'
              sourceAddresses: spokeAddressSpace
              protocols: [
                {
                  protocolType: 'Https'
                  port:443
                }
              ]
              targetFqdns: [
                '*.westeurope.batch.azure.com'
              ]
            }
          ]
        }
      }
    ]
  }
}

resource fwlDiagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'service'
  scope: fwl
  properties: {
    workspaceId: workspaceId
    logs:[
      {
        category: 'AzureFirewallApplicationRule'
        enabled: true
      }
      {
        category: 'AzureFirewallNetworkRule'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}


output privateIp string = fwl.properties.ipConfigurations[0].properties.privateIPAddress
