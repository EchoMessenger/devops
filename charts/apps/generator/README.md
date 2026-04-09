# Generator Helm Chart

A production-ready Helm chart for deploying the **Generator** service in Kubernetes. The Generator is a test scenario runner that simulates 7 malicious and anomalous user behaviors (R1-R7) to validate the EchoMessenger audit system's incident detection capabilities.

## Overview

### What is Generator?

Generator is a Go-based utility that:
- Creates virtual test users and topics via Tinode API
- Simulates realistic and malicious messaging patterns (brute force, mass delete, volume anomaly, etc.)
- Generates audit events for detection system validation
- Exports Prometheus metrics and JSON event logs
- Runs scenarios with configurable concurrency and rate limiting

### Chart Features

✅ **Job-based execution** — Runs to completion with configurable backoff and TTL  
✅ **OpenBao integration** — Automatically retrieves Tinode API key from OpenBao via ExternalSecrets  
✅ **ConfigMap-driven configuration** — Full YAML config template with scenario customization  
✅ **Metrics support** — Prometheus endpoint for monitoring test execution  
✅ **Security best practices** — Non-root user, read-only filesystem, dropped capabilities  
✅ **Optional CronJob** — Schedule recurring test runs (e.g., off-hours scenarios)  
✅ **RBAC ready** — ServiceAccount with security context  

## Prerequisites

1. **Kubernetes cluster** with Helm 3.0+
2. **External Secrets Operator (ESO)** — For retrieving secrets from OpenBao
3. **OpenBao** with Keygen-generated secrets at path: `secret/tinode/keygen`
4. **Running Tinode server** (use `tinode_new` chart):
   ```bash
   helm install tinode ./devops/charts/apps/tinode_new \
     --namespace tinode --create-namespace
   ```
   - Exposes WebSocket on port 16060
   - Exposes REST API on port 6060
   - Generator connects via DNS: `tinode:16060` and `tinode:6060`
5. **ghcr-secret** — GitHub Container Registry pull secret (must exist in namespace)

See [TINODE_COMPATIBILITY.md](./TINODE_COMPATIBILITY.md) for detailed Tinode integration setup.

## Installation

### 1. Add Chart to Your Helm Repository (Optional)

If using a Helm repo:
```bash
helm repo add echomessenger https://charts.echo-messenger.ru
helm repo update
```

### 2. Install with Default Configuration (Tinode in Same Namespace)

```bash
# Ensure Tinode is deployed in the same namespace
helm install tinode ./devops/charts/apps/tinode_new \
  --namespace tinode

# Then install Generator (connects via DNS shortname "tinode")
helm install generator ./generator \
  --namespace tinode
```

This runs the generator immediately as a Kubernetes Job with all default scenarios enabled.

### 3. Install with Custom Configuration

Create a `values-override.yaml`:

```yaml
generator:
  server:
    # Use HTTP for REST API (Tinode serves HTTP on port 6060)
    url: "wss://tinode:16060/v0/channels"
    apiEndpoint: "http://tinode:6060"
    
    # If Tinode in different namespace, use FQDN:
    # url: "wss://tinode.tinode.svc.cluster.local:16060/v0/channels"
    # apiEndpoint: "http://tinode.tinode.svc.cluster.local:6060"

  settings:
    maxConcurrency: 5
    rateLimitPerSecond: 50
    selectedScenarios: "brute_force,mass_delete"  # Run only these scenarios

  scenarios:
    brute_force:
      enabled: true
    mass_delete:
      enabled: true
    # Disable all others
    concurrent_sessions:
      enabled: false
    volume_anomaly:
      enabled: false

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 250m
    memory: 256Mi
```

Install with overrides:
```bash
helm install generator ./generator \
  --namespace audit \
  -f values-override.yaml
```

## Configuration

### Global Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| `image.repository` | `ghcr.io/echomessenger/generator` | Container image |
| `image.tag` | `latest` | Image tag |
| `image.pullPolicy` | `Always` | Pull policy |
| `imagePullSecrets[0].name` | `ghcr-secret` | Pull secret for ghcr.io |

### Generator Server Configuration

```yaml
generator:
  server:
    url: "wss://tinode:16060/v0/channels"      # Tinode WebSocket endpoint
    apiEndpoint: "https://tinode:6060"         # Tinode REST API endpoint
    timeoutSeconds: 30                         # Connection timeout
```

### Generator Execution Settings

```yaml
generator:
  settings:
    maxConcurrency: 10                 # Max parallel goroutines
    rateLimitPerSecond: 100            # Global rate limit (0 = unlimited)
    dryRun: false                      # Log events, don't send to server
    logLevel: "info"                   # debug, info, warn, error
    selectedScenarios: "all"           # "all" or comma-separated list
```

### Test Users

By default, three test users are provisioned:

```yaml
generator:
  users:
    - id: attacker
      login: attacker_user
      password: "GeneratorAttacker123!@#"
      description: "Attacker account for security testing"
    - id: victim
      login: victim_user
      password: "GeneratorVictim456!@#"
      description: "Victim account for testing"
    - id: normal_user1
      login: normal_user_1
      password: "GeneratorNormal001!@#"
      description: "Normal user for baseline traffic"
```

Add more users by extending this array in your values override.

### Scenarios Configuration

#### R1: Brute Force Login
```yaml
scenarios:
  brute_force:
    enabled: true
    userId: attacker
    targetLogin: victim_user
    minAttempts: 10
    intervalMs: 500           # 500ms between attempts
    timeoutSeconds: 60
```

#### R2: Concurrent Sessions
```yaml
scenarios:
  concurrent_sessions:
    enabled: true
    userId: attacker
    sessionCount: 4           # 4 simultaneous connections
    connectionIntervalMs: 100
```

#### R3: Mass Delete
```yaml
scenarios:
  mass_delete:
    enabled: true
    userId: attacker
    topic: "p2p-attacker-victim"
    deleteBurstCount: 12      # Delete 12 messages rapidly
    deleteIntervalMs: 100
```

#### R4: Volume Anomaly (High-Frequency Publishing)
```yaml
scenarios:
  volume_anomaly:
    enabled: true
    userId: attacker
    messagesPerMinute: 200    # 200 msgs/min (unusually high)
    durationSeconds: 120      # Run for 2 minutes
```

#### R5: Enumeration (Topic Subscription Attempts)
```yaml
scenarios:
  enumeration:
    enabled: true
    userId: attacker
    topicIds:
      - "grpAAA"
      - "grpBBB"
      - "grpCCC"              # Attempt to subscribe to restricted topics
    subscriptionIntervalMs: 200
```

#### R6: Inactive Account Activity
```yaml
scenarios:
  inactive_account:
    enabled: false            # Requires manual setup of inactive user
    userId: inactive
    messageBurstCount: 50
```

#### R7: Off-Hours Activity
```yaml
scenarios:
  off_hours:
    enabled: false            # Should run outside business hours
    userId: attacker
    messagesPerMinute: 50
    businessHoursStart: "09:00"
    businessHoursEnd: "18:00"
    durationSeconds: 300
```

#### Baseline: Normal Traffic
```yaml
scenarios:
  normal:
    enabled: true
    users:
      - victim
      - normal_user1
    durationSeconds: 300
    messagesPerMinute: 5      # Realistic traffic pattern
```

### OpenBao Integration

The chart uses ExternalSecrets Operator to retrieve the Tinode API key from OpenBao:

```yaml
externalSecrets:
  enabled: true
  refreshInterval: 1h
  secretStoreRef:
    name: openbao-global          # ClusterSecretStore name
    kind: ClusterSecretStore
  tinode:
    remoteRef:
      key: tinode/keygen          # OpenBao path set by keygen chart
```

The Tinode API key is injected as environment variable `TINODE_API_KEY` and can be used by the generator if needed.

### Job Configuration

```yaml
job:
  enabled: true
  hook:
    enabled: true
    weight: 50                    # Run after app deployment (post-install hook)
    deletePolicy: before-hook-creation,hook-succeeded
  backoffLimit: 2               # Retries on failure
  ttlSecondsAfterFinished: 3600 # Clean up pod after 1 hour
```

### Optional CronJob for Scheduled Runs

To run generator on a schedule (e.g., for off-hours scenarios):

```bash
helm install generator ./generator \
  --set cronjob.enabled=true \
  --set cronjob.schedule="0 22 * * *" \
  --set job.enabled=false \
  --set 'generator.settings.selectedScenarios=off_hours'
```

This creates a CronJob that runs at 22:00 UTC daily and executes only the `off_hours` scenario.

### Resource Limits

```yaml
resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

Generator is I/O-bound (network calls to Tinode), so CPU limits are typically low.

### Pod Security

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

## Usage Examples

### Example 1: Run All Scenarios (Default)
```bash
helm install generator ./generator \
  --namespace audit \
  --create-namespace
```

### Example 2: Dry Run (Validate Configuration Without Side Effects)
```bash
helm install generator ./generator \
  --namespace audit \
  --set 'generator.settings.dryRun=true'
```

Check logs:
```bash
kubectl logs -n audit job/generator --follow
```

### Example 3: Run Only Brute Force Scenario
```bash
helm install generator ./generator \
  --namespace audit \
  --set 'generator.settings.selectedScenarios=brute_force' \
  --set 'generator.scenarios.concurrent_sessions.enabled=false' \
  --set 'generator.scenarios.mass_delete.enabled=false' \
  --set 'generator.scenarios.volume_anomaly.enabled=false' \
  --set 'generator.scenarios.enumeration.enabled=false' \
  --set 'generator.scenarios.normal.enabled=false'
```

### Example 4: Production Setup with Custom Tinode Server
```bash
cat > prod-values.yaml <<EOF
generator:
  server:
    url: "wss://tinode.production.svc.cluster.local:16060/v0/channels"
    apiEndpoint: "https://tinode.production.svc.cluster.local:6060"
    timeoutSeconds: 60

  settings:
    maxConcurrency: 5
    rateLimitPerSecond: 25
    logLevel: warn

  scenarios:
    brute_force:
      minAttempts: 5
    volume_anomaly:
      messagesPerMinute: 100

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 250m
    memory: 256Mi

job:
  backoffLimit: 3
EOF

helm install generator ./generator \
  --namespace audit \
  -f prod-values.yaml
```

### Example 5: Scheduled Off-Hours Testing
```bash
cat > cronjob-values.yaml <<EOF
job:
  enabled: false

cronjob:
  enabled: true
  schedule: "0 22 * * *"  # 22:00 UTC daily

generator:
  settings:
    selectedScenarios: "off_hours"
  scenarios:
    off_hours:
      enabled: true
      messagesPerMinute: 75
      businessHoursStart: "09:00"
      businessHoursEnd: "18:00"
    brute_force:
      enabled: false
    concurrent_sessions:
      enabled: false
    # ... disable other scenarios
EOF

helm install generator ./generator \
  --namespace audit \
  -f cronjob-values.yaml
```

## Monitoring

### Prometheus Metrics

The generator exposes metrics at `http://<pod-ip>:8080/metrics`:

```
generator_messages_published_total{scenario}
generator_login_attempts_total{scenario, status}
generator_subscriptions_total{scenario}
generator_deletions_total{scenario}
generator_errors_total{scenario}
generator_active_connections
generator_scenario_duration_seconds{scenario}
```

Check metrics:
```bash
kubectl port-forward -n audit job/generator 8080:8080
curl http://localhost:8080/metrics
```

### Pod Annotations

The chart automatically adds Prometheus scrape annotations:
```yaml
podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/path: "/metrics"
  prometheus.io/port: "8080"
```

If you have Prometheus running in cluster, it will automatically discover and scrape metrics.

### Logs

View generator logs:
```bash
kubectl logs -n audit job/generator --follow
```

View events log (JSONL format):
```bash
kubectl exec -n audit job/generator -- cat /tmp/events.jsonl | head -20
```

## Troubleshooting

### Job Status

Check job status:
```bash
kubectl describe job -n audit generator
```

### Pod Logs

```bash
kubectl logs -n audit job/generator -c generator
```

### Configuration Validation

Render template locally to validate:
```bash
helm template generator ./generator \
  -f values-override.yaml \
  --namespace audit | less
```

### ExternalSecret Not Synced

If Tinode API key secret is not created:

1. Check ExternalSecret status:
```bash
kubectl get externalsecret -n audit
kubectl describe externalsecret -n audit generator-tinode
```

2. Verify OpenBao secret exists:
```bash
vault kv get secret/tinode/keygen
```

3. Verify ClusterSecretStore is accessible:
```bash
kubectl get secretstore,clustersecretstore -A
```

### Connection Issues

If generator cannot connect to Tinode:

1. Verify Tinode server URL:
```bash
helm get values -n audit generator | grep -A 5 "server:"
```

2. Test connectivity from pod:
```bash
kubectl run -n audit -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v wss://tinode:16060/v0/channels
```

## Upgrading

### Update Chart Values
```bash
helm upgrade generator ./generator \
  --namespace audit \
  --set 'generator.settings.selectedScenarios=brute_force,mass_delete'
```

### Update Chart Version
```bash
helm upgrade generator ./generator \
  --namespace audit
```

### Rollback
```bash
helm rollback generator --namespace audit
```

## Uninstalling

```bash
helm uninstall generator --namespace audit
```

This removes the Job, ConfigMap, ExternalSecret, Service, and ServiceAccount.

## Advanced Configuration

### Custom Test Users with Different Passwords

```yaml
generator:
  users:
    - id: attacker1
      login: attacker_one
      password: "Att@ck3rP@ss1!"
    - id: attacker2
      login: attacker_two
      password: "Att@ck3rP@ss2!"
```

### Custom Test Topics

```yaml
generator:
  topics:
    - name: "restricted_group"
      type: "group"
      description: "Restricted topic for enumeration testing"
      defaultAccessAuth: "R"          # Read-only
      defaultAccessAnon: "N"          # No anonymous access
    - name: "public_group"
      type: "group"
      defaultAccessAuth: "RWP"
      defaultAccessAnon: "N"
```

### Node Affinity

Run generator on specific nodes:

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: node-type
              operator: In
              values:
                - test-runner
```

## Architecture

### Workflow

1. **Chart Install** → ConfigMap and ExternalSecret created
2. **ExternalSecret Sync** → Tinode API key fetched from OpenBao
3. **Job Triggered** → Post-install hook runs generator Job
4. **Pod Initialization** → Generator container mounts config, starts
5. **Scenario Execution** → Generator connects to Tinode, runs scenarios
6. **Metrics Collection** → Prometheus scrapes `/metrics` endpoint
7. **Job Completion** → Pod exits, TTL cleans up after 1 hour

### File Mounts

- `/etc/generator/generator-config.yaml` — ConfigMap (read-only)
- `/tmp/` — Temporary directory for logs/events (emptyDir)

### Secrets

- `generator-tinode` — ExternalSecret with Tinode API key from OpenBao

## Integration with EchoMessenger Architecture

### Dependencies

- **Tinode Server** — Must be running and accessible
- **OpenBao** — Must contain keygen-generated secrets
- **External Secrets Operator** — Must be installed in cluster
- **Audit Service** — Will receive and process generator events

### Data Flow

```
Generator (this chart)
    ↓ (WebSocket + REST API calls)
Tinode Server
    ↓ (events published to Kafka)
Router (Go service)
    ↓ (Kafka topics)
Ingestor (Go service)
    ↓ (batch inserts)
ClickHouse (analytics DB)
    ↓ (data queries)
Audit Service (Spring Boot)
    ↓ (REST API)
Detection Rules (R1-R7 validation)
```

## License

Apache License 2.0

## Support

For issues or questions:

1. Check [Troubleshooting](#troubleshooting) section
2. Review `values.yaml` for configuration options
3. Enable debug logging: `--set 'generator.settings.logLevel=debug'`
4. Check pod logs: `kubectl logs -n audit job/generator -f`
5. Validate template: `helm template generator ./generator`
