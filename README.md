# Azure Terraform Security Modules

Secure-by-default Terraform modules for Azure services. Highlights:
- Opinionated defaults that pass `tfsec` + `checkov`.
- Optional private endpoints & network ACLs.
- Diagnostic settings wired to Log Analytics.
- Auto-generated inputs/outputs tables via `terraform-docs`.

## Modules
- `key_vault_secure` — soft delete + purge protection, RBAC, firewall restrictions, optional private endpoint.
- `storage_account_secure` — HTTPS only, min TLS 1.2, public access disabled, versioning/immutability, diag logs, optional CMK.
- `aks_secure_baseline` — private cluster, Azure AD integration, RBAC, network policy, restricted API, Azure Policy add-on (scaffold).
- `azure_policies` — assign secure baseline built-ins/initiatives with parameterization.

## Quickstart (demo)
```bash
cd examples/rg_kv_sa_demo
terraform init && terraform apply