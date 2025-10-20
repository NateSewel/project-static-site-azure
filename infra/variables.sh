#!/bin/bash
# ======================================================
# Azure Variables Loader (works for both local & CI/CD)
# ======================================================

# Load environment variables from .env
if [ -f "../.env" ]; then
  echo "📦 Loading environment variables from .env..."
  set -a
  # shellcheck disable=SC1091
  source ../.env
  set +a
else
  echo "⚙️ No .env file found. Please create one."
  exit 1
fi

# Validate required variables safely (even with 'set -u')
REQUIRED_VARS=("AZ_SUBSCRIPTION_ID" "AZ_LOCATION" "RESOURCE_GROUP")

for var in "${REQUIRED_VARS[@]}"; do
  # Use indirect expansion safely under 'set -u'
  if [ -z "${!var-}" ]; then
    echo "❌ ERROR: $var not set. Please export it or define it in .env"
    exit 1
  fi
done

# Show summary (for visibility)
echo "✅ Variables loaded successfully:"
echo "Subscription: ${AZ_SUBSCRIPTION_ID}"
echo "Region: ${AZ_LOCATION}"
echo "Resource Group: ${RESOURCE_GROUP}"
