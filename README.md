# Devops

Источник правды (Source of truth) для развёртывания приложений

## OpenBao
> Хранилище секретов

### Установка

```sh
# Go devops/charts/infra
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

**TODO**

## Strimzi

Управляет Kafka

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

**TODO**

## PostgreSQL для Tinode

### Установка
```sh
# Install PostgreSQL
helm install postgres ./postgres -n tinode --create-namespace

# Check PostgreSQL logs
kubectl logs postgres-0 -n tinode

# Check PostgreSQL functionality
kubectl exec -it -n tinode postgres-0 -- psql -U postgres -d postgres -c "\l"
```