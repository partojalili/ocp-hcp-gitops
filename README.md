# OpenShift 4.20 Hosted Control Plane - GitOps Deployment

This repository contains GitOps manifests for deploying an OpenShift 4.20 Hosted Control Plane cluster using ACM (Advanced Cluster Management) and OpenShift Virtualization (KubeVirt).

## Architecture

- **Control Plane**: Runs as pods on the ACM hub cluster
- **Worker Nodes**: Run as VMs using OpenShift Virtualization (KubeVirt)
- **OCP Version**: 4.20
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
├── day2-config/                    # Day 2 Operations
│   ├── README.md
│   └── network-policies/           # Network security policies
│       ├── deny-all-default.yaml
│       ├── allow-dns.yaml
│       ├── allow-ingress-controller.yaml
│       ├── allow-monitoring.yaml
│       └── kustomization.yaml
├── argocd/                         # GitOps configuration
│   ├── application.yaml
│   ├── applicationset.yaml
│   └── gitopscluster.yaml
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
oc extract secret/ocp420-hcp-admin-kubeconfig -n clusters --to=-
```

## Manual Deployment (Alternative)

If not using ArgoCD, deploy directly with kustomize:

```bash
oc apply -k overlays/production/
```

## Scaling Worker Nodes

Edit `nodepool.yaml` and change `spec.replicas`:

```bash
oc patch nodepool ocp420-hcp-workers -n clusters --type=merge -p '{"spec":{"replicas":5}}'
```

## Upgrading the Cluster

Update the `release-image` in both HostedCluster and NodePool resources.

## Day 2 Operations

### Network Policies

Baseline network security policies are managed via GitOps in `day2-config/network-policies/`.

**View deployed policies**:
```bash
oc get networkpolicy -n baseline-policies
```

**ArgoCD Application**:
```bash
oc get application network-policies -n openshift-gitops
```

### GitOps Self-Healing Demo

Demonstrate ArgoCD's self-healing capability by deleting a network policy:

**1. View current policies**:
```bash
oc get networkpolicy -n baseline-policies
```

**2. Delete a policy**:
```bash
oc delete networkpolicy allow-dns -n baseline-policies
```

**3. Watch ArgoCD automatically recreate it** (within ~30 seconds):
```bash
watch oc get networkpolicy -n baseline-policies
```

**4. Check ArgoCD sync status**:
```bash
oc get application network-policies -n openshift-gitops
```

ArgoCD detects the drift from Git and automatically recreates the deleted resource because `selfHeal: true` is enabled!

## Resources

- [Deploy HCP with OpenShift Virtualization](https://developers.redhat.com/articles/2026/04/20/deploy-hosted-control-planes-openshift-virtualization)
- [Using GitOps to Deploy HCP Clusters](https://www.redhat.com/en/blog/using-gitops-to-deploy-bare-metal-openshift-hosted-control-plane-clusters)
- [ACM GitOps Integration](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.9/html-single/gitops/index)
- [Network Policies Documentation](https://docs.openshift.com/container-platform/latest/networking/network_policy/about-network-policy.html)
