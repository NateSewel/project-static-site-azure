#!/bin/bash
# ============================================================
# Azure Infrastructure Teardown Script with Verification
# Deletes all resources in a Resource Group and waits for completion
# ============================================================

# Load environment variables from .env if present
if [ -f "../.env" ]; then
  echo "📦 Loading environment variables from .env file..."
  set -a
  source ../.env
  set +a
else
  echo "⚠️ No .env file found — ensure variables are exported manually!"
fi

# Validate required environment variables
REQUIRED_VARS=("AZ_SUBSCRIPTION_ID" "RESOURCE_GROUP")
for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var}" ]; then
    echo "❌ ERROR: $var is not set. Please export it or define it in .env"
    exit 1
  fi
done

echo "✅ All required environment variables are loaded."
echo "----------------------------------------------"
echo "Subscription: $AZ_SUBSCRIPTION_ID"
echo "Resource Group: $RESOURCE_GROUP"
echo "----------------------------------------------"

# Confirm deletion
read -p "⚠️ Are you sure you want to DELETE all resources in $RESOURCE_GROUP? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "❌ Deletion aborted."
  exit 0
fi

# Set the subscription context
az account set --subscription "$AZ_SUBSCRIPTION_ID"

# Delete Resource Group and wait for completion
echo "🧹 Deleting Resource Group: $RESOURCE_GROUP ..."
az group delete \
  --name "$RESOURCE_GROUP" \
  --yes \
  --verbose

# Poll to verify deletion
echo "⏳ Waiting for Resource Group to be fully removed..."
while az group exists --name "$RESOURCE_GROUP" >/dev/null 2>&1; do
  echo "   Resource Group still exists, waiting 10 seconds..."
  sleep 10
done

echo "✅ Resource Group $RESOURCE_GROUP and all resources have been deleted successfully!"
