#!/usr/bin/env bash
# Edit these for your environment (or pass env vars)
export AZ_SUBSCRIPTION_ID=""           # e.g. xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export AZ_LOCATION="eastus"           # change to your preferred region
export RG_NAME="rg-blizzy-static"     # Resource Group
export VNET_NAME="vnet-blizzy"
export VNET_PREFIX="10.0.0.0/16"
export SUBNET_NAME="snet-web"
export SUBNET_PREFIX="10.0.1.0/24"
export NSG_NAME="nsg-web"
export PUBLIC_IP_NAME="pip-blizzy"
export NIC_NAME="nic-blizzy"
export VM_NAME="vm-blizzy-web"
export VM_SIZE="Standard_B1s"
export VM_IMAGE="UbuntuLTS"
export ADMIN_USERNAME="azureuser"
# For SSH access: path to public key file
export SSH_KEY_PATH="$HOME/.ssh/id_rsa.pub"
# location to bundle site for upload (auto-generated)
export SITE_ZIP="site_bundle.zip"
