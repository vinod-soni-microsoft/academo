// Azure Container Apps Environment and Container App
@description('Azure region for resources')
param location string

@description('Name prefix for resources')
param namePrefix string

@description('Resource ID of the subnet for Container Apps')
param subnetId string

@description('Tags to apply to resources')
param tags object = {}

@description('Container image to deploy')
param containerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Azure Container Registry name for managed identity access')
param acrName string = ''

@description('CPU cores allocated to the container')
param cpuCore string = '0.25'

@description('Memory allocated to the container')
param memory string = '0.5Gi'

@description('Minimum number of replicas')
param minReplicas int = 1

@description('Maximum number of replicas')
param maxReplicas int = 3

// Log Analytics Workspace for Container Apps Environment
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-${namePrefix}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Azure Container Apps Environment with VNET integration
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: 'ace-${namePrefix}'
  location: location
  tags: tags
  properties: {
    vnetConfiguration: {
      infrastructureSubnetId: subnetId
    }
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
    zoneRedundant: false
  }
}

// Get reference to ACR if provided
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = if (!empty(acrName)) {
  name: acrName
}

// Assign AcrPull role to Container App managed identity
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(acrName)) {
  name: guid(acr.id, containerApp.id, 'acrpull')
  scope: acr
  properties: {
    principalId: containerApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalType: 'ServicePrincipal'
  }
}

// Container App with AngularJS application
resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ca-${namePrefix}'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    environmentId: containerAppsEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 80
        transport: 'auto'
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      registries: !empty(acrName) ? [
        {
          server: '${acrName}.azurecr.io'
          identity: 'system'
        }
      ] : []
    }
    template: {
      containers: [
        {
          name: 'angular-app'
          image: containerImage
          resources: {
            cpu: json(cpuCore)
            memory: memory
          }
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        rules: [
          {
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
}

@description('Resource ID of the Container Apps Environment')
output containerAppsEnvironmentId string = containerAppsEnvironment.id

@description('Name of the Container Apps Environment')
output containerAppsEnvironmentName string = containerAppsEnvironment.name

@description('Resource ID of the Container App')
output containerAppId string = containerApp.id

@description('Name of the Container App')
output containerAppName string = containerApp.name

@description('FQDN of the Container App')
output containerAppFqdn string = containerApp.properties.configuration.ingress.fqdn

@description('Log Analytics Workspace ID')
output logAnalyticsWorkspaceId string = logAnalytics.id

@description('Container image deployed')
output containerImageName string = containerImage
