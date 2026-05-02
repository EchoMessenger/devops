# Getting Started with Generator-JS Helm Chart

This guide will help you deploy the Event Generator to Kubernetes using Helm.

## Prerequisites

1. **Kubernetes cluster** (v1.20+)
2. **Helm** (v3.0+)
3. **kubectl** configured to access your cluster
4. **Tinode server** running and accessible from the cluster
5. **Keycloak** (optional, for OAuth2 authentication)

## Installation Methods

### Method 1: Quick Start (Development)

```bash
# Clone/navigate to repo
cd /path/to/echomessenger

# Install with development settings
helm install generator-js ./devops/charts/apps/generator-js \
  -f devops/charts/apps/generator-js/values-dev.yaml \
  --namespace generator \
  --create-namespace

# Check installation
kubectl get pods -n generator
```

### Method 2: Production Deployment (Scheduled)

```bash
# Install with production settings (daily at 22:00 UTC)
helm install generator-js ./devops/charts/apps/generator-js \
  -f devops/charts/apps/generator-js/values-prod.yaml \
  --namespace generator \
  --create-namespace

# Verify CronJob
kubectl get cronjobs -n generator
kubectl describe cronjob event-generator -n generator
```

### Method 3: One-Time Run (Testing)

```bash
# Run a single Job immediately
helm install generator-js ./devops/charts/apps/generator-js \
  --set job.enabled=true \
  --set cronjob.enabled=false \
  --namespace generator \
  --create-namespace

# Monitor execution
kubectl logs -f job/event-generator -n generator
```

### Method 4: Post-Deployment Hook (Automatic)

```bash
# Automatically run after Helm installation completes
helm install generator-js ./devops/charts/apps/generator-js \
  --set job.hook.enabled=true \
  --namespace generator \
  --create-namespace
```

## Configuration

### Basic Configuration

Create a `custom-values.yaml` file:

```yaml
generator:
  server:
    host: "tinode.default.svc.cluster.local"
    port: 16060
    keycloak:
      enabled: true
      url: "https://keycloak.example.com"
      realm: "echo"

  scenarios:
    r1_bruteforce:
      enabled: true
    r4_volumeanomaly:
      enabled: false  # Skip slow scenario
```

Then install:

```bash
helm install generator-js ./devops/charts/apps/generator-js \
  -f custom-values.yaml \
  --namespace generator \
  --create-namespace
```

### Environment Variables

Override environment variables:

```bash
helm install generator-js ./devops/charts/apps/generator-js \
  --set env.LOG_LEVEL=debug \
  --set env.RATE_LIMIT_MS=50 \
  --namespace generator \
  --create-namespace
```

### External Secrets (Vault/OpenBao)

For production, enable external secrets:

```bash
helm install generator-js ./devops/charts/apps/generator-js \
  --set externalSecrets.enabled=true \
  --set externalSecrets.secretStoreRef.name=openbao-global \
  --namespace generator \
  --create-namespace
```

## Verification

### Check Pod Status

```bash
# List all resources
kubectl get all -n generator

# Describe pod
kubectl describe pod <pod-name> -n generator

# View logs
kubectl logs <pod-name> -n generator
```

### Check Generated Events

```bash
# Copy events file from pod
kubectl cp generator/<pod-name>:/var/data/generator/events.jsonl ./events.jsonl

# View events
cat events.jsonl | jq .

# Count events
wc -l events.jsonl
```

### Check External Secrets

```bash
# Verify secrets are created
kubectl get secrets -n generator

# Describe external secret
kubectl describe externalsecrets generator-js -n generator
```

## Common Tasks

### View Logs

```bash
# Real-time logs
kubectl logs -f pod/<pod-name> -n generator

# Last 100 lines
kubectl logs <pod-name> -n generator --tail=100

# Job logs
kubectl logs -l app.kubernetes.io/name=generator-js -n generator
```

### List Scenarios

```bash
# Interactive pod
kubectl exec -it pod/<pod-name> -n generator -- /bin/sh

# Inside pod
node src/index.js --list-scenarios
```

### Test Connection

```bash
# Debug pod with utilities
kubectl run -it --rm debug \
  --image=curlimages/curl \
  --restart=Never \
  -n generator -- \
  curl http://tinode.default.svc.cluster.local:16060/v0/health
```

### Upgrade Deployment

```bash
# Update Helm release
helm upgrade generator-js ./devops/charts/apps/generator-js \
  -f custom-values.yaml \
  --namespace generator

# Check upgrade status
helm status generator-js -n generator
```

### Rollback Deployment

```bash
# List previous versions
helm history generator-js -n generator

# Rollback to previous
helm rollback generator-js 1 -n generator
```

### Uninstall

```bash
# Remove Helm release
helm uninstall generator-js -n generator

# Remove namespace
kubectl delete namespace generator
```

## Troubleshooting

### Pod Fails to Start

```bash
# Check pod events
kubectl describe pod <pod-name> -n generator

# Check logs
kubectl logs <pod-name> -n generator --previous

# Common issues:
# - Image pull failed: Check image repository and credentials
# - CrashLoopBackOff: Check logs for startup errors
# - Pending: Check resource requests vs available nodes
```

### Connection Issues

```bash
# Test Tinode connectivity
kubectl run -it --rm test \
  --image=curlimages/curl \
  --restart=Never \
  -n generator -- \
  curl http://tinode.default.svc.cluster.local:16060/v0/health

# Check DNS resolution
kubectl run -it --rm test \
  --image=nicolaka/netshoot \
  --restart=Never \
  -n generator -- \
  nslookup tinode.default.svc.cluster.local
```

### External Secrets Not Working

```bash
# Check if ESO operator is running
kubectl get pods -n external-secrets

# Check secret store
kubectl get secretstores -n generator
kubectl describe secretstores <store-name> -n generator

# Check external secret
kubectl describe externalsecrets generator-js -n generator

# View ESO logs
kubectl logs -n external-secrets deploy/external-secrets
```

### Resource Issues

```bash
# Check node resources
kubectl top nodes

# Check pod resources
kubectl top pod <pod-name> -n generator

# Describe pod for resource requests/limits
kubectl describe pod <pod-name> -n generator
```

## Next Steps

1. **Read the Helm Chart README**: `README.md` for comprehensive feature documentation
2. **Read Installation Guide**: `INSTALLATION.md` for 15+ deployment examples
3. **Check Values Reference**: See inline documentation in `values.yaml`
4. **Monitor Results**: Track job execution and verify events are generated
5. **Integrate with Audit Service**: Verify audit service detects incidents

## Additional Resources

- **Chart Documentation**: `README.md`
- **Detailed Installation**: `INSTALLATION.md`
- **Project Summary**: `COMPLETION_SUMMARY.md`
- **Event Generator**: `/generator/README.md`
- **Quick Start**: `/generator/QUICKSTART.md`
- **Deployment Guide**: `/generator/DEPLOYMENT.md`

## Support

For issues or questions:

1. Check pod logs: `kubectl logs <pod-name> -n generator`
2. Check pod events: `kubectl describe pod <pod-name> -n generator`
3. Review `INSTALLATION.md` troubleshooting section
4. Review `/generator/README.md` for event generator issues

---

**Happy generating! 🚀**
