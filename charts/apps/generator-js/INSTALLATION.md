# Helm Chart Installation Guide

## Quick Start

### 1. Install with Defaults

```bash
helm install generator-js ./devops/charts/apps/generator-js \
  --namespace generator \
  --create-namespace
```

### 2. Install with Development Values

```bash
helm install generator-js ./devops/charts/apps/generator-js \
  --namespace generator \
  --create-namespace \
  -f ./devops/charts/apps/generator-js/values-dev.yaml
```

### 3. Install with Production Values

```bash
helm install generator-js ./devops/charts/apps/generator-js \
  --namespace generator \
  --create-namespace \
  -f ./devops/charts/apps/generator-js/values-prod.yaml
```

## Configuration Examples

### Example 1: Run Once (Job Mode)

```bash
helm install generator-js ./devops/charts/apps/generator-js \
  --set job.enabled=true \
  --set cronjob.enabled=false \
  --set args.scenarios=all \
  --set args.logLevel=debug
```

### Example 2: Schedule Daily (CronJob Mode)

```bash
helm install generator-js ./devops/charts/apps/generator-js \
  --set job.enabled=false \
  --set cronjob.enabled=true \
  --set cronjob.schedule="0 22 * * *" \
  --set args.scenarios=r1-bruteforce,r4-volumeanomaly,r7-offhours
```

### Example 3: Run as Helm Hook (After Deployment)

```bash
helm install generator-js ./devops/charts/apps/generator-js \
  --set job.enabled=true \
  --set job.hook.enabled=true \
  --set cronjob.enabled=false
```

### Example 4: Dry Run (Test Connection Only)

```bash
helm install generator-js ./devops/charts/apps/generator-js \
  --set args.dryRun=true \
  --set args.logLevel=debug
```

### Example 5: Custom Tinode & Keycloak

```bash
helm install generator-js ./devops/charts/apps/generator-js \
  --set generator.server.host=tinode.prod.svc.cluster.local \
  --set generator.server.port=16060 \
  --set generator.server.keycloak.enabled=true \
  --set generator.server.keycloak.url=https://keycloak.prod.example.com \
  --set generator.server.keycloak.realm=echo \
  --set externalSecrets.enabled=true
```

## Verification

### Check Job Status

```bash
# List all jobs
kubectl get jobs -n generator

# Describe job
kubectl describe job event-generator -n generator

# View job logs
kubectl logs job/event-generator -n generator -f

# Check job events
kubectl describe job event-generator -n generator | grep -A 5 Events
```

### Check Generated Events

```bash
# Get pod name
POD=$(kubectl get pods -n generator -l app.kubernetes.io/name=generator-js -o jsonpath='{.items[0].metadata.name}')

# View event count
kubectl exec -n generator $POD -- wc -l /var/data/generator/events.jsonl

# View first events
kubectl exec -n generator $POD -- head -5 /var/data/generator/events.jsonl

# Validate JSON
kubectl exec -n generator $POD -- cat /var/data/generator/events.jsonl | jq . | head -20
```

### Check Secrets

```bash
# List secrets
kubectl get secrets -n generator

# Describe external secrets
kubectl describe externalsecrets -n generator

# Check secret values (encrypted)
kubectl get secret generator-secrets -n generator -o yaml
```

## Upgrading

### Update Chart

```bash
# Update to new version
helm upgrade generator-js ./devops/charts/apps/generator-js \
  --namespace generator \
  -f values-prod.yaml
```

### Change Configuration

```bash
# Change log level
helm upgrade generator-js ./devops/charts/apps/generator-js \
  --namespace generator \
  --set generator.settings.logLevel=debug
```

### Revert to Previous Version

```bash
# List releases
helm history generator-js -n generator

# Rollback to previous
helm rollback generator-js 1 -n generator
```

## Uninstalling

```bash
# Uninstall helm release
helm uninstall generator-js -n generator

# Delete namespace (optional)
kubectl delete namespace generator
```

## Troubleshooting

### Job Not Running

```bash
# Check job status
kubectl get jobs -n generator -o wide

# Check pod status
kubectl get pods -n generator

# Describe pod for events
kubectl describe pod generator-js-xxxxx -n generator

# Check pod logs
kubectl logs pod/generator-js-xxxxx -n generator
```

### External Secrets Not Working

```bash
# Check ESO operator running
kubectl get pods -n external-secrets

# Describe external secret
kubectl describe externalsecrets generator-js -n generator

# Check ESO logs
kubectl logs -n external-secrets deploy/external-secrets
```

### Image Pull Issues

```bash
# Check image pull secrets
kubectl get secrets -n generator | grep ghcr

# Test image pull
kubectl run test-image --image=ghcr.io/echomessenger/generator-js:1.0.0 \
  --image-pull-policy=Always \
  -n generator
```

### Tinode Connection Issues

```bash
# Test connectivity from pod
kubectl run -it --rm debug --image=curlimages/curl \
  --restart=Never -n generator -- \
  curl http://tinode.tinode.svc.cluster.local:6060/v0/health
```

## Best Practices

1. **Use Values Files**: Store environment-specific configurations in separate values files
2. **External Secrets**: Never commit credentials; use OpenBao/Vault integration
3. **Resource Limits**: Always set requests and limits to prevent resource starvation
4. **Logging**: Use appropriate log levels (debug for dev, info for prod)
5. **Monitoring**: Monitor job completion and event generation
6. **Scheduling**: Use CronJobs for production regular execution
7. **Retention**: Configure `ttlSecondsAfterFinished` to clean up old jobs

## Integration with CI/CD

### GitHub Actions Example

```yaml
- name: Deploy Event Generator
  run: |
    helm install generator-js ./devops/charts/apps/generator-js \
      --namespace generator \
      --create-namespace \
      -f values-prod.yaml \
      --wait \
      --timeout 5m
```

### GitOps (ArgoCD) Example

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: generator-js
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/echomessenger/echomessenger
    targetRevision: main
    path: devops/charts/apps/generator-js
    helm:
      valueFiles:
        - values-prod.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: generator
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## See Also

- [Helm Chart README](./README.md)
- [Event Generator README](../../generator/README.md)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
