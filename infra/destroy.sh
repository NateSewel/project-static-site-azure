#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/variables.sh"

echo "Deleting resource group ${RG_NAME} (this will remove all resources in it)."
read -p "Type DELETE to confirm: " confirm
if [[ "${confirm}" == "DELETE" ]]; then
  az group delete --name "${RG_NAME}" --yes --no-wait
  echo "Delete operation initiated."
else
  echo "Aborted."
fi
