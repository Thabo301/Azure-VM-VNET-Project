targetScope = 'resourceGroup'

// === PARAMETERS ===
param location string = 'southafricanorth'

// === VARIABLES ===
var vnetName = 'project-2-vnet'
var bastionHostName = 'bastion-lab'
var windowsNsgName = 'nsg-windows'
var linuxNsgName = 'nsg-linux'
// NEW: Define a unique name for the diagnostics storage account
var diagStorageAccountName = 'diag${uniqueString(resourceGroup().id)}'

var windowsSecurityRules = [
  {
    name: 'AllowRDP_From_Bastion'
    properties: {
      priority: 300, access: 'Allow', direction: 'Inbound', protocol: 'Tcp', sourcePortRange: '*', sourceAddressPrefix: 'AzureBastion', destinationPortRange: '3389', destinationAddressPrefix: '*'
    }
  }
]

var linuxSecurityRules = [
  {
    name: 'AllowSSH_From_Bastion'
    properties: {
      priority: 300, access: 'Allow', direction: 'Inbound', protocol: 'Tcp', sourcePortRange: '*', sourceAddressPrefix: 'AzureBastion', destinationPortRange: '22', destinationAddressPrefix: '*'
    }
  }
]

// === MODULES ===
// NEW: Deploy the diagnostics storage account first
module diagStorage 'modules/storage.bicep' = {
  name: 'DiagnosticsStorageDeployment'
  params: {
    location: location
    storageAccountName: diagStorageAccountName
  }
}

module windowsNsg 'modules/nsg.bicep' = {
  name: 'WindowsNsgDeployment'
  params: {
    location: location
    nsgName: windowsNsgName
    securityRules: windowsSecurityRules
  }
}

module linuxNsg 'modules/nsg.bicep' = {
  name: 'LinuxNsgDeployment'
  params: {
    location: location
    nsgName: linuxNsgName
    securityRules: linuxSecurityRules
  }
}

module networking 'modules/networking.bicep' = {
  name: 'NetworkingDeployment'
  params: {
    location: location
    vnetName: vnetName
    windowsNsgId: windowsNsg.outputs.nsgId
    linuxNsgId: linuxNsg.outputs.nsgId
  }
}

module bastion 'modules/bastion.bicep' = {
  name: 'BastionDeployment'
  dependsOn: [
    networking
  ]
  params: {
    location: location
    bastionHostName: bastionHostName
    vnetId: networking.outputs.vnetId
  }
}
