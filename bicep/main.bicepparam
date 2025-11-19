using 'main.bicep'

param location = readEnvironmentVariable('AZURE_LOCATION', 'eastus2')
param environmentName = readEnvironmentVariable('AZURE_ENV_NAME', 'aca-demo')
param namePrefix = 'aca-demo'
param acrName = readEnvironmentVariable('AZURE_CONTAINER_REGISTRY_NAME', 'acr${take(uniqueString(environmentName), 10)}')
param webContainerImage = readEnvironmentVariable('SERVICE_WEB_IMAGE_NAME', 'angular-app:latest')
param tags = {
  environment: 'demo'
  project: 'azure-container-apps'
  createdBy: 'azd'
}
