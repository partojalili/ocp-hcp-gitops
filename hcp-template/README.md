# Hosted Control Plane Cluster Template

This directory contains a reusable template for provisioning OpenShift Hosted Control Plane (HCP) clusters on your environment.

## Quick Start

**IMPORTANT:** The `provision-cluster.sh` script creates the cluster **configuration files only**. The actual cluster deployment happens in Step 4 below.

### Complete Workflow (Using ArgoCD)

```bash
# Step 1: Create cluster configuration directory
cd hcp-template
./provision-cluster.sh -n my-cluster

# Step 2: Seal secrets (REQUIRED before deployment)
cd ../clusters/my-cluster
cp ~/Downloads/pull-secret.txt ./
./scripts/seal-secrets.sh

# Step 3: Commit to Git (REQUIRED for ArgoCD - ArgoCD pulls from Git, not local files)
git add .
git commit -m "Add my-cluster configuration"
git push

# Step 4: Deploy the cluster (actual provisioning starts here)
oc apply -f argocd/application.yaml

# Step 5: Monitor deployment
oc get hostedcluster my-cluster -n clusters -w
```

**Why commit to Git?** ArgoCD reads manifests from the Git repository (`repoURL: https://github.com/partojalili/ocp-hcp-gitops.git`), not from your local filesystem. Without committing, ArgoCD won't find the sealed secret files and deployment will fail.

The `provision-cluster.sh` script will:
1. Auto-detect your environment's base domain
2. Create a new cluster configuration directory in `../clusters/my-cluster/`
3. Generate manifest files with your cluster name and settings
4. Configure 2 worker nodes with 4 cores and 8GB RAM (default)

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

## Step-by-Step Deployment

After running `provision-cluster.sh` to create the configuration, follow these steps to deploy the actual cluster:

### Step 1: Seal Secrets (REQUIRED)

**⚠️ IMPORTANT:** The pull secret is required for the cluster to pull the OCP release image. Without it, deployment will fail with authentication errors.

Navigate to your cluster directory and seal the secrets:

```bash
cd ../clusters/CLUSTER_NAME

# Download your pull secret from Red Hat Console
# https://console.redhat.com/openshift/install/pull-secret
# Save it as pull-secret.txt in the cluster directory
cp ~/Downloads/pull-secret.txt ./pull-secret.txt

# Run the seal-secrets script to encrypt the pull secret
./scripts/seal-secrets.sh
```

This creates `base/pull-secret-sealed.yaml` and `base/ssh-key-sealed.yaml` which are safe to commit to Git.

### Step 2: Commit to Git (REQUIRED for ArgoCD)

**⚠️ CRITICAL:** If using ArgoCD, you MUST commit the sealed secrets to Git before deploying. ArgoCD pulls manifests from Git, not from your local filesystem.

```bash
git add .
git commit -m "Add CLUSTER_NAME cluster configuration with sealed secrets"
git push
```

**Why is this required?**

The ArgoCD Application is configured to pull from Git:
```yaml
source:
  repoURL: https://github.com/partojalili/ocp-hcp-gitops.git
  targetRevision: main
  path: clusters/CLUSTER_NAME
```

The kustomization includes the sealed secrets:
```yaml
resources:
  - pull-secret-sealed.yaml  # ArgoCD looks for this in Git
  - ssh-key-sealed.yaml      # ArgoCD looks for this in Git
```

If you skip this step, ArgoCD will fail with: "unable to find resource pull-secret-sealed.yaml"

### Step 3: Deploy the Cluster (Actual Provisioning Starts Here)

**⚠️ This is when the actual cluster provisioning begins.**

**Option A: Using ArgoCD (GitOps - Recommended)**

```bash
# After committing to Git (Step 2)
oc apply -f argocd/application.yaml
```

ArgoCD will:
1. Sync from Git repository
2. Read the sealed secrets from Git
3. Create the HostedCluster and NodePool resources
4. Trigger cluster provisioning

**Option B: Manual Deployment with Kustomize (Git not required)**

```bash
# Deploy directly from local filesystem (no Git needed)
oc apply -k .
```

This reads from your local files, so Git commit is not required.

### Step 4: Monitor Cluster Provisioning

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

After running `provision-cluster.sh` (Step 1), your cluster directory will contain:

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

**Issue: Pull secret authentication failure**
```bash
# Error: "unauthorized: Could not find robot with specified username"
# Solution: Download a fresh pull secret from Red Hat Console
# https://console.redhat.com/openshift/install/pull-secret
# Re-run: ./scripts/seal-secrets.sh
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
