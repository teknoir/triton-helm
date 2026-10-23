{{/*
imagePullPolicy of a model init container.
Order: model.imagePullPolicy > .Values.modelImagePullPolicy > auto
(IfNotPresent for immutable ":sha-<hex>" / "@sha256:" refs, Always otherwise).
Call with: include "triton.modelPullPolicy" (dict "root" $ "model" .)
*/}}
{{- define "triton.modelPullPolicy" -}}
{{- if .model.imagePullPolicy -}}
{{- .model.imagePullPolicy -}}
{{- else if .root.Values.modelImagePullPolicy -}}
{{- .root.Values.modelImagePullPolicy -}}
{{- else if regexMatch "(:sha-[0-9a-f]{7,}|@sha256:[0-9a-f]{64})$" (toString .model.image) -}}
IfNotPresent
{{- else -}}
Always
{{- end -}}
{{- end -}}
