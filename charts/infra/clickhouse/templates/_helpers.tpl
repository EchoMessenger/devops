{{/*
Expand the name of the chart.
*/}}
{{- define "clickhouse.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "clickhouse.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "clickhouse.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "clickhouse.labels" -}}
helm.sh/chart: {{ include "clickhouse.chart" . }}
{{ include "clickhouse.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "clickhouse.selectorLabels" -}}
app.kubernetes.io/name: {{ include "clickhouse.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Generate random password
*/}}
{{- define "clickhouse.generatePassword" -}}
{{- randAlphaNum 24 }}
{{- end }}

{{/*
Get or generate default password
*/}}
{{- define "clickhouse.defaultPassword" -}}
{{- if .Values.clickhouse.defaultPassword }}
{{- .Values.clickhouse.defaultPassword }}
{{- else }}
{{- include "clickhouse.generatePassword" . }}
{{- end }}
{{- end }}

{{/*
Credentials secret name
*/}}
{{- define "clickhouse.credentialsSecretName" -}}
{{- if .Values.externalSecret.enabled }}
{{- include "clickhouse.fullname" . }}-external-credentials
{{- else }}
{{- include "clickhouse.fullname" . }}-credentials
{{- end }}
{{- end }}

{{/*
Generate SHA256 password hash for ClickHouse
*/}}
{{- define "clickhouse.passwordSHA256" -}}
{{- . | sha256sum }}
{{- end }}

{{/*
Generate connection URL
*/}}
{{- define "clickhouse.connectionUrl" -}}
{{- $fullname := include "clickhouse.fullname" . -}}
{{- $user := .Values.clickhouse.defaultUser -}}
{{- $password := include "clickhouse.defaultPassword" . -}}
{{- $port := .Values.service.httpPort -}}
{{- $database := .Values.clickhouse.defaultDatabase -}}
clickhouse://{{ $user }}:{{ $password }}@{{ $fullname }}:{{ $port }}/{{ $database }}
{{- end }}

{{/*
Generate native protocol connection URL
*/}}
{{- define "clickhouse.nativeUrl" -}}
{{- $fullname := include "clickhouse.fullname" . -}}
{{- $user := .Values.clickhouse.defaultUser -}}
{{- $password := include "clickhouse.defaultPassword" . -}}
{{- $port := .Values.service.tcpPort -}}
{{- $database := .Values.clickhouse.defaultDatabase -}}
clickhouse://{{ $user }}:{{ $password }}@{{ $fullname }}:{{ $port }}/{{ $database }}?secure=false
{{- end }}