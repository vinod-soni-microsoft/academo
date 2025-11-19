// Module to link Private DNS Zone to VNET (deploy in same RG as DNS zone)
@description('Name of the Private DNS Zone')
param privateDnsZoneName string

@description('Resource ID of the Virtual Network')
param vnetId string

@description('Tags to apply to resources')
param tags object = {}

// Link Private DNS Zone to VNET
resource vnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${privateDnsZoneName}/vnet-link-${uniqueString(vnetId)}'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

@description('Resource ID of the VNET link')
output vnetLinkId string = vnetLink.id
