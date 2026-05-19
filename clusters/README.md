# HCP Clusters

This directory contains provisioned Hosted Control Plane cluster configurations.

## Structure

Each subdirectory represents a separate HCP cluster:

```
clusters/
├── dev-hcp/           # Development cluster
├── prod-hcp/          # Production cluster
└── test-hcp/          # Test cluster
```

## Provisioning a New Cluster

To create a new cluster configuration, use the provisioning script from the `hcp-template/` directory:

```bash
cd ../hcp-template
./provision-cluster.sh -n my-new-cluster
```

This will automatically create a new directory in `clusters/my-new-cluster/` with all necessary configuration files.

## Cluster Lifecycle

### 1. Provision
```bash
cd ../hcp-template
./provision-cluster.sh -n my-cluster
```

### 2. Configure Secrets
```bash
cd my-cluster
# Place pull-secret.txt here
./scripts/seal-secrets.sh
```

### 3. Deploy
```bash
# GitOps (recommended)
oc apply -f argocd/application.yaml

# Or manual
oc apply -k .
```

### 4. Monitor
```bash
oc get hostedcluster my-cluster -n clusters -w
```

### 5. Delete
```bash
oc delete application my-cluster-hosted-cluster -n openshift-gitops
oc delete hostedcluster my-cluster -n clusters
rm -rf my-cluster/
```

## GitOps Workflow

When using ArgoCD:

1. Provision cluster configuration locally
2. Seal secrets
3. Commit and push to Git
4. Deploy ArgoCD application
5. ArgoCD syncs from Git and creates the cluster

All changes to cluster configuration should be made via Git commits for proper audit trail and drift prevention.
