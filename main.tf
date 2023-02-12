# Generate random resource group name
resource "random_pet" "rg-name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "argocd-cluster-rg" {
  name     = random_pet.rg-name.id
  location = var.resource_group_location
}

resource "random_id" "log_analytics_workspace_name_suffix" {
  byte_length = 8
}


# Create (and display) an SSH key
resource "tls_private_key" "linuxvmsshkey" {
  algorithm = "RSA"
  rsa_bits  = 4096
}



####Create Work Analytics Workspace

resource "azurerm_log_analytics_workspace" "argocd-log-analytics" {
  # The WorkSpace name has to be unique across the whole of azure, not just the current subscription/tenant.
  name                = "${var.log_analytics_workspace_name}-${random_id.log_analytics_workspace_name_suffix.dec}"
  location            = var.log_analytics_workspace_location
  resource_group_name = azurerm_resource_group.argocd-cluster-rg.name
  sku                 = var.log_analytics_workspace_sku
}

####Create ContainerInsights for Log Analytics
resource "azurerm_log_analytics_solution" "argocd-container-insights" {
  solution_name         = "ContainerInsights"
  location              = azurerm_log_analytics_workspace.argocd-log-analytics.location
  resource_group_name   = azurerm_resource_group.argocd-cluster-rg.name
  workspace_resource_id = azurerm_log_analytics_workspace.argocd-log-analytics.id
  workspace_name        = azurerm_log_analytics_workspace.argocd-log-analytics.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }
}

##############################################
# Configuring Networking
##############################################

#Create AKS Virtual Network for Node Pools
resource "azurerm_virtual_network" "argocd-virtual-network" {
  name                = "${var.resource_group_location}-argocd"
  location            = azurerm_resource_group.argocd-cluster-rg.location
  resource_group_name = azurerm_resource_group.argocd-cluster-rg.name
  address_space       = ["172.20.0.0/16"]
  tags = {

    environment = "Node Pool VNet"
  }

}

# Locals block for hardcoded names
locals {
  backend_address_pool_name      = "${azurerm_virtual_network.argocd-virtual-network.name}-beap"
  frontend_port_name             = "${azurerm_virtual_network.argocd-virtual-network.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.argocd-virtual-network.name}-feip"
  http_setting_name              = "${azurerm_virtual_network.argocd-virtual-network.name}-be-htst"
  listener_name                  = "${azurerm_virtual_network.argocd-virtual-network.name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.argocd-virtual-network.name}-rqrt"
}

#Create Kubernetes Service Subnet
resource "azurerm_subnet" "argocd-pool-subnet" {
  name                 = "argocd-pool-subnet"
  virtual_network_name = azurerm_virtual_network.argocd-virtual-network.name
  resource_group_name  = azurerm_resource_group.argocd-cluster-rg.name
  address_prefixes     = ["172.20.0.0/24"]
}

data "azurerm_subnet" "argocd-pool-subnet" {
  name                 = "argocd-pool-subnet"
  virtual_network_name = azurerm_virtual_network.argocd-virtual-network.name
  resource_group_name  = azurerm_resource_group.argocd-cluster-rg.name
  depends_on           = [azurerm_virtual_network.argocd-virtual-network]
}

#Create Application Gateway Ingress Controller Subnet
resource "azurerm_subnet" "argocd-agic-subnet" {
  name                 = "argocd-agic-subnet"
  virtual_network_name = azurerm_virtual_network.argocd-virtual-network.name
  resource_group_name  = azurerm_resource_group.argocd-cluster-rg.name
  address_prefixes     = ["172.20.1.0/24"]
}

data "azurerm_subnet" "argocd-agic-subnet" {
  name                 = "argocd-agic-subnet"
  virtual_network_name = azurerm_virtual_network.argocd-virtual-network.name
  resource_group_name  = azurerm_resource_group.argocd-cluster-rg.name
  depends_on           = [azurerm_virtual_network.argocd-virtual-network]

}

# Public Ip 
resource "azurerm_public_ip" "argocd-agic-publicip" {
  name                = "argocd-agic-publicip"
  location            = azurerm_resource_group.argocd-cluster-rg.location
  resource_group_name = azurerm_resource_group.argocd-cluster-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "argocd-agic" {
  name                = "argocd-agic"
  resource_group_name = azurerm_resource_group.argocd-cluster-rg.name
  location            = azurerm_resource_group.argocd-cluster-rg.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "argocd-agic-publicip"
    subnet_id = data.azurerm_subnet.argocd-agic-subnet.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_port {
    name = "httpsPort"
    port = 443
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.argocd-agic-publicip.id
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 1
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }

  depends_on = [azurerm_virtual_network.argocd-virtual-network, azurerm_public_ip.argocd-agic-publicip]
}



####Create AKS Cluster
resource "azurerm_kubernetes_cluster" "argocd-aks-cluster" {
  name                = var.cluster_name
  location            = azurerm_resource_group.argocd-cluster-rg.location
  resource_group_name = azurerm_resource_group.argocd-cluster-rg.name
  dns_prefix          = var.dns_prefix

  linux_profile {
    admin_username = "ubuntu"

    ssh_key {
      key_data = tls_private_key.linuxvmsshkey.public_key_openssh
      #file(var.ssh_public_key)
    }
  }

  ####Create AKS Cluster Master [System] Node
  default_node_pool {
    name       = "clusternode"
    node_count = 1
    vm_size    = "Standard_D2_v2" #Specify Good Compute Size for Cluster Master

  }


  ###Service Principal
  service_principal {
    client_id     = var.aks_service_principal_app_id
    client_secret = var.aks_service_principal_client_secret
  }

  #Enable Azure Policy
  azure_policy_enabled = true

  #CNI
  network_profile {
    load_balancer_sku = "Standard"
    network_plugin    = "kubenet"
  }

  tags = {
    Environment = "Development"
  }



}


#Create Node Pools with Predefined Variable Lists - Set Count based on List length(s)
resource "azurerm_kubernetes_cluster_node_pool" "argocdpool" {
  name                  = var.node_pool_names[count.index]
  availability_zones    = [1, 2, 3]
  enable_auto_scaling   = true
  kubernetes_cluster_id = azurerm_kubernetes_cluster.argocd-aks-cluster.id
  vm_size               = "standard_a2_v2" #"Standard_B1s"   #"Standard_D2_v2"
  os_disk_size_gb       = 30               # decide on disk sizes later.
  node_count            = var.agent_count  # set it to 2 for production
  min_count             = var.agent_count
  max_count             = var.node_max_count
  #orchestrator_version  = data.azurerm_kubernetes_service_versions.current.latest_version
  orchestrator_version = "1.23.8"
  os_sku               = "Ubuntu"
  count                = length(var.node_pool_names)
  node_labels          = null
  node_taints          = ["region=${var.node_pool_names[count.index]}:NoSchedule", "namespace=${var.node_pool_taints[count.index]}:NoSchedule"] #Validated successfully. Wrapped in list with count based on index in variable list [a,b,c]

  tags = {
    Environment = "Node Pools - ${var.node_pool_names[count.index]}"
  }
}





