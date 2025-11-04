# LAB517: Next-Gen AKS Operations Lab Guide

📊 **Difficulty:** Intermediate | 💡 **Knowledge Level:** Kubernetes basics helpful but not required

## Overview

This hands-on lab demonstrates the future of Azure Kubernetes Service (AKS) operations through AI agents. You'll manage production clusters using natural language—asking agents to diagnose issues, optimize configurations, and execute operations without memorizing complex CLI syntax.

**What makes this different?** Instead of memorizing kubectl commands and Azure CLI syntax, you'll simply describe what you want to accomplish, and AI agents handle the technical execution. This lab shows how AI is transforming the role of platform engineers and SREs.

### Prerequisites for Success

To get the most out of this lab, you should have:

- ✅ **Basic understanding of containers** - Know what Docker containers are
- ✅ **Familiarity with Kubernetes concepts** - Understand pods, deployments, services (or willing to learn as you go!)
- ✅ **Azure subscription access** - Contributor or Owner permissions
- ✅ **Completed infrastructure deployment** - Follow the [Lab Setup Guide](../README.md) first

**New to Kubernetes?** Check out [Kubernetes Basics](https://kubernetes.io/docs/tutorials/kubernetes-basics/) before starting.

### Key Technologies

This lab explores two complementary approaches to AI-powered AKS operations:

- **[CLI Agent for AKS](https://github.com/Azure/cli-agent-for-aks)** - Terminal-based AI assistant for interactive cluster management
- **[kagent](https://kagent.dev/)** - CNCF Sandbox project that brings AI agents directly into your Kubernetes cluster as native resources

Both approaches leverage the **[AKS MCP Server](https://github.com/Azure/aks-mcp)**, a standardized interface built on the Model Context Protocol that exposes Azure, AKS, and Kubernetes capabilities to AI agents.

### Learning Objectives

By the end of this lab, you will be able to:

- **Deploy and configure** AI agent frameworks (AKS MCP Server, CLI Agent, kagent) with Azure AI Foundry models
- **Build multi-agent systems** where specialized agents collaborate on complex operational tasks
- **Troubleshoot production scenarios** using natural language instead of memorizing CLI syntax
- **Orchestrate automated remediation** for node failures, traffic spikes, and configuration drift
- **Understand the Model Context Protocol (MCP)** and how it standardizes AI-tool integration

## Lab Activities Summary

### Phase 1: Environment Setup

**What you'll do:**

- Connect to the pre-provisioned AKS cluster
- Deploy required Kubernetes resources for the lab
- Authenticate GitHub Copilot for testing the local AKS MCP server

**Success criteria:**

- ✅ All Kubernetes namespaces created (kagent, sample, demo)
- ✅ AKS MCP server pod running in kagent namespace
- ✅ kagent dashboard accessible via LoadBalancer
- ✅ Sample applications deployed successfully

**Prerequisites verified:**

- Azure CLI authenticated and connected to the correct subscription
- kubectl configured with AKS cluster credentials
- All required VS Code extensions installed (GitHub Copilot, AKS)

**Key deployment steps:**

> **Important:** All commands below assume you are running them from the root of the repository. If you've navigated elsewhere, return to the repository root first with `cd /path/to/ignite25-LAB517-next-gen-aks-operations-with-models-and-agents-and-mcps-oh-my` or adjust paths accordingly.

#### 1. Create Kubernetes namespaces

```bash
kubectl create namespace kagent
kubectl create namespace sample
kubectl create namespace demo
```

#### 2. Apply network policy to demo namespace

```bash
kubectl apply -n demo -f - <<EOF
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF
```

#### 3. Deploy AKS MCP server in-cluster

The AKS MCP server is deployed with workload identity for Azure authentication:

```bash
# Set your deployment name (use the same RAND value from infrastructure deployment)
DEPLOYMENT_NAME=myDeployment$RAND

# Get the resource group name from deployment outputs
RG_NAME=$(az deployment group show \
  --resource-group myResourceGroup$RAND \
  --name $DEPLOYMENT_NAME \
  --query properties.outputs.rgName.value -o tsv)

# Get the managed identity client ID from deployment outputs
MANAGED_IDENTITY_CLIENT_ID=$(az deployment group show \
  --resource-group $RG_NAME \
  --name $DEPLOYMENT_NAME \
  --query properties.outputs.userAssignedIdentityClientId.value -o tsv)

# Deploy the AKS MCP server (update placeholder and apply)
sed "s/MANAGED_IDENTITY_CLIENT_ID/$MANAGED_IDENTITY_CLIENT_ID/g" \
  lab/manifests/aks-mcp.yaml | kubectl apply -f -
```

The deployment includes:

- **ServiceAccount** with Azure workload identity annotations
- **ClusterRoleBinding** granting cluster-admin permissions
- **Deployment** running the AKS MCP server container
- **Service** exposing the server on port 8000

#### 4. Install kagent via Helm

```bash
# Install CRDs
helm install kagent-crds oci://ghcr.io/kagent-dev/kagent/helm/kagent-crds \
  --namespace kagent \
  --create-namespace

# Get AI Services details from deployment outputs
AI_SERVICES_NAME=$(az cognitiveservices account list -g $RG_NAME --query "[0].name" -o tsv)
AI_SERVICES_KEY=$(az deployment group show \
  --resource-group $RG_NAME \
  --name $DEPLOYMENT_NAME \
  --query properties.outputs.aiServicesKey.value -o tsv)
AI_SERVICES_ENDPOINT=$(az deployment group show \
  --resource-group $RG_NAME \
  --name $DEPLOYMENT_NAME \
  --query properties.outputs.aiServicesEndpoint.value -o tsv)

# Install kagent with Azure AI Foundry configuration
helm upgrade kagent oci://ghcr.io/kagent-dev/kagent/helm/kagent \
  --install \
  --namespace kagent \
  --set providers.default=azureOpenAI \
  --set providers.azureOpenAI.model="gpt-4.1-mini" \
  --set providers.azureOpenAI.apiKey="$AI_SERVICES_KEY" \
  --set providers.azureOpenAI.config.apiVersion="2024-12-01-preview" \
  --set providers.azureOpenAI.config.azureDeployment="gpt-4.1-mini" \
  --set providers.azureOpenAI.config.azureEndpoint="$AI_SERVICES_ENDPOINT" \
  --set ui.service.type=LoadBalancer
```

> **Note:** The kagent UI is exposed via LoadBalancer for easier access in this lab. In production, consider using Ingress or port-forwarding instead.

#### 5. Deploy sample applications

Deploy a CPU-intensive app for load testing:

```bash
kubectl apply -f lab/manifests/sample-app.yaml
```

#### 6. Configure Azure Load Testing

```bash
# Get the sample app's LoadBalancer IP (wait for it to be assigned)
SAMPLE_APP_IP=$(kubectl get service sample-app -n sample -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Get the Load Testing resource name from deployment outputs
LOAD_TEST_NAME=$(az deployment group show \
  --resource-group $RG_NAME \
  --name $DEPLOYMENT_NAME \
  --query properties.outputs.loadTestName.value -o tsv)

# Update the load test configuration with the actual IP
sed "s|https://azure.microsoft.com|http://$SAMPLE_APP_IP|g" \
  lab/load-test/loadtest.config.yaml > loadtest.config.updated.yaml

# Create the load test
az load test create \
  --load-test-resource $LOAD_TEST_NAME \
  --resource-group $RG_NAME \
  --test-id sample-app-load-test \
  --display-name "Sample App Load Test" \
  --description "Pre-configured load test for sample application" \
  --load-test-config-file loadtest.config.updated.yaml \
  --test-plan lab/load-test/locustfile.py \
  --test-type Locust \
  --engine-instances 2
```

**What gets deployed:**

- **Kubernetes namespaces** (`kagent`, `sample`, `demo`) for organizing lab resources
- **AKS MCP server** deployed in-cluster with [workload identity](https://learn.microsoft.com/azure/aks/workload-identity-overview) for Azure authentication
- **kagent** installed via Helm with Azure AI Foundry model configuration
- **Sample applications** including a CPU-intensive app for load testing and a demo app with intentional misconfigurations
- **Azure Load Testing** configuration for performance testing

**Verify Phase 1 completion:**

```bash
# Check all pods are running in kagent namespace
kubectl get pods -n kagent

# You should see:
# - aks-mcp-* pod (Running)
# - kagent-* pods (Running)
# - kagent-ui-* pod (Running)

# Get the kagent dashboard URL
echo "http://$(kubectl get service kagent-ui -n kagent -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):8080"
```

### Phase 2: Understanding Model Context Protocol (MCP)

**What you'll learn:**

The Model Context Protocol (MCP) is an open standard that enables AI agents to access external tools and data sources consistently. Think of it as a universal adapter between AI models and systems like databases, APIs, and cloud services.

**Key concepts:**

- **MCP Servers** - Expose capabilities (tools, prompts, resources) through the protocol (e.g., AKS MCP server)
- **MCP Clients** - Applications like AI agents that connect to MCP servers (e.g., GitHub Copilot Chat, CLI Agent, kagent)
- **Tools** - Functions the AI calls to perform actions (kubectl commands, Azure APIs)
- **Resources** - Data sources providing context (cluster configs, logs)

**The AKS MCP Server** provides deep integration with Azure and Kubernetes, exposing tools for:

- Core AKS operations (cluster management, node pools)
- Monitoring & diagnostics (Azure Monitor, metrics)
- Networking (connectivity tests, DNS diagnostics)
- Compute resources (VM scale sets, node management)
- Kubernetes operations (kubectl commands, resource queries)
- Azure Advisor (optimization recommendations)
- Real-time observability (Inspektor Gadget)

### Phase 3: Testing MCP with GitHub Copilot

**What you'll do:**

- Start the local AKS MCP server in VS Code
- Use GitHub Copilot Chat to explore available MCP tools
- Query cluster information using natural language
- Run diagnostics and health checks through the agent

**Success criteria:**

- ✅ AKS MCP server running in VS Code (check OUTPUT panel)
- ✅ GitHub Copilot can list available tools
- ✅ Agent successfully queries your AKS cluster
- ✅ Diagnostics return cluster health information

**Key insight:** This demonstrates how MCP servers provide standardized tool access for AI agents. GitHub Copilot gains AKS-specific capabilities beyond its general knowledge by connecting to the AKS MCP server.

**Learn more:** [Model Context Protocol Documentation](https://modelcontextprotocol.io/docs)

### Phase 4: CLI Agent for AKS

**What you'll do:**

- Configure the CLI Agent with Azure AI Foundry models
- Explore agent capabilities through natural language queries
- Plan a Kubernetes upgrade workflow using the agent
- Learn about pre-upgrade compatibility checks and monitoring strategies

**Success criteria:**

- ✅ CLI Agent starts and connects to Azure AI Foundry
- ✅ Agent lists available tools successfully
- ✅ Agent provides Kubernetes version information
- ✅ Agent generates upgrade recommendations with pre-upgrade checks

**Key insight:** The CLI Agent brings AI assistance directly to your terminal, making it easy to perform cluster operations and get guidance on best practices without leaving your workflow. This is particularly valuable for planning complex operations where understanding compatibility and migration paths is critical.

**How it works:**

Built on [HolmesGPT](https://holmesgpt.dev/) (CNCF Sandbox project), the CLI Agent integrates with kubectl, Azure CLI, [Inspektor Gadget](https://www.inspektor-gadget.io/), and Azure Monitor. It operates in read-only mode by default to ensure safe diagnostics while providing intelligent troubleshooting guidance.

**Learn more:** [CLI Agent for AKS Documentation](https://github.com/Azure/cli-agent-for-aks)

### Phase 5: kagent - Kubernetes-Native AI Agents

**What you'll do:**

- Explore the kagent dashboard and pre-installed agents
- Interact with the k8s-agent for cluster operations
- Test natural language queries for security audits, high availability checks, and resource management
- Understand how agents run as Kubernetes custom resources

**Why kagent?**

- **Kubernetes-native** - Agents are defined as custom resources and managed with kubectl
- **Multi-agent architecture** - Create specialized agents that collaborate on complex tasks
- **CLI and Web UI** - Interact with agents through terminal or browser
- **Extensible** - Connect agents to MCP servers for additional capabilities

**Success criteria:**

- ✅ kagent dashboard loads successfully
- ✅ k8s-agent responds to natural language queries
- ✅ Agent successfully lists and describes cluster resources
- ✅ Agent provides security and best practice recommendations

**Key insight:** kagent brings AI agents directly into your cluster as Kubernetes-native resources. This enables [GitOps workflows](https://www.gitops.tech/), RBAC policies, and integration with existing Kubernetes tooling while maintaining production best practices.

**Learn more:**

- [kagent Documentation](https://kagent.dev/)
- [Kubernetes Custom Resources](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)

### Phase 6: Connecting kagent to AKS MCP Server

**What you'll do:**

- Create a RemoteMCPServer custom resource pointing to the in-cluster AKS MCP server
- Deploy a specialized AKS agent with comprehensive system prompts
- Connect the AKS agent to other specialized agents (k8s-agent, cilium-policy-agent)
- Build a multi-agent system where agents collaborate on complex tasks

**Deploy the AKS agent:**

The AKS agent is a specialized agent with expert knowledge of Azure and Kubernetes troubleshooting. Deploy it using the pre-configured manifest:

```bash
# Deploy the AKS agent
kubectl apply -f lab/manifests/aks-agent.yaml

# Verify the agent was created successfully
kubectl get agent aks-agent -n kagent

# Wait for the agent to be ready
kubectl wait --for=condition=Ready agent/aks-agent -n kagent --timeout=60s
```

The manifest includes:

- **Model configuration** pointing to Azure OpenAI gpt-4.1-mini
- **Comprehensive system prompt** with detailed Azure/Kubernetes expertise
- **Tool access** to the aks-mcp RemoteMCPServer
- **Troubleshooting methodology** and operational guidelines

**Multi-agent system benefits:**

- **Specialization** - Each agent is an expert in one domain rather than mediocre at everything
- **Transparency** - See delegation happening in real-time
- **Extensibility** - Add new specialized agents without modifying existing ones
- **Maintainability** - Update one agent's knowledge without affecting the system
- **Scalability** - Complex questions are automatically decomposed into manageable subtasks

**Key insight:** Multi-agent orchestration enables specialized agents to collaborate on complex operational tasks, improving accuracy, transparency, and scalability while reducing manual command overhead.

## What You've Accomplished

✅ **Deployed a complete AI-powered AKS operations environment** with multiple agent frameworks  
✅ **Tested three different agent interaction models** (GitHub Copilot, CLI Agent, kagent)  
✅ **Built multi-agent systems** where specialized agents collaborate on complex tasks  
✅ **Learned the Model Context Protocol (MCP)** and how it standardizes AI-tool integration  
✅ **Experienced natural language cluster operations** without memorizing CLI syntax

## Production Considerations

When implementing AI agents in production environments:

- **Choose the right agent model** - CLI for terminal workflows, kagent for Kubernetes-native operations, Copilot for development environments
- **Extend capabilities** - Add MCP servers for GitHub, Jira, Slack, monitoring tools, etc.
- **Enforce safety** - Use read-only modes, approval gates, and audit logs for critical operations
- **Test thoroughly** - Validate agents in non-production environments before deployment
- **Monitor agent behavior** - Track tool invocations, errors, and decision-making patterns
- **Maintain context** - Start fresh conversations for different tasks to avoid context pollution

## Key Takeaways

- **AI agents reduce cognitive load** by translating intent into tool execution
- **MCP standardizes tool access** enabling composable, extensible agent systems
- **Multi-agent collaboration** brings domain expertise (Kubernetes, Azure, Cilium) into unified workflows
- **Kubernetes-native agents** support GitOps, RBAC, and auditability
- **Natural language operations** democratize cluster management without requiring deep CLI expertise

## Additional Resources

- **AKS MCP Server** - [github.com/Azure/aks-mcp](https://github.com/Azure/aks-mcp)
- **CLI Agent for AKS** - [github.com/Azure/cli-agent-for-aks](https://github.com/Azure/cli-agent-for-aks)
- **kagent Documentation** - [kagent.dev](https://kagent.dev)
- **Model Context Protocol** - [modelcontextprotocol.io](https://modelcontextprotocol.io)
- **MCP for Beginners** - [github.com/microsoft/mcp-for-beginners](https://github.com/microsoft/mcp-for-beginners)
- **Azure AI Foundry** - [learn.microsoft.com/azure/ai-foundry](https://learn.microsoft.com/azure/ai-foundry/what-is-azure-ai-foundry)
- **HolmesGPT** - [holmesgpt.dev](https://holmesgpt.dev/)

## Next Steps

Now that you understand the fundamentals of AI-powered AKS operations, consider:

1. **Exploring additional MCP servers** to extend agent capabilities
2. **Creating custom agents** for your specific operational workflows
3. **Implementing GitOps patterns** with kagent for production deployments
4. **Building multi-agent systems** tailored to your organization's needs
5. **Contributing to open-source projects** like kagent, AKS MCP server, and CLI Agent

---

**Congratulations on completing the Next-Gen AKS Operations lab!** 🎉

You've experienced the future of cluster management where AI agents handle the complexity, allowing you to focus on strategy and innovation.
