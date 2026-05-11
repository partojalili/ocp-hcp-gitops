# OpenShift Hosted Control Plane - GitOps Deployment

This repository contains GitOps manifests for deploying an OpenShift 4.19 Hosted Control Plane cluster using ACM (Advanced Cluster Management) and OpenShift Virtualization (KubeVirt).

## Architecture

- **Control Plane**: Runs as pods on the ACM hub cluster
- **Worker Nodes**: Run as VMs using OpenShift Virtualization (KubeVirt)
- **OCP Version**: 4.19
- **Management**: ACM + OpenShift GitOps (ArgoCD)

## Prerequisites

1. **ACM 2.16** (or 2.10+) installed on hub cluster
2. **MultiCluster Engine (MCE) 2.11** (or 2.5+) enabled
3. OpenShift Virtualization operator installed
4. OpenShift GitOps operator installed
5. Storage classes available:
   - `lvms-vg1` for etcd
   - `ocs-storagecluster-ceph-rbd` for root volumes

**Note**: This repository is fully compatible with ACM 2.16 and MCE 2.11. See [ACM-2.16-COMPATIBILITY.md](ACM-2.16-COMPATIBILITY.md) for details.

## Directory Structure

```
ocp-hcp-gitops/
├── base/                           # Base Kustomize resources
│   ├── namespace.yaml
│   ├── pull-secret-sealed.yaml     # Encrypted pull secret
│   ├── ssh-key-sealed.yaml         # Encrypted SSH key
│   ├── hostedcluster.yaml
│   ├── nodepool.yaml
│   └── kustomization.yaml
├── overlays/                       # Environment-specific overlays
│   └── production/
│       ├── hostedcluster-patch.yaml
│       └── kustomization.yaml
├── policies/                       # ACM Policies
│   └── network/                    # Network security policies
│       ├── deny-all-policy.yaml
│       ├── placement.yaml
│       ├── placementbinding.yaml
│       └── managedclustersetbinding.yaml
├── argocd/                         # GitOps configuration
│   ├── application.yaml
│   ├── acm-network-policy-app.yaml
│   └── argocd-acm-permissions.yaml
└── scripts/                        # Helper scripts
    ├── seal-secrets.sh
    ├── validate-prereqs.sh
    ├── verify-acm-version.sh
    ├── get-kubeconfig.sh
    └── monitor-deployment.sh
```

## Deployment Steps

### 1. Install Sealed Secrets Controller

```bash
# Install on your ACM hub cluster
oc apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.36.6/controller.yaml

# Install kubeseal CLI
brew install kubeseal  # macOS
```

### 2. Seal Your Secrets

```bash
# Download your pull secret from https://console.redhat.com/openshift/install/pull-secret
# Save as pull-secret.txt

# Run the sealing script
./scripts/seal-secrets.sh

# Commit sealed secrets (safe!)
git add base/pull-secret-sealed.yaml base/ssh-key-sealed.yaml
git commit -m "Add sealed secrets"
git push
```

See [SEALED-SECRETS-GUIDE.md](SEALED-SECRETS-GUIDE.md) for detailed instructions.

### 2. Apply via ArgoCD

```bash
oc apply -f argocd/application.yaml
```

### 3. Monitor Deployment

```bash
# Watch HostedCluster status
oc get hostedcluster -n clusters -w

# Watch NodePool status
oc get nodepool -n clusters -w

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
