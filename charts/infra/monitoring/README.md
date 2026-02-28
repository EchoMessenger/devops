# Установка

```sh
#!/bin/bash
set -euo pipefail

echo "=== 1. Создание namespace ==="
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

echo "=== 2. Добавление Helm-репозиториев ==="
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

echo "=== 3. Prometheus Stack ==="
helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f monitoring/values-prometheus-stack.yaml \
  --wait --timeout 10m

echo "=== 4. Loki ==="
helm upgrade --install loki grafana/loki \
  --namespace monitoring \
  -f values-loki.yaml \
  --wait --timeout 10m

echo "=== 5. Promtail ==="
helm upgrade --install promtail grafana/promtail \
  --namespace monitoring \
  -f values-promtail.yaml \
  --wait

# echo "=== 6. Tempo ==="
# helm upgrade --install tempo grafana/tempo \
#   --namespace monitoring \
#   -f values-tempo.yaml \
#   --wait

echo "=== 7. Exporters и мониторы ==="
kubectl apply -f postgres-exporter.yaml
kubectl apply -f cert-manager-monitor.yaml
kubectl apply -f traefik-monitor.yaml
kubectl apply -f custom-alerts.yaml

echo "=== Готово! ==="
echo "Grafana: kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
```