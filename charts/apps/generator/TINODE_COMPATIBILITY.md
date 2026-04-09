# Generator & Tinode Compatibility

## Configuration Verification

### Tinode Service Details (from `tinode_new` chart)

| Component | Value | Port |
|-----------|-------|------|
| **Chart Name** | `tinode` | - |
| **Service Type** | ClusterIP | - |
| **HTTP Port** | 6060 | 6060 (REST API) |
| **gRPC/WebSocket Port** | 16060 | 16060 |
| **In-Cluster DNS** | `tinode.{namespace}.svc.cluster.local` | - |

### Generator Configuration Mapping

#### WebSocket Endpoint ✅ CORRECT
```yaml
# From generator values.yaml
url: "wss://tinode:16060/v0/channels"

# Resolves to:
# wss://tinode.default.svc.cluster.local:16060/v0/channels
# (or tinode.{release_namespace}.svc.cluster.local:16060 when deployed)
```

#### REST API Endpoint ✅ CORRECTED
```yaml
# From generator values.yaml
apiEndpoint: "http://tinode:6060"

# Note: HTTP (not HTTPS) - Tinode serves HTTP on port 6060
# Resolves to:
# http://tinode.default.svc.cluster.local:6060
# (or tinode.{release_namespace}.svc.cluster.local:6060 when deployed)
```

## Deployment Guide

### Prerequisites

1. **Tinode Server** must be deployed with `tinode_new` chart
   ```bash
   helm install tinode ./devops/charts/apps/tinode_new \
     --namespace tinode \
     --create-namespace
   ```

2. **Generator** and **Tinode** must be in the same cluster (same DNS)
   - If in different namespaces, use FQDN: `tinode.{tinode_namespace}.svc.cluster.local`

### Installation

#### Option 1: Same Namespace (Default)
```bash
helm install generator ./devops/charts/apps/generator \
  --namespace tinode
```

Uses default URLs:
- WebSocket: `wss://tinode:16060/v0/channels`
- REST API: `http://tinode:6060`

#### Option 2: Different Namespace (Requires Override)
```bash
helm install generator ./devops/charts/apps/generator \
  --namespace audit \
  --set 'generator.server.url=wss://tinode.tinode.svc.cluster.local:16060/v0/channels' \
  --set 'generator.server.apiEndpoint=http://tinode.tinode.svc.cluster.local:6060'
```

#### Option 3: Custom Tinode Address
```bash
helm install generator ./devops/charts/apps/generator \
  --namespace audit \
  --set 'generator.server.url=wss://tinode-custom.example.com:16060/v0/channels' \
  --set 'generator.server.apiEndpoint=http://tinode-custom.example.com:6060'
```

## Network Connectivity Verification

### Test WebSocket Connection
```bash
# From any pod in the cluster
kubectl run -it --rm debug --image=nicolaka/netcat --restart=Never -- \
  nc -zv tinode 16060
```

### Test REST API Connection
```bash
# From any pod in the cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v http://tinode:6060/
```

### Port Forwarding (Local Testing)
```bash
# Forward Tinode WebSocket
kubectl port-forward -n tinode svc/tinode 16060:16060

# In another terminal, test
wsc ws://localhost:16060/v0/channels
```

## Service Discovery

When Generator pod is deployed, it resolves `tinode` hostname to:

```
tinode → tinode.{namespace}.svc.cluster.local → {ClusterIP}:16060
```

**Important:** If Tinode is in a different namespace:
- Kubernetes DNS: `tinode.tinode.svc.cluster.local:16060`
- Must be explicitly configured in generator values

## Troubleshooting Connection Issues

### Error: "connection refused"
```
Check if Tinode pods are running:
  kubectl get pods -n tinode

Check Tinode service:
  kubectl get svc -n tinode
```

### Error: "dial wss://tinode:16060: name or service not known"
```
Tinode hostname cannot be resolved. Possible causes:
  1. Tinode pods not running
  2. Generator in different namespace without FQDN
  3. DNS not properly configured

Solution:
  - Use FQDN: wss://tinode.tinode.svc.cluster.local:16060/v0/channels
  - Override in values with full FQDN
```

### Error: "connection timeout"
```
Check Tinode readiness:
  kubectl get pods -n tinode -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")]}'

Check network policies:
  kubectl get networkpolicies -A

Increase timeout in generator values:
  --set 'generator.server.timeoutSeconds=60'
```

## Configuration Reference

### Kubernetes Service DNS Resolution

Generator pod resolves `tinode` as:

| Installation Scenario | Resolved Address |
|---|---|
| Same namespace | `tinode:16060` |
| Different namespace | `tinode.{namespace}.svc.cluster.local:16060` |
| External service | Full hostname or IP |

### Required Ports

| Port | Protocol | Usage |
|------|----------|-------|
| 6060 | HTTP | REST API (user provisioning) |
| 16060 | gRPC/WebSocket | WebSocket for messaging |

## Security Considerations

### TLS/SSL
- **Current Setup**: HTTP (port 6060), WSS (port 16060)
- **Production**: Consider enabling TLS in tinode_new chart
- **Generator Update**: Use `wss://` and `https://` if TLS enabled

### Network Policies
If cluster has network policies, ensure:
1. Generator namespace can reach Tinode namespace
2. Ports 6060 and 16060 are allowed
3. DNS port 53 is allowed for name resolution

### OpenBao Integration
Both charts pull from OpenBao:
- Tinode: Retrieves Postgres credentials and encryption keys from `tinode/*` paths
- Generator: Retrieves Tinode API key from `tinode/keygen` path
- Ensure both have access to same OpenBao instance

## Integration Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Kubernetes Cluster (Namespace: tinode/audit)               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ Generator Pod (this chart)                                 │
│ ├─ Connects to: wss://tinode:16060/v0/channels           │
│ └─ Provisioning: http://tinode:6060                       │
│         ↓                                                   │
│ Tinode Server Pod (tinode_new chart)                       │
│ ├─ WebSocket Listener: :16060                             │
│ ├─ REST API: :6060                                        │
│ └─ Database: PostgreSQL (postgres namespace)              │
│         ↓                                                   │
│ Router Pod (router chart)                                  │
│ ├─ Listens to Tinode events                               │
│ └─ Routes to Kafka topics: tinode.*                       │
│         ↓                                                   │
│ Ingestor Pod (ingestor chart)                              │
│ ├─ Consumes Kafka messages                                │
│ └─ Inserts to ClickHouse                                  │
│         ↓                                                   │
│ Audit Service Pod (audit chart)                            │
│ └─ Queries ClickHouse, validates detection rules          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Summary

✅ **Generator chart is compatible with tinode_new chart**

**Key Points:**
- WebSocket endpoint: Correctly configured for port 16060
- REST API: Updated to HTTP (not HTTPS) on port 6060
- Service discovery: Works automatically in same namespace
- Different namespaces: Use FQDN in values override

**Default Configuration:**
```yaml
server:
  url: "wss://tinode:16060/v0/channels"
  apiEndpoint: "http://tinode:6060"
  timeoutSeconds: 30
```

This configuration assumes Tinode is deployed with default service name "tinode" in the same namespace or accessible via DNS.
