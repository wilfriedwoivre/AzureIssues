param prefix string
param azFwlIp string

var batchips = [
  '13.69.65.64/26'
  '13.69.106.128/26'
  '13.69.125.173/32'
  '13.73.153.226/32'
  '13.73.157.134/32'
  '13.80.117.88/32' 
  '13.81.1.133/32'  
  '13.81.59.254/32' 
  '13.81.63.6/32' 
  '13.81.104.137/32'
  '13.94.214.82/32' 
  '13.95.9.27/32'
  '20.50.1.64/26'
  '23.97.180.74/32'
  '40.68.100.153/32'
  '40.68.191.54/32'
  '40.68.218.90/32'
  '40.115.50.9/32'
  '52.166.19.45/32'
  '52.174.33.113/32'
  '52.174.34.69/32'
  '52.174.35.218/32'
  '52.174.38.99/32'
  '52.174.176.203/32'
  '52.174.179.66/32'
  '52.174.180.164/32'
  '52.233.157.9/32'
  '52.233.157.78/32'
  '52.233.161.238/32'
  '52.233.172.80/32'
  '52.236.186.128/26'
  '104.40.183.25/32'
  '104.45.13.8/32'
  '104.47.149.96/32'
  '137.116.193.225/32'
  '168.63.5.53/32'
  '191.233.76.85/32'
  '2603:1020:206:1::340/122'
]

resource route 'Microsoft.Network/routeTables@2020-11-01' = {
  name: '${prefix}-rot'
  location: resourceGroup().location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'DefaultRoute'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: azFwlIp
        }
      }
    ]
  }
}


resource batchRoute 'Microsoft.Network/routeTables/routes@2020-11-01' = [for (batchip,i) in batchips: {
  name: '${prefix}-rot/batch-${i}'
  properties: {
    addressPrefix: batchip
    nextHopType: 'Internet'
  }
  dependsOn: [
    route 
  ]
}]

output id string = route.id
