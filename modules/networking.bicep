// === PARAMETERS ===
// These are the inputs that this module receives from main.bicep.
param location string
param vnetName string

// === RESOURCES ===
// These are the actual resources this module will create.

// The Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16' // The main address space for the entire VNet
      ]
    }
    // We define the three subnets here
    subnets: [
      {
        // This subnet MUST be named 'AzureBastionSubnet'
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: '10.0.0.0/27' // A small subnet just for Bastion
        }
      }
      {
        name: 'subnet-windows'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
      {
        name: 'subnet-linux'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
    ]
  }
}

// We create an output so other modules can find the VNet later.
output vnetId string = vnet.id
