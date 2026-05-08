# gitops-experiments-platform

Platform repo for a set of GitOps demos on OpenShift. It contains the Argo CD configuration (AppProjects, ApplicationSets, placements) and the tenant definitions for a fictional ecommerce platform made of two microservices — **orders** (Helm) and **invoices** (Kustomize).

Each scenario is self-contained under `scenarios/` and has a matching bootstrap Application in `bootstrap/` that you apply once to kick things off.

## Prerequisites

All scenarios require **OpenShift GitOps** (Argo CD) installed on the cluster. Scenarios 2, 4 and 5 also require **Advanced Cluster Management** on the hub.

The Argo CD controller needs permissions to manage ACM resources (policies, placements, clusterset bindings). Apply the least-privilege RBAC:

```bash
oc apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argocd-acm-policies
rules:
  - apiGroups: [cluster.open-cluster-management.io]
    resources: [managedclustersetbindings]
    verbs: [create, delete, get, list, patch, update, watch]
  - apiGroups: [cluster.open-cluster-management.io]
    resources: [managedclustersets/bind]
    verbs: [create]
  - apiGroups: [cluster.open-cluster-management.io]
    resources: [placements, placementdecisions]
    verbs: [create, delete, get, list, patch, update, watch]
  - apiGroups: [policy.open-cluster-management.io]
    resources: [policies, placementbindings]
    verbs: [create, delete, get, list, patch, update, watch]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argocd-acm-policies
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argocd-acm-policies
subjects:
  - kind: ServiceAccount
    name: openshift-gitops-argocd-application-controller
    namespace: openshift-gitops
EOF
```

Your user needs admin access in the Argo CD UI. If using the embedded OAuth server:

```bash
oc adm groups add-users cluster-admins $(oc whoami)
```

If using an external IdP (e.g. Keycloak) where OpenShift groups are not available, map your user or group directly in the ArgoCD RBAC:

```bash
oc patch argocd openshift-gitops -n openshift-gitops --type merge -p '
spec:
  rbac:
    policy: |
      g, <your-user-or-group>, role:admin
    defaultPolicy: role:readonly
'
```

## Scenarios

### 1 — Single cluster

All environments (qa, stage, prod) deployed on the same cluster via ApplicationSets with a simple list generator. Good starting point to show how Argo CD projects, RBAC and sync policies work.

```bash
oc apply -f bootstrap/1-single-cluster.yaml
```

### 2 — Multi-cluster with ACM

Same workloads but spread across clusters managed by ACM. Uses ACM Placements and the `clusterDecisionResource` generator so that Argo CD automatically targets clusters labeled `environment=nonprod` or `environment=prod`.

Each microservice has its own Git repo, AppProject and ApplicationSet pair, reflecting a setup where independent teams own their service lifecycle and need isolated RBAC and release cycles.

The scenario includes the integration resources that wire ACM and Argo CD together (GitOpsCluster, ManagedClusterSetBinding, Placement).

```bash
oc apply -f bootstrap/2-multi-cluster-acm.yaml
```

### 3 — PR environments

Spins up a temporary environment for every pull request on the orders repo whose branch ends in `-argocd`. Uses the `pullRequest` generator. The namespace and Application are cleaned up automatically when the PR is merged or closed.

```bash
oc apply -f bootstrap/3-pr-environments.yaml
```

### 4 — ACM operator policies

Installs OLM operators on managed clusters using ACM Governance Policies driven by fine-grained cluster labels. Each operator has its own label-based Placement, so you can enable them independently:

- `pipelines=enabled` — installs OpenShift Pipelines
- `servicemesh=enabled` — installs OpenShift Service Mesh 3 (Sail operator) + deploys Istio control plane (`Istio` + `IstioCNI` CRs)

Default values live in `scenarios/4-acm-operator-policies/values.yaml`.

```bash
oc apply -f bootstrap/4-acm-operator-policies.yaml

# Then label managed clusters to trigger installation:
oc label managedcluster <cluster-name> servicemesh=enabled
oc label managedcluster <cluster-name> pipelines=enabled
```

### 5 — ACM + Helm from Quay (OCI)

Deploys the Istio Bookinfo application across managed clusters using a Helm chart pulled from a Quay OCI registry. Same structure as scenario 2 (Placements, AppProject, ApplicationSets with `clusterDecisionResource`) but the ApplicationSet source is an OCI Helm chart instead of a Git repo.

Unlike scenario 2 (one ApplicationSet per service), here a single Helm chart packages the entire application and a single ApplicationSet per placement distributes it — suited for cohesive applications released as a unit.

The Quay OCI repo must be registered in Argo CD as a Helm repository. See the [bookinfo chart repo](https://github.com/too-common-name/gitops-experiments-bookinfo) for build/push instructions.

Pairs well with scenario 4 to also install the Service Mesh operator on target clusters via ACM policies.

```bash
oc apply -f bootstrap/5-acm-helm-quay.yaml
```

## Tenants

The `tenants/` folder contains Kustomize overlays that set up namespaces, quotas, limits, network policies and role bindings for each environment. These are consumed by the tenant ApplicationSets in scenarios 1 and 2.

## Related repos

- [gitops-experiments-orders](https://github.com/too-common-name/gitops-experiments-orders) — Orders microservice (Helm)
- [gitops-experiments-invoices](https://github.com/too-common-name/gitops-experiments-invoices) — Invoices microservice (Kustomize)
- [gitops-experiments-bookinfo](https://github.com/too-common-name/gitops-experiments-bookinfo) — Istio Bookinfo (Helm, OCI/Quay)
