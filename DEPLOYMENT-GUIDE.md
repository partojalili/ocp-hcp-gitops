# OCP 4.20 Hosted Control Plane - Deployment Guide

Complete guide for deploying an OpenShift 4.20 Hosted Control Plane cluster using ACM, OpenShift Virtualization, and GitOps.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│ ACM Hub Cluster (Management)                                 │
│                                                              │
│  ┌────────────────┐    ┌──────────────────┐                │
│  │  ArgoCD/GitOps │───▶│ HCP Control Plane│                │
│  │                │    │  (Running as Pods)│                │
│  └────────────────┘    └──────────────────┘                │
│                                                              │
│  ┌────────────────────────────────────────┐                │
│  │ OpenShift Virtualization (KubeVirt)     │                │
│  │                                          │                │
│  │  ┌──────┐  ┌──────┐  ┌──────┐          │                │
│  │  │ VM 1 │  │ VM 2 │  │ VM 3 │          │                │
│  │  │Worker│  │Worker│  │Worker│          │                │
│  │  └──────┘  └──────┘  └──────┘          │                │
│  │                                          │                │
│  └────────────────────────────────────────┘                │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

### 1. Software Requirements

- **OpenShift Hub Cluster**: 4.16+ (where ACM is installed)
- **ACM**: 2.16 recommended (2.10+ minimum)
- **MultiCluster Engine (MCE)**: 2.11 recommended (2.5+ minimum)
- **OpenShift Virtualization Operator**: Latest version
- **OpenShift GitOps Operator**: Latest version

**ACM 2.16 Compatibility**: This repository is fully compatible with ACM 2.16 and MCE 2.11, using the stable `v1beta1` HyperShift API. See [ACM-2.16-COMPATIBILITY.md](ACM-2.16-COMPATIBILITY.md) for details.

### 2. Hardware Requirements (per worker VM)

- **CPU**: 8 cores minimum
- **Memory**: 16Gi minimum
- **Storage**: 120Gi root volume + 16Gi etcd volume

### 3. Storage Classes Required

- `lvms-vg1` - For etcd persistent volumes
- `ocs-storagecluster-ceph-rbd` - For worker VM root volumes

### 4. Network Requirements

- Load Balancer available for API server endpoint
- DNS configured for the baseDomain
- Network connectivity between hub and hosted cluster

## Step-by-Step Deployment

### Step 1: Validate Prerequisites

Run the validation scripts:

```bash
cd ocp-hcp-gitops

# Verify ACM 2.16 / MCE 2.11 compatibility
./scripts/verify-acm-version.sh

# Validate all prerequisites
./scripts/validate-prereqs.sh
```

These scripts will check:
- ACM version (2.16 recommended)
- MCE version (2.11 recommended)
- HyperShift API version (v1beta1)
- OpenShift CLI (oc) availability
- Cluster connectivity
- OpenShift Virtualization operator
- GitOps operator
- Storage classes

### Step 2: Configure Secrets

#### Pull Secret

1. Download your pull secret from https://console.redhat.com/openshift/install/pull-secret

2. Base64 encode it:
   ```bash
   cat ~/Downloads/pull-secret.txt | base64 -w0
   ```

3. Edit `base/pull-secret.yaml` and replace `REPLACE_WITH_YOUR_BASE64_ENCODED_PULL_SECRET`

#### SSH Key (Optional but Recommended)

1. Generate SSH key:
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/ocp420-hcp -N ""
   ```

2. Edit `base/ssh-key.yaml` and paste the contents of `~/.ssh/ocp420-hcp.pub`

### Step 3: Customize Configuration

Edit `overlays/production/hostedcluster-patch.yaml`:

```yaml
spec:
  dns:
    baseDomain: your-domain.com  # Change this!
  
  release:
    image: quay.io/openshift-release-dev/ocp-release:4.20.0-x86_64
```

### Step 4: Enable HyperShift in MCE

If not already enabled:

```bash
oc patch mce multiclusterengine --type=merge -p '{"spec":{"overrides":{"components":[{"name":"hypershift-preview","enabled":true}]}}}'
```

Wait for the HyperShift operator to be ready:

```bash
oc wait --for=condition=Available deployment/operator -n hypershift --timeout=300s
```

### Step 5: Deploy via GitOps

#### Option A: Using ArgoCD Application

1. Push this repository to your Git server

2. Edit `argocd/application.yaml` and update the Git URL:
   ```yaml
   source:
     repoURL: https://github.com/YOUR-ORG/YOUR-REPO.git
   ```

3. Apply the ArgoCD Application:
   ```bash
   oc apply -f argocd/application.yaml
   ```

4. Monitor in ArgoCD UI:
   ```bash
   # Get ArgoCD route
   oc get route openshift-gitops-server -n openshift-gitops
   
   # Get admin password
   oc extract secret/openshift-gitops-cluster -n openshift-gitops --to=-
   ```

#### Option B: Direct Kustomize Deployment

```bash
oc apply -k overlays/production/
```

#### Option C: Using ApplicationSet (Multiple Clusters)

For managing multiple hosted clusters:

```bash
oc apply -f argocd/applicationset.yaml
```

### Step 6: Monitor Deployment

Use the monitoring script:

```bash
./scripts/monitor-deployment.sh ocp420-hcp clusters
```

Or manually check:

```bash
# HostedCluster status
oc get hostedcluster -n clusters -w

# NodePool status
oc get nodepool -n clusters -w

# Control plane pods
oc get pods -n clusters-ocp420-hcp

# Virtual machines
oc get vm -n clusters-ocp420-hcp

# Detailed status
oc describe hostedcluster ocp420-hcp -n clusters
```

### Step 7: Access the Hosted Cluster

Extract the kubeconfig:

```bash
./scripts/get-kubeconfig.sh ocp420-hcp clusters
```

Or manually:

```bash
oc extract secret/ocp420-hcp-admin-kubeconfig -n clusters --to=- > kubeconfig-ocp420-hcp.yaml

export KUBECONFIG=kubeconfig-ocp420-hcp.yaml
oc get nodes
```

## Post-Deployment Tasks

### Scale Worker Nodes

```bash
oc patch nodepool ocp420-hcp-workers -n clusters --type=merge -p '{"spec":{"replicas":5}}'
```

### Upgrade to a New Release

Update the release image in both HostedCluster and NodePool:

```bash
NEW_IMAGE="quay.io/openshift-release-dev/ocp-release:4.20.1-x86_64"

oc patch hostedcluster ocp420-hcp -n clusters --type=merge -p "{\"spec\":{\"release\":{\"image\":\"$NEW_IMAGE\"}}}"

oc patch nodepool ocp420-hcp-workers -n clusters --type=merge -p "{\"spec\":{\"release\":{\"image\":\"$NEW_IMAGE\"}}}"
```

### Add Additional NodePools

Create a new NodePool for different workload types:

```bash
cat <<EOF | oc apply -f -
apiVersion: hypershift.openshift.io/v1beta1
kind: NodePool
metadata:
  name: ocp420-hcp-gpu-workers
  namespace: clusters
spec:
  clusterName: ocp420-hcp
  replicas: 2
  release:
    image: quay.io/openshift-release-dev/ocp-release:4.20.0-x86_64
  platform:
    type: KubeVirt
    kubevirt:
      compute:
        cores: 16
        memory: 32Gi
      rootVolume:
        persistent:
          size: 200Gi
          storageClass: ocs-storagecluster-ceph-rbd
  nodeLabels:
    node-role.kubernetes.io/gpu: ""
  taints:
    - key: "nvidia.com/gpu"
      value: "true"
      effect: "NoSchedule"
EOF
```

## Troubleshooting

### HostedCluster Stuck in "Pending"

Check HyperShift operator logs:
```bash
oc logs -n hypershift deployment/operator --tail=50
```

Check control plane namespace events:
```bash
oc get events -n clusters-ocp420-hcp --sort-by='.lastTimestamp'
```

### NodePool VMs Not Starting

Check KubeVirt operator:
```bash
oc get pods -n openshift-cnv
```

Check VM events:
```bash
oc get vm -n clusters-ocp420-hcp
oc describe vm -n clusters-ocp420-hcp
```

Check storage:
```bash
oc get pvc -n clusters-ocp420-hcp
```

### Control Plane Pods CrashLooping

Check pod logs:
```bash
oc logs -n clusters-ocp420-hcp <pod-name>
```

Check resource constraints:
```bash
oc describe pod -n clusters-ocp420-hcp <pod-name>
```

### Cannot Access Hosted Cluster API

Check service publishing:
```bash
oc get svc -n clusters-ocp420-hcp | grep kube-apiserver
```

Check LoadBalancer service:
```bash
oc describe svc -n clusters-ocp420-hcp <api-service>
```

### ArgoCD Sync Issues

Check application status:
```bash
oc get application -n openshift-gitops
oc describe application ocp420-hosted-cluster -n openshift-gitops
```

Manual sync:
```bash
oc patch application ocp420-hosted-cluster -n openshift-gitops --type=merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

## Cleanup

### Delete Hosted Cluster

```bash
# Via ArgoCD
oc delete application ocp420-hosted-cluster -n openshift-gitops

# Or directly
oc delete hostedcluster ocp420-hcp -n clusters
oc delete nodepool ocp420-hcp-workers -n clusters

# Clean up namespace
oc delete namespace clusters-ocp420-hcp
```

## Best Practices

1. **Use GitOps**: Always manage HCP through Git for auditability
2. **Version Control**: Track all changes to manifests in Git
3. **Resource Limits**: Set appropriate CPU/memory for VMs based on workload
4. **High Availability**: Use HA mode for production clusters
5. **Monitoring**: Set up monitoring for both control plane and worker nodes
6. **Backup**: Regularly backup etcd and important configurations
7. **Updates**: Test upgrades in non-production environments first
8. **Security**: Use network policies and RBAC appropriately

## Additional Resources

- [Red Hat ACM Documentation](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.10/html-single/clusters/index)
- [HyperShift Documentation](https://hypershift-docs.netlify.app/)
- [OpenShift Virtualization](https://docs.openshift.com/container-platform/latest/virt/about_virt/about-virt.html)
- [OpenShift GitOps](https://docs.openshift.com/gitops/latest/understanding_openshift_gitops/about-redhat-openshift-gitops.html)

## Support

For issues and questions:
- Red Hat Support Portal: https://access.redhat.com/support
- OpenShift Community: https://community.redhat.com/
