#!/usr/bin/env bash
set -euo pipefail

OPENBAO_NAMESPACE="${OPENBAO_NAMESPACE:-openbao}"
KEYS_FILE="${KEYS_FILE:-openbao-keys.json}"

echo "=== OpenBao Initialization Script ==="

# Найти под
POD_NAME=$(kubectl get pod -n "${OPENBAO_NAMESPACE}" \
  -l app.kubernetes.io/name=openbao \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

if [ -z "${POD_NAME}" ]; then
  echo "ERROR: OpenBao pod not found in namespace ${OPENBAO_NAMESPACE}"
  exit 1
fi

echo "Using pod: ${POD_NAME}"

# Проверить статус
INITIALIZED=$(kubectl exec -n "${OPENBAO_NAMESPACE}" "${POD_NAME}" -- bao status -format=json 2>/dev/null | jq -r '.initialized' || echo "false")
SEALED=$(kubectl exec -n "${OPENBAO_NAMESPACE}" "${POD_NAME}" -- bao status -format=json 2>/dev/null | jq -r '.sealed' || echo "true")

echo "Initialized: ${INITIALIZED}, Sealed: ${SEALED}"

# Шаг 1: Инициализация
if [ "${INITIALIZED}" = "false" ]; then
  echo "=== Initializing OpenBao ==="
  kubectl exec -n "${OPENBAO_NAMESPACE}" "${POD_NAME}" -- \
    bao operator init -key-shares=1 -key-threshold=1 -format=json > "${KEYS_FILE}"
  
  echo "Keys saved to ${KEYS_FILE}"
  echo "!!! SAVE THIS FILE SECURELY AND DELETE FROM DISK !!!"
  
  UNSEAL_KEY=$(jq -r '.unseal_keys_b64[0]' "${KEYS_FILE}")
  ROOT_TOKEN=$(jq -r '.root_token' "${KEYS_FILE}")
else
  echo "OpenBao already initialized"
  
  if [ ! -f "${KEYS_FILE}" ]; then
    echo "ERROR: ${KEYS_FILE} not found. Provide UNSEAL_KEY and ROOT_TOKEN manually."
    echo "export UNSEAL_KEY=xxx"
    echo "export ROOT_TOKEN=xxx"
    exit 1
  fi
  
  UNSEAL_KEY=$(jq -r '.unseal_keys_b64[0]' "${KEYS_FILE}")
  ROOT_TOKEN=$(jq -r '.root_token' "${KEYS_FILE}")
fi

# Шаг 2: Unseal
if [ "${SEALED}" = "true" ]; then
  echo "=== Unsealing OpenBao ==="
  kubectl exec -n "${OPENBAO_NAMESPACE}" "${POD_NAME}" -- \
    bao operator unseal "${UNSEAL_KEY}"
fi

# Проверить что unsealed
sleep 2
SEALED=$(kubectl exec -n "${OPENBAO_NAMESPACE}" "${POD_NAME}" -- bao status -format=json | jq -r '.sealed')
if [ "${SEALED}" = "true" ]; then
  echo "ERROR: Failed to unseal"
  exit 1
fi

echo "=== OpenBao is unsealed ==="

# Шаг 3: Конфигурация
echo "=== Configuring OpenBao ==="

kubectl exec -n "${OPENBAO_NAMESPACE}" "${POD_NAME}" -- sh -c "
  export BAO_ADDR='http://127.0.0.1:8200'
  bao login ${ROOT_TOKEN}

  # Enable KV v2
  bao secrets enable -path=secret kv-v2 2>/dev/null || echo 'KV v2 already enabled'

  # Enable Kubernetes auth
  bao auth enable kubernetes 2>/dev/null || echo 'Kubernetes auth already enabled'

  # Configure Kubernetes auth
  bao write auth/kubernetes/config \\
    kubernetes_host=\"https://kubernetes.default.svc:443\" \\
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

  # Create kafka policy
  bao policy write kafka-policy - <<'EOF'
path \"secret/data/kafka/*\" {
  capabilities = [\"read\", \"list\"]
}
path \"secret/metadata/kafka/*\" {
  capabilities = [\"read\", \"list\"]
}
EOF

  # Create kafka role
  bao write auth/kubernetes/role/kafka \\
    bound_service_account_names=kafka-sa \\
    bound_service_account_namespaces=kafka \\
    policies=kafka-policy \\
    ttl=1h

  echo '=== Verification ==='
  bao auth list
  bao policy list
  bao list auth/kubernetes/role
"

echo "=== Configuration complete ==="
echo ""
echo "Root token: ${ROOT_TOKEN}"
echo "Now run: ./scripts/create-secrets.sh"