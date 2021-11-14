
param rgName string = 'networktest-rg'

targetScope = 'subscription'

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: deployment().location
}

module hubVnet 'hubVnet.bicep' = {
 name: 'hubVnet'
 scope: rg
}

module remoteVnet 'remoteVnet.bicep' = {
  name: 'remoteVnet'
  scope: rg
 }

 module linkHubRemote 'linkHubRemote.bicep' = {
  name: 'linkHubRemote'
  scope: rg
  params: {
    hubVnetGwPeer: hubVnet.outputs.hubVnetGwPeer
    hubVnetGwASN: hubVnet.outputs.hubVnetGwASN
    hubVnetGwIP: hubVnet.outputs.hubVnetGwIP
    hubVnetGWID: hubVnet.outputs.hubVnetGwid
    remoteVnetGwPeer: remoteVnet.outputs.remoteVnetGwPeer
    remoteVnetGwASN: remoteVnet.outputs.remoeVnetGwASN
    remoteVnetGwIP: remoteVnet.outputs.remoteVnetGwIP
    remoteVnetID: remoteVnet.outputs.remoteVnetGwid
  }
 }

 module spoke01 'spoke01.bicep' = {
  name: 'spoke01'
  scope: rg
  params: {
    hubVnetID: hubVnet.outputs.hubVnetID
  }
 }

 module spoke02 'spoke02.bicep' = {
  name: 'spoke02'
  scope: rg
  params: {
    hubVnetID: hubVnet.outputs.hubVnetID
  }
 }

 module Nva 'nva.bicep' = {
  name: 'Nva'
  scope: rg
  params: {
    hubVnetID: hubVnet.outputs.hubVnetID
  }
 }
