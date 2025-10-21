#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# -------------------------------
# Load environment variables
# -------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/../.env" ]; then
  echo "📦 Loading environment variables from .env..."
  set -a
  source "${SCRIPT_DIR}/../.env"
  set +a
else
  echo "⚙️ No .env file found. Relying on environment variables..."
fi

# -------------------------------
# Validate required variables
# -------------------------------
REQUIRED_VARS=("AZ_SUBSCRIPTION_ID" "AZ_LOCATION" "RESOURCE_GROUP" "VNET_NAME" "SUBNET_NAME" "SUBNET_PREFIX" "VNET_PREFIX" "NSG_NAME" "VM_NAME" "ADMIN_USERNAME" "SSH_KEY_PATH" "VM_SIZE" "VM_IMAGE" "PUBLIC_IP_NAME" "NIC_NAME")
for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var-}" ]; then
    echo "❌ ERROR: $var is not set!"
    exit 1
  fi
done

echo "🔑 Using SSH key at ${SSH_KEY_PATH}"

# -------------------------------
# Azure Deployment Steps
# -------------------------------

echo "[1/7] Setting subscription"
az account set --subscription "${AZ_SUBSCRIPTION_ID}"

echo "[2/7] Creating Resource Group: ${RESOURCE_GROUP}"
az group create --name "${RESOURCE_GROUP}" --location "${AZ_LOCATION}" --output none

echo "[3/7] Creating VNet ${VNET_NAME} with Subnet ${SUBNET_NAME}"
az network vnet create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${VNET_NAME}" \
  --address-prefix "${VNET_PREFIX}" \
  --subnet-name "${SUBNET_NAME}" \
  --subnet-prefix "${SUBNET_PREFIX}" \
  --output none

echo "[4/7] Creating NSG ${NSG_NAME} and rules"
echo "[4/7] Creating NSG ${NSG_NAME} and ensuring rules exist"

# Create NSG if it doesn't exist
if ! az network nsg show --resource-group "${RESOURCE_GROUP}" --name "${NSG_NAME}" &>/dev/null; then
  echo "📦 NSG ${NSG_NAME} does not exist. Creating..."
  az network nsg create --resource-group "${RESOURCE_GROUP}" --name "${NSG_NAME}" --output none
else
  echo "⚙️ NSG ${NSG_NAME} already exists. Skipping creation."
fi

# Function to create or update NSG rule
ensure_nsg_rule() {
  local RULE_NAME=$1
  local PRIORITY=$2
  local DIRECTION=$3
  local PORTS=$4
  local ACCESS=$5
  local PROTOCOL=${6:-Tcp}
  local DEST_PREFIX=${7:-'*'}

  if az network nsg rule show --resource-group "${RESOURCE_GROUP}" --nsg-name "${NSG_NAME}" --name "${RULE_NAME}" &>/dev/null; then
    echo "🔄 Updating existing NSG rule: ${RULE_NAME}"
    az network nsg rule update \
      --resource-group "${RESOURCE_GROUP}" \
      --nsg-name "${NSG_NAME}" \
      --name "${RULE_NAME}" \
      --protocol "${PROTOCOL}" \
      --direction "${DIRECTION}" \
      --priority "${PRIORITY}" \
      --destination-port-ranges "${PORTS}" \
      --access "${ACCESS}" \
      --destination-address-prefixes "${DEST_PREFIX}" \
      --output none
  else
    echo "➕ Creating NSG rule: ${RULE_NAME}"
    az network nsg rule create \
      --resource-group "${RESOURCE_GROUP}" \
      --nsg-name "${NSG_NAME}" \
      --name "${RULE_NAME}" \
      --protocol "${PROTOCOL}" \
      --direction "${DIRECTION}" \
      --priority "${PRIORITY}" \
      --destination-port-ranges "${PORTS}" \
      --access "${ACCESS}" \
      --destination-address-prefixes "${DEST_PREFIX}" \
      --output none
  fi
}

# Ensure required NSG rules
ensure_nsg_rule "Allow-HTTP" 100 Inbound 80 Allow
ensure_nsg_rule "Allow-HTTPS" 110 Inbound 443 Allow
ensure_nsg_rule "Allow-SSH" 120 Inbound 22 Allow
ensure_nsg_rule "Allow-Outbound-HTTPS" 130 Outbound 443 Allow Tcp Internet


echo "[5/7] Creating Public IP ${PUBLIC_IP_NAME}"
az network public-ip create --resource-group "${RESOURCE_GROUP}" --name "${PUBLIC_IP_NAME}" --allocation-method Static --sku Standard --output none

echo "[6/7] Creating NIC ${NIC_NAME}"
az network nic create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${NIC_NAME}" \
  --vnet-name "${VNET_NAME}" \
  --subnet "${SUBNET_NAME}" \
  --network-security-group "${NSG_NAME}" \
  --public-ip-address "${PUBLIC_IP_NAME}" \
  --output none

echo "[7/7] Creating VM ${VM_NAME} (cloud-init will deploy website)"
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
