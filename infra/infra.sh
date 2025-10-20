#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Load variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/variables.sh"

# Validate Azure CLI
if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI not found. Install it with 'az login'."
  exit 2
fi

# Validate SSH key
if [ ! -f "${SSH_KEY_PATH}" ]; then
  echo "SSH public key not found at ${SSH_KEY_PATH}. Generate with 'ssh-keygen'."
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
az network nsg rule create --resource-group "${RESOURCE_GROUP}" --nsg-name "${NSG_NAME}" \
  --name "Allow-HTTP" --priority 100 --protocol Tcp --destination-port-ranges 80 \
  --access Allow --direction Inbound --output none
az network nsg rule create --resource-group "${RESOURCE_GROUP}" --nsg-name "${NSG_NAME}" \
  --name "Allow-HTTPS" --priority 110 --protocol Tcp --destination-port-ranges 443 \
  --access Allow --direction Inbound --output none
az network nsg rule create --resource-group "${RESOURCE_GROUP}" --nsg-name "${NSG_NAME}" \
  --name "Allow-SSH" --priority 120 --protocol Tcp --destination-port-ranges 22 \
  --access Allow --direction Inbound --output none

# Allow all outbound traffic to GitHub (prevents cloud-init timeout)
az network nsg rule create --resource-group "$RESOURCE_GROUP" --nsg-name "$NSG_NAME" \
  --name "Allow-Outbound-Internet" --priority 1000 --protocol Tcp \
  --destination-address-prefix Internet --destination-port-ranges '*' \
  --access Allow --direction Outbound

echo "[5/7] Creating Public IP"
az network public-ip create --resource-group "${RESOURCE_GROUP}" --name "${PUBLIC_IP_NAME}" \
  --allocation-method Static --sku Standard --output none

echo "[6/7] Creating NIC ${NIC_NAME} and associating NSG + Subnet"
SUBNET_ID=$(az network vnet subnet show --resource-group "${RESOURCE_GROUP}" --vnet-name "${VNET_NAME}" --name "${SUBNET_NAME}" --query id -o tsv)
az network nic create --resource-group "${RESOURCE_GROUP}" --name "${NIC_NAME}" \
  --vnet-name "${VNET_NAME}" --subnet "${SUBNET_NAME}" \
  --network-security-group "${NSG_NAME}" \
  --public-ip-address "${PUBLIC_IP_NAME}" --output none

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
  --output json > /tmp/vm_create_out.json

PUBLIC_IP=$(az network public-ip show --resource-group "${RESOURCE_GROUP}" --name "${PUBLIC_IP_NAME}" --query ipAddress -o tsv)
echo "✅ VM Created. Website should be live at: http://${PUBLIC_IP}/"
