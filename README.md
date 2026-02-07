# Devops

Источник правды (Source of truth) для развёртывания приложений

## OpenBao
> Хранилище секретов

### Установка

```sh
# Go to devops/charts/infra
pwd

# Install, config and unseal main app
# Wait for all jobs to finish
helm install openbao-core ./openbao-core -n openbao --create-namespace

helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# Install ESO
helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets \
  --create-namespace

# Install ClusterSecretStore
helm install openbao-secretstore ./openbao-secretstore -n external-secrets
# Check ClusterSecretStore
kubectl describe clustersecretstore openbao-global
```

### Как это работает

#### Составные части:
- OpenBao — это хранилище секретов.
- Kubernetes ServiceAccount + RBAC — это способ доказать OpenBao, кто ты такой.
- ESO (External Secrets Operator) — это курьер, который умеет ходить в OpenBao и забирать/класть секреты.
- SecretStore / ClusterSecretStore — это настройки как именно ESO ходит в OpenBao.
- ExternalSecret — это инструкция какие секреты забрать и куда положить.
- PushSecret — это обратный ход: взять Kubernetes Secret и отправить его в OpenBao.

#### OpenBao

OpenBao (форк Vault) хранит секреты:
- пароли
- токены
- сертификаты
- dynamic secrets (DB users, etc)

Он ничего не знает про Kubernetes, пока не включен `Kubernetes auth method`

#### Service Account

Service Account - аккаунт какого-либо сервиса.

В Kubernetes любой pod работает от имени ServiceAccount. 
Что внутри ServiceAccount:
- JWT токен
- namespace
- имя SA

Этот токен передаётся в OpenBao, чтобы сказать: «Я pod из namespace X, serviceAccount Y»

В нашем случае SA нужен только для ESO, так как только eso ходит за секретами.

SA для ESO создаётся автоматически при установке.

#### RBAC - Role-Based Access Control

RBAC НЕ управляет OpenBao напрямую.

Он разрешает ESO:
- читать ServiceAccount токены
- создавать / обновлять Kubernetes Secrets
- читать ExternalSecret, SecretStore и т.д.

RBAC = доступ ВНУТРИ Kubernetes
OpenBao policies = доступ ВНУТРИ OpenBao

#### ESO - External Secrets Operator

1. живёт в Kubernetes
2. смотрит на CRD:
  - ExternalSecret
  - SecretStore
  - ClusterSecretStore
  - PushSecret
3. аутентифицируется в OpenBao
4. синхронизирует секреты

ESO никогда не хранит секреты у себя, он только переносчик.

#### SecretStore / ClusterSecretStore

Отвечают на вопрос “Как ходить в OpenBao?”

1. SecretStore
  - работает только в одном namespace
2. ClusterSecretStore
- доступен во всех namespace
- требует аккуратного RBAC

#### ExternalSecret

Отвечает на вопрос “Что забрать и куда положить?”

Пример процесса:
1. ESO читает ExternalSecret
2. Идёт в OpenBao
3. Забирает prod/db.password
4. Создаёт Kubernetes Secret db-secret

#### PushSecret

PushSecret — обратный поток

PushSecret нужен, когда секрет рождается в Kubernetes, но должен жить в OpenBao

## Strimzi

> Управляет Kafka

### Установка:
```sh
# Install Strimzi 
helm install strimzi-operator strimzi/strimzi-kafka-operator --namespace kafka --create-namespace
# Install chart to config Kafka
helm install kafka ./strimzi -n kafka --create-namespace

# Check Kafka
kubectl get kafka -n kafka
kubectl describe kafka kafka -n kafka

kubectl get kafkanodepool -n kafka
kubectl describe kafkanodepool dual-role -n kafka

kubectl get kafkatopic -n kafka

kubectl get kafkauser -n kafka

# Check PushSecret
kubectl describe pushsecret kafka-router-push -n kafka

# Check that secret is in OpenBao
ROOT_TOKEN=$(kubectl get secret openbao-bootstrap -n openbao -o jsonpath='{.data.root-token}' | base64 -d)

kubectl run bao-check -n openbao --rm -it \
  --image=curlimages/curl \
  --restart=Never -- sh -c "
curl -s -H 'X-Vault-Token: $ROOT_TOKEN' \
  http://openbao.openbao.svc:8200/v1/secret/data/kafka/user
"
```

### Как это работает

#### Основные компоненты

##### Kafka Cluster (Strimzi)

Развертывается в режиме KRaft (без ZooKeeper) для упрощенного управления
Используется архитектура dual-role, где узел выполняет роль и controller, и broker
Поддерживает два типа подключений: незашифрованное (9092) и TLS (9093)
Аутентификация клиентов через SCRAM-SHA-512

##### Entity Operator

- **Topic Operator** автоматически создает и управляет Kafka-топиками на основе CRD-ресурсов
- **User Operator** создает пользователей, генерирует credentials и сохраняет их в Kubernetes Secret

##### External Secrets Operator (PushSecret)

Отслеживает изменения в Kubernetes Secret, созданном User Operator
Автоматически синхронизирует учетные данные в OpenBao каждый час или при изменении
Использует ClusterSecretStore для безопасного подключения к OpenBao

##### OpenBao (Vault-совместимое хранилище)

Централизованное хранилище для credentials пользователей Kafka
Интегрируется с Kubernetes через ServiceAccount authentication
Обеспечивает единую точку доступа к секретам для всех приложений в кластере

#### Принцип работы

##### Процесс развертывания

1. Инициализация кластера: Helm создает CRD-ресурсы (Kafka, KafkaNodePool, KafkaTopic, KafkaUser, PushSecret)
2. Развертывание Kafka: Strimzi Operator разворачивает Kafka брокеры с хранилищем на PersistentVolume и запускает Entity Operator
3. Создание топиков: Topic Operator автоматически создает 10 преднастроенных топиков для приложения Tinode (ctrl, data, pres, meta, info и др.)
4. Создание пользователя: User Operator генерирует случайный пароль, создает SCRAM-credentials в Kafka и сохраняет их в Kubernetes Secret user
5. Синхронизация секретов: External Secrets Operator через PushSecret считывает данные из Secret и отправляет их в OpenBao по пути secret/kafka/user

- При создании пользователя автоматически генерируются password и sasl.jaas.config
- Credentials синхронизируются в OpenBao с интервалом 1 час (настраивается)
- При изменении/удалении Secret происходит автоматическая пересинхронизация
- Приложения могут получать актуальные credentials из OpenBao через ExternalSecret или напрямую через API

#### Сетевое взаимодействие

##### Внутри кластера:

- Клиенты подключаются через сервис kafka-kafka-bootstrap на портах 9092 (plain) или 9093 (TLS)
- Entity Operator взаимодействует с Kafka через внутренний API для управления ресурсами
- External Secrets Operator подключается к OpenBao по HTTPS с аутентификацией через Kubernetes ServiceAccount

##### Аутентификация:

- Все клиенты должны предоставить SCRAM-SHA-512 credentials
- Поддерживается дополнительное TLS-шифрование канала связи
- Access Control Lists (ACLs) настраиваются через параметр user.acls в values.yaml

## PostgreSQL для Tinode

> БД для Tinode

### Установка
```sh
# Install PostgreSQL
helm install postgres ./postgres -n tinode --create-namespace

# Check PostgreSQL logs
kubectl logs postgres-0 -n tinode

# Check PostgreSQL functionality
kubectl exec -it -n tinode postgres-0 -- psql -U postgres -d postgres -c "\l"
```