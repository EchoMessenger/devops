/ $ bao policy read eso-policy
# ghcr
path "secret/data/registry/ghcr/*" {
  capabilities = ["read"]
}
path "secret/metadata/registry/ghcr/*" {
  capabilities = ["read"]
}

# router
path "secret/data/router/*" {
  capabilities = ["read"]
}
path "secret/metadata/router/*" {
  capabilities = ["read"]
}

# kafka
path "secret/data/kafka/*" {
  capabilities = ["read"]
}
path "secret/metadata/kafka/*" {
  capabilities = ["read"]
}