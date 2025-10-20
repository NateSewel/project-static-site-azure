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
  echo "⚠️  No .env file found. Relying on exported environment variables..."
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

# Delete Resource Group and wait for completion
echo "🧹 Deleting Resource Group: $RESOURCE_GROUP ..."
az group delete \
  --name "$RESOURCE_GROUP" \
  --yes \
  --no-wait

# Wait until deletion completes
echo "⏳ Waiting for Resource Group deletion to complete..."
while az group exists --name "$RESOURCE_GROUP" | grep true > /dev/null; do
    echo "⏱  Resource Group still exists, waiting 15s..."
    sleep 15
done

echo "✅ Resource Group $RESOURCE_GROUP and all resources have been successfully deleted."
