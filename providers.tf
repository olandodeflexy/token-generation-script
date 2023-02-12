terraform {
  required_version = ">0.12"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
  #Configure Remote State - Backend - on Azure Storage Account in a separate location away from resources
  backend "azurerm" {
    resource_group_name  = "mec-tfstates-rg"
    storage_account_name = "argocdremotestate"
    container_name       = "tftstateargocddev01"
    key                  = "argocd_dev01.tfstate"
  }

}



provider "azurerm" {
  features {}
}