# Managed Cluster Configuration

This file documents the ManagedCluster labels for the `ocp-hcp` cluster.

## Apply Labels

To apply the labels to the managed cluster:

```bash
oc label managedcluster ocp-hcp cluster.open-cluster-management.io/clusterset=all-clusters --overwrite
oc label managedcluster ocp-hcp environment=production --overwrite
```

Or apply the patch file:

```bash
oc apply -f managedcluster-labels.yaml
```

## Current Labels

- **clusterset**: `all-clusters` - Makes cluster visible to all-clusters ManagedClusterSet
- **environment**: `production` - Production environment designation
- **cloud**: `Other` - Cloud provider (KubeVirt/OpenShift Virtualization)
- **vendor**: `OpenShift` - Platform vendor

## ManagedClusterSet Binding

The cluster is bound to the `all-clusters` clusterset, which allows it to be:
- Targeted by Placements selecting from the all-clusters set
- Managed by policies applied to the all-clusters set
- Visible to applications using the all-clusters binding
