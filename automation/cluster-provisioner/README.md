# Automated GCP OpenShift Cluster Provisioning

This automation watches for new cluster configurations and automatically provisions OpenShift clusters on GCP.

## Architecture

```
Developer Hub Template
    ↓
Creates cluster config in Git
    ↓
ArgoCD ApplicationSet detects new cluster
    ↓
Syncs manifests/ directory
    ↓
Kubernetes Job runs openshift-install
    ↓
Cluster provisioned on GCP
```

## Prerequisites

Before using the automation, you need to create three secrets in the `openshift-gitops` namespace:

### 1. GCP Service Account Secret

```bash
oc create secret generic gcp-service-account \
  --from-file=service-account.json=~/gcp-openshift-installer-key.json \
  -n openshift-gitops
```

### 2. OpenShift Pull Secret

```bash
# Get your pull secret from https://console.redhat.com/openshift/install/pull-secret
oc create secret generic openshift-pull-secret \
  --from-literal=pull-secret='{"auths":{"cloud.openshift.com":...}}' \
  -n openshift-gitops
```

### 3. SSH Key for Cluster Access

```bash
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -N '' -f ~/.ssh/openshift-clusters

oc create secret generic cluster-ssh-key \
  --from-file=ssh-public-key=~/.ssh/openshift-clusters.pub \
  --from-file=ssh-private-key=~/.ssh/openshift-clusters \
  -n openshift-gitops
```

## How It Works

When you create a GCP cluster using the Developer Hub template:

1. **Template creates PR** with cluster configuration
2. **You merge PR** to main branch
3. **ApplicationSet discovers** the new cluster directory
4. **ArgoCD syncs** the `manifests/` directory
5. **Kubernetes Job triggers** automatically (ArgoCD hook)
6. **Job runs openshift-install** with your credentials
7. **Cluster provisions** on GCP (takes ~30-40 minutes)
8. **Credentials saved** as Kubernetes secrets

## Monitoring Installation

### Check Job Status

```bash
# Find the installer job
oc get jobs -n gcp-<cluster-name> -l job-type=cluster-installer

# View job logs
oc logs -n gcp-<cluster-name> job/install-<cluster-name> -f
```

### Check Cluster Status

```bash
# After installation completes, get kubeconfig
oc get secret <cluster-name>-kubeconfig -n gcp-<cluster-name> -o jsonpath='{.data.kubeconfig}' | base64 -d > /tmp/kubeconfig

# Use the kubeconfig
export KUBECONFIG=/tmp/kubeconfig
oc get nodes
oc get co  # Check cluster operators
```

## Accessing the Cluster

After installation completes:

### Console URL
```
https://console-openshift-console.apps.<cluster-name>.<base-domain>
```

### API URL
```
https://api.<cluster-name>.<base-domain>:6443
```

### Kubeadmin Password
```bash
oc get secret <cluster-name>-kubeadmin -n gcp-<cluster-name> -o jsonpath='{.data.password}' | base64 -d
```

## Troubleshooting

### Job Fails with Permission Errors

Check GCP service account has required roles:
```bash
gcloud projects get-iam-policy openenv-jdpff \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:openshift-installer@*"
```

### Job Fails with Pull Secret Error

Verify pull secret format:
```bash
oc get secret openshift-pull-secret -n openshift-gitops -o jsonpath='{.data.pull-secret}' | base64 -d | jq '.'
```

### Installation Times Out

Check job logs for specific errors:
```bash
oc logs -n gcp-<cluster-name> job/install-<cluster-name> --tail=100
```

Common issues:
- GCP quotas exceeded
- Invalid install-config.yaml
- Network connectivity issues
- DNS zone not configured

## Manual Trigger

If you want to manually trigger cluster installation (bypassing the automation):

```bash
# Get the install-config
oc get configmap <cluster-name>-install-config -n gcp-<cluster-name> -o jsonpath='{.data.install-config\.yaml}' > install-config.yaml

# Follow manual installation steps in the cluster README.md
```

## Security Considerations

- **Secrets are cluster-scoped**: Each namespace can only access its own cluster credentials
- **RBAC controls**: Jobs run with minimal permissions
- **Pull secret rotation**: Rotate OpenShift pull secrets before they expire
- **GCP key rotation**: Rotate service account keys every 90 days
- **Kubeconfig access**: Limit who can read cluster kubeconfig secrets

## Cost Management

Each cluster installation creates GCP resources that incur costs:
- ~$705/month for standard 3-worker cluster
- Resources created: VMs, Load Balancers, Persistent Disks, VPC

**Remember to delete clusters when not needed!**

## Cleanup / Cluster Deletion

To delete a cluster:

1. Run the destroy command manually:
```bash
# Get credentials
oc get secret <cluster-name>-kubeconfig -n gcp-<cluster-name> \
  -o jsonpath='{.data.kubeconfig}' | base64 -d > /tmp/kubeconfig

# Destroy cluster
openshift-install destroy cluster --dir=<install-dir> --log-level=info
```

2. Delete the cluster directory from Git:
```bash
git rm -r clusters/gcp/<cluster-name>
git commit -m "Delete cluster <cluster-name>"
git push
```

3. ApplicationSet will automatically delete the ArgoCD Application

## Limitations

- One installation job per cluster
- No automatic cluster upgrades (manual process)
- No automatic destruction (must be done manually)
- Credentials stored as Kubernetes secrets (consider External Secrets Operator for production)

## Future Enhancements

Potential improvements:
- Use External Secrets Operator for credential management
- Add cluster health monitoring
- Automatic cluster upgrades via Jobs
- Integration with cost tracking tools
- Cluster hibernation for dev environments
