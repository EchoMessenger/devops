# Node.js Event Generator Helm Chart

Kubernetes Helm chart for deploying the EchoMessenger Event Generator as a Kubernetes Job or CronJob.

## Overview

This chart deploys the Node.js event generator that simulates security incidents (R1-R7 scenarios) for testing the EchoMessenger audit service's incident detection capabilities.

### Features

- **Job Deployment**: Run scenarios as a one-time Kubernetes Job
- **CronJob Support**: Schedule regular scenario execution
- **Helm Hooks**: Auto-run after main app deployment
- **External Secrets**: Integrate with OpenBao/Vault for credential management
- **Security**: Non-root user, read-only filesystem, dropped capabilities
- **Resource Management**: CPU/memory requests and limits
- **Volume Support**: Persistent volumes for logs and events

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- EchoMessenger Tinode server deployed
- Keycloak (optional, for JWT authentication)
- External Secrets Operator (if using secret management)

## Installation

### Add Chart Repository

```bash
helm repo add echomessenger https://charts.echo-messenger.ru
helm repo update
```

### Install with Defaults

```bash
helm install generator-js echomessenger/generator-js \
  --namespace generator \
  --create-namespace
```

### Install with Custom Values

```bash
helm install generator-js echomessenger/generator-js \
  --namespace generator \
  --create-namespace \
  -f values-production.yaml
```

### Upgrade Existing Deployment

```bash
helm upgrade generator-js echomessenger/generator-js \
  --namespace generator \
  -f values-production.yaml
```

## Configuration

### Basic Configuration

#### Tinode Server

```yaml
generator:
  server:
    host: "tinode.tinode.svc.cluster.local"
    port: 16060
    secure: false
    apiKey: "AQEAAAAABAA="
    timeoutSeconds: 30
```

#### Keycloak (Optional)

```yaml
generator:
  server:
    keycloak:
      enabled: true
      url: "https://keycloak.example.com"
      realm: "echo"
      clientId: "tinode-js"
```

#### Generator Settings

```yaml
generator:
  settings:
    rateLimitMs: 100          # Delay between operations
    maxConcurrent: 10         # Max parallel connections
    logLevel: info            # debug|info|warn|error
    dryRun: false             # Test mode without execution
```

### Scenario Configuration

Enable/disable specific scenarios:

```yaml
generator:
  scenarios:
    r1_bruteforce:
      enabled: true
      attempts: 15
      rateLimitMs: 100

    r2_concurrent:
      enabled: true
      sessionCount: 4

    r3_massdel:
      enabled: true
      deleteCount: 12

    r4_volumeanomaly:
      enabled: true
      messagesPerMinute: 200
      durationSeconds: 120

    r5_enumeration:
      enabled: true

    r6_inactive:
      enabled: false    # Requires manual setup

    r7_offhours:
      enabled: false    # Requires time config

    normal:
      enabled: true
```

### Job Configuration

#### Run as One-Time Job

```yaml
job:
  enabled: true
  hook:
    enabled: false      # Don't run as hook
  backoffLimit: 2
  ttlSecondsAfterFinished: 3600

cronjob:
  enabled: false
```

#### Run as Helm Hook (After Deploy)

```yaml
job:
  enabled: true
  hook:
    enabled: true
    weight: 50
    deletePolicy: before-hook-creation,hook-succeeded
```

#### Run as CronJob (Scheduled)

```yaml
job:
  enabled: false        # Disable one-time job

cronjob:
  enabled: true
  schedule: "0 22 * * *"  # Daily at 22:00 UTC
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
```

### Resource Configuration

```yaml
resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### Security

```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

### Storage

```yaml
volumes:
  logs:
    enabled: true
    size: 500Mi
    path: /var/log/generator
  data:
    enabled: true
    size: 1Gi
    path: /var/data/generator
```

## External Secrets Integration

### OpenBao/Vault Configuration

Store credentials in OpenBao:

```bash
# Tinode API key
vault kv put secret/tinode/keygen api_key="AQEAAAAABAA="

# Keycloak configuration
vault kv put secret/keycloak/generator \
  url="https://keycloak.example.com" \
  realm="echo"

# GitHub Container Registry
vault kv put secret/registry/ghcr \
  username="your-user" \
  token="ghp_xxxxx"
```

Enable External Secrets in values:

```yaml
externalSecrets:
  enabled: true
  refreshInterval: 1h
  secretStoreRef:
    name: openbao-global
    kind: ClusterSecretStore
```

## Usage Examples

### Run All Scenarios

```bash
helm install generator-js ./charts/generator-js \
  --set args.scenarios=all \
  --set args.logLevel=debug
```

### Run Specific Scenarios

```bash
helm install generator-js ./charts/generator-js \
  --set args.scenarios="r1-bruteforce,r4-volumeanomaly,r7-offhours"
```

### Dry Run (Test Connection)

```bash
helm install generator-js ./charts/generator-js \
  --set args.dryRun=true
```

### Schedule Daily Runs

```bash
helm install generator-js ./charts/generator-js \
  --set cronjob.enabled=true \
  --set cronjob.schedule="0 22 * * *" \
  --set job.enabled=false
```

## Troubleshooting

### Check Job Status

```bash
kubectl get jobs -n generator
kubectl describe job generator-js -n generator
kubectl logs job/generator-js -n generator
```

### Check CronJob Status

```bash
kubectl get cronjobs -n generator
kubectl describe cronjob generator-js-cronjob -n generator
kubectl logs job/generator-js-cronjob-xxxx -n generator
```

### Verify Output Files

```bash
# List generated events
kubectl exec -it pod/generator-js -- ls -lh /var/data/generator/

# View events
kubectl exec -it pod/generator-js -- cat /var/data/generator/events.jsonl | head -10
```

### Check Secret Configuration

```bash
kubectl get secrets -n generator
kubectl describe secret generator-secrets -n generator
kubectl get externalsecrets -n generator
```

### Debug Environment

```bash
kubectl set env job/generator-js --list -n generator
```

## Values Reference

### Top-level Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| image.repository | string | `ghcr.io/echomessenger/generator-js` | Container image |
| image.tag | string | `1.0.0` | Image tag |
| image.pullPolicy | string | `Always` | Pull policy |
| job.enabled | boolean | `true` | Enable Job deployment |
| cronjob.enabled | boolean | `false` | Enable CronJob |
| serviceAccount.create | boolean | `true` | Create ServiceAccount |
| resources.requests.cpu | string | `200m` | CPU request |
| resources.requests.memory | string | `256Mi` | Memory request |
| resources.limits.cpu | string | `500m` | CPU limit |
| resources.limits.memory | string | `512Mi` | Memory limit |

### Generator Configuration

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| generator.server.host | string | `tinode.tinode.svc.cluster.local` | Tinode host |
| generator.server.port | integer | `16060` | Tinode WebSocket port |
| generator.server.keycloak.enabled | boolean | `true` | Enable Keycloak |
| generator.settings.rateLimitMs | integer | `100` | Rate limit (ms) |
| generator.settings.maxConcurrent | integer | `10` | Max connections |
| generator.settings.logLevel | string | `info` | Log level |
| generator.scenarios.*.enabled | boolean | varies | Enable scenario |

See `values.yaml` for complete reference.

## Contributing

To modify this chart:

1. Update `values.yaml` with new configuration options
2. Update templates in `templates/` directory
3. Update `Chart.yaml` version
4. Run `helm lint` to validate
5. Test with `helm install --dry-run`

## License

Apache-2.0

## Support

For issues or questions:
- Check the [generator README](../../generator/README.md)
- Review Kubernetes logs: `kubectl logs job/generator-js`
- Check External Secrets status: `kubectl get externalsecrets`
- Review values configuration

## See Also

- [Node.js Event Generator](../../generator/README.md) - Generator documentation
- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [External Secrets Operator](https://external-secrets.io/)
