@description('The basename of the resource.')
param nameSuffix string

@description('Email address for alert notifications.')
param alertEmail string = 'noreply@example.com'

param nodeVmSize string = 'Standard_D4d_v4'
param nodeCount int = 3
param modelCapacity int = 1000
param addRoleAssignments bool = false

// @description('The user object id for the cluster admin.')
// @secure()
// param userObjectId string

resource aiServices 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  identity: {
    type: 'SystemAssigned'
  }
  kind: 'AIServices'
  location: resourceGroup().location
  name: 'myAIFoundry${nameSuffix}'
  properties: {
    customSubDomainName: 'myaifoundry${nameSuffix}'
    defaultProject: 'lab517'
    publicNetworkAccess: 'Enabled'
  }
  sku: {
    name: 'S0'
  }
}

resource gpt41Mini 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: aiServices
  name: 'gpt-4.1-mini'
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4.1-mini'
      version: '2025-04-14'
    }
  }
  sku: {
    capacity: modelCapacity
    name: 'GlobalStandard'
  }
}

resource gpt5Mini 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: aiServices
  name: 'gpt-5-mini'
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-5-mini'
      version: '2025-08-07'
    }
  }
  sku: {
    capacity: modelCapacity
    name: 'GlobalStandard'
  }
  dependsOn: [
    gpt41Mini
  ]
}

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  location: resourceGroup().location
  name: 'myManagedIdentity'
}

resource federatedIdentityCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2025-01-31-preview' = {
  parent: userAssignedIdentity
  name: 'myManagedIdentity-kagent-aks-mcp'
  properties: {
    audiences: [
      'api://AzureADTokenExchange'
    ]
    issuer: aksCluster.properties.oidcIssuerProfile.issuerURL
    subject: 'system:serviceaccount:kagent:aks-mcp'
  }
}

resource loadTest 'Microsoft.LoadTestService/loadTests@2024-12-01-preview' = {
  name: 'myLoadTest${nameSuffix}'
  location: resourceGroup().location
}

resource logsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: 'myLogs${nameSuffix}'
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource monitorWorkspace 'Microsoft.Monitor/accounts@2025-05-03-preview' = {
  name: 'myMonitor${nameSuffix}'
  location: resourceGroup().location
}

resource aksCluster 'Microsoft.ContainerService/managedClusters@2025-07-01' = {
  name: 'myAKSCluster'
  location: resourceGroup().location
  sku: {
    name: 'Base'
    tier: 'Standard'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    agentPoolProfiles: [
      {
        name: 'systempool'
        count: nodeCount
        osType: 'Linux'
        mode: 'System'
        vmSize: nodeVmSize
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'
        ]
      }
    ]
    addonProfiles: {
      azureKeyvaultSecretsProvider: {
        enabled: true
      }
      azurepolicy: {
        enabled: true
      }
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logsWorkspace.id
          useAADAuth: 'true'
        }
      }
    }
    azureMonitorProfile: {
      metrics: {
        enabled: true
        kubeStateMetrics: {}
      }
    }
    dnsPrefix: 'myAKSCluster'
    kubernetesVersion: '1.32'
    ingressProfile: {
      webAppRouting: {
        enabled: true
      }
    }
    metricsProfile: {
      costAnalysis: {
        enabled: true
      }
    }
    networkProfile: {
      loadBalancerSku: 'standard'
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkPolicy: 'cilium'
      networkDataplane: 'cilium'
    }
    nodeProvisioningProfile: {
      mode: 'Auto'
      defaultNodePools: 'Auto'
    }
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
    workloadAutoScalerProfile: {
      keda: {
        enabled: true
      }
      verticalPodAutoscaler: {
        enabled: true
      }
    }
  }
}

// resource argocd 'Microsoft.KubernetesConfiguration/extensions@2024-11-01' = {
//   name: 'argocd'
//   scope: aksCluster
//   plan: {
//     name: 'main'
//     product: 'argo-cd-cnab'
//     publisher: 'bitnami'
//   }
//   properties: {
//     autoUpgradeMinorVersion: false
//     configurationProtectedSettings: {}
//     configurationSettings: {
//       '': ''
//     }
//     extensionType: 'Bitnami.ArgocdMain'
//     releaseTrain: 'stable'
//     scope: {
//       cluster: {
//         releaseNamespace: 'argocd'
//       }
//     }
//   }
// }

resource dataCollectionEndpoint 'Microsoft.Insights/dataCollectionEndpoints@2023-03-11' = {
  name: 'MSProm-${resourceGroup().location}-${aksCluster.name}'
  location: resourceGroup().location
  kind: 'Linux'
  properties: {
    description: 'Data Collection Endpoint for Prometheus'
  }
}

resource dataCollectionRuleAssociationEndpoint 'Microsoft.Insights/dataCollectionRuleAssociations@2023-03-11' = {
  name: 'configurationAccessEndpoint'
  scope: aksCluster
  properties: {
    dataCollectionEndpointId: dataCollectionEndpoint.id
  }
}

resource dataCollectionRuleMSCI 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: 'MSCI-${resourceGroup().location}-${aksCluster.name}'
  location: resourceGroup().location
  kind: 'Linux'
  properties: {
    dataSources: {
      syslog: []
      extensions: [
        {
          streams: [
            'Microsoft-ContainerInsights-Group-Default'
          ]
          extensionName: 'ContainerInsights'
          extensionSettings: {
            dataCollectionSettings: {
              interval: '1m'
              namespaceFilteringMode: 'Off'
              enableContainerLogV2: true
            }
          }
          name: 'ContainerInsightsExtension'
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: logsWorkspace.id
          name: 'ciworkspace'
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-ContainerInsights-Group-Default'
        ]
        destinations: [
          'ciworkspace'
        ]
      }
    ]
  }
}

resource dataCollectionRuleAssociationMSCI 'Microsoft.Insights/dataCollectionRuleAssociations@2023-03-11' = {
  name: 'MSCI-${resourceGroup().location}-${aksCluster.name}'
  scope: aksCluster
  properties: {
    dataCollectionRuleId: dataCollectionRuleMSCI.id
  }
}

resource dataCollectionRuleMSProm 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: 'MSProm-${resourceGroup().location}-${aksCluster.name}'
  location: resourceGroup().location
  kind: 'Linux'
  properties: {
    dataCollectionEndpointId: dataCollectionEndpoint.id
    dataSources: {
      prometheusForwarder: [
        {
          streams: [
            'Microsoft-PrometheusMetrics'
          ]
          name: 'PrometheusDataSource'
        }
      ]
    }
    destinations: {
      monitoringAccounts: [
        {
          accountResourceId: monitorWorkspace.id
          name: 'MonitoringAccount1'
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-PrometheusMetrics'
        ]
        destinations: [
          'MonitoringAccount1'
        ]
      }
    ]
  }
}

resource dataCollectionRuleAssociationMSProm 'Microsoft.Insights/dataCollectionRuleAssociations@2023-03-11' = {
  name: 'MSProm-${resourceGroup().location}-${aksCluster.name}'
  scope: aksCluster
  properties: {
    dataCollectionRuleId: dataCollectionRuleMSProm.id
  }
}

resource prometheusK8sRules 'Microsoft.AlertsManagement/prometheusRuleGroups@2023-03-01' = {
  name: 'KubernetesRecordingRulesRuleGroup - ${aksCluster.name}'
  location: resourceGroup().location
  properties: {
    enabled: true
    description: 'Kubernetes Recording Rules RuleGroup'
    clusterName: aksCluster.name
    scopes: [
      monitorWorkspace.id
      aksCluster.id
    ]
    interval: 'PT1M'
    rules: [
      {
        record: 'node_namespace_pod_container:container_cpu_usage_seconds_total:sum_irate'
        expression: 'sum by (cluster, namespace, pod, container) (irate(container_cpu_usage_seconds_total{job="cadvisor", image!=""}[5m])) * on (cluster, namespace, pod) group_left(node) topk by (cluster, namespace, pod) (1, max by(cluster, namespace, pod, node) (kube_pod_info{node!=""}))'
      }
      {
        record: 'node_namespace_pod_container:container_memory_working_set_bytes'
        expression: 'container_memory_working_set_bytes{job="cadvisor", image!=""}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1, max by(namespace, pod, node) (kube_pod_info{node!=""}))'
      }
      {
        record: 'node_namespace_pod_container:container_memory_rss'
        expression: 'container_memory_rss{job="cadvisor", image!=""}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1, max by(namespace, pod, node) (kube_pod_info{node!=""}))'
      }
      {
        record: 'node_namespace_pod_container:container_memory_cache'
        expression: 'container_memory_cache{job="cadvisor", image!=""}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1, max by(namespace, pod, node) (kube_pod_info{node!=""}))'
      }
      {
        record: 'node_namespace_pod_container:container_memory_swap'
        expression: 'container_memory_swap{job="cadvisor", image!=""}* on (namespace, pod) group_left(node) topk by(namespace, pod) (1, max by(namespace, pod, node) (kube_pod_info{node!=""}))'
      }
      {
        record: 'cluster:namespace:pod_memory:active:kube_pod_container_resource_requests'
        expression: 'kube_pod_container_resource_requests{resource="memory",job="kube-state-metrics"} * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) ((kube_pod_status_phase{phase=~"Pending|Running"} == 1))'
      }
      {
        record: 'namespace_memory:kube_pod_container_resource_requests:sum'
        expression: 'sum by (namespace, cluster) (sum by (namespace, pod, cluster) (max by (namespace, pod, container, cluster) (kube_pod_container_resource_requests{resource="memory",job="kube-state-metrics"}) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (kube_pod_status_phase{phase=~"Pending|Running"} == 1)))'
      }
      {
        record: 'cluster:namespace:pod_cpu:active:kube_pod_container_resource_requests'
        expression: 'kube_pod_container_resource_requests{resource="cpu",job="kube-state-metrics"} * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) ((kube_pod_status_phase{phase=~"Pending|Running"} == 1))'
      }
      {
        record: 'namespace_cpu:kube_pod_container_resource_requests:sum'
        expression: 'sum by (namespace, cluster) (sum by (namespace, pod, cluster) (max by (namespace, pod, container, cluster) (kube_pod_container_resource_requests{resource="cpu",job="kube-state-metrics"}) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (kube_pod_status_phase{phase=~"Pending|Running"} == 1)))'
      }
      {
        record: 'cluster:namespace:pod_memory:active:kube_pod_container_resource_limits'
        expression: 'kube_pod_container_resource_limits{resource="memory",job="kube-state-metrics"} * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) ((kube_pod_status_phase{phase=~"Pending|Running"} == 1))'
      }
      {
        record: 'namespace_memory:kube_pod_container_resource_limits:sum'
        expression: 'sum by (namespace, cluster) (sum by (namespace, pod, cluster) (max by (namespace, pod, container, cluster) (kube_pod_container_resource_limits{resource="memory",job="kube-state-metrics"}) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (kube_pod_status_phase{phase=~"Pending|Running"} == 1)))'
      }
      {
        record: 'cluster:namespace:pod_cpu:active:kube_pod_container_resource_limits'
        expression: 'kube_pod_container_resource_limits{resource="cpu",job="kube-state-metrics"} * on (namespace, pod, cluster)group_left() max by (namespace, pod, cluster) ( (kube_pod_status_phase{phase=~"Pending|Running"} == 1) )'
      }
      {
        record: 'namespace_cpu:kube_pod_container_resource_limits:sum'
        expression: 'sum by (namespace, cluster) (sum by (namespace, pod, cluster) (max by (namespace, pod, container, cluster) (kube_pod_container_resource_limits{resource="cpu",job="kube-state-metrics"}) * on(namespace, pod, cluster) group_left() max by (namespace, pod, cluster) (kube_pod_status_phase{phase=~"Pending|Running"} == 1)))'
      }
      {
        record: 'namespace_workload_pod:kube_pod_owner:relabel'
        expression: 'max by (cluster, namespace, workload, pod) ((label_replace(label_replace(kube_pod_owner{job="kube-state-metrics", owner_kind="ReplicaSet"}, "replicaset", "$1", "owner_name", "(.*)") * on(replicaset, namespace) group_left(owner_name) topk by(replicaset, namespace) (1, max by (replicaset, namespace, owner_name) (kube_replicaset_owner{job="kube-state-metrics"})), "workload", "$1", "owner_name", "(.*)"  )))'
        labels: {
          workload_type: 'deployment'
        }
      }
      {
        record: 'namespace_workload_pod:kube_pod_owner:relabel'
        expression: 'max by (cluster, namespace, workload, pod) ((label_replace(kube_pod_owner{job="kube-state-metrics", owner_kind="DaemonSet"}, "workload", "$1", "owner_name", "(.*)")))'
        labels: {
          workload_type: 'daemonset'
        }
      }
      {
        record: 'namespace_workload_pod:kube_pod_owner:relabel'
        expression: 'max by (cluster, namespace, workload, pod) ((label_replace(kube_pod_owner{job="kube-state-metrics", owner_kind="StatefulSet"}, "workload", "$1", "owner_name", "(.*)")))'
        labels: {
          workload_type: 'statefulset'
        }
      }
      {
        record: 'namespace_workload_pod:kube_pod_owner:relabel'
        expression: 'max by (cluster, namespace, workload, pod) ((label_replace(kube_pod_owner{job="kube-state-metrics", owner_kind="Job"}, "workload", "$1", "owner_name", "(.*)")))'
        labels: {
          workload_type: 'job'
        }
      }
      {
        record: ':node_memory_MemAvailable_bytes:sum'
        expression: 'sum(node_memory_MemAvailable_bytes{job="node"} or (node_memory_Buffers_bytes{job="node"} + node_memory_Cached_bytes{job="node"} + node_memory_MemFree_bytes{job="node"} + node_memory_Slab_bytes{job="node"})) by (cluster)'
      }
      {
        record: 'cluster:node_cpu:ratio_rate5m'
        expression: 'sum(rate(node_cpu_seconds_total{job="node",mode!="idle",mode!="iowait",mode!="steal"}[5m])) by (cluster) /count(sum(node_cpu_seconds_total{job="node"}) by (cluster, instance, cpu)) by (cluster)'
      }
    ]
  }
}

resource prometheusNodeRules 'Microsoft.AlertsManagement/prometheusRuleGroups@2023-03-01' = {
  name: 'NodeRecordingRulesRuleGroup - ${aksCluster.name}'
  location: resourceGroup().location
  properties: {
    enabled: true
    description: 'Node Recording Rules RuleGroup'
    clusterName: aksCluster.name
    scopes: [
      monitorWorkspace.id
      aksCluster.id
    ]
    interval: 'PT1M'
    rules: [
      {
        record: 'instance:node_num_cpu:sum'
        expression: 'count without (cpu, mode) (node_cpu_seconds_total{job="node",mode="idle"})'
      }
      {
        record: 'instance:node_cpu_utilisation:rate5m'
        expression: '1 - avg without (cpu) (sum without (mode) (rate(node_cpu_seconds_total{job="node", mode=~"idle|iowait|steal"}[5m])))'
      }
      {
        record: 'instance:node_load1_per_cpu:ratio'
        expression: '(node_load1{job="node"}/  instance:node_num_cpu:sum{job="node"})'
      }
      {
        record: 'instance:node_memory_utilisation:ratio'
        expression: '1 - ((node_memory_MemAvailable_bytes{job="node"} or (node_memory_Buffers_bytes{job="node"} + node_memory_Cached_bytes{job="node"} + node_memory_MemFree_bytes{job="node"} + node_memory_Slab_bytes{job="node"})) / node_memory_MemTotal_bytes{job="node"})'
      }
      {
        record: 'instance:node_vmstat_pgmajfault:rate5m'
        expression: 'rate(node_vmstat_pgmajfault{job="node"}[5m])'
      }
      {
        record: 'instance_device:node_disk_io_time_seconds:rate5m'
        expression: 'rate(node_disk_io_time_seconds_total{job="node", device!=""}[5m])'
      }
      {
        record: 'instance_device:node_disk_io_time_weighted_seconds:rate5m'
        expression: 'rate(node_disk_io_time_weighted_seconds_total{job="node", device!=""}[5m])'
      }
      {
        record: 'instance:node_network_receive_bytes_excluding_lo:rate5m'
        expression: 'sum without (device) (rate(node_network_receive_bytes_total{job="node", device!="lo"}[5m]))'
      }
      {
        record: 'instance:node_network_transmit_bytes_excluding_lo:rate5m'
        expression: 'sum without (device) (rate(node_network_transmit_bytes_total{job="node", device!="lo"}[5m]))'
      }
      {
        record: 'instance:node_network_receive_drop_excluding_lo:rate5m'
        expression: 'sum without (device) (rate(node_network_receive_drop_total{job="node", device!="lo"}[5m]))'
      }
      {
        record: 'instance:node_network_transmit_drop_excluding_lo:rate5m'
        expression: 'sum without (device) (rate(node_network_transmit_drop_total{job="node", device!="lo"}[5m]))'
      }
    ]
  }
}

resource prometheusUXRules 'Microsoft.AlertsManagement/prometheusRuleGroups@2023-03-01' = {
  name: 'UXRecordingRulesRuleGroup - ${aksCluster.name}'
  location: resourceGroup().location
  properties: {
    enabled: true
    description: 'UX Recording Rules for Linux'
    clusterName: aksCluster.name
    scopes: [
      monitorWorkspace.id
      aksCluster.id
    ]
    interval: 'PT1M'
    rules: [
      {
        record: 'ux:pod_cpu_usage:sum_irate'
        expression: '(sum by (namespace, pod, cluster, microsoft_resourceid) (irate(container_cpu_usage_seconds_total{container != "", pod != "", job = "cadvisor"}[5m]))) * on (pod, namespace, cluster, microsoft_resourceid) group_left (node, created_by_name, created_by_kind) (max by (node, created_by_name, created_by_kind, pod, namespace, cluster, microsoft_resourceid) (kube_pod_info{pod != "", job = "kube-state-metrics"}))'
      }
      {
        record: 'ux:controller_cpu_usage:sum_irate'
        expression: 'sum by (namespace, node, cluster, created_by_name, created_by_kind, microsoft_resourceid) (ux:pod_cpu_usage:sum_irate)'
      }
      {
        record: 'ux:pod_workingset_memory:sum'
        expression: '(sum by (namespace, pod, cluster, microsoft_resourceid) (container_memory_working_set_bytes{container != "", pod != "", job = "cadvisor"})) * on (pod, namespace, cluster, microsoft_resourceid) group_left (node, created_by_name, created_by_kind)(max by (node, created_by_name, created_by_kind, pod, namespace, cluster, microsoft_resourceid) (kube_pod_info{pod != "", job = "kube-state-metrics"}))'
      }
      {
        record: 'ux:controller_workingset_memory:sum'
        expression: 'sum by (namespace, node, cluster, created_by_name, created_by_kind, microsoft_resourceid) (ux:pod_workingset_memory:sum)'
      }
      {
        record: 'ux:pod_rss_memory:sum'
        expression: '(sum by (namespace, pod, cluster, microsoft_resourceid) (container_memory_rss{container != "", pod != "", job = "cadvisor"})) * on (pod, namespace, cluster, microsoft_resourceid) group_left (node, created_by_name, created_by_kind)(max by (node, created_by_name, created_by_kind, pod, namespace, cluster, microsoft_resourceid) (kube_pod_info{pod != "", job = "kube-state-metrics"}))'
      }
      {
        record: 'ux:controller_rss_memory:sum'
        expression: 'sum by (namespace, node, cluster, created_by_name, created_by_kind, microsoft_resourceid) (ux:pod_rss_memory:sum)'
      }
      {
        record: 'ux:pod_container_count:sum'
        expression: 'sum by (node, created_by_name, created_by_kind, namespace, cluster, pod, microsoft_resourceid) (((sum by (container, pod, namespace, cluster, microsoft_resourceid) (kube_pod_container_info{container != "", pod != "", container_id != "", job = "kube-state-metrics"}) or sum by (container, pod, namespace, cluster, microsoft_resourceid) (kube_pod_init_container_info{container != "", pod != "", container_id != "", job = "kube-state-metrics"}))* on (pod, namespace, cluster, microsoft_resourceid) group_left (node, created_by_name, created_by_kind)(max by (node, created_by_name, created_by_kind, pod, namespace, cluster, microsoft_resourceid) (kube_pod_info{pod != "", job = "kube-state-metrics"}))))'
      }
      {
        record: 'ux:controller_container_count:sum'
        expression: 'sum by (node, created_by_name, created_by_kind, namespace, cluster, microsoft_resourceid) (ux:pod_container_count:sum)'
      }
      {
        record: 'ux:pod_container_restarts:max'
        expression: 'max by (node, created_by_name, created_by_kind, namespace, cluster, pod, microsoft_resourceid) (((max by (container, pod, namespace, cluster, microsoft_resourceid) (kube_pod_container_status_restarts_total{container != "", pod != "", job = "kube-state-metrics"}) or sum by (container, pod, namespace, cluster, microsoft_resourceid) (kube_pod_init_status_restarts_total{container != "", pod != "", job = "kube-state-metrics"}))* on (pod, namespace, cluster, microsoft_resourceid) group_left (node, created_by_name, created_by_kind)(max by (node, created_by_name, created_by_kind, pod, namespace, cluster, microsoft_resourceid) (kube_pod_info{pod != "", job = "kube-state-metrics"}))))'
      }
      {
        record: 'ux:controller_container_restarts:max'
        expression: 'max by (node, created_by_name, created_by_kind, namespace, cluster, microsoft_resourceid) (ux:pod_container_restarts:max)'
      }
      {
        record: 'ux:pod_resource_limit:sum'
        expression: '(sum by (cluster, pod, namespace, resource, microsoft_resourceid) ((max by (cluster, microsoft_resourceid, pod, container, namespace, resource) (kube_pod_container_resource_limits{container != "", pod != "", job = "kube-state-metrics"})))unless (count by (pod, namespace, cluster, resource, microsoft_resourceid)(kube_pod_container_resource_limits{container != "", pod != "", job = "kube-state-metrics"})!= on (pod, namespace, cluster, microsoft_resourceid) group_left() sum by (pod, namespace, cluster, microsoft_resourceid) (kube_pod_container_info{container != "", pod != "", job = "kube-state-metrics"}) ))* on (namespace, pod, cluster, microsoft_resourceid) group_left (node, created_by_kind, created_by_name)(kube_pod_info{pod != "", job = "kube-state-metrics"})'
      }
      {
        record: 'ux:controller_resource_limit:sum'
        expression: 'sum by (cluster, namespace, created_by_name, created_by_kind, node, resource, microsoft_resourceid) (ux:pod_resource_limit:sum)'
      }
      {
        record: 'ux:controller_pod_phase_count:sum'
        expression: 'sum by (cluster, phase, node, created_by_kind, created_by_name, namespace, microsoft_resourceid) ( ((kube_pod_status_phase{job="kube-state-metrics",pod!=""}) or (label_replace((count(kube_pod_deletion_timestamp{job="kube-state-metrics",pod!=""}) by (namespace, pod, cluster, microsoft_resourceid) * count(kube_pod_status_reason{reason="NodeLost", job="kube-state-metrics"} == 0) by (namespace, pod, cluster, microsoft_resourceid)), "phase", "terminating", "", ""))) * on (pod, namespace, cluster, microsoft_resourceid) group_left (node, created_by_name, created_by_kind)(max by (node, created_by_name, created_by_kind, pod, namespace, cluster, microsoft_resourceid) (kube_pod_info{job="kube-state-metrics",pod!=""})))'
      }
      {
        record: 'ux:cluster_pod_phase_count:sum'
        expression: 'sum by (cluster, phase, node, namespace, microsoft_resourceid) (ux:controller_pod_phase_count:sum)'
      }
      {
        record: 'ux:node_cpu_usage:sum_irate'
        expression: 'sum by (instance, cluster, microsoft_resourceid) ((1 - irate(node_cpu_seconds_total{job="node", mode="idle"}[5m])))'
      }
      {
        record: 'ux:node_memory_usage:sum'
        expression: 'sum by (instance, cluster, microsoft_resourceid) ((node_memory_MemTotal_bytes{job = "node"}- node_memory_MemFree_bytes{job = "node"} - node_memory_cached_bytes{job = "node"}- node_memory_buffers_bytes{job = "node"}))'
      }
      {
        record: 'ux:node_network_receive_drop_total:sum_irate'
        expression: 'sum by (instance, cluster, microsoft_resourceid) (irate(node_network_receive_drop_total{job="node", device!="lo"}[5m]))'
      }
      {
        record: 'ux:node_network_transmit_drop_total:sum_irate'
        expression: 'sum by (instance, cluster, microsoft_resourceid) (irate(node_network_transmit_drop_total{job="node", device!="lo"}[5m]))'
      }
    ]
  }
}

resource actionGroup 'Microsoft.Insights/actionGroups@2024-10-01-preview' = {
  name: 'RecommendedAlertRules-AG-1'
  location: 'Global'
  properties: {
    groupShortName: 'recalert1'
    enabled: true
    emailReceivers: [
      {
        name: 'Email_-EmailAction-'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

resource metricAlertCpu 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'CPU Usage Percentage - ${aksCluster.name}'
  location: 'Global'
  properties: {
    severity: 3
    enabled: true
    scopes: [
      aksCluster.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
      allOf: [
        {
          threshold: 95
          name: 'Metric1'
          metricNamespace: 'Microsoft.ContainerService/managedClusters'
          metricName: 'node_cpu_usage_percentage'
          operator: 'GreaterThan'
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    targetResourceType: 'Microsoft.ContainerService/managedClusters'
    actions: [
      {
        actionGroupId: actionGroup.id
        webHookProperties: {}
      }
    ]
  }
}

resource metricAlertMemory 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Memory Working Set Percentage - ${aksCluster.name}'
  location: 'Global'
  properties: {
    severity: 3
    enabled: true
    scopes: [
      aksCluster.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
      allOf: [
        {
          threshold: 100
          name: 'Metric1'
          metricNamespace: 'Microsoft.ContainerService/managedClusters'
          metricName: 'node_memory_working_set_percentage'
          operator: 'GreaterThan'
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    targetResourceType: 'Microsoft.ContainerService/managedClusters'
    actions: [
      {
        actionGroupId: actionGroup.id
        webHookProperties: {}
      }
    ]
  }
}

resource contributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (addRoleAssignments) {
  name: guid(userAssignedIdentity.id, 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor role
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'b24988ac-6180-42a0-ab88-20f7382dd24c'
    ) // Contributor role
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource cognitiveServicesOpenAIUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (addRoleAssignments) {
  name: guid(userAssignedIdentity.id, aiServices.id, '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd') // Cognitive Services OpenAI User role
  scope: aiServices
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
    ) // Cognitive Services OpenAI User role
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource monitoringReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (addRoleAssignments) {
  name: guid(userAssignedIdentity.id, monitorWorkspace.id, '43d0d8ad-25c7-4714-9337-8ba259a9fe05') // Monitoring Reader role
  scope: monitorWorkspace
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '43d0d8ad-25c7-4714-9337-8ba259a9fe05'
    ) // Monitoring Reader role
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource logAnalyticsReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (addRoleAssignments) {
  name: guid(userAssignedIdentity.id, logsWorkspace.id, '43d0d8ad-25c7-4714-9337-8ba259a9fe05') // Log Analytics Reader role
  scope: logsWorkspace
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '43d0d8ad-25c7-4714-9337-8ba259a9fe05'
    ) // Log Analytics Reader role
    principalId: userAssignedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output logsWorkspaceId string = logsWorkspace.id
output monitorWorkspaceId string = monitorWorkspace.id
output aksId string = aksCluster.id
output aiServicesId string = aiServices.id
output aiServicesEndpoint string = aiServices.properties.endpoint
output aiServicesKey string = aiServices.listKeys().key1
output userAssignedIdentityId string = userAssignedIdentity.id
output userAssignedIdentityPrincipalId string = userAssignedIdentity.properties.principalId
output userAssignedIdentityClientId string = userAssignedIdentity.properties.clientId
output aksName string = aksCluster.name
output rgName string = resourceGroup().name
output loadTestId string = loadTest.id
output loadTestName string = loadTest.name
