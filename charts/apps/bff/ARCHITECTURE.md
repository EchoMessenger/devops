# BFF Helm Chart - Architecture Decision: ExternalSecrets as Source of Truth

## Problem Identified

The initial configuration had a redundancy:
- `serviceUrls` in values.yaml (hardcoded FQDN addresses)
- `externalSecrets` pointing to the same values in OpenBao

**Question**: Why use OpenBao if URLs are already in values.yaml?

---

## Solution: ExternalSecrets as Single Source of Truth

### Architecture Decision (IMPLEMENTED ✅)

**Production (default):**
- ExternalSecrets **enabled** (fetches from OpenBao)
- Service URLs come from OpenBao vault path: `secret/data/echomessenger/bff`
- Allows infrastructure changes without redeploying chart
- Follows enterprise configuration management patterns

**Development (opt-in):**
- ExternalSecrets **disabled** (`--set externalSecrets.enabled=false`)
- Service URLs from `fallbackServiceUrls` in values.yaml
- No OpenBao dependency needed
- Suitable for local k3s, testing environments

---

## Configuration Structure (AFTER FIX)

```yaml
env:
  # Only non-sensitive, STATIC configuration
  BFF_PORT: "7000"
  LOG_LEVEL: "info"
  RATE_LIMIT_PER_MINUTE: "100"

# PRODUCTION: All dynamic configuration from OpenBao
externalSecrets:
  enabled: true  # Always true in production
  vaultPath: "secret/data/echomessenger/bff"
  secretKeys:
    - name: KEYCLOAK_ISSUER_URI
      key: keycloak_issuer_uri
    - name: AUDIT_SERVICE_URL
      key: audit_service_url
    - name: TASKTRACKER_SERVICE_URL
      key: tasktracker_service_url
    - name: RESTAUTH_SERVICE_URL
      key: restauth_service_url

# DEVELOPMENT: Fallback when ExternalSecrets disabled
fallbackServiceUrls:
  keycloakIssuerUri: "http://keycloak.default.svc.cluster.local:8080/realms/echo"
  auditServiceUrl: "http://audit.default.svc.cluster.local:8080"
  tasktrackerServiceUrl: "http://tasktracker.default.svc.cluster.local:8000"
  restauthServiceUrl: "http://restauth.default.svc.cluster.local:8000"
```

---

## Why This Matters

### Scenario 1: Infrastructure Migration
**Without ExternalSecrets approach:**
- Audit service moves to new IP: 10.0.2.50
- Must edit values.yaml and redeploy chart
- Risk of inconsistency across services

**With ExternalSecrets approach:**
- Update value in OpenBao: `audit_service_url: "http://audit-new.default.svc.cluster.local:8080"`
- ExternalSecret automatically syncs (1 hour refresh)
- Pod environment updated without redeployment
- All services see new value consistently

### Scenario 2: Multi-Environment
**Without ExternalSecrets:**
- Need different values.yaml for each environment
- Chart duplication across environments

**With ExternalSecrets:**
- Single chart in Git
- Different OpenBao paths per environment:
  - Dev: `secret/data/echomessenger/bff-dev`
  - Staging: `secret/data/echomessenger/bff-staging`
  - Production: `secret/data/echomessenger/bff-prod`
- Deploy same chart, sync from different vaults

---

## Implementation Details

### What Changed

| File | Change |
|------|--------|
| `values.yaml` | Removed `serviceUrls`, added `fallbackServiceUrls`, improved comments |
| `configmap.yaml` | Updated to use `fallbackServiceUrls` instead of `serviceUrls` |
| `externalsecrets.yaml` | Changed from `data[]` to `dataFrom[]` for cleaner extraction |

### How It Works

**Production Flow:**
```
┌─────────────────┐
│  ExternalSecret │  refreshInterval: 1h
│  (enabled: true)│
└────────┬────────┘
         │
         ▼
┌──────────────────────┐
│  OpenBao Vault       │
│  Path: secret/data/  │
│  echomessenger/bff   │
└────────┬─────────────┘
         │
         ▼
┌──────────────────────┐
│  Kubernetes Secret   │
│  bff-secrets         │
└────────┬─────────────┘
         │
         ▼
┌──────────────────────┐
│  BFF Pod Environment │
│  KEYCLOAK_ISSUER_URI │
│  AUDIT_SERVICE_URL   │
│  TASKTRACKER_SVC_URL │
│  RESTAUTH_SERVICE_URL│
└──────────────────────┘
```

**Development Flow:**
```
┌─────────────────────┐
│ ExternalSecret      │  enabled: false
│ (DISABLED)          │
└─────────────────────┘
         │
         ▼
┌──────────────────────┐
│  ConfigMap           │
│  bff-fallback        │
│  (values.yaml data)  │
└────────┬─────────────┘
         │
         ▼
┌──────────────────────┐
│  BFF Pod Environment │
│  (from ConfigMap)    │
└──────────────────────┘
```

---

## OpenBao Setup (for your reference)

To use this chart, set up OpenBao with:

```bash
# 1. Store values in OpenBao
vault kv put secret/echomessenger/bff \
  keycloak_issuer_uri="http://keycloak.default.svc.cluster.local:8080/realms/echo" \
  audit_service_url="http://audit.default.svc.cluster.local:8080" \
  tasktracker_service_url="http://tasktracker.default.svc.cluster.local:8000" \
  restauth_service_url="http://restauth.default.svc.cluster.local:8000"

# 2. Verify values
vault kv get secret/echomessenger/bff

# 3. Configure Kubernetes auth (if not already done)
vault auth enable kubernetes
vault write auth/kubernetes/config \
  token_reviewer_jwt=... \
  kubernetes_host=... \
  kubernetes_ca_cert=...

# 4. Create policy
vault policy write bff - <<EOF
path "secret/data/echomessenger/bff" {
  capabilities = ["read", "list"]
}
EOF

# 5. Create role
vault write auth/kubernetes/role/bff \
  bound_service_account_names=bff \
  bound_service_account_namespaces=default \
  policies=bff \
  ttl=24h
```

---

## Usage Examples

### Install with Production Defaults (ExternalSecrets enabled)
```bash
helm install bff devops/charts/apps/bff/
```

### Install in Development Mode (no OpenBao required)
```bash
helm install bff devops/charts/apps/bff/ \
  --set externalSecrets.enabled=false
```

### Install with Custom OpenBao Path
```bash
helm install bff devops/charts/apps/bff/ \
  --set externalSecrets.vaultPath="secret/data/my-custom-path"
```

---

## Benefits of This Architecture

✅ **Enterprise-Grade**
- Centralized configuration management
- No secrets in Git
- Multi-environment support

✅ **Operational Flexibility**
- Change infrastructure without redeploying
- Consistent config across services
- 1-hour auto-sync from vault

✅ **Developer-Friendly**
- Dev mode works without vault
- Clear separation of concerns
- Easy to understand flow

✅ **Security**
- Sensitive data never in source code
- Vault access control
- Audit trail for all config changes

---

## Validation

✅ Chart lint: PASSED
✅ Production mode template: VALID
✅ Development mode template: VALID
✅ FQDN service URLs: VERIFIED
✅ ExternalSecrets configuration: CORRECT

---

## Summary

**Removed redundancy** by making ExternalSecrets the single source of truth for service URLs.

**Architecture now:**
- **Production**: All service URLs from OpenBao (dynamic, flexible)
- **Development**: Fallback ConfigMap (no dependencies)

This follows enterprise patterns used by audit service and maintains consistency across EchoMessenger deployments.
