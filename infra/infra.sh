#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

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

echo "[1/11] Setting subscription"
if [ -n "${AZ_SUBSCRIPTION_ID}" ]; then
  az account set --subscription "${AZ_SUBSCRIPTION_ID}"
fi

echo "[2/11] Creating resource group: ${RESOURCE_GROUP}"
az group create --name "${RESOURCE_GROUP}" --location "${AZ_LOCATION}" --output none

echo "[3/11] Creating VNet ${VNET_NAME} with subnet ${SUBNET_NAME}"
az network vnet create \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${VNET_NAME}" \
  --address-prefix "${VNET_PREFIX}" \
  --subnet-name "${SUBNET_NAME}" \
  --subnet-prefix "${SUBNET_PREFIX}" \
  --output none

echo "[4/11] Creating Network Security Group ${NSG_NAME} and rules"
az network nsg create --resource-group "${RESOURCE_GROUP}" --name "${NSG_NAME}" --output none

# Allow HTTP and HTTPS inbound
az network nsg rule create --resource-group "${RESOURCE_GROUP}" --nsg-name "${NSG_NAME}" \
  --name "Allow-HTTP" --priority 100 --protocol Tcp --destination-port-ranges 80 \
  --access Allow --direction Inbound --output none

az network nsg rule create --resource-group "${RESOURCE_GROUP}" --nsg-name "${NSG_NAME}" \
  --name "Allow-HTTPS" --priority 110 --protocol Tcp --destination-port-ranges 443 \
  --access Allow --direction Inbound --output none

# Allow SSH in (optional)
az network nsg rule create --resource-group "${RESOURCE_GROUP}" --nsg-name "${NSG_NAME}" \
  --name "Allow-SSH" --priority 120 --protocol Tcp --destination-port-ranges 22 \
  --access Allow --direction Inbound --output none

echo "[5/11] Creating Public IP"
az network public-ip create --resource-group "${RESOURCE_GROUP}" --name "${PUBLIC_IP_NAME}" \
  --allocation-method Static --sku Standard --output none

echo "[6/11] Creating NIC and associating NSG and Subnet"
SUBNET_ID=$(az network vnet subnet show --resource-group "${RESOURCE_GROUP}" --vnet-name "${VNET_NAME}" --name "${SUBNET_NAME}" --query id -o tsv)

az network nic create --resource-group "${RESOURCE_GROUP}" --name "${NIC_NAME}" \
  --vnet-name "${VNET_NAME}" --subnet "${SUBNET_NAME}" \
  --network-security-group "${NSG_NAME}" \
  --public-ip-address "${PUBLIC_IP_NAME}" --output none

echo "[7/11] Preparing site bundle"
pushd "${SCRIPT_DIR}/.." >/dev/null
zip -r "${SITE_ZIP}" site -x "*/.git/*" >/dev/null
popd >/dev/null

# Upload site bundle to a temporary storage: we'll use az vm run-command to fetch from the running machine
echo "[8/11] Creating VM ${VM_NAME} (this may take a few minutes)"
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
echo "Public IP: ${PUBLIC_IP}"

# Wait until VM responds to run-command
echo "[9/11] Uploading site bundle to VM using az vm run-command (base64 transfer)"
VM_ID_JSON="/tmp/vm_create_out.json"
VM_RESOURCE_GROUP="${RESOURCE_GROUP}"
# encode zip to base64 and send as a script to write file on VM
BASE64_ZIP=$(base64 -w 0 "${SCRIPT_DIR}/../${SITE_ZIP}")
RUN_SCRIPT=$(cat <<EOF
#!/bin/bash
set -e
cat <<'BASE64ZIP' > /tmp/site.b64
${BASE64_ZIP}
BASE64ZIP
base64 -d /tmp/site.b64 > /tmp/site.zip
apt-get update -y || true
apt-get install -y unzip || true
mkdir -p /var/www/html
unzip -o /tmp/site.zip -d /var/www/html
chown -R www-data:www-data /var/www/html
systemctl restart nginx || true
EOF
)

# Create a temporary script file
echo "${RUN_SCRIPT}" > /tmp/run_upload.sh
chmod +x /tmp/run_upload.sh

echo "[10/11] Running command on VM to extract site bundle (requires VM to be ready)"
az vm run-command invoke \
  --command-id RunShellScript \
  --name "${VM_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --scripts "@/tmp/run_upload.sh" \
  --output json

echo "[11/11] Done. Website should be available at http://${PUBLIC_IP}/"
echo "Visit: http://${PUBLIC_IP}/"

# Save outputs for later
cat > "${SCRIPT_DIR}/deploy_output.json" <<EOF
{
  "resource_group": "${RESOURCE_GROUP}",
  "public_ip": "${PUBLIC_IP}",
  "vm_name": "${VM_NAME}"
}
EOF

echo "Saved deploy_output.json in ${SCRIPT_DIR}"
