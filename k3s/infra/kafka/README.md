# kafka-infisical Helm chart

This chart deploys Strimzi CRs (provided by you in files/) and creates ExternalSecrets that fetch
secrets from Infisical via External Secrets Operator.


## Quickstart
1. Install External Secrets Operator in your cluster and create a SecretStore configured to talk to Infisical.
2. Copy your local uploaded CRs into `files/` as described in `files/README.md`.
3. Configure `values.yaml` (Infisical credentials or credentials secret name and paths).
4. Run: `helm install kafka-infisical ./kafka-infisical -n kafka --create-namespace`


--- file: example-deploy-instructions.txt ---
Optional: if you want the chart packager to automatically include the uploaded files, run these commands
on the packager/CI runner (where /mnt/data is reachable):


mkdir -p kafka-infisical/files
cp /mnt/data/strimzi-kraft-nodepools.yaml kafka-infisical/files/strimzi-kraft-nodepools.yaml
cp /mnt/data/topics.yaml kafka-infisical/files/topics.yaml
cp /mnt/data/user.yaml kafka-infisical/files/user.yaml
helm package kafka-infisical