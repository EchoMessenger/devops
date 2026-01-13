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
  bao login s.TognBz5LGGV5lvDCcdmhJY8e

  bao kv put secret/kafka/user password='I/O0lbOoar3uHwuG8BZZettCOV92qMxCAMTCeaauzpc='
  bao kv put secret/kafka/sasl ENABLE='ture' MECHANISM='SCRAM-SHA-512'
  bao kv put secret/kafka/tls ENABLE='true' INSECURE_SKIP_VERIFY='false'

  bao kv list secret/kafka
"
```

## Strimzi
Управляет Kafka

Установка:
```sh
helm install strimzi strimzi/strimzi-kafka-operator -n strimzi --set watchNamespaces="{kafka}
```

То есть ставится в namespace `strimzi` и следит за namespace `kafka`


