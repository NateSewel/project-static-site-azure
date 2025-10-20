#!/bin/bash
# ======================================================
# Azure Variables Loader (local & CI/CD compatible)
# ======================================================

# List of required variables
REQUIRED_VARS=(
  "AZ_SUBSCRIPTION_ID"
  "AZ_LOCATION"
  "RESOURCE_GROUP"
  "VNET_NAME"
  "SUBNET_NAME"
  "NSG_NAME"
  "VM_NAME"
  "PUBLIC_IP_NAME"
  "NIC_NAME"
  "VM_SIZE"
  "VM_IMAGE"
  "ADMIN_USERNAME"
  "SSH_KEY_PATH"
)

# Load .env file if it exists (local development)
if [ -f "../.env" ]; then
  echo "📦 Loading environment variables from .env..."
  set -a
  source ../.env
  set +a
else
  echo "⚙️ No .env file found. Relying on environment variables..."
fi

# Validate required variables
for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var-}" ]; then
    echo "❌ ERROR: $var is not set! Please define it as an environment variable or in .env"
    exit 1
  fi
done

# Display loaded variables (safe for debugging)
echo "✅ Variables loaded successfully:"
for var in "${REQUIRED_VARS[@]}"; do
  echo "$var = ${!var}"
done
