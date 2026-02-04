{{/*
Expand the name of the chart.
*/}}
{{- define "openbao-config.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "openbao-config.fullname" -}}
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

{{/*
OpenBao server address
*/}}
{{- define "openbao-config.serverAddr" -}}
{{- if .Values.openbaoServerAddr }}
{{- .Values.openbaoServerAddr }}
{{- else }}
http://openbao.openbao.svc.cluster.local:8200
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "openbao-config.labels" -}}
helm.sh/chart: {{ include "openbao-config.name" . }}
app.kubernetes.io/name: {{ include "openbao-config.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}