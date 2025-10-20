#!/bin/bash
# ============================================================
# Azure Infrastructure Teardown Script
# Safely Deletes All Resources for the Static Website Project
# ============================================================

# Load environment variables from .env if present
if [ -f "../.env" ]; then
  echo "📦 Loading environment variables from .env file..."
  set -a
  source ../.env
  set +a
else
  echo "⚠️  No .env file found — ensure variables are exported manually!"
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
read -p "⚠️  Are you sure you want to DELETE all resources in $RESOURCE_GROUP? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "❌ Deletion aborted."
  exit 0
fi

# Set the subscription context
az account set --subscription "$AZ_SUBSCRIPTION_ID"

# Delete Resource Group (and all resources within it)
echo "🧹 Deleting Resource Group: $RESOURCE_GROUP ..."
az group delete \
  --name "$RESOURCE_GROUP" \
  --yes \
  --no-wait

echo "🚀 Teardown initiated. All resources in $RESOURCE_GROUP will be deleted."
echo "⏳ It may take several minutes to complete."
echo "✅ Script execution finished."