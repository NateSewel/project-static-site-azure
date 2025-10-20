#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Load variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/variables.sh"

# Quick checks
if ! command -v az >/dev/null 2>&1; then
  echo "❌ az CLI not found. Install az CLI and login with OIDC before running."
  exit 2
fi

if [ ! -f "${SSH_KEY_PATH}" ]; then
  echo "❌ SSH public key not found at ${SSH_KEY_PATH}. Create one with 'ssh-keygen'."
  exit 2
fi

echo "[1/7] Setting subscription"
az account set --subscription "${AZ_SUBSCRIPTION_ID}"

echo "[2/7] Creating resource group: ${RESOURCE_GROUP}"
az group create --name "${RESOURCE_GROUP}" --location "${AZ_LOCATION}" --output none

echo "[3/7] Creating VNet ${VNET_NAME} with subnet ${SUBNET_NAME}"
az network vnet create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${VNET_NAME}" \
  --address-prefix "${VNET_PREFIX}" \
  --subnet-name "${SUBNET_NAME}" \
  --subnet-prefix "${SUBNET_PREFIX}" \
  --output none

echo "[4/7] Creating NSG ${NSG_NAME} and rules"
az network nsg create --resource-group "${RESOURCE_GROUP}" --name "${NSG_NAME}" --output none

# Allow HTTP, HTTPS, SSH inbound
for rule in "Allow-HTTP 80" "Allow-HTTPS 443" "Allow-SSH 22"; do
  read -r NAME PORT <<< "$rule"
  az network nsg rule create --resource-group "${RESOURCE_GROUP}" --nsg-name "${NSG_NAME}" \
    --name "$NAME" --priority $((100 + RANDOM % 50)) --protocol Tcp \
    --destination-port-ranges "$PORT" --access Allow --direction Inbound --output none
done

echo "[5/7] Creating Public IP"
az network public-ip create --resource-group "${RESOURCE_GROUP}" --name "${PUBLIC_IP_NAME}" \
  --allocation-method Static --sku Standard --output none

echo "[6/7] Creating NIC ${NIC_NAME}"
SUBNET_ID=$(az network vnet subnet show --resource-group "${RESOURCE_GROUP}" --vnet-name "${VNET_NAME}" --name "${SUBNET_NAME}" --query id -o tsv)
az network nic create --resource-group "${RESOURCE_GROUP}" --name "${NIC_NAME}" \
  --vnet-name "${VNET_NAME}" --subnet "${SUBNET_NAME}" \
  --network-security-group "${NSG_NAME}" \
  --public-ip-address "${PUBLIC_IP_NAME}" --output none

echo "[7/7] Creating VM ${VM_NAME} (cloud-init will deploy site)"
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
echo "🌐 Website should be available at http://${PUBLIC_IP}/"
