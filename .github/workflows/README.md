# GitHub Actions Workflows

This directory contains CI/CD workflows for automated deployment to Azure.

## Workflows

### 1. `infrastructure.yml` - Infrastructure Deployment
Deploys Azure infrastructure using Bicep templates.

**Triggers:**
- Push to `main` branch (when `bicep/**` files change)
- Manual workflow dispatch

**What it does:**
- Deploys all Bicep templates at subscription scope
- Creates resource groups, VNET, ACR, Container Apps Environment, and Container App
- Outputs deployment information

### 2. `build-and-deploy.yml` - Build and Deploy Application
Builds Docker image and deploys to Container Apps.

**Triggers:**
- Push to `main` branch (when `app/**`, `bicep/**`, or workflow files change)
- Manual workflow dispatch

**What it does:**
- Builds Docker image from `app/` directory
- Pushes image to ACR with git commit SHA and `latest` tags
- Updates Container App with new image
- Provides deployment summary with app URL

## Setup Instructions

### 1. Create Azure Service Principal with Federated Credentials

```powershell
# Set variables
$appName = "gh-aca-demo-sp"
$subscriptionId = "<your-subscription-id>"
$githubOrg = "<your-github-username-or-org>"
$githubRepo = "<your-repo-name>"

# Create Azure AD Application
$app = az ad app create --display-name $appName | ConvertFrom-Json

# Create Service Principal
$sp = az ad sp create --id $app.appId | ConvertFrom-Json

# Assign Contributor role at subscription level
az role assignment create `
  --assignee $sp.id `
  --role Contributor `
  --scope "/subscriptions/$subscriptionId"

# Create federated credential for main branch
az ad app federated-credential create `
  --id $app.id `
  --parameters "{
    `"name`": `"github-main-branch`",
    `"issuer`": `"https://token.actions.githubusercontent.com`",
    `"subject`": `"repo:$githubOrg/$githubRepo:ref:refs/heads/main`",
    `"audiences`": [`"api://AzureADTokenExchange`"]
  }"

# Create federated credential for pull requests (optional)
az ad app federated-credential create `
  --id $app.id `
  --parameters "{
    `"name`": `"github-pull-requests`",
    `"issuer`": `"https://token.actions.githubusercontent.com`",
    `"subject`": `"repo:$githubOrg/$githubRepo:pull_request`",
    `"audiences`": [`"api://AzureADTokenExchange`"]
  }"

# Display values for GitHub secrets
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Add these secrets to your GitHub repository:" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Green
Write-Host "AZURE_CLIENT_ID: $($app.appId)" -ForegroundColor Yellow
Write-Host "AZURE_TENANT_ID: $((az account show | ConvertFrom-Json).tenantId)" -ForegroundColor Yellow
Write-Host "AZURE_SUBSCRIPTION_ID: $subscriptionId" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Green
```

### 2. Add GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions → New repository secret

Add these three secrets:
- `AZURE_CLIENT_ID` - Application (client) ID from above
- `AZURE_TENANT_ID` - Your Azure AD tenant ID
- `AZURE_SUBSCRIPTION_ID` - Your Azure subscription ID

### 3. Update Workflow Files

Edit the workflow files if needed to match your resource names:
- `ACR_NAME` - Your ACR name (currently: acracademo5462)
- `CONTAINER_APP_NAME` - Your Container App name (currently: ca-aca-demo)
- `AZURE_RESOURCE_GROUP_ACR` - Resource group for ACR (currently: rg-vnet-aca-demo)
- `AZURE_RESOURCE_GROUP_ACA` - Resource group for Container Apps (currently: rg-ace-aca-demo)

## Usage

### Deploy Infrastructure
```bash
# Trigger manually from GitHub Actions UI
# Or push changes to bicep/ directory
git add bicep/
git commit -m "Update infrastructure"
git push
```

### Build and Deploy Application
```bash
# Trigger manually from GitHub Actions UI
# Or push changes to app/ directory
git add app/
git commit -m "Update application"
git push
```

## Security Features

✅ **Federated Identity** - No secrets stored, uses OpenID Connect (OIDC)  
✅ **Private ACR** - ACR build tasks use managed identity  
✅ **Least Privilege** - Service Principal has only required permissions  
✅ **Audit Trail** - All deployments tracked in GitHub Actions logs

## Troubleshooting

### ACR Build Fails
If ACR build fails due to private network restrictions:
1. Temporarily enable public access: `az acr update --name <acr-name> --public-network-enabled true`
2. Run the workflow
3. Disable public access: `az acr update --name <acr-name> --public-network-enabled false`

### Container App Update Fails
- Check that managed identity has AcrPull role
- Verify image exists in ACR
- Check Container App logs: `az containerapp logs show --name <app-name> --resource-group <rg-name> --follow`

## Alternative: Use Azure DevOps or Azure Pipelines

If you prefer Azure DevOps, you can use Azure Pipelines with similar steps and managed identity authentication.
