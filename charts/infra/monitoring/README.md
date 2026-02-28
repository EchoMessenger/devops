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
  -f monitoring/values-promtail.yaml \
  --wait

# echo "=== 6. Tempo ==="
# helm upgrade --install tempo grafana/tempo \
#   --namespace monitoring \
#   -f values-tempo.yaml \
#   --wait

echo "=== 7. Exporters и мониторы ==="
kubectl apply -f monitoring/postgres-exporter.yaml
kubectl apply -f monitoring/cert-manager-monitor.yaml
kubectl apply -f monitoring/traefik-monitor.yaml
kubectl apply -f monitoring/custom-alerts.yaml

echo "=== Готово! ==="
echo "Grafana: kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
```

# Использование

Port-forward:

```sh
# На сервере
export POD_NAME=$(kubectl --namespace monitoring get pod -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=kube-prometheus-stack" -oname)
kubectl --namespace monitoring port-forward $POD_NAME 3000
# Локально
ssh -L 3000:127.0.0.1:3000 nikita@www.echo-messenger.ru
```

Получаем пароль на сервере:

```sh
kubectl --namespace monitoring get secrets kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```

Заходим на `localhost:3000` вводим `admin` и пароль