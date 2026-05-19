# Hosted Control Plane Cluster Template

This directory contains a reusable template for provisioning OpenShift Hosted Control Plane (HCP) clusters on your environment.

## Quick Start

Provision a new cluster with a single command:

```bash
cd hcp-template
./provision-cluster.sh -n my-cluster
```

This will:
1. Auto-detect your environment's base domain
2. Create a new cluster configuration in `../clusters/my-cluster/`
3. Configure 2 worker nodes with 4 cores and 8GB RAM (default)

## Usage

### Basic Provisioning

```bash
./provision-cluster.sh -n CLUSTER_NAME
```

### Advanced Options

```bash
./provision-cluster.sh -n CLUSTER_NAME [-d BASE_DOMAIN] [-r REPLICAS] [-c CORES] [-m MEMORY]

Options:
  -n CLUSTER_NAME    Name of the cluster (required)
                     Must be lowercase alphanumeric with hyphens only
                     Examples: dev-hcp, prod-hcp, test-cluster

  -d BASE_DOMAIN     Base domain for the cluster (optional)
                     If not provided, auto-detected from hub cluster
                     Example: apps.cluster-q2pfv.dynamic2.redhatworkshops.io

  -r REPLICAS        Number of worker nodes (default: 2)
                     Example: -r 3

  -c CORES           CPU cores per worker node (default: 4)
                     Minimum: 2 cores
                     Example: -c 8

  -m MEMORY          Memory per worker in Gi (default: 8)
                     Minimum: 8Gi
                     Example: -m 16

  -h                 Show help message
```

### Examples

**Development cluster with minimal resources:**
```bash
./provision-cluster.sh -n dev-hcp -r 2 -c 4 -m 8
```

**Production cluster with more capacity:**
```bash
./provision-cluster.sh -n prod-hcp -r 5 -c 8 -m 16
```

**Specify custom domain:**
```bash
./provision-cluster.sh -n test-hcp -d apps.cluster-xxxxx.dynamic2.redhatworkshops.io
```

## Post-Provisioning Steps

After running `provision-cluster.sh`, follow these steps:

### 1. Seal Secrets

Navigate to your cluster directory and seal the secrets:

```bash
cd ../clusters/CLUSTER_NAME

# Download your pull secret from Red Hat Console
# https://console.redhat.com/openshift/install/pull-secret
# Save it as pull-secret.txt in the cluster directory

# Run the seal-secrets script
./scripts/seal-secrets.sh
```

### 2. Commit to Git (Optional for GitOps)

If using ArgoCD for GitOps deployment:

```bash
git add .
git commit -m "Add CLUSTER_NAME configuration"
git push
```

### 3. Deploy the Cluster

**Option A: Using ArgoCD (GitOps - Recommended)**

```bash
oc apply -f argocd/application.yaml
```

ArgoCD will automatically sync from Git and deploy the cluster.

**Option B: Manual Deployment with Kustomize**

```bash
oc apply -k .
```

### 4. Monitor Deployment

Watch the cluster provisioning:

```bash
# Watch HostedCluster status
oc get hostedcluster CLUSTER_NAME -n clusters -w

# Watch NodePool status
oc get nodepool CLUSTER_NAME-workers -n clusters -w

# Check control plane pods
oc get pods -n clusters-CLUSTER_NAME

# Get kubeconfig (after cluster is ready)
oc extract secret/CLUSTER_NAME-admin-kubeconfig -n clusters --to=-
```

## Directory Structure

After provisioning, your cluster directory will contain:

```
clusters/CLUSTER_NAME/
├── base/
│   ├── namespace.yaml
│   ├── hostedcluster.yaml
│   ├── nodepool.yaml
│   ├── pull-secret-sealed.yaml      # Created by seal-secrets.sh
│   ├── ssh-key-sealed.yaml          # Created by seal-secrets.sh
│   └── kustomization.yaml
│
├── overlays/
│   └── production/
│       ├── hostedcluster-patch.yaml
│       └── kustomization.yaml
│
├── argocd/
│   └── application.yaml
│
├── scripts/
│   └── seal-secrets.sh
│
├── kustomization.yaml
└── pull-secret.txt                   # You provide this (not committed)
```

## Cluster Naming Convention

Cluster names must follow these rules:
- Lowercase letters (a-z)
- Numbers (0-9)
- Hyphens (-) only
- No spaces or special characters

**Good examples:**
- `dev-hcp`
- `prod-cluster-01`
- `test-env`

**Bad examples:**
- `Dev_HCP` (uppercase and underscore)
- `prod cluster` (space)
- `test@env` (special character)

## Customizing the Template

To customize the template for your environment:

1. **Edit base files** in `hcp-template/base/` to change defaults
2. **Update provision-cluster.sh** to add new parameters or logic
3. **Modify overlays** to add environment-specific configurations

## Deleting a Cluster

To remove a provisioned cluster:

```bash
# Delete the ArgoCD application (if using GitOps)
oc delete application CLUSTER_NAME-hosted-cluster -n openshift-gitops

# Delete the cluster resources
oc delete hostedcluster CLUSTER_NAME -n clusters
oc delete nodepool CLUSTER_NAME-workers -n clusters

# Remove finalizers if stuck
oc patch hostedcluster CLUSTER_NAME -n clusters --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]'

# Remove the cluster directory
rm -rf ../clusters/CLUSTER_NAME
```

## Troubleshooting

**Issue: Auto-detection of base domain fails**
```bash
# Manually specify the domain
./provision-cluster.sh -n my-cluster -d apps.cluster-xxxxx.dynamic2.redhatworkshops.io
```

**Issue: Sealed secrets controller not found**
```bash
# Install Sealed Secrets controller
oc apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.36.6/controller.yaml
```

**Issue: Cluster provisioning stuck**
```bash
# Check HostedCluster status
oc get hostedcluster CLUSTER_NAME -n clusters -o yaml

# Check control plane pods
oc get pods -n clusters-CLUSTER_NAME

# Check events
oc get events -n clusters-CLUSTER_NAME --sort-by='.lastTimestamp'
```

## Prerequisites

- ACM 2.10+ (tested with 2.16) installed on hub cluster
- MultiCluster Engine (MCE) 2.5+ (tested with 2.11)
- OpenShift Virtualization operator installed
- OpenShift GitOps operator installed (if using ArgoCD)
- Sealed Secrets controller installed
- Storage classes available:
  - `lvms-vg1` for etcd
  - `ocs-external-storagecluster-ceph-rbd` for root volumes

## Resources

- [Deploy HCP with OpenShift Virtualization](https://developers.redhat.com/articles/2026/04/20/deploy-hosted-control-planes-openshift-virtualization)
- [Using GitOps to Deploy HCP Clusters](https://www.redhat.com/en/blog/using-gitops-to-deploy-bare-metal-openshift-hosted-control-plane-clusters)
- [ACM GitOps Integration](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.9/html-single/gitops/index)
