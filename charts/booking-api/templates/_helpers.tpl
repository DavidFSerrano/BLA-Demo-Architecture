{{- define "booking-api.name" -}}
{{- .Chart.Name -}}
{{- end -}}

{{- define "booking-api.selectorLabels" -}}
app: booking-api
app.kubernetes.io/name: {{ include "booking-api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "booking-api.labels" -}}
{{ include "booking-api.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
environment: {{ .Values.environment | default .Release.Namespace }}
{{- end -}}
