// Main Bicep template for Azure Container Apps with VNET integration
targetScope = 'subscription'

@description('Azure region for all resources')
param location string = 'eastus'

@description('Name prefix for all resources')
param namePrefix string = 'aca-demo'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@description('Name for the Azure Container Registry')
param acrName string = 'acr${uniqueString(environmentName)}'

@description('Container image for the web service')
param webContainerImage string = ''

@description('Tags to apply to all resources')
param tags object = {
  environment: 'demo'
  project: 'azure-container-apps'
  'azd-env-name': environmentName
}

// Resource group for VNET and networking resources
resource rgVnet 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-vnet-aca-demo'
  location: location
  tags: tags
}

// Resource group for Azure Container Apps Environment
resource rgAce 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-ace-aca-demo'
  location: location
  tags: tags
}

// Deploy VNET and subnets in the first resource group
module vnetModule 'modules/vnet.bicep' = {
  scope: rgVnet
  params: {
    location: location
    vnetName: 'vnet-${namePrefix}'
    tags: tags
  }
}

// Deploy Azure Container Registry in the second resource group with private endpoint
module acrModule 'modules/acr.bicep' = {
  scope: rgAce
  params: {
    location: location
    registryName: acrName
    privateEndpointSubnetId: vnetModule.outputs.privateEndpointsSubnetId
    tags: tags
  }
}

// Link Private DNS Zone to VNET for ACR name resolution
module privateDnsZoneLink 'modules/dns-zone-link.bicep' = {
  scope: rgAce  // Deploy in same RG as DNS zone
  params: {
    privateDnsZoneName: 'privatelink.azurecr.io'
    vnetId: vnetModule.outputs.vnetId
    tags: tags
  }
}

// Deploy Azure Container Apps Environment and Container App in the second resource group
module acaModule 'modules/container-apps.bicep' = {
  scope: rgAce
  dependsOn: [
    privateDnsZoneLink
  ]
  params: {
    location: location
    namePrefix: namePrefix
    subnetId: vnetModule.outputs.containerAppsSubnetId
    containerImage: !empty(webContainerImage) ? webContainerImage : 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
    acrName: !empty(webContainerImage) ? acrModule.outputs.registryName : ''
    tags: tags
  }
}

// Outputs
@description('The name of the VNET resource group')
output vnetResourceGroupName string = rgVnet.name

@description('The name of the Container Apps resource group')
output containerAppsResourceGroupName string = rgAce.name

@description('The FQDN of the Container App')
output containerAppFqdn string = acaModule.outputs.containerAppFqdn

@description('The URL to access the application')
output applicationUrl string = 'https://${acaModule.outputs.containerAppFqdn}'

@description('Service endpoints for azd')
output SERVICE_WEB_ENDPOINT_URL string = 'https://${acaModule.outputs.containerAppFqdn}'

@description('Container App name for azd')
output SERVICE_WEB_NAME string = acaModule.outputs.containerAppName

@description('Container image name for azd')
output SERVICE_WEB_IMAGE_NAME string = acaModule.outputs.containerImageName

@description('Azure Container Registry name')
output AZURE_CONTAINER_REGISTRY_NAME string = acrModule.outputs.registryName

@description('Azure Container Registry login server')
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = acrModule.outputs.loginServer
