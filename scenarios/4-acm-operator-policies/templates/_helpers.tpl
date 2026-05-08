{{/*
  Generates a Placement + PlacementBinding pair for an ACM policy stack.
  Expects a dict with:
    - name: stack identifier (used as cluster label key and resource name prefix)
  Convention: cluster label "<name>=enabled", policy "policy-<name>"
*/}}
{{- define "acm-policies.placement-and-binding" -}}
apiVersion: cluster.open-cluster-management.io/v1beta1
kind: Placement
metadata:
  name: {{ .name }}-placement
  namespace: acm-policies
spec:
  predicates:
    - requiredClusterSelector:
        labelSelector:
          matchLabels:
            {{ .name }}: "enabled"
---
apiVersion: policy.open-cluster-management.io/v1
kind: PlacementBinding
metadata:
  name: {{ .name }}-binding
  namespace: acm-policies
placementRef:
  name: {{ .name }}-placement
  kind: Placement
  apiGroup: cluster.open-cluster-management.io
subjects:
  - name: policy-{{ .name }}
    kind: Policy
    apiGroup: policy.open-cluster-management.io
{{- end -}}
