param location string = resourceGroup().location
param adminusername string = 'AzureAdmin'
param adminpassword string = 'MyP@ssword01'
param hubVnetID string

var vnetSpoke02name = 'spoke02Vnet'
var Spoke02addressSpacePrefix = '10.3.0.0/16'
var vnetSpoke02Subnets = [
  {
    name: 'main'
    subnetPrefix: '10.3.0.0/24'
  }
]

resource spoke02Vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: vnetSpoke02name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        Spoke02addressSpacePrefix
      ]
    }
    subnets: [for subnet in vnetSpoke02Subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.subnetPrefix
      }
    }]
  }
}

resource spokeVnetPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-03-01' = {
  name: 'spoke02Vnet/hubVnet'
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
  name: 'hubVnet/spoke02Vnet'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spoke02Vnet.id
    }
  }
}

resource nsgSpoke02vm 'Microsoft.Network/networkSecurityGroups@2020-11-01' = {
  name: 'nsgSpoke02vm'
  location: location
  properties: {
    securityRules: []
  }
}

resource nicSpoke02vm 'Microsoft.Network/networkInterfaces@2020-11-01' = {
  name: 'nicSpoke02vm${guid('nicSpoke02vm', resourceGroup().id)}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${spoke02Vnet.id}/subnets/main'
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
      id: nsgSpoke02vm.id
    }
  }
}

resource vmSpoke02 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: 'vmSpoke02'
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
        name: 'vmSpoke02_OsDisk_${guid('vmSpoke02', resourceGroup().id)}'
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
      computerName: 'vmSpoke02'
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
          id: nicSpoke02vm.id
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
  parent: vmSpoke02
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
