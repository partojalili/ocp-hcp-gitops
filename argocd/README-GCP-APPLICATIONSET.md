# GCP OpenShift Clusters ApplicationSet

This ApplicationSet automatically discovers and manages OpenShift clusters on Google Cloud Platform.

## How It Works

### Automatic Discovery

The ApplicationSet uses a **Git Directory Generator** to:

1. **Watch** the `clusters/gcp/` directory in the repository
2. **Discover** any subdirectory under `clusters/gcp/*`
3. **Automatically create** an ArgoCD Application for each discovered cluster

### Directory Structure Expected

```
clusters/gcp/
├── cluster-name-1/
│   ├── install-config.yaml
│   ├── catalog-info.yaml
│   └── README.md
├── cluster-name-2/
│   ├── install-config.yaml
│   ├── catalog-info.yaml
│   └── README.md
└── ...
```

Each cluster directory becomes an ArgoCD Application named `gcp-cluster-<directory-name>`.

## What Gets Created

For each cluster directory (e.g., `clusters/gcp/prod-cluster`), the ApplicationSet creates:

**Application Name**: `gcp-cluster-prod-cluster`

**Labels**:
- `cluster-name: prod-cluster`
- `platform: gcp`
- `cluster-type: openshift`
- `managed-by: applicationset`

**Sync Policy**:
- Automated sync with pruning and self-healing enabled
- Creates namespace automatically
- Retries on failures (up to 5 times with exponential backoff)

## Benefits

### ✅ Automatic Cluster Management
- New clusters are discovered automatically when added to Git
- No manual ArgoCD Application creation needed
- Cluster removal is handled automatically

### ✅ GitOps Native
- Single source of truth in Git
- Declarative cluster configuration
- Audit trail through Git history

### ✅ Scalable
- Manage 1 or 100 clusters with the same ApplicationSet
- No duplication of ArgoCD configuration
- Consistent sync policies across all clusters

### ✅ Developer Hub Integration
- Works seamlessly with the GCP cluster template
- Developer Hub creates cluster config → ApplicationSet deploys it
- Self-service cluster provisioning with GitOps governance

## Adding a New Cluster

### Method 1: Using Developer Hub Template (Recommended)

1. Go to Developer Hub → Create
2. Select "OpenShift Cluster on GCP"
3. Fill in cluster details
4. Submit the form

The template will:
- Create a PR with cluster configuration in `clusters/gcp/<cluster-name>/`
- Once merged, the ApplicationSet automatically picks it up
- ArgoCD Application is created automatically

### Method 2: Manual Git Commit

1. Create a new directory: `clusters/gcp/<cluster-name>/`
2. Add cluster configuration files:
   - `install-config.yaml` - OpenShift installer config
   - `catalog-info.yaml` - Developer Hub catalog entry
   - `README.md` - Cluster documentation
3. Commit and push to main branch
4. ApplicationSet detects it within 3 minutes (default refresh interval)

## Removing a Cluster

1. Delete the cluster directory: `clusters/gcp/<cluster-name>/`
2. Commit and push
3. ApplicationSet automatically removes the ArgoCD Application
4. With `prune: true`, resources in the cluster namespace are also removed

## Monitoring

### View All Managed Clusters

```bash
oc get applications -n openshift-gitops -l managed-by=applicationset,platform=gcp
```

### Check ApplicationSet Status

```bash
oc get applicationset gcp-openshift-clusters -n openshift-gitops -o yaml
```

### View Generated Applications

```bash
oc get applications -n openshift-gitops -l cluster-type=openshift,platform=gcp
```

## Customization

### Change Sync Policy

Edit `gcp-clusters-applicationset.yaml`:

```yaml
syncPolicy:
  automated:
    prune: false  # Don't automatically delete resources
    selfHeal: false  # Don't automatically sync changes
```

### Add Cluster-Specific Overrides

You can use labels from the cluster directory to customize behavior:

```yaml
generators:
  - git:
      repoURL: https://github.com/partojalili/ocp-hcp-gitops.git
      revision: main
      directories:
        - path: clusters/gcp/*
      # Read values from a config file in each directory
      files:
        - path: clusters/gcp/*/config.json
```

### Filter Specific Clusters

Exclude certain directories:

```yaml
directories:
  - path: clusters/gcp/*
    exclude: clusters/gcp/test-*
```

## Troubleshooting

### Application Not Created

**Check ApplicationSet status:**
```bash
oc describe applicationset gcp-openshift-clusters -n openshift-gitops
```

**Common issues:**
- Directory doesn't exist in Git
- ApplicationSet controller not running
- Git authentication issues

### Application Out of Sync

**Check application status:**
```bash
oc get application gcp-cluster-<name> -n openshift-gitops
```

**Force refresh:**
```bash
argocd app sync gcp-cluster-<name>
```

### Multiple Applications for Same Cluster

This shouldn't happen, but if it does:
- Check for duplicate directories in `clusters/gcp/`
- Ensure directory names are unique
- Delete duplicate Applications manually

## Best Practices

1. **Use consistent naming**: `<environment>-<region>-<purpose>` (e.g., `prod-us-east1-api`)
2. **Document each cluster**: Maintain detailed README.md in each cluster directory
3. **Version control everything**: All cluster configs should be in Git
4. **Use pull requests**: Review cluster changes before merging
5. **Monitor sync status**: Set up alerts for out-of-sync applications

## Security Considerations

- **Credentials**: Never commit secrets to Git - use Sealed Secrets or External Secrets
- **RBAC**: Limit who can merge to main branch
- **Audit**: Review Git history for cluster configuration changes
- **Backup**: Ensure cluster configs are backed up (Git serves as backup)

## Integration with Other Tools

### ArgoCD Notifications

Enable notifications for cluster sync events:

```yaml
metadata:
  annotations:
    notifications.argoproj.io/subscribe.on-sync-succeeded.slack: dev-ops-channel
```

### External Secrets Operator

Reference secrets from external vaults:

```yaml
# In cluster directory
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: gcp-credentials
```

## References

- [ArgoCD ApplicationSet Documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/)
- [Git Generator Documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Git/)
- [OpenShift GitOps](https://docs.openshift.com/container-platform/latest/cicd/gitops/understanding-openshift-gitops.html)
