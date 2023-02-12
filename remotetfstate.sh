#!/bin/sh

set -e

RESOURCE_GROUP_NAME="mec-tfstates-rg"
STORAGE_ACCOUNT_NAME="argocdremotestate"
location="eastus"
tfstatename_container="tftstateargocddev01"
KEYVAULT="argocd-tfs-kvault" # Parameter 'vault_name' must conform to the following pattern: '^[a-zA-Z0-9-]{3,24}$'.
KEYVAULTSECRET="argocdtfstatesecret" 
KEY="argocd_dev01.tfstate" # i.e. "vnet_appappgtw_terraform.tfstate"  - make sure naming convention follows after resources being built by terraform

# Create Resource Group
echo "Creating $RESOURCE_GROUP_NAME resource group..."
az group create -l $location -n $RESOURCE_GROUP_NAME --tags 'environment=production' 'business-owner-email=francis.poku@tiacloud.co.uk' 'division=TIA' 'managed-by=tiacloud' 'product=iac'

echo "Resource group $RESOURCE_GROUP_NAME created."

# Create Storage Account
echo "Creating $STORAGE_ACCOUNT storage account..."
az storage account create -n $STORAGE_ACCOUNT_NAME -g $RESOURCE_GROUP_NAME -l $location --sku Standard_LRS --encryption-services blob --tags 'environment=production' 'business-owner-email=francis.poku@tiacloud.co.uk' 'division=TIA' 'managed-by=tiacloud' 'product=iac'

echo "Storage account $STORAGE_ACCOUNT created."

# Retrieve the storage account key
echo "Retrieving storage account key..."
ACCOUNT_KEY=$(az storage account keys list --resource-group $RESOURCE_GROUP_NAME --account-name $STORAGE_ACCOUNT_NAME --query '[0].value' -o tsv)

echo "Storage account key retrieved."

# Create Storage Account blob
echo "Creating $tfstatename_container storage container..."
az storage container create  --name $tfstatename_container --account-name $STORAGE_ACCOUNT_NAME

echo "Storage container $tfstatename_container  created."



#Create Key Vault
echo "Creating $KEYVAULT key vault..."
az keyvault create --name $KEYVAULT --resource-group $RESOURCE_GROUP_NAME --location $location

echo "Key vault $KEYVAULT created."

#Create Secret Key
echo "Store storage access key into key vault secret..."
az keyvault secret set --name $KEYVAULTSECRET --vault-name $KEYVAULT --value $ACCOUNT_KEY

echo "Key vault secret created."

# Display information
echo "Azure Storage Account and KeyVault have been created."
echo "Run the following command to initialize Terraform to store its state into Azure Storage:"
echo "terraform init  -backend-config=\"storage_account_name=$STORAGE_ACCOUNT_NAME\" -backend-config=\"container_name=$tfstatename_container\" -backend-config=\"access_key=\$(az keyvault secret show --name $KEYVAULTSECRET --vault-name $KEYVAULT --query value -o tsv)\" -backend-config=\"key=$KEY\""