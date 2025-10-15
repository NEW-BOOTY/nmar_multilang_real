{{- define "nmar.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 -}}
{{- end -}}

{{- define "nmar.fullname" -}}
{{- printf "%s-%s" (include "nmar.name" .) .Release.Name | trunc 63 -}}
{{- end -}}
