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
ClickHouse HTTP URL для внутрикластерного DNS
Использует fullname и service.httpPort из values
*/}}
{{- define "clickhouse.httpUrl" -}}
http://{{ include "clickhouse.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local:{{ .Values.service.httpPort }}
{{- end -}}

{{/*
ClickHouse TCP URL
*/}}
{{- define "clickhouse.tcpUrl" -}}
{{ include "clickhouse.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local:{{ .Values.service.tcpPort }}
{{- end -}}

{{/*
ClickHouse native URL with credentials
*/}}
{{- define "clickhouse.nativeUrl" -}}
{{- $root := .root -}}
clickhouse://{{ .username }}:{{ .password }}@{{ include "clickhouse.fullname" $root }}.{{ $root.Release.Namespace }}.svc.cluster.local:{{ $root.Values.service.tcpPort }}/{{ $root.Values.clickhouse.defaultDatabase }}
{{- end -}}

{{/*
ClickHouse JDBC URL
*/}}
{{- define "clickhouse.jdbcUrl" -}}
jdbc:clickhouse://{{ include "clickhouse.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local:{{ .Values.service.httpPort }}/{{ .Values.clickhouse.defaultDatabase }}
{{- end -}}

{{/*
Stable secret value: prefer explicit value, then reuse an existing Secret, then fall back to random on first install.
*/}}
{{- define "clickhouse.secretValue" -}}
{{- $root := .root -}}
{{- $explicit := .value | default "" -}}
{{- if ne $explicit "" -}}
{{- $explicit -}}
{{- else -}}
{{- $existingSecret := lookup "v1" "Secret" $root.Release.Namespace .secretName -}}
{{- if $existingSecret -}}
{{- index $existingSecret.data .secretKey | b64dec -}}
{{- else -}}
{{- randAlphaNum (.length | default 24) -}}
{{- end -}}
{{- end -}}
{{- end -}}
