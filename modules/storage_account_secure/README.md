## Compliance Mapping
| Framework | Requirement | Terraform | Static Analysis |
|---|---|---|---|
| CIS Azure v2.0 | 3.1 Enforce HTTPS | `enable_https_traffic_only=true` | `CKV_AZURE_43`, `AZU020` |
| CIS Azure v2.0 | 3.11 Min TLS 1.2 | `min_tls_version=TLS1_2` | `CKV_AZURE_44` |
| CIS Azure v2.0 | 3.9 Public access off | `allow_blob_public_access=false` | `CKV_AZURE_33`, `AZU019` |
| ISO 27001 A.8.13 | Data retention | `delete_retention_policy` | Evidence via logs |