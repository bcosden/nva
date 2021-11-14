param location string = resourceGroup().location
param adminusername string = 'AzureAdmin'
param adminpassword string = 'MyP@ssword01'
param hubVnetID string

var vnetSpoke01name = 'spoke01Vnet'
var Spoke01addressSpacePrefix = '10.2.0.0/16'
var vnetSpoke01Subnets = [
  {
    name: 'main'
    subnetPrefix: '10.2.0.0/24'
  }
]

resource spoke01Vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: vnetSpoke01name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        Spoke01addressSpacePrefix
      ]
    }
    subnets: [for subnet in vnetSpoke01Subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.subnetPrefix
      }
    }]
  }
}

resource spokeVnetPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-03-01' = {
  name: 'spoke01Vnet/hubVnet'
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
  name: 'hubVnet/spoke01Vnet'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spoke01Vnet.id
    }
  }
}

resource nsgSpoke01vm 'Microsoft.Network/networkSecurityGroups@2020-11-01' = {
  name: 'nsgSpoke01vm'
  location: location
  properties: {
    securityRules: []
  }
}

resource nicSpoke01vm 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: 'nicSpoke01vm${guid('nicSpoke01vm', resourceGroup().id)}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${spoke01Vnet.id}/subnets/main'
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
      id: nsgSpoke01vm.id
    }
  }
}

resource vmSpoke01 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: 'vmSpoke01'
  location: location
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
        name: 'vmSpoke01_OsDisk_${guid('vmSpoke01', resourceGroup().id)}'
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
      computerName: 'vmSpoke01'
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
          id: nicSpoke01vm.id
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
  parent: vmSpoke01
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    settings: {
      fileUris: [
        'https://raw.githubusercontent.com/bcosden/nva/master/EnableIcmp.ps1'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell EnableIcmp.ps1'
    }
  }
}
