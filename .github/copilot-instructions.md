# Azure Container Apps with Bicep - Workspace Instructions

## Project Overview
This workspace contains Azure Bicep templates for provisioning:
- Two resource groups (rg-vnet-aca-demo and rg-ace-aca-demo)
- Virtual Network with two subnets
- Azure Container Apps Environment
- Container App with AngularJS web application

## Development Guidelines
- Use Bicep best practices for infrastructure as code
- Ensure proper subnet delegation for Container Apps
- Follow Azure naming conventions
- Include all necessary configurations for VNET integration

## Project Structure
- `/bicep` - Bicep templates for infrastructure
- `/app` - AngularJS web application source
- `/README.md` - Deployment instructions
