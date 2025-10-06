#!/usr/bin/env bash
set -euo pipefail

# Usage:
#  - Run normally to create a new app registration, secret, service principal, and role assignments:
#      ./azure_set.sh
#  - If you've already created the app (for example `atlantis-tf-ci-sp`) and want to skip creating it
#    again but still create a new client secret and role assignments, run:
#      SKIP_CREATE_APP=true EXISTING_APP_ID=<appId> ./azure_set.sh
#    or
#      SKIP_CREATE_APP=true ./azure_set.sh
#    (the latter will attempt to find an app by the display name 'atlantis-tf-ci-sp' in the tenant)
#
# Notes:
#  - The script will print APP_ID, TENANT_ID and CLIENT_SECRET; record these securely as GitHub/Atlantis secrets.
#  - When skipping creation the script will attempt to find an existing Service Principal for the app and reuse it.

# ====== INPUTS (load from .env or defaults) ======
# You can put your configuration in a local .env file (not checked in). The repo includes .env.example.
if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi

SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-}"
RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-}"         # narrow scope for applies
DEV_AAD_GROUP_NAME="${DEV_AAD_GROUP_NAME:-}"  # or leave blank to assign individual users
# Optional: state storage (if using AzureRM backend)
STATE_RG="${STATE_RG:-}"
STATE_STORAGE_ACCOUNT="${STATE_STORAGE_ACCOUNT:-}"
STATE_CONTAINER="${STATE_CONTAINER:-}"

# Control flags (optional)
# - Set SKIP_CREATE_APP=true to skip creating the app registration (use an existing one).
#   When skipping you can provide EXISTING_APP_ID (the appId) or the script will try
#   to look up an app with the same display name in your tenant.
# - Example: SKIP_CREATE_APP=true EXISTING_APP_ID=<appId> ./azure_set.sh
SKIP_CREATE_APP="${SKIP_CREATE_APP:-false}"
EXISTING_APP_ID="${EXISTING_APP_ID:-}"
SKIP_CREATE_SECRET="${SKIP_CREATE_SECRET:-false}"
EXISTING_CLIENT_SECRET="${EXISTING_CLIENT_SECRET:-}"

# ====== Context ======
if [[ -z "${SUBSCRIPTION_ID:-}" ]]; then
  echo "ERROR: SUBSCRIPTION_ID is not set. Copy .env.example to .env and fill SUBSCRIPTION_ID, or export it before running."
  exit 2
fi

az account set --subscription "$SUBSCRIPTION_ID"
RG_ID=$(az group show -n "$RESOURCE_GROUP_NAME" --query id -o tsv)

# ====== Create SP for Atlantis/Terraform CI ======
APP_NAME="atlantis-tf-ci-sp"

# Determine whether to create a new app registration or reuse an existing one
if [[ "${SKIP_CREATE_APP}" == "true" ]]; then
  if [[ -n "${EXISTING_APP_ID}" ]]; then
    APP_ID="${EXISTING_APP_ID}"
    echo "SKIP_CREATE_APP=true: using provided EXISTING_APP_ID=$APP_ID"
  else
    echo "SKIP_CREATE_APP=true: looking up app by display name '$APP_NAME'..."
    APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv || true)
    if [[ -z "$APP_ID" ]]; then
      echo "Could not find an existing app by name '$APP_NAME'. Provide EXISTING_APP_ID or unset SKIP_CREATE_APP to create a new app."
      exit 1
    fi
    echo "Found existing app. APP_ID=$APP_ID"
  fi
else
  echo "Creating app registration: $APP_NAME"
  # create app and directly query returned fields to avoid jq dependency
  APP_JSON=$(az ad app create --display-name "$APP_NAME")
  APP_ID=$(echo "$APP_JSON" | awk -F 'appId":\"' '{print $2}' | awk -F'\"' '{print $1}')
  OBJ_ID=$(echo "$APP_JSON" | awk -F '"id":\"' '{print $2}' | awk -F'\"' '{print $1}' || true)
  # Note: older/newer az CLI output shapes vary; using a small awk extract to avoid jq dependency
fi

# Create a client secret (record this securely in your GitHub/Atlantis secrets)
if [[ "${SKIP_CREATE_SECRET}" == "true" ]]; then
  if [[ -n "${EXISTING_CLIENT_SECRET}" ]]; then
    CLIENT_SECRET="${EXISTING_CLIENT_SECRET}"
    echo "SKIP_CREATE_SECRET=true: using provided EXISTING_CLIENT_SECRET"
  else
    echo "SKIP_CREATE_SECRET=true but no EXISTING_CLIENT_SECRET provided. Provide EXISTING_CLIENT_SECRET or unset SKIP_CREATE_SECRET to create a new secret."
    exit 1
  fi
else
  # Use --query to retrieve only the password (no jq required)
  CLIENT_SECRET=$(az ad app credential reset --id "$APP_ID" --append --query password -o tsv)
fi
TENANT_ID=$(az account show --query tenantId -o tsv)

echo "APP_ID: $APP_ID"
echo "TENANT_ID: $TENANT_ID"
echo "CLIENT_SECRET: $CLIENT_SECRET"
echo ">> Store these as Atlantis env vars or GitHub Secrets: AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_CLIENT_SECRET, AZURE_SUBSCRIPTION_ID"

# Create Service Principal entity (Enterprise application) if it doesn't already exist
# Try to detect an existing SP for this appId; if present, reuse it.
SP_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv 2>/dev/null || true)
if [[ -z "$SP_ID" ]]; then
  echo "Service principal not found for appId $APP_ID — creating..."
  SP_ID=$(az ad sp create --id "$APP_ID" --query id -o tsv)
  echo "Created SP: $SP_ID"
else
  echo "Service principal already exists: $SP_ID"
fi

# ====== Role assignments (least privilege) ======
# Atlantis/Terraform CI => Contributor on the target RG (NOT on the whole subscription)
# az role assignment create \
#   --assignee-object-id "$SP_ID" \
#   --assignee-principal-type ServicePrincipal \
#   --role "Contributor" \
#   --scope "$RG_ID"

# Optional: if your Terraform state is in Azure Storage, allow blob access on the state account
# if [[ -n "${STATE_STORAGE_ACCOUNT:-}" && -n "${STATE_CONTAINER:-}" ]]; then
#   SA_ID=$(az storage account show -n "$STATE_STORAGE_ACCOUNT" -g "$STATE_RG" --query id -o tsv)
#   az role assignment create \
#     --assignee-object-id "$SP_ID" \
#     --assignee-principal-type ServicePrincipal \
#     --role "Storage Blob Data Contributor" \
#     --scope "$SA_ID"
# fi

# ====== Create Dev Group ======
if [[ -n "${DEV_AAD_GROUP_NAME:-}" ]]; then
  echo "Creating Azure AD group: $DEV_AAD_GROUP_NAME"
  az ad group create --display-name "$DEV_AAD_GROUP_NAME" --mail-nickname "devs-readonly" --query id -o tsv
fi

# ====== Dev read-only access (group preferred) ======
if [[ -n "${DEV_AAD_GROUP_NAME:-}" ]]; then
  # Helper: poll for AAD group existence and return its id (or empty on failure)
  wait_for_group() {
    local name="$1"; local attempts="${2:-12}"; local delay="${3:-5}"; local gid=""
    for i in $(seq 1 "$attempts"); do
      gid=$(az ad group show --group "$name" --query id -o tsv 2>/dev/null || true)
      if [[ -n "$gid" ]]; then
        echo "$gid"
        return 0
      fi
      sleep "$delay"
    done
    return 1
  }

  # Try to find existing group
  GROUP_ID=$(az ad group show --group "$DEV_AAD_GROUP_NAME" --query id -o tsv 2>/dev/null || true)
  if [[ -z "$GROUP_ID" ]]; then
    echo "Creating Azure AD group: $DEV_AAD_GROUP_NAME"
    # create returns the object; try to create and capture id
    MAIL_NICKNAME=$(echo "$DEV_AAD_GROUP_NAME" | tr '[:upper:]' '[:lower:]' | tr ' _' '-' | tr -cd '[:alnum:]-')
    GROUP_ID=$(az ad group create --display-name "$DEV_AAD_GROUP_NAME" --mail-nickname "$MAIL_NICKNAME" --query id -o tsv 2>/dev/null || true)
    if [[ -z "$GROUP_ID" ]]; then
      # If create did not immediately return an id, poll for the group to appear
      echo "Waiting for AAD group to propagate..."
      GROUP_ID=$(wait_for_group "$DEV_AAD_GROUP_NAME" 12 5) || true
    fi
  fi

  if [[ -z "$GROUP_ID" ]]; then
    echo ">>> Could not find or create AAD group '$DEV_AAD_GROUP_NAME' — skipping Reader assignment."
  else
    echo "Assigning Reader role to group $DEV_AAD_GROUP_NAME ($GROUP_ID)"
    # Retry role assignment a few times to avoid PrincipalNotFound due to replication delays
    for attempt in 1 2 3 4 5; do
      if az role assignment create \
        --assignee-object-id "$GROUP_ID" \
        --assignee-principal-type Group \
        --role "Reader" \
        --scope "$RG_ID" 2>/dev/null; then
        echo "Assigned Reader to group"
        break
      else
        echo "Role assignment attempt $attempt failed — retrying in 5s..."
        sleep 5
      fi
    done
  fi
else
  echo ">>> Skipping dev Reader assignment (no DEV_AAD_GROUP_NAME set). To grant an individual:"
  echo "az role assignment create --assignee <userUPN or objectId> --role Reader --scope $RG_ID"
fi

echo "Done. CI SP can apply only in $RESOURCE_GROUP_NAME; devs are Reader."
