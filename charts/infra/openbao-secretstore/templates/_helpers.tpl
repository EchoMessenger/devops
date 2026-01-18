{{- define "openbao-secretstore.name" -}}
openbao-backend
{{- end }}

{{- define "openbao-secretstore.labels" -}}
app.kubernetes.io/name: openbao-secretstore
app.kubernetes.io/managed-by: Helm
{{- end }}
