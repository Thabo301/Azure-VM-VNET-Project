// This Bicep file is designed to be deployed to an EXISTING resource group.
targetScope = 'resourceGroup'

// === PARAMETERS ===
// These are the inputs needed for the deployment.
@description('The location of the resources. This MUST match the location of your existing resource group.')
param location string = 'southafricanorth'

@description('Administrator username for the VMs.')
param adminUsername string

@description('Administrator password for the VMs. Must be complex.')
@secure()
param adminPassword string

// === VARIABLES ===
// Defining all names in one place for easy management.
var vnetName = 'project-2-vnet'
var bastionHostName = 'bastion-lab'
var windowsVmName = 'Windows-VM'
var linuxVmName = 'Linux-VM'
var windowsNsgName = 'nsg-windows'
var linuxNsgName = 'nsg-linux'
var diagStorageAccountName = 'diag${uniqueString(resourceGroup().id)}'

// OS Image for Windows Server
var windowsOsImage = {
  publisher: 'MicrosoftWindowsServer'
  offer: 'WindowsServer'
  sku: '2022-datacenter-azure-edition'
  version: 'latest'
}

// OS Image for Ubuntu Linux
var linuxOsImage = {
  publisher: 'Canonical'
  offer: '0001-com-ubuntu-server-jammy'
  sku: '22_04-lts'
  version: 'latest'
}

// === RESOURCES ===

// 1. Diagnostics Storage Account
resource diagStorage 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: diagStorageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

// 2. Network Security Groups (NSGs)
resource windowsNsg 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: windowsNsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowRDP_From_Bastion'
        properties: {
          priority: 300, access: 'Allow', direction: 'Inbound', protocol: 'Tcp', sourcePortRange: '*', sourceAddressPrefix: 'AzureBastion', destinationPortRange: '3389', destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource linuxNsg 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: linuxNsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSSH_From_Bastion'
        properties: {
          priority: 300, access: 'Allow', direction: 'Inbound', protocol: 'Tcp', sourcePortRange: '*', sourceAddressPrefix: 'AzureBastion', destinationPortRange: '22', destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// 3. Virtual Network (and its subnets, with NSGs attached)
resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [ '10.0.0.0/16' ]
    }
    subnets: [
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.0.0/27'
        }
      }
      {
        name: 'subnet-windows'
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: windowsNsg.id
          }
        }
      }
      {
        name: 'subnet-linux'
        properties: {
          addressPrefix: '10.0.2.0/24'
          networkSecurityGroup: {
            id: linuxNsg.id
          }
        }
      }
    ]
  }
}

// 4. Public IP for Bastion
resource bastionPip 'Microsoft.Network/publicIpAddresses@2022-07-01' = {
  name: '${bastionHostName}-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// 5. Azure Bastion Host
resource bastionHost 'Microsoft.Network/bastionHosts@2022-07-01' = {
  name: bastionHostName
  location: location
  // Bastion needs to be deployed after the VNet exists
  dependsOn: [
    vnet
  ]
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet.properties.subnets[0].id // References the AzureBastionSubnet
          }
          publicIPAddress: {
            id: bastionPip.id
          }
        }
      }
    ]
  }
}

// 6. Network Interface (NIC) for Windows VM
resource windowsNic 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: '${windowsVmName}-nic'
  location: location
  dependsOn: [
    vnet
  ]
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet.properties.subnets[1].id // References the subnet-windows
          }
        }
      }
    ]
  }
}

// 7. Network Interface (NIC) for Linux VM
resource linuxNic 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: '${linuxVmName}-nic'
  location: location
  dependsOn: [
    vnet
  ]
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet.properties.subnets[2].id // References the subnet-linux
          }
        }
      }
    ]
  }
}

// 8. Windows Virtual Machine
resource windowsVm 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: windowsVmName
  location: location
  dependsOn: [
    windowsNic
  ]
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1s'
    }
    osProfile: {
      computerName: windowsVmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: windowsOsImage
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: windowsNic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: diagStorage.properties.primaryEndpoints.blob
      }
    }
  }
}

// 9. Linux Virtual Machine
resource linuxVm 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: linuxVmName
  location: location
  dependsOn: [
    linuxNic
  ]
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1s'
    }
    osProfile: {
      computerName: linuxVmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: linuxOsImage
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: linuxNic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: diagStorage.properties.primaryEndpoints.blob
      }
    }
  }
}
