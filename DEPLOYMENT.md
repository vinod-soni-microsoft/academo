# Deployment Guide - Quick Reference

## Quick Deploy

```powershell
# 1. Login to Azure
az login
az account set --subscription "<your-subscription-id>"

# 2. Deploy
az deployment sub create `
  --name "aca-demo-deployment" `
  --location eastus `
  --template-file bicep/main.bicep `
  --parameters bicep/main.bicepparam

# 3. Get the URL
az containerapp show `
  --name ca-aca-demo `
  --resource-group rg-ace-aca-demo `
  --query "properties.configuration.ingress.fqdn" `
  --output tsv
```

## What Gets Deployed

### Resource Group: rg-vnet-aca-demo
- Virtual Network: `vnet-aca-demo`
  - Subnet: `snet-private-endpoints` (10.0.1.0/24)
  - Subnet: `snet-container-apps` (10.0.2.0/23) with delegation

### Resource Group: rg-ace-aca-demo
- Log Analytics Workspace: `log-aca-demo`
- Container Apps Environment: `ace-aca-demo` (VNET-integrated)
- Container App: `ca-aca-demo` (running AngularJS app)

## Expected Results

✅ Two resource groups created  
✅ VNET with proper subnet delegation  
✅ Container Apps Environment integrated with VNET  
✅ Container App accessible via HTTPS  
✅ AngularJS application running successfully  

Access your app at: `https://<container-app-fqdn>`

## Troubleshooting

If deployment fails, check:
1. Azure subscription has sufficient quota for Container Apps
2. Region supports Azure Container Apps
3. Bicep templates are valid: `az bicep build --file bicep/main.bicep`

View logs:
```powershell
az containerapp logs show `
  --name ca-aca-demo `
  --resource-group rg-ace-aca-demo `
  --follow
```

## Cleanup

```powershell
az group delete --name rg-vnet-aca-demo --yes --no-wait
az group delete --name rg-ace-aca-demo --yes --no-wait
```
