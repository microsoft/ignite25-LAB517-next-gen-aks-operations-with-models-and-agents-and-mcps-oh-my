<p align="center">
<img src="img/Banner-ignite-25.png" alt="decorative banner" width="1200"/>
</p>

# [Microsoft Ignite 2025](https://ignite.microsoft.com)

## 🔥LAB517: Next-Gen AKS Operations with Models, and Agents, and MCPs

[![Microsoft Azure AI Foundry Discord](https://dcbadge.limes.pink/api/server/ByRwuEEgH4)](https://aka.ms/AIFoundryDiscord-Ignite25)
[![Azure AI Foundry Developer Forum](https://img.shields.io/badge/GitHub-Azure_AI_Foundry_Developer_Forum-blue?style=for-the-badge&logo=github&color=adff2f&logoColor=fff)](https://aka.ms/AIFoundryForum-Ignite25)

### Who Should Take This Lab?

This lab is designed for:

- **Platform Engineers** managing Kubernetes clusters in production
- **DevOps Engineers** interested in AI-assisted operations
- **Site Reliability Engineers (SREs)** exploring automation opportunities
- **Cloud Architects** evaluating next-generation operational tools

**Prerequisites:** Basic familiarity with Kubernetes concepts and Azure is helpful but not required. The lab provides context and links to foundational resources.

### Session Description

Build confidence in managing AKS at scale with next‑gen ops tools. In this hands‑on lab, you’ll simulate a production service hit by traffic spikes, discover how AI‑driven alerts surface hidden bottlenecks, and deploy agents that self‑heal nodes. Using open‑source tools and the aks‑mcp server, you can automate cluster scaling, patch management, and real‑time troubleshooting—letting the AI orchestrate Kubernetes and Azure resources with natural‑language commands and pre‑built MCP integrations. 

### 🧠 Learning Outcomes

By the end of this session, learners will be able to:

- **Deploy and configure** AI agent frameworks (AKS MCP Server, CLI Agent, kagent) with Azure AI Foundry models
- **Build multi-agent systems** where specialized agents collaborate on complex operational tasks
- **Troubleshoot production scenarios** using natural language instead of memorizing CLI syntax
- **Orchestrate automated remediation** for node failures, traffic spikes, and configuration drift
- **Generate proactive health assessments** combining Azure Advisor recommendations with Kubernetes best practices
- **Understand the Model Context Protocol (MCP)** and how it standardizes AI-tool integration

### 💻 Technologies Used

1. **[Azure Kubernetes Service (AKS)](https://learn.microsoft.com/azure/aks/)** - Managed Kubernetes service in Azure
1. **[Azure AI Foundry](https://learn.microsoft.com/azure/ai-foundry/)** - Platform for building AI applications with enterprise-grade models
1. **[Model Context Protocol (MCP)](https://modelcontextprotocol.io/)** - Open standard for connecting AI agents to external tools
1. **[AKS MCP Server](https://github.com/Azure/aks-mcp)** - MCP server that exposes AKS and Kubernetes capabilities to AI agents
1. **[CLI Agent for AKS](https://github.com/Azure/cli-agent-for-aks)** - Terminal-based AI assistant for cluster management
1. **[kagent](https://kagent.dev/)** - Kubernetes-native AI agents (CNCF Sandbox project)

### 📚 Foundational Resources

New to these technologies? Start here:

- **[Kubernetes Basics](https://kubernetes.io/docs/tutorials/kubernetes-basics/)** - Introduction to Kubernetes concepts
- **[What is Azure Kubernetes Service?](https://learn.microsoft.com/azure/aks/intro-kubernetes)** - AKS overview and key features
- **[Introduction to Azure AI Foundry](https://learn.microsoft.com/azure/ai-foundry/what-is-azure-ai-foundry)** - Learn about enterprise AI capabilities
- **[Model Context Protocol Docs](https://modelcontextprotocol.io/docs/getting-started/intro)** - Understanding MCP architecture
- **[MCP for Beginners](https://github.com/microsoft/mcp-for-beginners)** - Step-by-step guide to building with MCP

### 🚀 Getting Started

This lab follows a two-step process:

1. **[Deploy Infrastructure](lab/README.md)** - Set up your AKS cluster, Azure AI Foundry, and monitoring tools (20-25 minutes)
2. **[Start Lab Activities](lab/guide/README.md)** - Work through hands-on scenarios with AI agents

#### Step 1: Deploy Lab Infrastructure

Head over to the **[Lab Setup Guide](lab/README.md)** for step-by-step instructions on deploying:

- Azure Kubernetes Service cluster with advanced features
- Azure AI Foundry with GPT models
- Azure Monitor and Log Analytics workspaces
- All necessary infrastructure for the hands-on lab

The guide includes prerequisites, deployment commands, troubleshooting tips, and cleanup instructions.

### 🌟 Microsoft Learn MCP Server

[![Install in VS Code](https://img.shields.io/badge/VS_Code-Install_Microsoft_Docs_MCP-0098FF?style=flat-square&logo=visualstudiocode&logoColor=white)](https://vscode.dev/redirect/mcp/install?name=microsoft.docs.mcp&config=%7B%22type%22%3A%22http%22%2C%22url%22%3A%22https%3A%2F%2Flearn.microsoft.com%2Fapi%2Fmcp%22%7D)

The Microsoft Learn MCP Server is a remote MCP Server that enables clients like GitHub Copilot and other AI agents to bring trusted and up-to-date information directly from Microsoft's official documentation. Get started by using the one-click button above for VSCode or access the [mcp.json](.vscode/mcp.json) file included in this repo.

For more information, setup instructions for other dev clients, and to post comments and questions, visit our Learn MCP Server GitHub repo at [https://github.com/MicrosoftDocs/MCP](https://github.com/MicrosoftDocs/MCP). Find other MCP Servers to connect your agent to at [https://mcp.azure.com](https://mcp.azure.com).

*Note: When you use the Learn MCP Server, you agree with [Microsoft Learn](https://learn.microsoft.com/en-us/legal/termsofuse) and [Microsoft API Terms](https://learn.microsoft.com/en-us/legal/microsoft-apis/terms-of-use) of Use.*

### 📚 Resources and Next Steps

| Resources          | Links                             | Description        |
|:-------------------|:----------------------------------|:-------------------|
| Ignite 2025 Next Steps | [https://aka.ms/Ignite25-Next-Steps](https://aka.ms/Ignite25-Next-Steps?ocid=ignite25_nextsteps_cnl) | Links to all repos for Ignite 2025 Sessions |
| Azure AI Foundry Community Discord | [![Microsoft Azure AI Foundry Discord](https://dcbadge.limes.pink/api/server/ByRwuEEgH4)](https://aka.ms/AIFoundryDiscord-Ignite25)| Connect with the Azure AI Foundry Community! |
| Learn at Ignite | [https://aka.ms/LearnAtIgnite](https://aka.ms/LearnAtIgnite?ocid=ignite25_nextsteps_github_cnl) | Continue learning on Microsoft Learn |

## Content Owners

<table>
<tr>
    <td align="center"><a href="http://github.com/pauldotyu">
        <img src="https://github.com/pauldotyu.png" width="100px;" alt="Paul Yu"/><br />
        <sub><b>Paul Yu</b></sub></a><br />
            <a href="https://github.com/pauldotyu" title="talk">📢</a> 
    </td>
    <td align="center"><a href="http://github.com/pavneeta">
        <img src="https://github.com/pavneeta.png" width="100px;" alt="Pavneet Ahluwalia"/><br />
        <sub><b>Pavneet Ahluwalia</b></sub></a><br />
            <a href="https://github.com/pavneeta" title="talk">📢</a> 
    </td>
</tr></table>


## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit [Contributor License Agreements](https://cla.opensource.microsoft.com).

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft
trademarks or logos is subject to and must follow
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
