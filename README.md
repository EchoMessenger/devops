# devops

Этот репозиторий содержит Docker Compose файлы и конфигурации для различных сервисов, относящихся к проекту.

## OpenBao
> Хранилище секретов
1. Для всего, что указано в values.namespaces:
  - Создаёт ServiceAccounts - определители личности (non-human accounts). В нашем случае они создаются для неймспейсов, но могут и для подов.
  - Создаёт SecretStores - конфигурации подключения. 
2. Создаёт AuthDelegator, который вызывается OpenBao для проверки токенов (JWT) от ServiceAccounts. AuthDelegator подтверждает валидность токена. Vault выдаёт поду свой токен.

Как это работает:

External Secrets Operator (ESO) — это «курьер» между вашим внешним хранилищем секретов (например, OpenBao, HashiCorp Vault или AWS Secrets Manager) и вашим кластером Kubernetes.

Если говорить совсем просто:
- Проблема: В Kubernetes есть встроенные Secrets, но хранить в них пароли в чистом виде (или в Git) небезопасно. Настоящие пароли должны лежать в защищенном сейфе (например, в OpenBao).
- Решение (ESO): Вы устанавливаете этого оператора в кластер. Он постоянно следит за вашим «сейфом». Как только там появляется или меняется пароль, ESO автоматически берет его оттуда и создает/обновляет обычный Secret в Kubernetes.
- Результат: Ваше приложение (Pod) даже не знает про ESO или OpenBao — оно просто читает обычный секрет из Kubernetes, который ESO заботливо принес и положил рядом.

1. ESO берет токен ServiceAccount (созданного в неймспейсе).
2. ESO идет в OpenBao, говорит: «Я от имени SA такого-то, хочу секрет для роли namespace-X».
3. OpenBao берет этот токен и идет к K8s API, чтобы подтвердить личность (это возможно, так как есть ClusterRoleBinding на system:auth-delegator).
4. K8s API подтверждает: «Да, токен настоящий, это SA из неймспейса X».
5. OpenBao выдает секрет.
6. ESO записывает его в обычный K8s Secret.

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
helm install strimzi-operator strimzi/strimzi-kafka-operator --namespace kafka
# Может вызвать warning, это нормально
helm install kafka ./strimzi --namespace kafka
```
