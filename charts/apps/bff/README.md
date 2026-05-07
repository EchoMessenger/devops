# BFF Helm Chart

Kubernetes Helm chart for deploying the BFF (Backend for Frontend) service in an EchoMessenger cluster.

## Overview

The BFF service is a stateless API gateway that sits between the React web frontend and backend microservices. It provides:

- **Single Entry Point**: Unified REST API for frontend clients
- **JWT Authentication**: Token validation against Keycloak
- **Rate Limiting**: Per-IP request throttling with token bucket algorithm
- **CORS Handling**: Eliminates cross-origin request issues
- **Request Forwarding**: HTTP proxy to Audit and TaskTracker services

## Prerequisites

- Kubernetes 1.24+
- Helm 3.0+
- ExternalSecrets Operator (for Keycloak credentials management)
- OpenBao (or Vault) for secrets storage
- Traefik Ingress Controller (for external access)

## Quick Start

### 1. Install the Chart

```bash
helm install bff ./devops/charts/apps/bff/ \
  --namespace default \
  --create-namespace
```

### 2. Verify Installation

```bash
# Check deployment status
kubectl get deployment bff

# Check service
kubectl get service bff

# Check pod logs
kubectl logs -f deployment/bff
```

### 3. Test Health Endpoints

```bash
# Forward port
kubectl port-forward svc/bff 7000:7000

# Liveness probe
curl http://localhost:7000/health

# Readiness probe
curl http://localhost:7000/ready
```

## Configuration

### Chart Values

Key configuration values (see `values.yaml` for all options):

| Value | Default | Description |
|-------|---------|-------------|
| `replicaCount` | 2 | Number of replicas |
| `image.repository` | `ghcr.io/echomessenger/bff` | Docker image repository |
| `image.tag` | `latest` | Docker image tag |
| `service.port` | 7000 | Service port |
| `ingress.enabled` | true | Enable Ingress for external access |
| `autoscaling.enabled` | true | Enable HPA (Horizontal Pod Autoscaler) |
| `autoscaling.minReplicas` | 2 | HPA minimum replicas |
| `autoscaling.maxReplicas` | 3 | HPA maximum replicas |
| `externalSecrets.enabled` | true | Use ExternalSecrets for sensitive data |

### Environment Variables

#### Non-Sensitive (ConfigMap)

```yaml
BFF_PORT: "7000"              # Server port
LOG_LEVEL: "info"             # Log level (debug, info, warn, error)
RATE_LIMIT_PER_MINUTE: "100"  # Requests per minute per IP
CORS_ALLOWED_ORIGINS: "http://192.168.56.1:8080" # Comma-separated browser origin allowlist
CORS_ALLOW_CREDENTIALS: "false" # Set true only when frontend uses credentialed CORS
```

#### Sensitive (ExternalSecrets)

```yaml
KEYCLOAK_ISSUER_URI: "http://keycloak.default.svc.cluster.local:8080/realms/echo"
```

#### Backend Service URLs (ConfigMap)

```yaml
AUDIT_SERVICE_URL: "http://audit-audit-service.audit.svc.cluster.local:8080"
TASKTRACKER_SERVICE_URL: "http://tasktracker-tasktracker.tasktracker.svc.cluster.local:8000"
AUDIT_SERVICE_HEALTH_PORT: "8081"
TASKTRACKER_SERVICE_HEALTH_PORT: "8000"
AUDIT_SERVICE_HEALTH_PATH: "/actuator/health/readiness"
TASKTRACKER_SERVICE_HEALTH_PATH: "/health"
```

### Service-to-Service Communication

All internal service URLs use Fully Qualified Domain Names (FQDN) in the format:

```
http://<service-name>.<namespace>.svc.cluster.local:<port>
```

This ensures proper DNS resolution within the Kubernetes cluster and works across namespaces.

**Examples**:
- Audit: `http://audit-audit-service.audit.svc.cluster.local:8080`
- TaskTracker: `http://tasktracker-tasktracker.tasktracker.svc.cluster.local:8000`

### Custom Configuration

Override values during installation:

```bash
helm install bff ./devops/charts/apps/bff/ \
  --set replicaCount=3 \
  --set image.tag=v1.2.3 \
  --set externalSecrets.enabled=false \
  --set env.CORS_ALLOWED_ORIGINS="https://app.echo-messenger.ru,http://192.168.56.1:8080" \
  --set ingress.hosts[0].host=my-bff.example.com
```

## Security Features

### Pod Security

- **Non-root user**: Runs as UID 1000 (non-root)
- **Read-only filesystem**: Container root filesystem is read-only
- **Security context**: No privilege escalation allowed
- **Capabilities**: All Linux capabilities dropped (CAP_ALL dropped)

### Network Security

- **ClusterIP Service**: Only accessible within the cluster (by default)
- **Ingress TLS**: HTTPS enforced via cert-manager (Let's Encrypt)
- **JWT Authentication**: All `/bff/v1/*` routes require Bearer token

### Secrets Management

- **ExternalSecrets Operator**: Syncs secrets from OpenBao/Vault
- **Kubernetes Secrets**: Mounted at runtime, not stored in ConfigMaps
- **Refresh Interval**: 1 hour (configurable in `externalsecrets.yaml`)

## Scaling

### Horizontal Pod Autoscaling (HPA)

HPA is enabled by default with the following configuration:

- **Min replicas**: 2
- **Max replicas**: 3
- **Target CPU**: 70% utilization

The autoscaler will automatically scale up when CPU usage exceeds 70% and scale down when it drops below that threshold.

### Manual Scaling

```bash
# Scale to 4 replicas
kubectl scale deployment bff --replicas=4

# Disable autoscaling
helm upgrade bff ./devops/charts/apps/bff/ \
  --set autoscaling.enabled=false \
  --set replicaCount=4
```

## Ingress & External Access

The chart includes a Traefik Ingress for external access:

- **Hostname**: `bff.echo-messenger.ru`
- **Path**: `/bff` (prefix-based routing)
- **TLS**: HTTPS via Let's Encrypt (cert-manager)
- **Middleware**: Rate limiting middleware applied

### Configure Ingress

```bash
helm upgrade bff ./devops/charts/apps/bff/ \
  --set ingress.hosts[0].host=my-bff.example.com \
  --set ingress.hosts[0].paths[0].path=/api/gateway
```

## Deployment Without ExternalSecrets

If ExternalSecrets is not available, disable it and use ConfigMap fallback:

```bash
helm install bff ./devops/charts/apps/bff/ \
  --set externalSecrets.enabled=false
```

**Note**: Fallback ConfigMap contains FQDN service URLs. Update as needed for your deployment.

## Health Checks

### Liveness Probe

- **Endpoint**: `GET /health`
- **Port**: 7000
- **Initial delay**: 10 seconds
- **Period**: 10 seconds
- **Timeout**: 3 seconds
- **Failure threshold**: 3

Restarts the pod if health check fails.

### Readiness Probe

- **Endpoint**: `GET /ready`
- **Port**: 7000
- **Initial delay**: 5 seconds
- **Period**: 5 seconds
- **Timeout**: 3 seconds
- **Failure threshold**: 3

Removes the pod from load balancing if readiness check fails.

## Troubleshooting

### Pod not starting?

```bash
# Check pod status
kubectl describe pod <pod-name>

# View logs
kubectl logs <pod-name>

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

### Readiness failing?

The `/ready` endpoint checks downstream service connectivity. Verify:

```bash
# Check service DNS resolution (from within pod)
kubectl exec -it <pod-name> -- nslookup audit-audit-service.audit.svc.cluster.local

# Test connectivity to backends
kubectl exec -it <pod-name> -- curl http://audit-audit-service.audit.svc.cluster.local:8081/actuator/health/readiness
```

### ExternalSecrets not syncing?

```bash
# Check ExternalSecret status
kubectl describe externalsecret bff-secrets

# Verify OpenBao/Vault connectivity
kubectl logs -f secret-store

# Check if secret was created
kubectl get secret bff-secrets
```

### Rate limiting issues?

If requests are being rate-limited unexpectedly:

```bash
# Increase rate limit
helm upgrade bff ./devops/charts/apps/bff/ \
  --set env.RATE_LIMIT_PER_MINUTE=200
```

## Resource Requirements

### Default Limits

- **Request (CPU)**: 100m
- **Request (Memory)**: 128Mi
- **Limit (CPU)**: 500m
- **Limit (Memory)**: 256Mi

Adjust as needed for your workload:

```bash
helm upgrade bff ./devops/charts/apps/bff/ \
  --set resources.requests.cpu=200m \
  --set resources.requests.memory=256Mi \
  --set resources.limits.cpu=1000m \
  --set resources.limits.memory=512Mi
```

## Uninstall

```bash
helm uninstall bff --namespace default
```

## Development

### Validate Chart

```bash
helm lint ./devops/charts/apps/bff/
```

### Dry Run

```bash
helm install bff ./devops/charts/apps/bff/ --dry-run --debug
```

### Template Preview

```bash
helm template bff ./devops/charts/apps/bff/
```

## Service URLs Format

All inter-service communication uses FQDN:

```
http://<service>.<namespace>.svc.cluster.local:<port>
```

**Examples**:

| Service | URL |
|---------|-----|
| Keycloak | `http://keycloak.default.svc.cluster.local:8080` |
| Audit | `http://audit-audit-service.audit.svc.cluster.local:8080` |
| TaskTracker | `http://tasktracker-tasktracker.tasktracker.svc.cluster.local:8000` |

This format ensures DNS resolution is explicit and works across all namespaces.

## References

- [BFF Service Documentation](../../bff/README.md)
- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [External Secrets Operator](https://external-secrets.io/)
