# OpenShift Hosted Control Plane - GitOps Deployment

This repository contains GitOps manifests for deploying an OpenShift 4.19 Hosted Control Plane cluster using ACM (Advanced Cluster Management) and OpenShift Virtualization (KubeVirt).

## ⚠️ IMPORTANT: Update Base Domain

**Before deploying**, you MUST update the base domain to match your environment.

### File to Update

**Only update this file:**
```
overlays/production/hostedcluster-patch.yaml
```

This is the **production overlay** that contains your real cluster domain.

### Step-by-Step Instructions

1. **Find your cluster's base domain:**
   ```bash
   oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}'
   ```
   Example output: `apps.cluster-q2pfv.dynamic2.redhatworkshops.io`

2. **Edit the overlay file:**
   ```bash
   vim overlays/production/hostedcluster-patch.yaml
   ```

3. **Update line 9 with your domain:**
   ```yaml
   spec:
     dns:
       baseDomain: apps.cluster-XXXXX.dynamic2.redhatworkshops.io  # ← Update this
   ```

4. **Commit and push:**
   ```bash
   git add overlays/production/hostedcluster-patch.yaml
   git commit -m "Update baseDomain for my environment"
   git push
   ```

### Files Overview

| File | Purpose | Should You Edit? |
|------|---------|------------------|
| `overlays/production/hostedcluster-patch.yaml` | Production domain override | ✅ **YES - Update this!** |
| `base/hostedcluster.yaml` | Base template with placeholder | ❌ NO - Keep as `example.com` |

**Note:** The `baseDomain` field is **immutable** after cluster creation. If you need to change it later, you must delete and recreate the HostedCluster.

## Architecture

- **Control Plane**: Runs as pods on the ACM hub cluster
- **Worker Nodes**: Run as VMs using OpenShift Virtualization (KubeVirt)
- **OCP Version**: 4.19
- **Management**: ACM + OpenShift GitOps (ArgoCD)

## How It Works - GitOps Flow

This repository implements a complete GitOps workflow where changes flow from Git to production automatically:

```
Developer → Git Push → ArgoCD Sync → ACM Policy → Managed Cluster → Production
```

**Key Flow:**
1. **Developer** commits changes to GitHub (e.g., update webserver HTML)
2. **ArgoCD** detects changes and syncs to hub cluster (~3 min)
3. **ACM Placement** selects target clusters based on labels
4. **ACM Policy Controller** propagates policies to managed clusters
5. **Managed Cluster** applies resources (ConfigMap, Deployment, etc.)
6. **Kubernetes** performs rolling update with new content
7. **Compliance** status reported back to hub

**Total Time:** ~4-6 minutes from commit to production!

📖 **See [GITOPS-FLOW.md](GITOPS-FLOW.md) for detailed flow diagrams and component interactions.**

## Prerequisites

1. **ACM 2.16** (or 2.10+) installed on hub cluster
2. **MultiCluster Engine (MCE) 2.11** (or 2.5+) enabled
3. OpenShift Virtualization operator installed
4. OpenShift GitOps operator installed
5. Storage classes available:
   - `lvms-vg1` for etcd
   - `ocs-storagecluster-ceph-rbd` for root volumes

**Note**: This repository is fully compatible with ACM 2.16 and MCE 2.11. See [ACM-2.16-COMPATIBILITY.md](ACM-2.16-COMPATIBILITY.md) for details.

## Initial Setup: GitOps Operator & ACM Integration

**IMPORTANT**: Before deploying the Hosted Control Plane, you must install OpenShift GitOps and grant it permissions to manage ACM resources.

### 1. Install OpenShift GitOps Operator

Install the OpenShift GitOps operator on your hub cluster:

```bash
cat <<EOF | oc apply -f -
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
EOF
```

Wait for the operator to be ready:

```bash
# Watch for operator installation
oc get csv -n openshift-operators | grep gitops

# Wait for ArgoCD instance to be created
oc get pods -n openshift-gitops
```

### 2. Grant ArgoCD Permissions for ACM

ArgoCD needs permissions to manage ACM resources (Policies, Placements, HostedClusters, NodePools).

Apply the RBAC configuration:

```bash
oc apply -f argocd/argocd-acm-permissions.yaml
```

This grants the ArgoCD application controller:
- Permissions to create/update/delete ACM Policies and Placements
- Permissions to manage HyperShift resources (HostedCluster, NodePool)
- Cluster-admin access in the `openshift-gitops` namespace

Verify permissions:

```bash
# Check ClusterRole was created
oc get clusterrole argocd-acm-policy-manager

# Check ClusterRoleBinding
oc get clusterrolebinding argocd-acm-policy-manager
```

### 3. Verify GitOps Installation

Confirm ArgoCD is running and accessible:

```bash
# Check ArgoCD pods
oc get pods -n openshift-gitops

# Get ArgoCD route
oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}'

# Get admin password (if needed)
oc extract secret/openshift-gitops-cluster -n openshift-gitops --to=-
```

📖 **For detailed GitOps integration guide, see [ACM-ARGOCD-INTEGRATION.md](ACM-ARGOCD-INTEGRATION.md)**

---

## Directory Structure

```
ocp-hcp-gitops/
├── base/                              # Base Kustomize resources
│   ├── namespace.yaml
│   ├── pull-secret-sealed.yaml        # Encrypted pull secret
│   ├── ssh-key-sealed.yaml            # Encrypted SSH key
│   ├── hostedcluster.yaml
│   ├── nodepool.yaml
│   └── kustomization.yaml
│
├── overlays/                          # Environment-specific overlays
│   └── production/
│       ├── hostedcluster-patch.yaml
│       └── kustomization.yaml
│
├── policies/                          # ACM Policies (managed by ArgoCD)
│   ├── network/                       # Network security policies
│   │   ├── deny-all-policy.yaml
│   │   ├── allow-ingress-policy.yaml
│   │   ├── allow-ingress-placement.yaml
│   │   ├── allow-ingress-placementbinding.yaml
│   │   ├── placement.yaml
│   │   ├── placementbinding.yaml
│   │   └── managedclustersetbinding.yaml
│   └── webserver-app/                 # Webserver application policy
│       ├── webserver-policy.yaml
│       ├── placement.yaml
│       └── placementbinding.yaml
│
├── argocd/                            # ArgoCD applications
│   ├── application.yaml               # Main HCP deployment app
│   ├── acm-network-policy-app.yaml    # Network policy app
│   ├── acm-webserver-app.yaml         # Webserver app
│   └── argocd-acm-permissions.yaml    # RBAC for ArgoCD
│
├── scripts/                           # Helper scripts
│   ├── seal-secrets.sh
│   ├── validate-prereqs.sh
│   ├── verify-acm-version.sh
│   ├── get-kubeconfig.sh
│   └── monitor-deployment.sh
│
├── conn-ocp-hcp.sh                    # Connect to hosted cluster
├── disconnect-ocp-hcp.sh              # Disconnect from hosted cluster
├── kustomization.yaml                 # Root kustomization
├── managedcluster-labels.yaml         # ManagedCluster labels
│
└── Documentation/
    ├── README.md                      # This file
    ├── ACM-ARGOCD-INTEGRATION.md      # ACM + ArgoCD integration guide
    ├── ACM-2.16-COMPATIBILITY.md      # ACM 2.16 compatibility notes
    ├── DEPLOYMENT-GUIDE.md            # Detailed deployment guide
    ├── GITOPS-FLOW.md                 # Complete GitOps flow diagram ⭐
    ├── HOW-TO-UPDATE-WEBSERVER.md     # Auto-reload webserver guide
    ├── MANAGEDCLUSTER.md              # ManagedCluster configuration
    ├── QUICK-REFERENCE.md             # Command quick reference
    ├── QUICK-START-ACM-2.16.md        # Quick start guide
    └── SEALED-SECRETS-GUIDE.md        # Sealed secrets guide
```

## Deployment Steps

**Prerequisites**: Ensure you have completed the [Initial Setup](#initial-setup-gitops-operator--acm-integration) above.

### 1. Install Sealed Secrets Controller

```bash
# Install on your ACM hub cluster
oc apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.36.6/controller.yaml

# Install kubeseal CLI
brew install kubeseal  # macOS
```

### 2. Seal Your Secrets

**IMPORTANT:** The `pull-secret.txt` file must be placed in the **repository root** directory.

```bash
# 1. Download your pull secret from Red Hat
# https://console.redhat.com/openshift/install/pull-secret

# 2. Save it in the REPOSITORY ROOT (NOT in subdirectories)
# Location: /path/to/ocp-hcp-gitops/pull-secret.txt
cp ~/Downloads/pull-secret.txt ./pull-secret.txt

# 3. Run the sealing script (from repository root)
./scripts/seal-secrets.sh

# 4. Commit sealed secrets (safe to commit!)
git add base/pull-secret-sealed.yaml base/ssh-key-sealed.yaml
git commit -m "Add sealed secrets"
git push
```

**File Location:**
```
ocp-hcp-gitops/
├── pull-secret.txt           ← Put it HERE (repository root)
├── scripts/
│   └── seal-secrets.sh      ← Script looks for ../pull-secret.txt
└── base/
    └── pull-secret-sealed.yaml  ← Output goes here
```

**Note:** The `pull-secret.txt` file is already in `.gitignore` and will not be committed to Git.

See [SEALED-SECRETS-GUIDE.md](SEALED-SECRETS-GUIDE.md) for detailed instructions.

### 2. Deploy via ArgoCD (GitOps)

Deploy the Hosted Control Plane cluster using ArgoCD:

```bash
# Deploy the HCP cluster application
oc apply -f argocd/application.yaml

# Deploy the ACM policy applications
oc apply -f argocd/acm-network-policy-app.yaml
oc apply -f argocd/acm-webserver-app.yaml
```

ArgoCD will automatically sync from Git and deploy:
- HostedCluster and NodePool resources
- ACM Policies for network security
- ACM Policies for webserver application

### 3. Monitor Deployment

**Check ArgoCD Applications:**

```bash
# List all ArgoCD applications
oc get applications -n openshift-gitops

# Check sync status
oc get application ocp-hcp-hosted-cluster -n openshift-gitops
oc get application acm-webserver-app -n openshift-gitops
oc get application acm-deny-all-network-policy -n openshift-gitops
```

**Monitor Hosted Cluster Deployment:**

```bash
# Watch HostedCluster status
oc get hostedcluster -n clusters -w

# Watch NodePool status
oc get nodepool -n clusters -w

# Check control plane pods
oc get pods -n clusters-ocp-hcp

# Get kubeconfig for hosted cluster
oc extract secret/ocp-hcp-admin-kubeconfig -n clusters --to=-
```

## Manual Deployment (Alternative)

If not using ArgoCD, deploy directly with kustomize:

```bash
oc apply -k overlays/production/
```

## Scaling Worker Nodes

Edit `nodepool.yaml` and change `spec.replicas`:

```bash
oc patch nodepool ocp-hcp-workers -n clusters --type=merge -p '{"spec":{"replicas":5}}'
```

## Upgrading the Cluster

Update the `release-image` in both HostedCluster and NodePool resources.

## Day 2 Operations

### Network Policies via ACM

Network security policies are enforced across managed clusters using ACM Policies, deployed via ArgoCD.

**View ACM Policy**:
```bash
oc get policy -n open-cluster-management-policies
```

**Check which clusters are targeted**:
```bash
oc get placementdecision -n open-cluster-management-policies -o yaml
```

**View NetworkPolicy on managed cluster (ocp-hcp)**:
```bash
# Login to the managed cluster first
oc get networkpolicy deny-all-default -n webserver-prod
```

**ArgoCD Application**:
```bash
oc get application acm-deny-all-network-policy -n openshift-gitops
```

### Drift Prevention and Self-Healing Demo

Demonstrate ArgoCD's drift prevention capability with ACM policy enforcement:

**1. Create the target namespace on the managed cluster**:
```bash
# Login to ocp-hcp managed cluster
oc new-project webserver-prod
```

**2. Verify the NetworkPolicy was automatically created by ACM**:
```bash
oc get networkpolicy deny-all-default -n webserver-prod
```

**3. Delete the NetworkPolicy to simulate drift**:
```bash
oc delete networkpolicy deny-all-default -n webserver-prod
```

**4. Watch ACM automatically recreate it** (within ~10 seconds):
```bash
watch oc get networkpolicy deny-all-default -n webserver-prod
```

**5. Check the ACM Policy compliance status**:
```bash
# From hub cluster
oc get policy policy-deny-all-network -n open-cluster-management-policies -o jsonpath='{.status.compliant}'
```

**What's happening**:
- ArgoCD syncs the ACM Policy definition from Git to the hub cluster (with `selfHeal: true`)
- ACM enforces the NetworkPolicy on managed clusters based on Placement rules
- If someone deletes the NetworkPolicy on the managed cluster, ACM detects the drift and recreates it automatically
- This provides **two layers of drift prevention**: ArgoCD protects the policy definition, ACM enforces the policy on clusters

## Resources

- [Deploy HCP with OpenShift Virtualization](https://developers.redhat.com/articles/2026/04/20/deploy-hosted-control-planes-openshift-virtualization)
- [Using GitOps to Deploy HCP Clusters](https://www.redhat.com/en/blog/using-gitops-to-deploy-bare-metal-openshift-hosted-control-plane-clusters)
- [ACM GitOps Integration](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.9/html-single/gitops/index)
- [Network Policies Documentation](https://docs.openshift.com/container-platform/latest/networking/network_policy/about-network-policy.html)
