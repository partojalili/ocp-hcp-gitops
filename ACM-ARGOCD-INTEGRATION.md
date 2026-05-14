# ACM + ArgoCD Integration Guide

## Overview

This guide explains how to integrate **Advanced Cluster Management (ACM)** with **ArgoCD** to manage policies, placements, and cluster configurations using GitOps.

## Architecture

```
GitHub Repository
    ↓
ArgoCD (Hub Cluster)
    ↓
ACM Policies (Hub Cluster)
    ↓
Managed Clusters (via ACM)
```

**Benefits:**
- GitOps workflow for ACM policies
- Version control for cluster configurations
- Automated policy enforcement
- Easier collaboration and review process

---

## Prerequisites

1. OpenShift cluster with cluster-admin access
2. Advanced Cluster Management operator installed
3. OpenShift GitOps operator installed

---

## Step 1: Install Operators

### Install OpenShift GitOps Operator

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-gitops-operator
  namespace: openshift-operators
spec:
  channel: latest
  name: openshift-gitops-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
```

Apply:
```bash
oc apply -f openshift-gitops-subscription.yaml
```

### Install ACM Operator

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: open-cluster-management
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: open-cluster-management
  namespace: open-cluster-management
spec:
  targetNamespaces:
  - open-cluster-management
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: advanced-cluster-management
  namespace: open-cluster-management
spec:
  channel: release-2.14
  name: advanced-cluster-management
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
```

Apply:
```bash
oc apply -f acm-subscription.yaml
```

### Create MultiClusterHub

```yaml
apiVersion: operator.open-cluster-management.io/v1
kind: MultiClusterHub
metadata:
  name: multiclusterhub
  namespace: open-cluster-management
spec: {}
```

Apply:
```bash
oc apply -f multiclusterhub.yaml
```

---

## Step 2: Grant ArgoCD Permissions to Manage ACM Resources

Create a ClusterRole for ACM policy management:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argocd-acm-policy-manager
rules:
  # ACM Policies
  - apiGroups:
      - policy.open-cluster-management.io
    resources:
      - policies
      - placementbindings
    verbs:
      - create
      - delete
      - get
      - list
      - patch
      - update
      - watch
  
  # ACM Placements
  - apiGroups:
      - cluster.open-cluster-management.io
    resources:
      - placements
      - placementdecisions
      - managedclustersetbindings
    verbs:
      - create
      - delete
      - get
      - list
      - patch
      - update
      - watch
```

Bind to ArgoCD service account:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argocd-acm-policy-manager
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argocd-acm-policy-manager
subjects:
  - kind: ServiceAccount
    name: openshift-gitops-argocd-application-controller
    namespace: openshift-gitops
```

Apply:
```bash
oc apply -f argocd-acm-rbac.yaml
```

---

## Step 3: Configure ArgoCD to Ignore ACM Status Fields

ACM policies have status fields that ArgoCD shouldn't manage. Configure ArgoCD to ignore them:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: acm-policies
  namespace: openshift-gitops
spec:
  destination:
    namespace: open-cluster-management-policies
    server: https://kubernetes.default.svc
  
  # Important: Ignore status fields
  ignoreDifferences:
    - group: policy.open-cluster-management.io
      jsonPointers:
        - /status
      kind: Policy
    - group: cluster.open-cluster-management.io
      jsonPointers:
        - /status
      kind: Placement
    - group: policy.open-cluster-management.io
      jsonPointers:
        - /status
      kind: PlacementBinding
  
  project: default
  
  source:
    path: policies/webserver-app
    repoURL: https://github.com/YOUR-ORG/YOUR-REPO.git
    targetRevision: main
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    retry:
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
      limit: 5
    syncOptions:
      - CreateNamespace=true
```

---

## Step 4: Structure Your Git Repository

### Recommended Directory Structure

```
your-gitops-repo/
├── policies/
│   ├── webserver-app/
│   │   ├── webserver-policy.yaml      # ACM Policy
│   │   ├── placement.yaml              # Placement
│   │   └── placementbinding.yaml      # PlacementBinding
│   ├── network-policies/
│   │   ├── deny-all-policy.yaml
│   │   ├── placement.yaml
│   │   └── placementbinding.yaml
│   └── compliance/
│       └── ...
├── argocd-apps/
│   ├── acm-webserver-app.yaml         # ArgoCD Application
│   └── acm-network-policy.yaml
└── README.md
```

### Example ACM Policy

`policies/webserver-app/webserver-policy.yaml`:

```yaml
apiVersion: policy.open-cluster-management.io/v1
kind: Policy
metadata:
  name: policy-webserver-app
  namespace: open-cluster-management-policies
  annotations:
    policy.open-cluster-management.io/standards: NIST SP 800-53
    policy.open-cluster-management.io/categories: CM Configuration Management
    policy.open-cluster-management.io/controls: CM-2 Baseline Configuration
spec:
  remediationAction: enforce
  disabled: false
  policy-templates:
    - objectDefinition:
        apiVersion: policy.open-cluster-management.io/v1
        kind: ConfigurationPolicy
        metadata:
          name: policy-webserver-deployment
        spec:
          remediationAction: enforce
          severity: low
          namespaceSelector:
            include:
              - webserver-prod
          object-templates:
            - complianceType: mustonlyhave
              objectDefinition:
                apiVersion: apps/v1
                kind: Deployment
                metadata:
                  name: webserver
                  namespace: webserver-prod
                # ... deployment spec
```

### Example Placement

`policies/webserver-app/placement.yaml`:

```yaml
apiVersion: cluster.open-cluster-management.io/v1beta1
kind: Placement
metadata:
  name: placement-webserver-app
  namespace: open-cluster-management-policies
spec:
  predicates:
    - requiredClusterSelector:
        labelSelector:
          matchExpressions:
            - key: environment
              operator: In
              values:
                - production
```

### Example PlacementBinding

`policies/webserver-app/placementbinding.yaml`:

```yaml
apiVersion: policy.open-cluster-management.io/v1
kind: PlacementBinding
metadata:
  name: binding-policy-webserver-app
  namespace: open-cluster-management-policies
placementRef:
  apiGroup: cluster.open-cluster-management.io
  kind: Placement
  name: placement-webserver-app
subjects:
  - apiGroup: policy.open-cluster-management.io
    kind: Policy
    name: policy-webserver-app
```

### Example ArgoCD Application

`argocd-apps/acm-webserver-app.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: acm-webserver-app
  namespace: openshift-gitops
spec:
  destination:
    namespace: open-cluster-management-policies
    server: https://kubernetes.default.svc
  
  ignoreDifferences:
    - group: policy.open-cluster-management.io
      jsonPointers:
        - /status
      kind: Policy
  
  project: default
  
  source:
    path: policies/webserver-app
    repoURL: https://github.com/partojalili/ocp-hcp-gitops.git
    targetRevision: main
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    retry:
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
    syncOptions:
      - CreateNamespace=true
```

---

## Step 5: Deploy ArgoCD Applications

### Option 1: Apply Directly

```bash
oc apply -f argocd-apps/acm-webserver-app.yaml
```

### Option 2: Use ApplicationSet (Recommended for Multiple Apps)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: acm-policies
  namespace: openshift-gitops
spec:
  generators:
    - git:
        repoURL: https://github.com/partojalili/ocp-hcp-gitops.git
        revision: main
        directories:
          - path: policies/*
  
  template:
    metadata:
      name: 'acm-{{path.basename}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/partojalili/ocp-hcp-gitops.git
        targetRevision: main
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: open-cluster-management-policies
      ignoreDifferences:
        - group: policy.open-cluster-management.io
          jsonPointers:
            - /status
          kind: Policy
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

---

## Step 6: Verify Integration

### Check ArgoCD Applications

```bash
oc get applications -n openshift-gitops
```

Expected output:
```
NAME                          SYNC STATUS   HEALTH STATUS
acm-webserver-app             Synced        Healthy
```

### Check ACM Policies

```bash
oc get policies -n open-cluster-management-policies
```

Expected output:
```
NAME                      REMEDIATION ACTION   COMPLIANCE STATE   AGE
policy-webserver-app      enforce              Compliant          5m
```

### Check Policy Status on Managed Cluster

```bash
oc get policy policy-webserver-app -n open-cluster-management-policies -o yaml | grep -A 10 "status:"
```

---

## Workflow: Making Changes

### 1. Edit Policy in Git

```bash
# Clone repo
git clone https://github.com/partojalili/ocp-hcp-gitops.git
cd ocp-hcp-gitops

# Edit policy
vim policies/webserver-app/webserver-policy.yaml

# Commit and push
git add policies/webserver-app/webserver-policy.yaml
git commit -m "Update webserver deployment replicas"
git push
```

### 2. ArgoCD Auto-Sync

ArgoCD automatically detects changes and syncs (~3 minutes).

Check sync status:
```bash
oc get applications acm-webserver-app -n openshift-gitops -o jsonpath='{.status.sync.status}'
```

### 3. ACM Enforces Policy

ACM detects policy changes and enforces on managed clusters (~1 minute).

Check compliance:
```bash
oc get policy policy-webserver-app -n open-cluster-management-policies
```

### 4. Verify on Managed Cluster

```bash
# Switch to managed cluster
oc login <managed-cluster-api>

# Check resources
oc get deployment webserver -n webserver-prod
```

---

## Best Practices

### 1. Use `mustonlyhave` for Resources That Should Update

```yaml
complianceType: mustonlyhave  # Forces exact match, updates resources
```

Instead of:
```yaml
complianceType: musthave      # Only checks existence, doesn't update
```

### 2. Avoid `subPath` in ConfigMap Mounts

ConfigMaps with `subPath` don't update on pod restart. Mount the entire directory:

```yaml
volumeMounts:
  - mountPath: /var/www/html
    name: application-content
```

Instead of:
```yaml
volumeMounts:
  - mountPath: /var/www/html/application.html
    name: application-content
    subPath: application.html
```

### 3. Use Annotations to Trigger Restarts

Add a version annotation to force deployment restarts when ConfigMaps change:

```yaml
spec:
  template:
    metadata:
      annotations:
        config-version: "1"  # Increment when changing ConfigMap
```

### 4. Structure Policies by Purpose

```
policies/
├── security/          # Security policies
├── compliance/        # Compliance policies
├── applications/      # Application deployments
└── infrastructure/    # Infrastructure configs
```

### 5. Use Separate ArgoCD Applications

Create one ArgoCD Application per policy directory for better isolation and control.

### 6. Enable Auto-Sync with Caution

For production:
```yaml
syncPolicy:
  automated:
    prune: false      # Don't auto-delete
    selfHeal: false   # Manual intervention required
```

For dev/test:
```yaml
syncPolicy:
  automated:
    prune: true       # Auto-delete removed resources
    selfHeal: true    # Auto-fix drift
```

---

## Troubleshooting

### ArgoCD Not Syncing

```bash
# Force refresh
oc annotate application acm-webserver-app -n openshift-gitops \\
  argocd.argoproj.io/refresh=normal --overwrite

# Check sync status
oc get application acm-webserver-app -n openshift-gitops -o yaml | grep -A 20 "status:"
```

### ACM Policy Not Compliant

```bash
# Check policy details
oc describe policy policy-webserver-app -n open-cluster-management-policies

# Check on managed cluster
oc get configurationpolicy -n <managed-cluster-namespace>
```

### Permission Issues

```bash
# Verify ArgoCD has proper permissions
oc describe clusterrolebinding argocd-acm-policy-manager

# Check ArgoCD service account
oc get sa openshift-gitops-argocd-application-controller -n openshift-gitops
```

---

## Summary

✅ **What You Get:**
- GitOps workflow for ACM policies
- Automated policy enforcement
- Version control and audit trail
- Easy rollback capabilities
- Collaborative policy management

✅ **Key Components:**
1. OpenShift GitOps (ArgoCD)
2. Advanced Cluster Management (ACM)
3. Git repository with policies
4. RBAC permissions for ArgoCD
5. ArgoCD Applications pointing to Git

✅ **Workflow:**
```
Edit Policy in Git → Commit & Push → ArgoCD Syncs → ACM Enforces → Applied on Clusters
```

---

## Additional Resources

- [ACM Documentation](https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes)
- [OpenShift GitOps Documentation](https://docs.openshift.com/gitops/latest/understanding_openshift_gitops/about-redhat-openshift-gitops.html)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
