#!/usr/bin/env bash
set -euo pipefail

# create_state.sh
# Idempotent helper to create an Azure resource group, storage account, and container
# for Terraform state backend.

# Load configuration from .env if present (do NOT check .env into source control)
if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi

# Edit these or export environment variables before running (sensitive values should be in .env)
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-}"
STATE_RG="${STATE_RG:-rg-tfstate}"
LOCATION="${LOCATION:-eastus}"
STATE_STORAGE_ACCOUNT="${STATE_STORAGE_ACCOUNT:-}"
STATE_CONTAINER="${STATE_CONTAINER:-tfstate}"

# Optional: set this to true to skip creating storage account if it already exists
DRY_RUN="${DRY_RUN:-false}"

if [[ -z "${SUBSCRIPTION_ID:-}" ]]; then
  echo "ERROR: SUBSCRIPTION_ID is not set. Please set it in your .env or export it in your shell."
  exit 2
fi

az account set --subscription "$SUBSCRIPTION_ID"

# Basic validation for storage account
if [[ -z "${STATE_STORAGE_ACCOUNT:-}" ]]; then
  echo "ERROR: STATE_STORAGE_ACCOUNT is not set. Please set STATE_STORAGE_ACCOUNT in .env or export it."
  exit 2
fi

# Create resource group if missing
if az group show -n "$STATE_RG" &>/dev/null; then
  echo "Resource group '$STATE_RG' already exists"
else
  echo "Creating resource group '$STATE_RG' in $LOCATION..."
  az group create -n "$STATE_RG" -l "$LOCATION" -o none
fi

# Check storage account name validity and uniqueness
# Storage account names must be 3-24 lowercase alphanumeric
if [[ ! "$STATE_STORAGE_ACCOUNT" =~ ^[a-z0-9]{3,24}$ ]]; then
  echo "ERROR: STATE_STORAGE_ACCOUNT must be 3-24 lowercase letters and numbers. Current: $STATE_STORAGE_ACCOUNT"
  exit 1
fi

# Create storage account if missing
if az storage account show -n "$STATE_STORAGE_ACCOUNT" -g "$STATE_RG" &>/dev/null; then
  echo "Storage account '$STATE_STORAGE_ACCOUNT' already exists in resource group '$STATE_RG'"
else
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "DRY_RUN: would create storage account '$STATE_STORAGE_ACCOUNT' in $STATE_RG"
  else
    echo "Creating storage account '$STATE_STORAGE_ACCOUNT'..."
    az storage account create -n "$STATE_STORAGE_ACCOUNT" -g "$STATE_RG" --sku Standard_RAGRS --kind StorageV2 --access-tier Hot -o none
  fi
fi

# Get storage key
STORAGE_KEY=$(az storage account keys list -n "$STATE_STORAGE_ACCOUNT" -g "$STATE_RG" --query '[0].value' -o tsv)

# Create container if missing
if az storage container show -n "$STATE_CONTAINER" --account-name "$STATE_STORAGE_ACCOUNT" &>/dev/null; then
  echo "Container '$STATE_CONTAINER' already exists in '$STATE_STORAGE_ACCOUNT'"
else
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "DRY_RUN: would create container '$STATE_CONTAINER' in storage account '$STATE_STORAGE_ACCOUNT'"
  else
    echo "Creating container '$STATE_CONTAINER' in storage account '$STATE_STORAGE_ACCOUNT'..."
    az storage container create -n "$STATE_CONTAINER" --account-name "$STATE_STORAGE_ACCOUNT" --account-key "$STORAGE_KEY" -o none
  fi
fi

# Output backend config snippet for Terraform
echo
echo "Terraform backend configuration (use these values):"
echo "resource_group_name = \"$STATE_RG\""
echo "storage_account_name = \"$STATE_STORAGE_ACCOUNT\""
echo "container_name = \"$STATE_CONTAINER\""
echo "access_key = \"$STORAGE_KEY\""

echo "Done."
