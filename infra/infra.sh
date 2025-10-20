#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ======================================================
# Azure Infrastructure Setup Script (Static Website VM)
# ======================================================

# Load variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/variables.sh"

# Quick checks
if ! command -v az >/dev/null 2>&1; then
  echo "az CLI not found. Install az CLI and login with 'az login' before running."
  exit 2
fi

if [ ! -f "${SSH_KEY_PATH}" ]; then
  echo "SSH public key not found at ${SSH_KEY_PATH}. Create one with 'ssh-keygen'."
  exit 2
fi

# -----------------------------
# 1️⃣ Set subscription
# -----------------------------
echo "[1/7] Setting subscription"
az account set --subscription "${AZ_SUBSCRIPTION_ID}"

# -----------------------------
# 2️⃣ Create Resource Group
# -----------------------------
echo "[2/7] Creating resource group: ${RESOURCE_GROUP}"
az group create --name "${RESOURCE_GROUP}" --location "${AZ_LOCATION}" --output none

# -----------------------------
# 3️⃣ Create VNet & Subnet
# -----------------------------
echo "[3/7] Creating VNet ${VNET_NAME} with subnet ${SUBNET_NAME}"
az network vnet create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${VNET_NAME}" \
  --address-prefix "${VNET_PREFIX}" \
  --subnet-name "${SUBNET_NAME}" \
  --subnet-prefix "${SUBNET_PREFIX}" \
  --output none

# -----------------------------
# 4️⃣ Create NSG and rules
# -----------------------------
echo "[4/7] Creating NSG ${NSG_NAME} and rules"
az network nsg create --resource-group "${RESOURCE_GROUP}" --name "${NSG_NAME}" --output none

# Inbound rules
az network nsg rule create --resource-group "${RESOURCE_GROUP}" --nsg-name "${NSG_NAME}" \
  --name "Allow-HTTP" --priority 100 --protocol Tcp --destination-port-ranges 80 \
  --access Allow --direction Inbound --output none

az network nsg rule create --resource-group "${RESOURCE_GROUP}" --nsg-name "${NSG_NAME}" \
  --name "Allow-HTTPS" --priority 110 --protocol Tcp --destination-port-ranges 443 \
  --access Allow --direction Inbound --output none

az network nsg rule create --resource-group "${RESOURCE_GROUP}" --nsg-name "${NSG_NAME}" \
  --name "Allow-SSH" --priority 120 --protocol Tcp --destination-port-ranges 22 \
  --access Allow --direction Inbound --output none

# Outbound rule: allow all internet traffic
az network nsg rule create --resource-group "${RESOURCE_GROUP}" --nsg-name "${NSG_NAME}" \
  --name "Allow-Internet-Outbound" --priority 1000 --protocol Tcp \
  --destination-address-prefix Internet --destination-port-ranges '*' \
  --access Allow --direction Outbound --output none

# -----------------------------
# 5️⃣ Create Public IP
# -----------------------------
echo "[5/7] Creating Public IP ${PUBLIC_IP_NAME}"
az network public-ip create --resource-group "${RESOURCE_GROUP}" --name "${PUBLIC_IP_NAME}" \
  --allocation-method Static --sku Standard --output none

# -----------------------------
# 6️⃣ Create NIC and associate NSG & Subnet
# -----------------------------
echo "[6/7] Creating NIC ${NIC_NAME}"
az network nic create --resource-group "${RESOURCE_GROUP}" --name "${NIC_NAME}" \
  --vnet-name "${VNET_NAME}" --subnet "${SUBNET_NAME}" \
  --network-security-group "${NSG_NAME}" \
  --public-ip-address "${PUBLIC_IP_NAME}" --output none

# -----------------------------
# 7️⃣ Create VM (cloud-init handles website)
# -----------------------------
echo "[7/7] Creating VM ${VM_NAME} (cloud-init handles website)"
az vm create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${VM_NAME}" \
  --size "${VM_SIZE}" \
  --image "${VM_IMAGE}" \
  --admin-username "${ADMIN_USERNAME}" \
  --ssh-key-values "${SSH_KEY_PATH}" \
  --nics "${NIC_NAME}" \
  --custom-data "../vm/cloud-init.yml" \
  --output json > /tmp/vm_create_out.json

# Extract public IP
PUBLIC_IP=$(az network public-ip show --resource-group "${RESOURCE_GROUP}" --name "${PUBLIC_IP_NAME}" --query ipAddress -o tsv)
echo "🌐 Website should be available at: http://${PUBLIC_IP}/"
