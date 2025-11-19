# Azure Container Apps with Secure ACR - Bicep Template

This project demonstrates deploying an AngularJS web application to Azure Container Apps with full VNET integration and secure Azure Container Registry (ACR) using private endpoints.

## 🏗️ Architecture Overview

The solution provisions the following Azure resources:

### Resource Groups
1. **rg-vnet-aca-demo**: Contains networking and registry resources
   - Virtual Network (VNET) with 10.0.0.0/16 address space
   - Two subnets:
     - `snet-private-endpoints` (10.0.1.0/24): Hosts Private Endpoints for ACR
     - `snet-container-apps` (10.0.2.0/23): Dedicated subnet for Container Apps
   - Azure Container Registry (Premium SKU)
   - Private Endpoint for ACR
   - Private DNS Zone (privatelink.azurecr.io)
   - DNS Zone VNET Link

2. **rg-ace-aca-demo**: Contains Azure Container Apps resources
   - Azure Container Apps Environment (VNET-integrated)
   - Log Analytics Workspace
   - Container App with system-assigned managed identity
   - Container App running AngularJS application

### Security Features
- 🔒 **Private ACR**: Public network access disabled, admin credentials disabled
- 🔒 **Private Endpoint**: ACR accessible only within VNET via private endpoint
- 🔒 **Managed Identity**: Container App authenticates to ACR using system-assigned identity
- 🔒 **RBAC**: AcrPull role automatically assigned to Container App identity
- 🔒 **Private DNS**: Name resolution for ACR via private DNS zone
- 🔒 **Network Isolation**: All ACR traffic stays within Azure backbone

### Key Features
- ✅ VNET-integrated Azure Container Apps Environment
- ✅ Premium Azure Container Registry with private endpoint
- ✅ Secure authentication using managed identities (no passwords)
- ✅ Automated CI/CD with GitHub Actions
- ✅ Log Analytics integration for monitoring
- ✅ Auto-scaling configuration (1-3 replicas)
- ✅ HTTPS ingress with external access
- ✅ Sample AngularJS web application

## 📁 Project Structure

```
.
├── bicep/
│   ├── main.bicep                    # Main deployment template (subscription scope)
│   ├── main.bicepparam               # Parameters file
│   └── modules/
│       ├── vnet.bicep                # VNET and subnets module
│       ├── acr.bicep                 # Azure Container Registry with private endpoint
│       ├── dns-zone-link.bicep       # Private DNS zone VNET linking
│       └── container-apps.bicep      # Container Apps with managed identity
├── app/
│   ├── index.html                    # AngularJS application
│   ├── Dockerfile                    # Container image definition
│   └── .dockerignore                 # Docker ignore file
├── .github/
│   └── workflows/
│       ├── infrastructure.yml        # Infrastructure deployment workflow
│       ├── build-and-deploy.yml      # Application build and deployment workflow
│       └── README.md                 # Workflow setup instructions
├── azure.yaml                        # Azure Developer CLI configuration
└── README.md                         # This file
```

## 🚀 Prerequisites

Before deploying, ensure you have:

1. **Azure CLI** installed ([Download](https://docs.microsoft.com/cli/azure/install-azure-cli))
2. **Azure Developer CLI (azd)** installed ([Download](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd))
3. **Azure subscription** with appropriate permissions (Contributor role)
4. **GitHub account** (for CI/CD automation)
5. **Git** installed

## 📋 Deployment Options

### Option 1: Deploy with Azure Developer CLI (azd) - Recommended

This is the fastest way to deploy everything:

```powershell
# Login to Azure
azd auth login

# Initialize and deploy (first time)
azd up

# Or deploy infrastructure and app separately
azd provision  # Deploy infrastructure
azd deploy     # Deploy application
```

The `azd up` command will:
1. Deploy all Bicep templates
2. Build the Docker image
3. Push image to ACR
4. Update Container App with the new image

### Option 2: Deploy with Azure CLI

#### Step 1: Login to Azure

```powershell
az login
az account set --subscription "<your-subscription-id>"
```

#### Step 2: Deploy Infrastructure

```powershell
az deployment sub create `
  --name "aca-demo-deployment" `
  --location eastus2 `
  --template-file bicep/main.bicep `
  --parameters bicep/main.bicepparam
```

The deployment creates:
- 2 resource groups
- VNET with 2 subnets
- Premium ACR with private endpoint
- Private DNS zone and VNET link
- Container Apps Environment
- Container App with managed identity

#### Step 3: Build and Push Docker Image

```powershell
# Get ACR name from deployment output
$acrName = az deployment sub show `
  --name "aca-demo-deployment" `
  --query "properties.outputs.acrName.value" `
  --output tsv

# Build and push image using ACR Tasks
az acr build `
  --registry $acrName `
  --image angular-app:latest `
  ./app
```

**Note**: If your ACR has public access disabled, you may need to temporarily enable it:
```powershell
az acr update --name $acrName --public-network-enabled true
az acr build --registry $acrName --image angular-app:latest ./app
az acr update --name $acrName --public-network-enabled false
```

#### Step 4: Update Container App

```powershell
az containerapp update `
  --name ca-aca-demo `
  --resource-group rg-ace-aca-demo `
  --image "$acrName.azurecr.io/angular-app:latest"
```

#### Step 5: Get Application URL

```powershell
$fqdn = az containerapp show `
  --name ca-aca-demo `
  --resource-group rg-ace-aca-demo `
  --query "properties.configuration.ingress.fqdn" `
  --output tsv

Write-Host "Application URL: https://$fqdn" -ForegroundColor Green
```

### Option 3: Automated CI/CD with GitHub Actions

For continuous deployment, set up GitHub Actions workflows (see `.github/workflows/README.md` for detailed instructions):

1. **Create Service Principal** with federated credentials
2. **Add GitHub Secrets**: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`
3. **Push to main branch** to trigger automated deployment

The workflows will automatically:
- Deploy infrastructure changes when `bicep/**` is modified
- Build and deploy application when `app/**` is modified

Get ACR credentials:

```powershell
$acrServer = az acr show --name $acrName --query "loginServer" --output tsv
$acrUsername = az acr credential show --name $acrName --query "username" --output tsv
$acrPassword = az acr credential show --name $acrName --query "passwords[0].value" --output tsv
```

Update the Container App:

```powershell
az containerapp update `
  --name ca-aca-demo `
  --resource-group rg-ace-aca-demo `
  --image "$acrServer/angular-app:v1" `
  --registry-server $acrServer `
  --registry-username $acrUsername `
  --registry-password $acrPassword
```

## 🔒 Security Architecture

### How ACR Private Endpoint Works

```
Container App (in VNET)
    ↓ (uses managed identity)
    ↓ (private endpoint connection)
    ↓
Private Endpoint (10.0.1.x) ← Private DNS Zone (privatelink.azurecr.io)
    ↓
ACR (Public access: DISABLED)
```

### Security Features Explained

1. **Private Endpoint**: ACR has a private IP (10.0.1.x) within your VNET
2. **Public Access Disabled**: ACR rejects all internet traffic
3. **Managed Identity**: Container App has a system-assigned identity (no passwords)
4. **RBAC**: Identity has AcrPull role to pull images
5. **Private DNS**: `<acr-name>.azurecr.io` resolves to private IP within VNET
6. **Admin Disabled**: No username/password authentication allowed

### Verify Security Configuration

```powershell
# Check ACR public access (should be Disabled)
az acr show --name <acr-name> --query "{publicAccess:publicNetworkAccess, adminUser:adminUserEnabled}"

# Check private endpoint connection
az network private-endpoint list --resource-group rg-vnet-aca-demo --output table

# Check managed identity role assignment
az role assignment list --assignee <principal-id> --scope <acr-resource-id>
```

## 🔧 Customization

### Modify Parameters

Edit `bicep/main.bicepparam` to customize:
- Azure region (`location`)
- Environment name (`environmentName`)

### Modify VNET Configuration

Edit `bicep/modules/vnet.bicep` to change:
- VNET address space (default: 10.0.0.0/16)
- Subnet address prefixes

### Modify Container App Configuration

Edit `bicep/modules/container-apps.bicep` to change:
- Container image
- CPU and memory allocations (default: 0.5 CPU, 1.0 GB RAM)
- Scaling rules (default: 1-3 replicas)
- Environment variables

## 📊 Monitoring and Troubleshooting

### View Container App Logs

```powershell
# Stream live logs
az containerapp logs show `
  --name ca-aca-demo `
  --resource-group rg-ace-aca-demo `
  --follow

# View recent logs
az containerapp logs show `
  --name ca-aca-demo `
  --resource-group rg-ace-aca-demo `
  --tail 100
```

### Check Container App Health

```powershell
# Get detailed status
az containerapp show `
  --name ca-aca-demo `
  --resource-group rg-ace-aca-demo `
  --query "{name:name, status:properties.provisioningState, running:properties.runningStatus, replicas:properties.runningStatus, fqdn:properties.configuration.ingress.fqdn}"

# List revisions
az containerapp revision list `
  --name ca-aca-demo `
  --resource-group rg-ace-aca-demo `
  --output table
```

### View Log Analytics Workspace

Navigate to the Azure Portal:
1. Go to resource group `rg-ace-aca-demo`
2. Open the Log Analytics workspace `log-aca-demo`
3. Run KQL queries in the Logs section

Example queries:
```kusto
// Recent container logs
ContainerAppConsoleLogs_CL
| where ContainerAppName_s == "ca-aca-demo"
| order by TimeGenerated desc
| take 100

// Error logs only
ContainerAppConsoleLogs_CL
| where ContainerAppName_s == "ca-aca-demo"
| where Log_s contains "error" or Log_s contains "failed"
| order by TimeGenerated desc

// HTTP requests
ContainerAppSystemLogs_CL
| where ContainerAppName_s == "ca-aca-demo"
| where Type_s == "HttpRequest"
| summarize count() by bin(TimeGenerated, 5m), StatusCode_d
```

### Common Issues and Solutions

#### Issue: ACR Build Fails (Private Network)
**Solution**: Temporarily enable public access, build, then disable:
```powershell
az acr update --name <acr-name> --public-network-enabled true
az acr build --registry <acr-name> --image angular-app:latest ./app
az acr update --name <acr-name> --public-network-enabled false
```

#### Issue: Container App Can't Pull Image
**Solution**: Verify managed identity has AcrPull role:
```powershell
$principalId = az containerapp show --name ca-aca-demo --resource-group rg-ace-aca-demo --query "identity.principalId" -o tsv
$acrId = az acr show --name <acr-name> --query id -o tsv
az role assignment create --assignee $principalId --role AcrPull --scope $acrId
```

#### Issue: Application Not Responding
**Solution**: Check logs and restart:
```powershell
az containerapp logs show --name ca-aca-demo --resource-group rg-ace-aca-demo --tail 50
az containerapp revision restart --name ca-aca-demo --resource-group rg-ace-aca-demo
```
  --query "{Status:properties.provisioningState, FQDN:properties.configuration.ingress.fqdn, Replicas:properties.template.scale}"
```

## 🧹 Cleanup

To delete all resources:

```powershell
# Delete both resource groups
az group delete --name rg-vnet-aca-demo --yes --no-wait
az group delete --name rg-ace-aca-demo --yes --no-wait

# Or use azd
azd down --purge
```

## 📝 AngularJS Application Features

The sample application includes:
- Modern, responsive UI with gradient design
- Interactive counter with increment/decrement/reset functionality
- Real-time clock display
- Environment information display
- Containerized with nginx:alpine
- Demonstrates AngularJS directives, controllers, and data binding

## 🔐 Security Best Practices Implemented

✅ **Network Security**
- VNET integration for Container Apps
- Private endpoint for ACR (no public access)
- Network isolation between services
- Private DNS resolution within VNET

✅ **Identity & Access**
- System-assigned managed identities (no passwords)
- RBAC-based authorization (AcrPull role)
- Admin credentials disabled on ACR
- Least privilege access principle

✅ **Data Protection**
- HTTPS ingress for Container App
- Encrypted traffic within Azure backbone
- No credentials stored in code or configuration

✅ **Monitoring & Compliance**
- Log Analytics for audit trails
- Container App logs retention
- Activity log monitoring
- Ready for Azure Policy enforcement

### Production Recommendations
- Enable Azure DDoS Protection Standard
- Implement Web Application Firewall (WAF)
- Configure custom domain with SSL/TLS
- Set up Azure Monitor alerts
- Implement Azure Key Vault for secrets
- Enable diagnostic logs for all resources
- Configure backup and disaster recovery

## 🚀 CI/CD Automation

This project includes GitHub Actions workflows for automated deployment:

1. **Infrastructure Workflow**: Deploys Bicep templates on infrastructure changes
2. **Build & Deploy Workflow**: Builds Docker image and updates Container App

See `.github/workflows/README.md` for setup instructions.

### Benefits of CI/CD
- ✅ Automated image builds on code changes
- ✅ Zero-downtime deployments with revisions
- ✅ Consistent deployment process
- ✅ Audit trail in GitHub Actions logs
- ✅ Federated identity (no stored credentials)

## 📚 Additional Resources

- [Azure Container Apps Documentation](https://learn.microsoft.com/azure/container-apps/)
- [Azure Container Registry Documentation](https://learn.microsoft.com/azure/container-registry/)
- [Azure Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure Private Endpoint Documentation](https://learn.microsoft.com/azure/private-link/)
- [Managed Identities Documentation](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/)
- [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/)

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📄 License

This project is provided as-is for demonstration purposes.

---

**Production Checklist**:
- [ ] Review and adjust VNET address spaces
- [ ] Configure custom domain and SSL certificates
- [ ] Set up monitoring alerts and dashboards
- [ ] Implement backup and disaster recovery
- [ ] Enable Azure Policy for compliance
- [ ] Configure Azure Front Door or Application Gateway
- [ ] Review and adjust scaling limits
- [ ] Implement proper secret management with Key Vault
- [ ] Set up staging and production environments
- [ ] Configure CI/CD pipelines with proper approvals
