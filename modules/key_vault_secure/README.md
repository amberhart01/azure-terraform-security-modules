## Compliance Mapping
| Control Framework | Requirement | Terraform | Static Analysis |
|---|---|---|---|
| CIS Azure v2.0 | 8.1 Ensure purge protection is enabled | `purge_protection_enabled=true` | `CKV_AZURE_189`, `AZU023` |
| CIS Azure v2.0 | 8.3 Restrict public network access | `public_network_access_enabled=false`, `network_acls` | `CKV_AZURE_190`, `AZU024` |
| ISO 27001 A.8.12 | Secure key management | Key Vault with RBAC + diag | Policy-as-code evidence |