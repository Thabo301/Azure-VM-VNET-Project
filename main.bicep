// === TARGET SCOPE ===
// This tells Bicep that our deployment will create a resource group itself.
targetScope = 'subscription'

// === PARAMETERS ===
// These are the inputs for our deployment.
@description('The name of the resource group to create.')
param resourceGroupName string = 'project-2-rg'

@description('The location for all the resources.')
param location string = 'EastUS'

// === VARIABLES ===
// We define our resource names here for easy management.
var vnetName = 'project-2-vnet'
var bastionHostName = 'bastion-lab'

// === DEPLOYMENT ===
// This block creates the resource group first.
resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
}

// Now, we create a 'module'. Think of this as a sub-deployment
// that will create all the networking resources inside the new resource group.
module networking 'modules/networking.bicep' = {
  name: 'NetworkingDeployment'
  scope: resourceGroup // Deploys this module into the RG we just created
  params: {
    location: location
    vnetName: vnetName
  }
}