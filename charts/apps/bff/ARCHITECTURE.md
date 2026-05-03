# BFF Helm Chart - Architecture: Flexible Service URL Configuration

## Overview

The BFF Helm chart supports flexible service configuration that balances between enterprise-grade secret management and operational simplicity.

## Configuration Strategy

### What Gets Stored Where

| Configuration | Storage | Sensitivity | Update Method |
|---|---|---|---|
 ConfigMap | Non-sensitive | Helm upgrade |
 ExternalSecret | Sensitive | Auto-sync (1h) |
 ExternalSecret | Sensitive | Auto-sync (1h) |
 ConfigMap | Non-sensitive | Helm upgrade |

## Architecture Decision

### Why This Approach?

**Service URLs in values.yaml (not vault):**
- Service names are infrastructure-specific (e.g., `audit-audit-service.audit.svc.cluster.local`)
- Changes are typically rare and coordinated with infrastructure changes
- Versioned in Git, easy to track changes per release
- Can be easily overridden per environment with `--set` flags
- No vault access required during deployment

**Sensitive credentials in vault:**
- Keycloak issuer URI contains authentication endpoints
- GHCR tokens are secrets and should never be in source code
- ExternalSecrets auto-syncs from OpenBao (1-hour refresh)
- Follows enterprise security patterns

## Configuration Structure

### Production Setup

```yaml
# values.yaml
env:
  # Non-sensitive configuration
  BFF_PORT: "7000"
  LOG_LEVEL: "info"
  RATE_LIMIT_PER_MINUTE: "100"
  # Backend service URLs (infrastructure-specific, can be overridden)
  AUDIT_SERVICE_URL: "http://audit-audit-service.audit.svc.cluster.local:8080"
  TASKTRACKER_SERVICE_URL: "http://tasktracker-tasktracker.tasktracker.svc.cluster.local:8000"

# Sensitive credentials from OpenBao
externalSecrets:
  enabled: true
  keycloak:
    remoteRef:
      key: platform/keycloak
  registry:
    remoteRef:
      key: registry/ghcr
```

### Development Setup (No Vault Required)

```bash
helm install bff devops/charts/apps/bff/ \
  --set externalSecrets.enabled=false
```

This uses fallback ConfigMap with hardcoded Keycloak URI:
```yaml
fallbackKeycloakIssuerUri: "http://keycloak.default.svc.cluster.local:8080/realms/echo"
```

## Data Flow

### Production (with ExternalSecrets enabled)

```

 Helm values.yaml            
 Service URLs (ConfigMap)  

               
git commit -m "Fix keycloak client"

 Kubernetes ConfigMap        
 - BFF_PORT                  
 - LOG_LEVEL                 
 - AUDIT_SERVICE_URL         
 - TASKTRACKER_SERVICE_URL   

               
        
                       
git commit -m "Fix keycloak client"               
  
 OpenBao Vault         ExternalSec. 
 - platform/keycloak (  Keycloak)   
 - registry/ghcr      
                 
                          
git commit -m "Fix keycloak client"
                 
 Kubernetes Secrets                   
 - bff-keycloak                       
 - ghcr-secret                        
                 
                          
       
                   
git commit -m "Fix keycloak client"
         
 BFF Pod Environment          
 - From ConfigMap             
 - From Secrets               
         
```

### Development (ExternalSecrets disabled)

```

 Helm values.yaml            

               
        
                                 
git commit -m "Fix keycloak client"                         
   
 Fallback ConfigMap     ConfigMap        
 ( (keycloak fallback)non-   sensitive)  
   
                                
         
                     
git commit -m "Fix keycloak client"
         
 BFF Pod Environment          
 (all from ConfigMap)         
         
```

## Updating Service URLs

### Method 1: Update values.yaml (Recommended for most cases)

```bash
# For configuration that rarely changes
helm upgrade bff devops/charts/apps/bff/ \
  --set env.AUDIT_SERVICE_URL="http://new-audit-address:8080"
```

### Method 2: Version in Git

Service URLs are treated as infrastructure configuration:

```yaml
# values.yaml (committed to Git)
env:
  AUDIT_SERVICE_URL: "http://audit-audit-service.audit.svc.cluster.local:8080"
  TASKTRACKER_SERVICE_URL: "http://tasktracker-tasktracker.tasktracker.svc.cluster.local:8000"
```

This allows:
- Easy review of infrastructure changes in Git history
- Per-environment values via values-<env>.yaml
- Clear rollback history

## Service Discovery Naming

Services use fully qualified domain names (FQDN):

```
http://<service-name>.<namespace>.svc.cluster.local:<port>
```

**Examples:**
- Audit: `http://audit-audit-service.audit.svc.cluster.local:8080`
- TaskTracker: `http://tasktracker-tasktracker.tasktracker.svc.cluster.local:8000`

This ensures:
- Explicit namespace scoping (services can be in different namespaces)
- DNS resolution works across all namespaces
- Clear intent about where services are located

## Deployment Scenarios

### Scenario 1: Standard Kubernetes Deployment

```bash
# Deploy with services in audit/tasktracker namespaces (default)
helm install bff devops/charts/apps/bff/ -n bff
```

Pod receives:
- Service URLs from ConfigMap (as per values.yaml)
- Keycloak credentials from OpenBao via ExternalSecrets

### Scenario 2: Custom Namespace for Services

```bash
# If services are in different namespace
helm upgrade bff devops/charts/apps/bff/ -n bff \
  --set env.AUDIT_SERVICE_URL="http://audit-service.custom-ns.svc.cluster.local:8080"
```

### Scenario 3: Local Development (k3s/minikube)

```bash
# No vault required
helm install bff devops/charts/apps/bff/ \
  --set externalSecrets.enabled=false \
  --set env.AUDIT_SERVICE_URL="http://localhost:9000" \
  --set env.TASKTRACKER_SERVICE_URL="http://localhost:9001"
```

## Validation Checklist

Before deploying, verify:

```bash
# 1. Helm lint passes
helm lint devops/charts/apps/bff/

# 2. Template renders correctly
helm template bff devops/charts/apps/bff/ | grep SERVICE_URL

# 3. Service URLs are correct
kubectl get configmap -n bff bff -o yaml | grep SERVICE_URL

# 4. Pod receives environment variables
kubectl exec -n bff <pod-name> -- env | grep SERVICE_URL
```

## Summary

 ConfigMap (flexible, versionable)
 ExternalSecrets (secure, auto-synced)
 **Development Mode**: Works without vault dependency
 **Production Ready**: Full enterprise secret management
 **Multi-Environment**: Easy to customize per environment with `--set` flags
