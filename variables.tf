variable "resource_group_name_prefix" {
  default     = "resource-group"
  description = "Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription."
}

variable "resource_group_location" {
  default     = "eastus"
  description = "Location of the resource group."
}


#Create Predefined Lists
variable "node_pool_names" {
  description = "Node Pools Availability Zones"
  type        = list(string)
  default     = ["europe", "northamerica", "asia"]
}


variable "node_pool_taints" {
  description = "Node Pools Namespace"
  type        = list(string)
  default     = ["eu", "na", "as"]
}


#Node Count for each NodePool
variable "agent_count" {
  default = 1
}


variable "node_min_count" {
  description = "Minimum number of nodes in the cluster"
  default     = 1
}

variable "node_max_count" {
  description = "Maximum number of nodes in the cluster"
  default     = 10
}

variable "max_pods" {
  description = "Total number of pods that can be started on a kubernetes node  "
  default     = 110
}


# variable "node_pool_taints" {
#   type = map(object({taints = list("key=value:NoSchedule", "key2=value2:NoSchedule", "key3=value3:NoSchedule")}))

# }


variable "map_example" {
  description = "map type"
  type        = map(any)
  default = {
    key1 = "value1"
    key1 = "value2"
    key1 = "value2"
  }





}

#Not needed if not already installed.
# variable "ssh_public_key" {
#     default = "~/.ssh/id_rsa.pub"
# }

variable "dns_prefix" {
  default = "argocd-aks-dns"
}

variable "cluster_name" {
  default = "argocd-aks-cluster"
}

variable "resource_group_name" {
  default = "argocd-cluster-rg"
}


variable "location" {
  default = "eastus"
}


variable "log_analytics_workspace_name" {
  default = "argocd-aks-log-analytics"
}

# refer https://azure.microsoft.com/global-infrastructure/services/?products=monitor for log analytics available regions
variable "log_analytics_workspace_location" {
  default = "eastus"
}

# refer https://azure.microsoft.com/pricing/details/monitor/ for log analytics pricing 
variable "log_analytics_workspace_sku" {
  default = "PerGB2018"
}



variable "aks_service_principal_app_id" {
  description = "Application ID/Client ID  of the service principal. Used by AKS to manage AKS related resources on Azure like vms, subnets."
}

variable "aks_service_principal_client_secret" {
  description = "Secret of the service principal. Used by AKS to manage Azure."
}

variable "aks_service_principal_object_id" {
  description = "Object ID of the service principal."
}


