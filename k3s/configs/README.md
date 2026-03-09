nikita@echo:~/devops$ sudo ls -la /etc/rancher/k3s/
total 24
drwxr-xr-x 2 root root       4096 Mar  8 23:33 .
drwxr-xr-x 4 root root       4096 Nov 22 18:04 ..
-rw-r--r-- 1 root root       1910 Mar  8 21:17 audit-policy.yaml
-rw-r--r-- 1 root root       1322 Mar  8 23:33 config.yaml
-rw------- 1 root root        271 Mar  8 23:29 encryption-config.yaml
-rw-r----- 1 root k3s-admins 2969 Mar  8 23:33 k3s.yaml

# Encryption config

```sh
# Генерируем 32-байтный ключ
KEY=$(head -c 32 /dev/urandom | base64)

# Создаём конфиг шифрования
sudo tee /etc/rancher/k3s/encryption-config.yaml << EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${KEY}
      - identity: {}
EOF

# Права только для root
sudo chmod 600 /etc/rancher/k3s/encryption-config.yaml
sudo ls -la /etc/rancher/k3s/encryption-config.yaml
```