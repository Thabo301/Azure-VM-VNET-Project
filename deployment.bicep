/*
================================================================================================================
Bicep Template for a Secure Azure Environment
================================================================================================================
Description:
This Infrastructure as Code (IaC) template deploys a complete, secure Azure environment.
It is designed to be deployed into a pre-existing resource group. The architecture includes:
- A Virtual Network with three segregated subnets (Bastion, Windows, Linux).
- A diagnostics Storage Account for VM boot logs.
- Two Network Security Groups (NSGs) with rules allowing RDP/SSH access only via Azure Bastion.
- An Azure Bastion host for secure, browser-based remote access.
- A Windows Server 2022 VM.
- An Ubuntu 22.04 LTS VM.

Author: Thabo M.
Project: Azure Secure VNet Lab
================================================================================================================
*/

// This template is designed to be deployed to an EXISTING resource group.
targetScope = 'resourceGroup'

// === PARAMETERS ===
// These are the inputs you would provide during deployment.

@description('The Azure region where the resources will be deployed. This MUST match the location of your existing Resource Group.')
param location string = 'southafricanorth'

@description('Administrator username for both the Windows and Linux VMs.')
param adminUsername string

@description('Administrator password for the VMs. Must meet Azure complexity requirements.')
@secure()
param adminPassword string

// === VARIABLES ===
// Defining all names in one place for consistency and easy updates.

var vnetName = 'project-2-vnet'
var bastionHostName = 'bastion-lab'
var windowsVmName = 'Windows-VM'
var linuxVmName = 'Linux-VM'
var windowsNsgName = 'nsg-windows'
var linuxNsgName = 'nsg-linux'

// Creates a unique and valid name for the diagnostics storage account based on the resource group's unique ID.
var diagStorageAccountName = 'diag${uniqueString(resourceGroup().id)}'

// === RESOURCES ===

// --- 1. Core Infrastructure ---

@description('A Storage Account for VM boot diagnostics, a best practice for monitoring.')
resource diagStorage 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: diagStorageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

@description('Network Security Group for the Windows Subnet to allow RDP only from the Bastion service.')
resource windowsNsg 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: windowsNsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowRDP_From_Bastion'
        properties: {
          priority: 300
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'AzureBastion' // Using the AzureBastion service tag is a key security feature.
          destinationPortRange: '3389'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

@description('Network Security Group for the Linux Subnet to allow SSH only from the Bastion service.')
resource linuxNsg 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: linuxNsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSSH_From_Bastion'
        properties: {
          priority: 300
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'AzureBastion'
          destinationPortRange: '22'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

@description('The main Virtual Network, containing three distinct subnets for network segregation.')
resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        // This subnet MUST be named 'AzureBastionSubnet' for the Bastion service to work.
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.0.0/27'
        }
      }
      {
        name: 'subnet-windows'
        properties: {
          addressPrefix: '10.0.1.0/24'
          // Attach the Windows NSG to this subnet to enforce its rules.
          networkSecurityGroup: {
            id: windowsNsg.id
          }
        }
      }
      {
        name: 'subnet-linux'
        properties: {
          addressPrefix: '10.0.2.0/24'
          // Attach the Linux NSG to this subnet to enforce its rules.
          networkSecurityGroup: {
            id: linuxNsg.id
          }
        }
      }
    ]
  }
}

// --- 2. Secure Access Components ---

@description('The Public IP Address required for the Azure Bastion Host.')
resource bastionPip 'Microsoft.Network/publicIpAddresses@2022-07-01' = {
  name: '${bastionHostName}-pip'
  location: location
  sku: {
    // Bastion requires a Standard SKU Public IP.
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

@description('The Azure Bastion Host, providing secure RDP/SSH access without exposing VMs to the public internet.')
resource bastionHost 'Microsoft.Network/bastionHosts@2022-07-01' = {
  name: bastionHostName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          // Connects the Bastion service to its dedicated subnet within the VNet.
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          publicIPAddress: {
            id: bastionPip.id
          }
        }
      }
    ]
  }
}

// --- 3. Virtual Machine Network Interfaces (NICs) ---

@description('The Network Interface for the Windows VM, connecting it to the protected Windows subnet.')
resource windowsNic 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: '${windowsVmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          // Connects the NIC to the 'subnet-windows'.
          subnet: {
            id: vnet.properties.subnets[1].id
          }
        }
      }
    ]
  }
}

@description('The Network Interface for the Linux VM, connecting it to the protected Linux subnet.')
resource linuxNic 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: '${linuxVmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          // Connects the NIC to the 'subnet-linux'.
          subnet: {
            id: vnet.properties.subnets[2].id
          }
        }
      }
    ]
  }
}

// --- 4. Virtual Machines ---

@description('The Windows Server 2022 Virtual Machine.')
resource windowsVm 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: windowsVmName
  location: location
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
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
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

@description('The Ubuntu 22.04 LTS Linux Virtual Machine.')
resource linuxVm 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  name: linuxVmName
  location: location
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
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts'
        version: 'latest'
      }
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
