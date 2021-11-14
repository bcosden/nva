
param location string = resourceGroup().location

param hubVnetGwPeer string
param hubVnetGwASN int
param hubVnetGwIP string
param hubVnetGWID string
param remoteVnetGwPeer string
param remoteVnetGwASN int
param remoteVnetGwIP string
param remoteVnetID string

resource localRemoteGw 'Microsoft.Network/localNetworkGateways@2021-02-01' = {
  name: 'localRemoteGw'
  location: location
  properties: {
    bgpSettings: {
      asn: hubVnetGwASN
      bgpPeeringAddress: hubVnetGwPeer
    }
    gatewayIpAddress: hubVnetGwIP
    localNetworkAddressSpace: {
      addressPrefixes: [
        '${hubVnetGwPeer}/32'
      ]
    }
  }
}

resource localHubGw 'Microsoft.Network/localNetworkGateways@2021-02-01' = {
  name: 'localHubGw'
  location: location
  properties: {
    bgpSettings: {
      asn: remoteVnetGwASN
      bgpPeeringAddress: remoteVnetGwPeer
    }
    gatewayIpAddress: remoteVnetGwIP
    localNetworkAddressSpace: {
      addressPrefixes: [
        '${remoteVnetGwPeer}/32'
      ]
    }
  }
}

resource hubTOremoteConnect 'Microsoft.Network/connections@2021-02-01' = {
  name: 'hubTOremoteConnect'
  location: 'eastus'
  properties: {
    virtualNetworkGateway1: {
      id: hubVnetGWID
      properties: {
      }
    }
    localNetworkGateway2: {
      id: localHubGw.id
      properties: {
      }
    }
    connectionType: 'IPsec'
    connectionProtocol: 'IKEv2'
    sharedKey: 'mypresharedkey12093'
    routingWeight: 0
    enableBgp: true
    useLocalAzureIpAddress: false
    usePolicyBasedTrafficSelectors: false
    ipsecPolicies: []
    trafficSelectorPolicies: []
    expressRouteGatewayBypass: false
    dpdTimeoutSeconds: 45
    connectionMode: 'Default'
  }
}

resource remoteTOhubConnect 'Microsoft.Network/connections@2021-02-01' = {
  name: 'remoteTOhubConnect'
  location: 'eastus'
  properties: {
    virtualNetworkGateway1: {
      id: remoteVnetID
      properties: {
      }
    }
    localNetworkGateway2: {
      id: localRemoteGw.id
      properties: {
      }
    }
    connectionType: 'IPsec'
    connectionProtocol: 'IKEv2'
    sharedKey: 'mypresharedkey12093'
    routingWeight: 0
    enableBgp: true
    useLocalAzureIpAddress: false
    usePolicyBasedTrafficSelectors: false
    ipsecPolicies: []
    trafficSelectorPolicies: []
    expressRouteGatewayBypass: false
    dpdTimeoutSeconds: 45
    connectionMode: 'Default'
  }
}
