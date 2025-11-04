# Lab Infrastructure Deployment

> **Next Step:** After completing this deployment, continue to the **[Lab Guide](guide/README.md)** for hands-on activities!

This guide will walk you through deploying the complete Azure infrastructure for the LAB517 session, including:

- **Azure Kubernetes Service (AKS)** cluster with advanced features
- **Azure AI Foundry** with GPT-4.1-mini and GPT-5-mini models
- **Azure Monitor** workspace for Prometheus metrics
- **Log Analytics** workspace for logs and diagnostics
- **Azure Load Testing** service
- **Managed Identity** with federated credentials for workload identity

## Prerequisites

Before you begin, ensure you have:

1. **Azure CLI** installed and configured ([Install Guide](https://learn.microsoft.com/cli/azure/install-azure-cli))
2. **kubectl** installed ([Install Guide](https://kubernetes.io/docs/tasks/tools/))
3. **jq** installed for JSON parsing (`brew install jq` on macOS)
4. An **Azure subscription** with sufficient quota for:
   - AKS cluster with Standard D4pds v5 VMs (3 nodes minimum)
   - Azure OpenAI with 200 TPM capacity for 2 model deployments
5. **Contributor** or **Owner** access to the subscription
6. Azure CLI **logged in** to your subscription: `az login`

## Deployment Steps

### 1. Navigate to the Infrastructure Directory

```bash
cd lab/infra

RAND=$RANDOM
export RAND
echo "Random resource identifier will be: ${RAND}"

LOCATION=westus3
```

> **Note:** The `$RAND` variable ensures unique resource names and prevents naming conflicts. Save this value if you need to reference these resources later.

### 2. Create Resource Group

```bash
az group create \
--name myResourceGroup$RAND \
--location $LOCATION
```

This creates a new resource group to contain all lab resources.

### 3. Deploy Infrastructure

```bash
az deployment group create \
--resource-group myResourceGroup$RAND \
--name myDeployment$RAND \
--template-file main.bicep \
--parameters nameSuffix=$RAND modelCapacity=200 nodeVmSize=standard_d4pds_v5 addRoleAssignments=true \
--debug
```

> **Deployment time:** This typically takes 10-15 minutes to complete.

**Parameters explained:**

- `nameSuffix`: Unique suffix for resource names (using $RAND)
- `modelCapacity`: Token-per-minute capacity for AI models (200 TPM)
- `nodeVmSize`: VM size for AKS nodes (Standard_D4pds_v5)
- `addRoleAssignments`: Automatically assigns necessary RBAC roles

### 4. Verify Deployment Outputs

Once deployment completes, verify the outputs:

```bash
az deployment group show \
--resource-group myResourceGroup$RAND \
--name myDeployment$RAND \
--query properties.outputs | jq
```

You should see outputs including:

- AKS cluster name and ID
- AI Services endpoint and keys
- Managed identity details
- Workspace IDs for monitoring

### 5. Grant Additional Permissions to Managed Identity

The managed identity needs additional permissions to interact with Azure resources for the MCP server operations:

```bash
MANAGED_IDENTITY_PRINCIPAL_ID=$(az deployment group show \
--resource-group myResourceGroup$RAND \
--name myDeployment$RAND \
--query properties.outputs | jq -r .userAssignedIdentityPrincipalId.value)

# contributor on subscription
az role assignment create \
--role Contributor \
--scope /subscriptions/$(az account show --query id -o tsv) \
--assignee $MANAGED_IDENTITY_PRINCIPAL_ID

# ai user on ai foundry account
az role assignment create \
--role 'Cognitive Services OpenAI User' \
--scope $(az deployment group show \
--resource-group myResourceGroup$RAND \
--name myDeployment$RAND \
--query properties.outputs | jq -r .aiServicesId.value) \
--assignee $MANAGED_IDENTITY_PRINCIPAL_ID

# monitoring reader on log analytics
az role assignment create \
--role 'Monitoring Reader' \
--scope $(az deployment group show \
--resource-group myResourceGroup$RAND \
--name myDeployment$RAND \
--query properties.outputs | jq -r .logsWorkspaceId.value) \
--assignee $MANAGED_IDENTITY_PRINCIPAL_ID

# monitoring reader on prometheus
az role assignment create \
--role 'Monitoring Reader' \
--scope $(az deployment group show \
--resource-group myResourceGroup$RAND \
--name myDeployment$RAND \
--query properties.outputs | jq -r .monitorWorkspaceId.value) \
--assignee $MANAGED_IDENTITY_PRINCIPAL_ID
```

**Role assignments explained:**

- **Contributor**: Allows the identity to manage AKS and related resources
- **Cognitive Services OpenAI User**: Enables AI model inference calls
- **Monitoring Reader** (2x): Provides read access to logs and metrics

### 6. Connect to Your AKS Cluster

Configure kubectl to connect to your new cluster:

```bash
az aks get-credentials -g myResourceGroup$RAND -n myAKSCluster --overwrite
```

Verify connectivity:

```bash
kubectl get nodes
```

You should see 3 nodes in Ready state.

## ✅ Verify Your Deployment

Before proceeding to the lab exercises, confirm your infrastructure is ready:

```bash
# Check that all nodes are ready
kubectl get nodes

# Verify you have 3 nodes in Ready state
# Expected output:
# NAME                                STATUS   ROLES   AGE   VERSION
# aks-systempool-12345678-vmss000000  Ready    agent   10m   v1.32.x
# aks-systempool-12345678-vmss000001  Ready    agent   10m   v1.32.x
# aks-systempool-12345678-vmss000002  Ready    agent   10m   v1.32.x

# Verify deployment outputs are accessible
az deployment group show \
  --resource-group myResourceGroup$RAND \
  --name myDeployment$RAND \
  --query properties.outputs.aksName.value -o tsv
# Expected output: myAKSCluster
```

If all checks pass, you're ready to proceed! 🎉

## What's Next?

Now that your infrastructure is deployed, you're ready to begin the hands-on lab exercises!

### 📖 Lab Guide

Head over to the **[Lab Guide](guide/README.md)** for step-by-step instructions on:

1. **Deploying the AKS MCP Server** to enable AI-powered cluster operations
2. **Configuring agent frameworks** to work with your cluster
3. **Running lab scenarios** to practice AI-driven troubleshooting and automated remediation
4. **Exploring multi-agent systems** for complex operational tasks

The lab guide will walk you through real-world scenarios including traffic spikes, node failures, and AI-driven diagnostics.

## Troubleshooting

### Deployment Fails with Quota Error

If you encounter quota errors, try:

- Using a different Azure region: `LOCATION=eastus`
- Reducing the model capacity: `modelCapacity=100`
- Using a smaller VM size: `nodeVmSize=standard_d2pds_v5`

### Role Assignment Errors

Role assignments may take a few minutes to propagate. If you see permission errors:

1. Wait 2-3 minutes for propagation
2. Retry the failed command
3. Verify you have sufficient permissions in the subscription

### Unable to Connect to Cluster

If `kubectl` commands fail:

```bash
# Re-fetch credentials
az aks get-credentials -g myResourceGroup$RAND -n myAKSCluster --overwrite --admin

# Verify cluster is running
az aks show -g myResourceGroup$RAND -n myAKSCluster --query powerState
```

## Cleanup

When you're done with the lab, delete the resource group and purge the AI Services account to remove all resources:

```sh
# Delete the resource group
az group delete -n myResourceGroup$RAND -y

# Purge the AI Services account (use the nameSuffix from deployment)
az cognitiveservices account purge -n myAIFoundry$RAND -g myResourceGroup$RAND --location $LOCATION
```

> **Warning:** This will permanently delete all resources created in this lab. The purge command is necessary to fully remove the AI Services account from soft-delete state, allowing you to reuse the same name if needed.
