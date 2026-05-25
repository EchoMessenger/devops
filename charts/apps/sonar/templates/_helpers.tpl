{{- define "sonar.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "sonar.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "sonar.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{ include "sonar.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "sonar.selectorLabels" -}}
app.kubernetes.io/name: {{ include "sonar.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "sonar.postgresqlName" -}}
{{- default "sonarqube-postgres" .Values.postgres.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
