// === PARAMETERS ===
param location string
param storageAccountName string

// === RESOURCE ===
// Creates a standard, general-purpose storage account
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}
