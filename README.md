# devops

Этот репозиторий содержит Docker Compose файлы и конфигурации для различных сервисов, относящихся к проекту.

## OpenBao
Хранит секреты

Усановка:
```sh
# Go to openbao helm dir
cd ./charts/infra

# Delete OpenBao and its data if exists
helm uninstall openbao -n openbao
kubectl delete pvc -n openbao --all
rm -f openbao-keys.json

# Reinstall
helm upgrade --install openbao ./charts/openbao -n openbao --create-namespace

# Run init
./scripts/openbao/init-openbao.sh
# Script saves keys to .json file. Save it safely then remove it
rm -f openbao-keys.json
```

Создание секретов происходит вручную. Переменные среды необходимо заменить на реальные значения
```sh
kubectl exec -n openbao openbao-0 -- sh -c "
  bao login ${ROOT_TOKEN}

  bao kv put secret/kafka/user password='${KAFKA_USER_PASSWORD}'
  bao kv put secret/kafka/sasl ENABLE='${KAFKA_SASL_ENABLE}' MECHANISM='${KAFKA_SASL_MECHANISM}'
  bao kv put secret/kafka/tls ENABLE='${KAFKA_TLS_ENABLE}' INSECURE_SKIP_VERIFY='${KAFKA_TLS_INSECURE_SKIP_VERIFY}'

  bao kv list secret/kafka
"
```

