{{- define "keycloak.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "keycloak.labels" -}}
app.kubernetes.io/name: keycloak
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}
