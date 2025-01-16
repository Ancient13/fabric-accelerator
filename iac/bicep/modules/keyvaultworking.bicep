
// Parameters
@description('Location where resources will be deployed. Defaults to resource group location')
param location string = resourceGroup().location

@description('Cost Centre tag that will be applied to all resources in this deployment')
param cost_centre_tag string

@description('System Owner tag that will be applied to all resources in this deployment')
param owner_tag string

@description('Subject Matter Expert (SME) tag that will be applied to all resources in this deployment')
param sme_tag string

@description('Key Vault name')
param keyvault_name string

@description('Create Purview ?')
param create_purview bool


@description('Object IDs for default access policies.')
param accessPolicyObjectIds array

// Variables
var suffix = uniqueString(resourceGroup().id)
var keyvault_uniquename = '${keyvault_name}-${suffix}'
@description('Specifies whether the key vault is a standard vault or a premium vault.')
var skuName = 'standard'

@description('Specifies the name of the secret that you want to create.')

var sqlAdminPassword = base64(uniqueString(resourceGroup().id, 'sqlAdminPassword'))


// Create Key Vault
resource keyvault 'Microsoft.KeyVault/vaults@2023-07-01' ={
  name: keyvault_uniquename
  location: location
  tags: {
    CostCentre: cost_centre_tag
    Owner: owner_tag
    SME: sme_tag
  }
  properties:{
    enabledForDeployment: true
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    tenantId: subscription().tenantId

    // Default Access Policies. Replace the ObjectID's with your user/group id
    accessPolicies: [
      for objectId in accessPolicyObjectIds: {
        tenantId: subscription().tenantId
        objectId: objectId
        permissions: { secrets: ['list', 'get', 'set'] }
      }
    ]
    sku: {
      name: skuName
      family: 'A'

    }
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Add secrets to the Key Vault
resource sqlAdminPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyvault
  name: 'sqlserver-admin-password'
  properties: {
    value: sqlAdminPassword
  }
}


output keyvault_name string = keyvault.name
