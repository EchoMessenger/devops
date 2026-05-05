# Monitoring stack (k3s): Prometheus + Grafana + Loki + Promtail

Инструкция проверена на текущем окружении EchoMessenger и включает рабочий пайплайн OpenBao audit logs:

`OpenBao (/vault/audit/audit.log) -> Promtail (file scrape) -> Loki -> Grafana`

## Предусловия

1. OpenBao развернут из `devops/charts/infra/openbao-core` с hostPath для audit-логов:
   - в pod: `/vault/audit/audit.log`
   - на ноде: `/var/log/openbao/audit.log`
2. В `devops/charts/infra/monitoring/values-promtail.yaml` уже есть:
   - `extraVolumes/extraVolumeMounts` на `/var/log/openbao`
   - `extraScrapeConfigs` с `job_name: openbao-audit`

## Argo CD (рекомендуемый способ)

Для GitOps в репозитории добавлен отдельный манифест:

- `devops/argocd/monitoring.yaml` — 4 приложения:
  - `monitoring-kube-prometheus-stack` (wave `0`)
  - `monitoring-loki` (wave `1`)
  - `monitoring-promtail` (wave `2`)
  - `monitoring-addons` (wave `3`)

И обновлен `devops/argocd/infra.yaml`: `charts/infra/monitoring` исключен из общего `infra-apps`, чтобы monitoring не пытался устанавливаться как обычный Helm chart.

Применение:

```sh
kubectl apply -f devops/argocd/infra.yaml
kubectl apply -f devops/argocd/monitoring.yaml
```

Важно:
- для Loki в Argo CD зафиксированы те же обязательные параметры, что и в ручном `helm upgrade` (SingleBinary + schemaConfig + delete_request_store);
- `CreateNamespace=true`, `automated.prune=true`, `automated.selfHeal=true` включены;
- `monitoring-addons` берет только `*.yaml` манифесты (без `values-*.yaml` и `README.md`).

## Установка / обновление стека (ручной Helm)

Выполнять из корня репозитория:

```sh
cd /Users/nikitadyuckov/Documents/GitHub/EchoMessenger

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

### 1) Prometheus + Grafana

```sh
helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f devops/charts/infra/monitoring/values-prometheus-stack.yaml \
  --wait --timeout 10m
```

### 2) Loki (важно для chart 6.55.0+)

Для Loki в этом chart нужно явно задавать:
- `deploymentMode=SingleBinary` (top-level)
- `schemaConfig`
- `compactor.delete_request_store` при включенном retention

```sh
helm upgrade --install loki grafana/loki \
  -n monitoring \
  -f devops/charts/infra/monitoring/values-loki.yaml \
  --reset-values \
  --set deploymentMode=SingleBinary \
  --set loki.schemaConfig.configs[0].from=2024-01-01 \
  --set loki.schemaConfig.configs[0].store=tsdb \
  --set loki.schemaConfig.configs[0].object_store=filesystem \
  --set loki.schemaConfig.configs[0].schema=v13 \
  --set loki.schemaConfig.configs[0].index.prefix=loki_index_ \
  --set loki.schemaConfig.configs[0].index.period=24h \
  --set loki.compactor.retention_enabled=true \
  --set loki.compactor.delete_request_store=filesystem \
  --wait --timeout 10m
```

### 3) Promtail

```sh
helm upgrade --install promtail grafana/promtail \
  -n monitoring \
  -f devops/charts/infra/monitoring/values-promtail.yaml \
  --wait --timeout 10m
```

### 4) Дополнительные ServiceMonitor/Rules

```sh
kubectl apply -f devops/charts/infra/monitoring/postgres-exporter.yaml
kubectl apply -f devops/charts/infra/monitoring/cert-manager-monitor.yaml
kubectl apply -f devops/charts/infra/monitoring/traefik-monitor.yaml
kubectl apply -f devops/charts/infra/monitoring/custom-alerts.yaml
```

## Быстрая проверка пайплайна OpenBao -> Loki

### 1) Проверить файл в Promtail pod

```sh
POD=$(kubectl -n monitoring get pods -l app.kubernetes.io/name=promtail -o jsonpath='{.items[0].metadata.name}')
kubectl -n monitoring exec "$POD" -- sh -c 'ls -la /var/log/openbao'
kubectl -n monitoring exec "$POD" -- sh -c 'grep -n "job_name: openbao-audit" /etc/promtail/promtail.yaml'
```

### 2) Сгенерировать audit-событие в OpenBao

```sh
ROOT_TOKEN=$(kubectl -n openbao get secret openbao-bootstrap -o jsonpath='{.data.root-token}' | base64 -d)
kubectl -n openbao exec sts/openbao -- sh -c \
'curl -s -H "X-Vault-Token: '"$ROOT_TOKEN"'" http://127.0.0.1:8200/v1/auth/token/lookup-self >/dev/null && echo ok'
```

### 3) Проверить данные в Loki

```sh
kubectl -n monitoring port-forward svc/loki-gateway 3100:80
```

Во втором терминале:

```sh
curl -G 'http://127.0.0.1:3100/loki/api/v1/query_range' \
  --data-urlencode 'query={job="openbao-audit",service="openbao"}' \
  --data-urlencode 'limit=50' \
  --data-urlencode "start=$(date -u -d '15 minutes ago' +%s)000000000" \
  --data-urlencode "end=$(date -u +%s)000000000"
```

## Grafana доступ

```sh
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```

Логин: `admin`, пароль из команды выше.

## Рекомендуемые панели для OpenBao audit

Datasource: `Loki`

1. Time series (events/min):
```logql
sum(count_over_time({job="openbao-audit",service="openbao"}[1m]))
```

2. Top users (Table/Bar gauge):
```logql
topk(
  5,
  sum by (user) (
    count_over_time(
      {job="openbao-audit",service="openbao"}
      | json user="auth.display_name"
      | user!=""
      [5m]
    )
  )
)
```

3. Errors (Logs):
```logql
{job="openbao-audit",service="openbao"} |~ "(?i)error|denied|forbidden|permission"
```

4. Raw logs (Logs):
```logql
{job="openbao-audit",service="openbao"}
```

## Troubleshooting

### `502 Bad Gateway` на `loki-gateway`

Проверить gateway logs:

```sh
kubectl -n monitoring logs deploy/loki-gateway --tail=200
```

Если есть `loki-distributor... could not be resolved` или `loki-query-frontend... could not be resolved`:
- применился неправильный Loki mode (обычно не SingleBinary);
- повторить `helm upgrade` Loki с `--reset-values` и `--set deploymentMode=SingleBinary`.

### `invalid compactor config: compactor.delete-request-store should be configured`

Добавить:

```sh
--set loki.compactor.delete_request_store=filesystem
```

### В `query` видите `log queries are not supported as an instant query type`

Это нормально для логовых stream-запросов. Используйте `query_range`.
