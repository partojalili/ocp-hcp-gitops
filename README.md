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
├── base/
│   ├── namespace.yaml
│   ├── pull-secret.yaml (template - needs your pull secret)
│   ├── hostedcluster.yaml
│   ├── nodepool.yaml
│   └── kustomization.yaml
├── overlays/
│   └── production/
│       ├── hostedcluster-patch.yaml
│       └── kustomization.yaml
└── argocd/
    └── application.yaml
```

## Deployment Steps

### 1. Configure Pull Secret

Edit `base/pull-secret.yaml` and add your Red Hat pull secret:

```bash
# Download your pull secret from https://console.redhat.com/openshift/install/pull-secret
cat ~/pull-secret.txt | base64 -w0
```

Paste the base64 output into `base/pull-secret.yaml`

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

## Resources

- [Deploy HCP with OpenShift Virtualization](https://developers.redhat.com/articles/2026/04/20/deploy-hosted-control-planes-openshift-virtualization)
- [Using GitOps to Deploy HCP Clusters](https://www.redhat.com/en/blog/using-gitops-to-deploy-bare-metal-openshift-hosted-control-plane-clusters)
- [ACM GitOps Integration](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.9/html-single/gitops/index)
