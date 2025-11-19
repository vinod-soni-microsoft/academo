// Virtual Network with subnets for Container Apps and Private Endpoints
@description('Azure region for the virtual network')
param location string

@description('Name of the virtual network')
param vnetName string

@description('Tags to apply to resources')
param tags object = {}

@description('Virtual network address prefix')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Subnet address prefix for private endpoints')
param privateEndpointsSubnetPrefix string = '10.0.1.0/24'

@description('Subnet address prefix for container apps')
param containerAppsSubnetPrefix string = '10.0.2.0/23'

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-private-endpoints'
        properties: {
          addressPrefix: privateEndpointsSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'snet-container-apps'
        properties: {
          addressPrefix: containerAppsSubnetPrefix
        }
      }
    ]
  }
}

// Reference to the Container Apps subnet
resource containerAppsSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' existing = {
  parent: vnet
  name: 'snet-container-apps'
}

// Reference to the Private Endpoints subnet
resource privateEndpointsSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' existing = {
  parent: vnet
  name: 'snet-private-endpoints'
}

@description('Resource ID of the virtual network')
output vnetId string = vnet.id

@description('Name of the virtual network')
output vnetName string = vnet.name

@description('Resource ID of the Container Apps subnet')
output containerAppsSubnetId string = containerAppsSubnet.id

@description('Resource ID of the Private Endpoints subnet')
output privateEndpointsSubnetId string = privateEndpointsSubnet.id
