param batchName string
param poolName string
param subnetId string
param vmSize string

resource pool 'Microsoft.Batch/batchAccounts/pools@2021-01-01' = {
  name: '${batchName}/${poolName}'
  properties:{
    displayName: poolName
    networkConfiguration:{
      publicIPAddressConfiguration:{
        provision: 'NoPublicIPAddresses'
      }
      subnetId: subnetId
    }
    deploymentConfiguration:{
      virtualMachineConfiguration: {
        imageReference: {
          publisher: 'microsoftwindowsserver'
          offer: 'windowsserver'
          sku: '2016-datacenter-smalldisk'
          version: 'latest'
        }
        nodeAgentSkuId: 'batch.node.windows amd64'
        windowsConfiguration: {
          enableAutomaticUpdates: false
        }
      }
    }
    vmSize: vmSize
    scaleSettings:{
      fixedScale:{
        targetDedicatedNodes: 1
        targetLowPriorityNodes: 0
        resizeTimeout: 'PT15M'
      }
    }
  }
}

