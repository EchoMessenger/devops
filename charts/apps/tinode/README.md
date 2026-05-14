# Tinode Helm Chart

Helm chart для развертывания Tinode chat server в Kubernetes (k3s).

## Предварительные требования

- Kubernetes 1.19+ (k3s 1.19+)
- Helm 3.0+
- База данных PostgreSQL или MySQL
- (Опционально) Ingress controller (nginx, traefik)
- (Опционально) cert-manager для автоматических SSL сертификатов

## Быстрый старт

### 1. Подготовка базы данных PostgreSQL

```bash
# Установка PostgreSQL через Helm (если еще не установлен)
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install postgres bitnami/postgresql \
  --set auth.username=tinode \
  --set auth.password=tinode123 \
  --set auth.database=tinode \
  --set primary.persistence.size=10Gi
```

### 2. Генерация ключей шифрования

**ВАЖНО**: В production обязательно сгенерируйте свои уникальные ключи!

```bash
# Генерация ключей
API_KEY_SALT=$(openssl rand -base64 32)
AUTH_TOKEN_KEY=$(openssl rand -base64 32)
UID_ENCRYPTION_KEY=$(openssl rand -base64 16)

echo "API_KEY_SALT: $API_KEY_SALT"
echo "AUTH_TOKEN_KEY: $AUTH_TOKEN_KEY"
echo "UID_ENCRYPTION_KEY: $UID_ENCRYPTION_KEY"
```

### 3. Создание файла с вашими настройками

Создайте файл `my-values.yaml`:

```yaml
database:
  type: postgres
  waitFor:
    enabled: true
    host: postgres-postgresql
    port: 5432
  postgres:
    dsn: "postgresql://tinode:tinode123@postgres-postgresql:5432/tinode?sslmode=disable"

encryption:
  apiKeySalt: "ВАШ_API_KEY_SALT"
  authTokenKey: "ВАШ_AUTH_TOKEN_KEY"
  uidEncryptionKey: "ВАШ_UID_ENCRYPTION_KEY"

ingress:
  enabled: true
  className: "traefik"  # или "nginx" в зависимости от вашего ingress
  hosts:
    - host: tinode.local
      paths:
        - path: /
          pathType: Prefix
```

### 4. Установка Tinode

```bash
# Установка из локальной директории
helm install tinode ./tinode-helm -f my-values.yaml

# Или если chart упакован
helm install tinode tinode-helm-0.1.0.tgz -f my-values.yaml

# С указанием namespace
helm install tinode ./tinode-helm -f my-values.yaml -n tinode --create-namespace
```

### 5. Проверка статуса

```bash
# Проверка подов
kubectl get pods -l app.kubernetes.io/name=tinode

# Проверка сервисов
kubectl get svc -l app.kubernetes.io/name=tinode

# Проверка ingress
kubectl get ingress

# Логи
kubectl logs -l app.kubernetes.io/name=tinode -f
```

## Конфигурация

### Основные параметры

| Параметр | Описание | Значение по умолчанию |
|----------|----------|----------------------|
| `replicaCount` | Количество реплик | `1` |
| `image.repository` | Docker репозиторий | `ghcr.io/echomessenger/tinode-server` |
| `image.tag` | Тег образа | `latest-amd64` |
| `database.type` | Тип БД (postgres/mysql/mongodb/rethinkdb) | `postgres` |
| `database.postgres.dsn` | PostgreSQL DSN | см. values.yaml |
| `encryption.apiKeySalt` | API key salt (base64) | **ИЗМЕНИТЬ!** |
| `encryption.authTokenKey` | Auth token key (base64) | **ИЗМЕНИТЬ!** |
| `encryption.uidEncryptionKey` | UID encryption key (base64) | **ИЗМЕНИТЬ!** |

### Хранилище медиа файлов

#### Файловая система (по умолчанию)

```yaml
media:
  handler: "fs"
  fs:
    corsOrigins: '["*"]'

persistence:
  enabled: true
  size: 10Gi
```

#### S3-совместимое хранилище

```yaml
media:
  handler: "s3"
  s3:
    accessKeyId: "YOUR_ACCESS_KEY"
    secretAccessKey: "YOUR_SECRET_KEY"
    region: "eu-central-1"
    bucket: "tinode-media"
    endpoint: ""  # для MinIO укажите https://minio.example.com

persistence:
  enabled: false  # отключаем PVC
```

#### S3 с использованием Minio (OpenBao)

Если вы используете OpenBao для управления секретами, создайте отдельный Minio chart для Tinode:

```bash
# 1. Установите minio-tinode chart (один раз)
helm install minio-tinode ./devops/charts/infra/minio-tinode \
  -n tinode-infra --create-namespace

# Это создаст Minio StatefulSet и подключит его через PushSecret к OpenBao
# Credentials будут синхронизированы в OpenBao по пути tinode/s3

# 2. Деплойте tinode с включенным S3 (точки подключения заполнятся автоматически из OpenBao)
helm install tinode ./tinode-helm \
  -f values-s3-minio.yaml \
  -n tinode --create-namespace
```

**Пример `values-s3-minio.yaml`** (используется с OpenBao):

```yaml
# Среда: tinode-infra (где развернут minio-tinode)
openbao:
  enabled: true
  clusterSecretStore: openbao-global
  secrets:
    s3:
      path: tinode/s3  # OpenBao будет получать отсюда credentials

# Включаем S3 как обработчик медиа
media:
  handler: "s3"
  s3:
    # Значения заполнятся автоматически из ExternalSecret (из OpenBao)
    # которые в свою очередь поступают из minio-tinode chart PushSecret
    region: "us-east-1"
    bucket: "tinode-minio"
    # Endpoint вычисляется автоматически: http://minio-tinode.tinode-infra.svc.cluster.local:9000
    endpoint: ""
    corsOrigins: '["https://tinode.echo-messenger.ru"]'

# Отключаем локальное хранилище (используем S3)
persistence:
  enabled: false

# Используем OpenBao для получения S3 credentials
encryption:
  apiKeySalt: ""  # будет заполнено из OpenBao
  authTokenKey: ""
  uidEncryptionKey: ""
```

**Архитектура потока**:
```
minio-tinode StatefulSet (ns: tinode-infra)
    ↓
    Secret: minio-tinode-credentials
    ↓
    PushSecret (синхронизирует в OpenBao)
    ↓
    OpenBao: tinode/s3 (accessKey, secretKey, endpoint, region, bucket)
    ↓
    Tinode ExternalSecret (читает из OpenBao)
    ↓
    Tinode Secret: aws-access-key-id, aws-secret-access-key
    ↓
    Tinode Deployment (инжектирует AWS_* переменные)
    ↓
    Tinode app (подключается к Minio как к S3 хранилищу)
```

### Email верификация

```yaml
email:
  verification:
    required: true
  smtp:
    hostUrl: "https://tinode.example.com"
    server: "smtp.gmail.com"
    port: "587"
    sender: "noreply@example.com"
    login: "noreply@example.com"
    password: "YOUR_PASSWORD"
    authMechanism: "plain"
```

### Push уведомления

```yaml
fcm:
  enabled: true
  projectId: "your-project"
  credFile: "/path/to/firebase-creds.json"
  apiKey: "YOUR_API_KEY"
  appId: "YOUR_APP_ID"
  senderId: "YOUR_SENDER_ID"
  vapidKey: "YOUR_VAPID_KEY"
```

### WebRTC звонки

Tinode включает звонки только если `WEBRTC_ENABLED=true` и файл `iceServersFile`
содержит непустой JSON-массив ICE-серверов. TURN credential не храните в git:
создайте Kubernetes Secret отдельно.

```bash
cat > /tmp/ice-servers.json <<'EOF'
[
  {
    "urls": ["stun:158.160.78.105:3478"]
  },
  {
    "urls": [
      "turn:158.160.78.105:3478?transport=udp",
      "turn:158.160.78.105:3478?transport=tcp"
    ],
    "username": "tinode",
    "credential": "CHANGE_ME_TO_TURN_PASSWORD"
  }
]
EOF

kubectl -n tinode create secret generic tinode-ice-servers \
  --from-file=ice-servers.json=/tmp/ice-servers.json \
  --dry-run=client -o yaml | kubectl apply -f -
```

Production values already reference this Secret:

```yaml
webrtc:
  enabled: true
  iceServersFile: "/etc/tinode/ice-servers.json"
  iceServersSecret:
    create: false
    name: "tinode-ice-servers"
    key: "ice-servers.json"
```

After redeploying Tinode, check logs:

```bash
kubectl -n tinode logs deploy/tinode | grep -E "Video calls|ICE"
```

### Ingress с SSL

```yaml
ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
    - host: tinode.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: tinode-tls
      hosts:
        - tinode.example.com
```

## Примеры развертывания

### Development (локальный k3s)

```bash
# Минимальная конфигурация для разработки
cat <<EOF > dev-values.yaml
database:
  type: postgres
  postgres:
    dsn: "postgresql://tinode:tinode@postgres:5432/tinode?sslmode=disable"
  sampleData: "data.json"  # Загрузить тестовые данные

encryption:
  apiKeySalt: "$(openssl rand -base64 32)"
  authTokenKey: "$(openssl rand -base64 32)"
  uidEncryptionKey: "$(openssl rand -base64 16)"

resources:
  requests:
    cpu: 100m
    memory: 256Mi
EOF

helm install tinode ./tinode-helm -f dev-values.yaml
```

### Production

См. файл `values-production.yaml` для полной конфигурации production.

```bash
# Отредактируйте values-production.yaml под свои нужды
vim values-production.yaml

# Установка
helm install tinode ./tinode-helm -f values-production.yaml -n tinode --create-namespace
```

### Production с высокой доступностью

```yaml
replicaCount: 3

cluster:
  enabled: true
  selfName: "tinode-${POD_NAME}"
  nodes:
    - name: "tinode-0"
      addr: "tinode-0.tinode-headless:12000"
    - name: "tinode-1"
      addr: "tinode-1.tinode-headless:12001"
    - name: "tinode-2"
      addr: "tinode-2.tinode-headless:12002"

affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchExpressions:
        - key: app.kubernetes.io/name
          operator: In
          values:
          - tinode
      topologyKey: kubernetes.io/hostname
```

## Обновление

```bash
# Обновление релиза
helm upgrade tinode ./tinode-helm -f my-values.yaml

# Обновление с изменением значений
helm upgrade tinode ./tinode-helm -f my-values.yaml --set replicaCount=3

# Откат к предыдущей версии
helm rollback tinode
```

## Удаление

```bash
# Удаление релиза (данные в PVC сохраняются)
helm uninstall tinode

# Полное удаление включая PVC
helm uninstall tinode
kubectl delete pvc -l app.kubernetes.io/name=tinode
```

## Мониторинг и отладка

```bash
# Логи всех подов
kubectl logs -l app.kubernetes.io/name=tinode --tail=100 -f

# Подключение к поду
kubectl exec -it deployment/tinode -- /bin/bash

# Проверка конфигурации
kubectl exec -it deployment/tinode -- cat /opt/tinode/working.config

# Port-forward для локального доступа
kubectl port-forward svc/tinode 6060:6060

# Затем открыть http://localhost:6060
```

## Troubleshooting

### База данных не готова

Если под падает с ошибкой подключения к БД:

```yaml
database:
  waitFor:
    enabled: true
    host: postgres-postgresql
    port: 5432
```

### Проблемы с правами доступа к uploads

```bash
# Проверить владельца директории
kubectl exec -it deployment/tinode -- ls -la /opt/tinode/uploads

# Исправить права (если нужно)
kubectl exec -it deployment/tinode -- chown -R 1000:1000 /opt/tinode/uploads
```

### Не работает email верификация

Проверьте логи SMTP:

```bash
kubectl logs -l app.kubernetes.io/name=tinode | grep -i smtp
```

Для Gmail включите "Доступ для ненадежных приложений" или используйте App Password.

### Ingress не работает

```bash
# Проверить ingress controller
kubectl get pods -n ingress-nginx  # или -n kube-system для traefik

# Проверить ingress
kubectl describe ingress tinode

# Проверить сертификаты (если используется cert-manager)
kubectl get certificate
kubectl describe certificate tinode-tls
```

## Лицензия

Следует лицензии основного проекта Tinode.

## WebSocket и разработка на удаленной машине

### Включение WebSocket в Ingress

WebSocket поддержка уже включена в конфигурации Ingress (см. `templates/ingress.yaml`).

Traefik автоматически поддерживает WebSocket и долгоживущие соединения благодаря аннотациям:
```yaml
annotations:
  traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
  traefik.ingress.kubernetes.io/router.middlewares: "gzip@kubernetescrd"
```

### Локальная разработка webapp с удаленным Tinode

Если вы разрабатываете webapp локально и хотите подключиться к Tinode на VPS:

1. **Убедитесь, что DNS сконфигурирован**: `tinode.echo-messenger.ru` должен указывать на IP вашего VPS
2. **Запустите webapp локально** (например, на `localhost:3000`)
3. **Установите переменную окружения** `TINODE_HOST=tinode.echo-messenger.ru`
4. **Запустите webapp контейнер**:

```bash
export TINODE_HOST="tinode.echo-messenger.ru"
docker run -p 8080:80 \
  -e API_KEY="your-api-key" \
  -e TINODE_HOST="${TINODE_HOST}" \
  my-webapp:latest
```

Webapp автоматически подключится к удаленному Tinode через WebSocket.

### Отладка WebSocket

Если WebSocket соединение не работает:

```bash
# 1. Проверьте, что Ingress запущен и конфигурирован
kubectl get ingress tinode

# 2. Проверьте сервис
kubectl get svc tinode

# 3. Посмотрите логи Traefik
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik | grep -i websocket

# 4. Проверьте доступность из вашей машины
curl -i http://tinode.echo-messenger.ru/
```

В браузере откройте DevTools → Network tab и проверьте:
- Найдите WebSocket соединение к `tinode.echo-messenger.ru`
- Status должен быть `101 Switching Protocols`
- Если это TLS, используется `wss://`, если нет - `ws://`

## Поддержка

- [Tinode Documentation](https://github.com/tinode/chat)
- [Tinode API Docs](https://tinode.co/api.html)
