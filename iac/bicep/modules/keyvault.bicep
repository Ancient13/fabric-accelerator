
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

@description('Purview Account name')
param purview_account_name string

@description('Resource group of Purview Account')
param purviewrg string

@description('Object IDs for default access policies.')
param accessPolicyObjectIds array

// Variables

@description('Specifies whether the key vault is a standard vault or a premium vault.')
var skuName = 'standard'

@description('Specifies the name of the secret that you want to create.')

var sqlAdminPassword = base64(uniqueString(resourceGroup().id, 'sqlAdminPassword'))


// Create Key Vault
resource keyvault 'Microsoft.KeyVault/vaults@2023-07-01' ={
  name: keyvault_name
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

// Create Key Vault Access Policies for Purview
resource existing_purview_account 'Microsoft.Purview/accounts@2021-07-01' existing = {
  name: purview_account_name
  scope: resourceGroup(purviewrg)
}
  
resource this_keyvault_accesspolicy 'Microsoft.KeyVault/vaults/accessPolicies@2022-07-01' = {
  name: 'add'
  parent: keyvault
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: existing_purview_account.identity.principalId
        permissions: { secrets: ['list', 'get'] }
      }
    ]
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
