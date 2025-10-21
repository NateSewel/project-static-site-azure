#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/../.env" ]; then
  echo "📦 Loading environment variables from .env..."
  set -a
  source "${SCRIPT_DIR}/../.env"
  set +a
else
  echo "⚙️ No .env file found. Relying on environment variables..."
fi

# Validate required variables
REQUIRED_VARS=("AZ_SUBSCRIPTION_ID" "AZ_LOCATION" "RESOURCE_GROUP" "VM_NAME" "ADMIN_USERNAME" "SSH_KEY_PATH")
for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var-}" ]; then
    echo "❌ ERROR: $var is not set!"
    exit 1
  fi
done

# Check SSH key exists
if [ ! -f "${SSH_KEY_PATH}" ]; then
  echo "❌ SSH key not found at ${SSH_KEY_PATH}. Create one with 'ssh-keygen'."
  exit 2
fi

# Set subscription
echo "[1/7] Setting subscription"
az account set --subscription "${AZ_SUBSCRIPTION_ID}"

# Create Resource Group
echo "[2/7] Creating Resource Group: ${RESOURCE_GROUP}"
az group create --name "${RESOURCE_GROUP}" --location "${AZ_LOCATION}" --output none

# Create VNet & Subnet
echo "[3/7] Creating VNet ${VNET_NAME} with Subnet ${SUBNET_NAME}"
az network vnet create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${VNET_NAME}" \
  --address-prefix "${VNET_PREFIX}" \
  --subnet-name "${SUBNET_NAME}" \
  --subnet-prefix "${SUBNET_PREFIX}" \
  --output none

# Create NSG and inbound rules
echo "[4/7] Creating NSG ${NSG_NAME} and rules"
az network nsg create --resource-group "${RESOURCE_GROUP}" --name "${NSG_NAME}" --output none
az network nsg rule create --resource-group "${RESOURCE_GROUP}" --nsg-name "${NSG_NAME}" --name "Allow-HTTP" --priority 100 --protocol Tcp --destination-port-ranges 80 --access Allow --direction Inbound --output none
az network nsg rule create --resource-group "${RESOURCE_GROUP}" --nsg-name "${NSG_NAME}" --name "Allow-HTTPS" --priority 110 --protocol Tcp --destination-port-ranges 443 --access Allow --direction Inbound --output none
az network nsg rule create --resource-group "${RESOURCE_GROUP}" --nsg-name "${NSG_NAME}" --name "Allow-SSH" --priority 120 --protocol Tcp --destination-port-ranges 22 --access Allow --direction Inbound --output none

# Optional: outbound HTTPS to allow git clone
az network nsg rule create --resource-group "${RESOURCE_GROUP}" --nsg-name "${NSG_NAME}" --name "Allow-Outbound-HTTPS" --priority 130 --protocol Tcp --direction Outbound --destination-address-prefixes Internet --destination-port-ranges 443 --access Allow --output none

# Create Public IP
echo "[5/7] Creating Public IP ${PUBLIC_IP_NAME}"
az network public-ip create --resource-group "${RESOURCE_GROUP}" --name "${PUBLIC_IP_NAME}" --allocation-method Static --sku Standard --output none

# Create NIC
echo "[6/7] Creating NIC ${NIC_NAME}"
az network nic create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${NIC_NAME}" \
  --vnet-name "${VNET_NAME}" \
  --subnet "${SUBNET_NAME}" \
  --network-security-group "${NSG_NAME}" \
  --public-ip-address "${PUBLIC_IP_NAME}" \
  --output none

# Create VM with cloud-init
echo "[7/7] Creating VM ${VM_NAME} (cloud-init will handle website setup)"
az vm create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${VM_NAME}" \
  --size "${VM_SIZE}" \
  --image "${VM_IMAGE}" \
  --admin-username "${ADMIN_USERNAME}" \
  --ssh-key-values "${SSH_KEY_PATH}" \
  --nics "${NIC_NAME}" \
  --custom-data "../vm/cloud-init.yml" \
  --output json

# Show public IP
PUBLIC_IP=$(az network public-ip show --resource-group "${RESOURCE_GROUP}" --name "${PUBLIC_IP_NAME}" --query ipAddress -o tsv)
echo "✅ VM created. Access your website at http://${PUBLIC_IP}/"
echo "🚀 Deployment complete!"