// Azure Container Registry module
@description('Azure region for the registry')
param location string

@description('Name of the container registry')
param registryName string

@description('Tags to apply to resources')
param tags object = {}

@description('SKU for the container registry - must be Premium for private endpoints')
@allowed([
  'Premium'
])
param sku string = 'Premium'

@description('Resource ID of the subnet for private endpoint')
param privateEndpointSubnetId string

// Azure Container Registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: registryName
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Disabled'
    networkRuleBypassOptions: 'AzureServices'
    policies: {
      retentionPolicy: {
        status: 'disabled'
        days: 7
      }
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        status: 'disabled'
        type: 'Notary'
      }
    }
  }
}

// Private DNS Zone for ACR
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azurecr.io'
  location: 'global'
  tags: tags
}

// Private Endpoint for ACR
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: '${registryName}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${registryName}-plsc'
        properties: {
          privateLinkServiceId: containerRegistry.id
          groupIds: [
            'registry'
          ]
        }
      }
    ]
  }
}

// Private DNS Zone Group
resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-azurecr-io'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

@description('Resource ID of the Container Registry')
output registryId string = containerRegistry.id

@description('Name of the Container Registry')
output registryName string = containerRegistry.name

@description('Login server for the Container Registry')
output loginServer string = containerRegistry.properties.loginServer

@description('Private DNS Zone ID for ACR')
output privateDnsZoneId string = privateDnsZone.id

@description('Private Endpoint ID for ACR')
output privateEndpointId string = privateEndpoint.id
