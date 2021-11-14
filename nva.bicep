param location string = resourceGroup().location
param adminusername string = 'AzureAdmin'
param adminpassword string = 'MyP@ssword01'
param hubVnetID string

var vnetNvaname = 'nvaVnet'
var NvaaddressSpacePrefix = '10.4.0.0/16'
var vnetNvaSubnets = [
  {
    name: 'main'
    subnetPrefix: '10.4.0.0/24'
  }
]

resource nvaVnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: vnetNvaname
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        NvaaddressSpacePrefix
      ]
    }
    subnets: [for subnet in vnetNvaSubnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.subnetPrefix
      }
    }]
  }
}

resource spokeVnetPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-03-01' = {
  name: 'nvaVnet/hubVnet'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: true
    remoteVirtualNetwork: {
      id: hubVnetID
    }
  }
}

resource hubVnetPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-03-01' = {
  name: 'hubVnet/nvaVnet'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: nvaVnet.id
    }
  }
}

resource nsgNvavm 'Microsoft.Network/networkSecurityGroups@2020-11-01' = {
  name: 'nsgNvavm'
  location: location
  properties: {
    securityRules: []
  }
}

resource nicNvavm 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: 'nicNvavm${guid('nicNvavm', resourceGroup().id)}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${nvaVnet.id}/subnets/main'
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
    enableIPForwarding: true
    networkSecurityGroup: {
      id: nsgNvavm.id
    }
  }
}

resource vmNva 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: 'vmNva'
  location: location
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
        name: 'vmNva_OsDisk_${guid('vmNva', resourceGroup().id)}'
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
      computerName: 'vmNva'
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
          id: nicNvavm.id
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

resource symbolicname 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = {
  name: 'enableIPForwarding'
  location: location
  parent: vmNva
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    settings: {
      fileUris: [
        'uri(deployment().properties.templateLink.uri, 'LinuxRouter.sh')'
      ]
    }
    protectedSettings: {
      commandToExecute: 'sh LinuxRouter.sh'
    }
  }
}
