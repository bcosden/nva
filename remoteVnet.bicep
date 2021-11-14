
param location string = resourceGroup().location
param adminusername string = 'AzureAdmin'
param adminpassword string = 'MyP@ssword01'

var vnetRemotename = 'remoteVnet'
var addressSpacePrefix = '10.1.0.0/16'
var vnetRemoteSubnets = [
  {
    name: 'main'
    subnetPrefix: '10.1.0.0/24'
  }
  {
    name: 'GatewaySubnet'
    subnetPrefix: '10.1.100.0/26'
  }
  {
    name: 'AzureBastionSubnet'
    subnetPrefix: '10.1.200.0/26'
  }
]

var remoteVnetGwCfg = {
  gatewayName: 'remoteVnetGw'
  gatewayPublicIPName: 'remoteVnetGwPip'
  asn: 65510
  gatewaySku: 'VpnGw2AZ' 
  gatewayGen: 'Generation2'
}

resource remoteVnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: vnetRemotename
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressSpacePrefix
      ]
    }
    subnets: [for subnet in vnetRemoteSubnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.subnetPrefix
      }
    }]
  }
}

resource remoteVnetGwPip 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: remoteVnetGwCfg.gatewayPublicIPName
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

resource remoteVnetGw 'Microsoft.Network/virtualNetworkGateways@2021-02-01' = {
  name: remoteVnetGwCfg.gatewayName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'remoteVnetipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${remoteVnet.id}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: remoteVnetGwPip.id
          }
        }
      }
    ]
    activeActive: false
    enableBgp: true
    bgpSettings: {
      asn: remoteVnetGwCfg.asn
    }
    vpnType: 'RouteBased'
    gatewayType: 'Vpn'
    vpnGatewayGeneration: remoteVnetGwCfg.gatewayGen
    sku: {
      name: remoteVnetGwCfg.gatewaySku
      tier: remoteVnetGwCfg.gatewaySku
    }
  }
}

resource bastionPip 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: 'bastionPip'
  location: 'eastus'
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2021-02-01' = {
  name: 'bastionHost'
  location: 'eastus'
  sku: {
    name: 'Standard'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: bastionPip.id
          }
          subnet: {
            id: remoteVnet.properties.subnets[2].id
          }
        }
      }
    ]
  }
}

resource nsgRemotetestvm 'Microsoft.Network/networkSecurityGroups@2020-11-01' = {
  name: 'nsgRemotetestvm'
  location: 'eastus'
  properties: {
    securityRules: []
  }
}

resource nicRemotetestvm 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: 'nicRemotetestvm${guid('nicRemotetestvm', resourceGroup().id)}'
  location: 'eastus'
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: '10.1.0.4'
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${remoteVnet.id}/subnets/main'
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
      id: nsgRemotetestvm.id
    }
  }
}

resource vmRemotetestvm 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: 'vmRemotetestvm'
  location: 'eastus'
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-Datacenter'
        version: 'latest'
      }
      osDisk: {
        osType: 'Windows'
        name: 'vmRemotetestvm_OsDisk_${guid('vmRemotetestvm', resourceGroup().id)}'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        diskSizeGB: 127
      }
      dataDisks: []
    }
    osProfile: {
      computerName: 'vmRemotetestvm'
      adminUsername: adminusername
      adminPassword: adminpassword
      windowsConfiguration: {
        provisionVMAgent: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
          assessmentMode: 'ImageDefault'
        }
      }
      secrets: []
      allowExtensionOperations: true
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicRemotetestvm.id
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

resource customScript 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = {
  name: 'enableIcmp'
  location: location
  parent: vmRemotetestvm
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    settings: {
      commandToExecute: 'netsh.exe advfirewall firewall set rule group="File and Printer Sharing" new enable=yes'
    }
  }
}

output remoteVnetGwid string = remoteVnetGw.id
output remoteVnetGwPeer string = remoteVnetGw.properties.bgpSettings.bgpPeeringAddress
output remoeVnetGwASN int = remoteVnetGw.properties.bgpSettings.asn
output remoteVnetGwIP string = remoteVnetGwPip.properties.ipAddress
