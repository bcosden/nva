
param location string = resourceGroup().location
param adminusername string = 'AzureAdmin'
param adminpassword string = 'MyP@ssword01'

var vnetHubname = 'hubVnet'
var addressSpacePrefix = '10.0.0.0/16'
var vnetHubSubnets = [
  {
    name: 'main'
    subnetPrefix: '10.0.0.0/24'
  }
  {
    name: 'GatewaySubnet'
    subnetPrefix: '10.0.100.0/26'
  }
  {
    name: 'AzureFirewallManagementSubnet'
    subnetPrefix: '10.0.101.0/26'
  }
  {
    name: 'AzureFirewallSubnet'
    subnetPrefix: '10.0.102.0/26'
  }
]

var hubVnetGwCfg = {
  gatewayName: 'hubVnetGw'
  gatewayPublicIPName: 'hubVnetGwPip'
  asn: 65502
  gatewaySku: 'VpnGw2AZ' 
  gatewayGen: 'Generation2'
}

resource hubVnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: vnetHubname
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressSpacePrefix
      ]
    }
    subnets: [for subnet in vnetHubSubnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.subnetPrefix
      }
    }]
  }
}

resource hubVnetGwPip 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: hubVnetGwCfg.gatewayPublicIPName
  location: location
  zones: [
    '1'
    '2'
    '3'
  ]
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource hubVnetGw 'Microsoft.Network/virtualNetworkGateways@2021-02-01' = {
  name: hubVnetGwCfg.gatewayName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'hubVnetipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${hubVnet.id}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: hubVnetGwPip.id
          }
        }
      }
    ]
    activeActive: false
    enableBgp: true
    bgpSettings: {
      asn: hubVnetGwCfg.asn
    }
    vpnType: 'RouteBased'
    gatewayType: 'Vpn'
    vpnGatewayGeneration: hubVnetGwCfg.gatewayGen
    sku: {
      name: hubVnetGwCfg.gatewaySku
      tier: hubVnetGwCfg.gatewaySku
    }
  }
}

resource fwmgmtPip 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
  name: 'fwmgmtPip'
  location: 'eastus'
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    ipTags: []
  }
}

resource fwpublicPip 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
  name: 'fwpublicPip'
  location: 'eastus'
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    ipTags: []
  }
}

resource hubFirewallPolicy 'Microsoft.Network/firewallPolicies@2021-03-01' = {
  name: 'hubFirewallPolicy'
  location: location
  dependsOn: [
    hubVnetGw
  ]
  properties: {
    sku: {
      tier: 'Standard'
    }
  threatIntelMode: 'Alert'
  }
}

resource hubFwPolicyApplicationGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2021-03-01' = {
  parent: hubFirewallPolicy
  name: 'DefaultApplicationRuleCollectionGroup'
  dependsOn: [
    hubFwPolicyNetworkGroup
    hubFirewall
  ]
  properties: {
    priority: 300
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'internet'
            protocols: [
              {
                protocolType: 'Http'
                port: 80
              }
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            fqdnTags: []
            webCategories: []
            targetFqdns: [
              '*'
            ]
            targetUrls: []
            terminateTLS: false
            sourceAddresses: [
              '*'
            ]
            destinationAddresses: []
            sourceIpGroups: []
          }
        ]
        name: 'apprule01'
        priority: 300
      }
    ]
  }
}

resource hubFwPolicyNetworkGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2021-03-01' = {
  parent: hubFirewallPolicy
  name: 'DefaultNetworkRuleCollectionGroup'
  properties: {
    priority: 200
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'ICMP'
            ipProtocols: [
              'ICMP'
            ]
            sourceAddresses: [
              '*'
            ]
            sourceIpGroups: []
            destinationAddresses: [
              '10.0.0.0/8'
            ]
            destinationIpGroups: []
            destinationFqdns: []
            destinationPorts: [
              '*'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'ssh'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              '*'
            ]
            sourceIpGroups: []
            destinationAddresses: [
              '10.0.0.0/16'
            ]
            destinationIpGroups: []
            destinationFqdns: []
            destinationPorts: [
              '22'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'rdp'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              '*'
            ]
            sourceIpGroups: []
            destinationAddresses: [
              '10.2.0.0/16'
              '10.3.0.0/16'
            ]
            destinationIpGroups: []
            destinationFqdns: []
            destinationPorts: [
              '3389'
            ]
          }
        ]
        name: 'collection01'
        priority: 100
      }
    ]
  }
}

resource hubFirewall 'Microsoft.Network/azureFirewalls@2021-03-01' = {
  name: 'hubFirewall'
  location: 'eastus'
  dependsOn: [
    hubVnet
    hubVnetGw
  ]
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    additionalProperties: {}
    ipConfigurations: [
      {
        name: 'primary'
        properties: {
          publicIPAddress: {
            id: fwpublicPip.id
          }
          subnet: {
            id: '${hubVnet.id}/subnets/AzureFirewallSubnet'
          }
        }
      }
    ]
    firewallPolicy: {
      id: hubFirewallPolicy.id
    }
    managementIpConfiguration: {
      name: 'management'
      properties: {
        publicIPAddress: {
          id: fwmgmtPip.id
        }
        subnet: {
          id: '${hubVnet.id}/subnets/AzureFirewallManagementSubnet'
        }
      }
    }
  }
}

resource nsgHubtestvm 'Microsoft.Network/networkSecurityGroups@2020-11-01' = {
  name: 'nsgHubtestvm'
  location: 'eastus'
  properties: {
    securityRules: []
  }
}

resource nicHubtestvm 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: 'nicHubtestvm${guid('nicHubtestvm', resourceGroup().id)}'
  location: 'eastus'
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: '10.0.0.4'
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${hubVnet.id}/subnets/main'
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    dnsSettings: {
      dnsServers: []
    }
    enableAcceleratedNetworking: true
    enableIPForwarding: false
    networkSecurityGroup: {
      id: nsgHubtestvm.id
    }
  }
}

resource vmHubtestvm 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: 'vmHubtestvm'
  location: 'eastus'
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
        version: 'latest'
      }
      osDisk: {
        osType: 'Linux'
        name: 'vmHubtestvm_OsDisk_${guid('vmHubtestvm', resourceGroup().id)}'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        diskSizeGB: 30
      }
      dataDisks: []
    }
    osProfile: {
      computerName: 'vmHubtestvm'
      adminUsername: adminusername
      adminPassword: adminpassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
        provisionVMAgent: true
        patchSettings: {
          patchMode: 'ImageDefault'
          assessmentMode: 'ImageDefault'
        }
      }
      secrets: []
      allowExtensionOperations: true
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicHubtestvm.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

output hubVnetGwid string = hubVnetGw.id
output hubVnetGwPeer string = hubVnetGw.properties.bgpSettings.bgpPeeringAddress
output hubVnetGwASN int = hubVnetGw.properties.bgpSettings.asn
output hubVnetGwIP string = hubVnetGwPip.properties.ipAddress
output hubVnetID string = hubVnet.id
