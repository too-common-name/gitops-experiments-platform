# gitops-experiments-platform

Platform repo for a set of GitOps demos on OpenShift. It contains the Argo CD configuration (AppProjects, ApplicationSets, placements) and the tenant definitions for a fictional ecommerce platform made of two microservices — **orders** (Helm) and **invoices** (Kustomize).

Each scenario is self-contained under `scenarios/` and has a matching bootstrap Application in `bootstrap/` that you apply once to kick things off.

## Prerequisites

All scenarios require **OpenShift GitOps** (Argo CD) installed on the cluster. Scenarios 2 and 4 also require **Advanced Cluster Management** on the hub.

The Argo CD controller needs cluster-admin to manage ACM resources (policies, placements) across namespaces:

```bash
oc adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller
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

Shows how to install OLM operators on managed clusters using ACM Governance Policies driven by cluster labels. This scenario is a Helm chart — label a cluster with `automation=enabled` and ACM takes care of installing Pipelines and AAP.

Per-cluster values live in `clusters/<name>/acm-policies-values.yaml`.

```bash
oc apply -f bootstrap/4-acm-operator-policies.yaml
```

## Tenants

The `tenants/` folder contains Kustomize overlays that set up namespaces, quotas, limits, network policies and role bindings for each environment. These are consumed by the tenant ApplicationSets in scenarios 1 and 2.

## Related repos

- [gitops-experiments-orders](https://github.com/too-common-name/gitops-experiments-orders) — Orders microservice (Helm)
- [gitops-experiments-invoices](https://github.com/too-common-name/gitops-experiments-invoices) — Invoices microservice (Kustomize)
