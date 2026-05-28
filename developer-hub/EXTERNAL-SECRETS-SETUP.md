# External Secrets Operator Setup

This guide explains how the automated secret management works using External Secrets Operator, eliminating the need for manual secret sealing.

## Overview

**Old Workflow (Manual):**
1. Developer Hub creates PR with plain-text secrets
2. **Manual step:** Run `seal-pr-secrets.sh` script
3. Commit sealed secrets
4. Merge PR
5. ArgoCD deploys cluster

**New Workflow (Fully Automated):**
1. Developer Hub creates PR with ExternalSecret resources
2. **Merge PR immediately** - no manual steps!
3. ArgoCD deploys ExternalSecret resources
4. External Secrets Operator automatically creates Kubernetes Secrets
5. Cluster provisions automatically

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Developer Hub                                               │
│  - User fills out form (no secrets required!)              │
│  - Creates PR with ExternalSecret YAML                     │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ GitHub Repository                                           │
│  - PR contains ExternalSecret resources (safe to commit!)  │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ ArgoCD                                                      │
│  - Syncs ExternalSecret resources to cluster                │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ External Secrets Operator                                   │
│  - Reads ExternalSecret resources                          │
│  - Fetches secrets from hcp-secrets namespace               │
│  - Creates Kubernetes Secrets in cluster namespace         │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ HostedCluster                                               │
│  - Uses auto-created pull secret and SSH key               │
│  - Provisions successfully                                  │
└─────────────────────────────────────────────────────────────┘
```

## Components Installed

### 1. External Secrets Operator
- **Namespace:** `external-secrets-operator`
- **Purpose:** Syncs secrets from various backends to Kubernetes
- **Installation:** Helm chart
- **Version:** Latest stable

### 2. Central Secrets Namespace
- **Namespace:** `hcp-secrets`
- **Purpose:** Stores source secrets (pull secret, SSH key)
- **Access:** Read-only for External Secrets Operator

### 3. ClusterSecretStore
- **Name:** `hcp-secrets-store`
- **Type:** Kubernetes backend
- **Scope:** Cluster-wide (all namespaces can use it)
- **Source:** `hcp-secrets` namespace

## Stored Secrets

### Pull Secret
- **Source Secret:** `ocp-pull-secret` in `hcp-secrets` namespace
- **Type:** `kubernetes.io/dockerconfigjson`
- **Content:** Your Red Hat pull secret
- **Synced to:** Each cluster namespace as `<cluster-name>-pull-secret`

### SSH Key
- **Source Secret:** `ocp-ssh-key` in `hcp-secrets` namespace
- **Type:** `Opaque`
- **Content:** SSH public key for node access
- **Synced to:** Each cluster namespace as `<cluster-name>-ssh-key`

## How ExternalSecrets Work

When you provision a cluster, the template creates two ExternalSecret resources:

### Pull Secret ExternalSecret
```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: devhub3-pull-secret
  namespace: clusters-devhub3
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: hcp-secrets-store
    kind: ClusterSecretStore
  target:
    name: devhub3-pull-secret
    creationPolicy: Owner
    template:
      type: kubernetes.io/dockerconfigjson
  dataFrom:
    - extract:
        key: ocp-pull-secret
```

### SSH Key ExternalSecret
```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: devhub3-ssh-key
  namespace: clusters-devhub3
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: hcp-secrets-store
    kind: ClusterSecretStore
  target:
    name: devhub3-ssh-key
    creationPolicy: Owner
  data:
    - secretKey: id_rsa.pub
      remoteRef:
        key: ocp-ssh-key
        property: ssh-publickey
```

The External Secrets Operator watches these resources and automatically:
1. Fetches the secret from `hcp-secrets` namespace
2. Creates the target secret in the cluster namespace
3. Refreshes every hour to detect any updates
4. Maintains the secret lifecycle (updates, deletes)

## Verification

### Check External Secrets Operator Status
```bash
# Check ESO pods
oc get pods -n external-secrets-operator

# Should show:
# external-secrets-*                   1/1     Running
# external-secrets-cert-controller-*   1/1     Running
# external-secrets-webhook-*           1/1     Running
```

### Check ClusterSecretStore
```bash
oc get clustersecretstore hcp-secrets-store

# Should show:
# NAME                AGE   STATUS   READY
# hcp-secrets-store   ...   Valid    True
```

### Check Source Secrets
```bash
# List secrets in central store
oc get secrets -n hcp-secrets

# Should show:
# ocp-pull-secret   kubernetes.io/dockerconfigjson
# ocp-ssh-key       Opaque
```

### Check ExternalSecret for a Cluster
```bash
# Replace devhub3 with your cluster name
oc get externalsecret -n clusters-devhub3

# Should show:
# NAME                    STORE               STATUS         READY
# devhub3-pull-secret     hcp-secrets-store   SecretSynced   True
# devhub3-ssh-key         hcp-secrets-store   SecretSynced   True
```

### Verify Synced Secrets
```bash
# Check that secrets were created
oc get secrets -n clusters-devhub3 | grep -E "pull-secret|ssh-key"

# Should show:
# devhub3-pull-secret   kubernetes.io/dockerconfigjson
# devhub3-ssh-key       Opaque
```

## Updating Central Secrets

If you need to update the pull secret or SSH key:

### Update Pull Secret
```bash
# Update the secret
oc create secret generic ocp-pull-secret \
  --from-file=.dockerconfigjson=new-pull-secret.txt \
  --type=kubernetes.io/dockerconfigjson \
  -n hcp-secrets \
  --dry-run=client -o yaml | oc apply -f -

# External Secrets Operator will sync to all clusters within 1 hour
# Or force immediate sync:
oc annotate externalsecret <cluster-name>-pull-secret \
  -n clusters-<cluster-name> \
  force-sync="$(date +%s)" --overwrite
```

### Update SSH Key
```bash
# Update the secret
oc create secret generic ocp-ssh-key \
  --from-file=ssh-publickey=new-key.pub \
  -n hcp-secrets \
  --dry-run=client -o yaml | oc apply -f -

# Syncs automatically within 1 hour
```

## Troubleshooting

### ExternalSecret Shows "SecretSyncedError"
```bash
# Check ExternalSecret status
oc describe externalsecret <name> -n <namespace>

# Common issues:
# 1. Source secret doesn't exist in hcp-secrets namespace
# 2. ClusterSecretStore not ready
# 3. Permission issues

# Fix: Verify source secret exists
oc get secret ocp-pull-secret -n hcp-secrets
oc get secret ocp-ssh-key -n hcp-secrets
```

### Secret Not Created
```bash
# Check ESO logs
oc logs -n external-secrets-operator deployment/external-secrets

# Check if ClusterSecretStore is ready
oc get clustersecretstore hcp-secrets-store

# Verify permissions
oc get rolebinding -n hcp-secrets | grep external-secrets
```

### Cluster Provisioning Fails with "Secret Not Found"
```bash
# Check if ExternalSecret created the secret
oc get secret <cluster-name>-pull-secret -n clusters-<cluster-name>

# If missing, check ExternalSecret status
oc get externalsecret <cluster-name>-pull-secret -n clusters-<cluster-name>

# Force sync
oc annotate externalsecret <cluster-name>-pull-secret \
  -n clusters-<cluster-name> \
  force-sync="$(date +%s)" --overwrite
```

## Security Considerations

### ✅ Secure
- Secrets stored in `hcp-secrets` namespace (access controlled)
- ExternalSecret resources don't contain secrets (safe in Git)
- RBAC controls who can read source secrets
- Secrets encrypted at rest in etcd

### ⚠️ Considerations
- This setup uses Kubernetes secrets as the backend
- For production, consider upgrading to HashiCorp Vault
- Regularly rotate pull secrets and SSH keys
- Limit access to `hcp-secrets` namespace

## Migration from SealedSecrets

If you have existing clusters using SealedSecrets:

### They Continue Working
- Existing SealedSecret resources still work
- No migration required for running clusters
- New clusters automatically use ExternalSecrets

### To Migrate (Optional)
1. Keep the running cluster as-is
2. Delete and recreate cluster using new template
3. Or manually replace SealedSecrets with ExternalSecrets

## Future Enhancements

### Upgrade to HashiCorp Vault (Production)

For production environments, upgrade to Vault:

1. **Install Vault**
2. **Migrate secrets from Kubernetes to Vault**
3. **Update ClusterSecretStore to use Vault backend**
4. **No changes to ExternalSecret resources needed!**

The ExternalSecret resources remain the same - only the backend changes.

## Summary

**Benefits of this approach:**
- ✅ **Zero manual steps** - fully automated workflow
- ✅ **Secrets never in Git** - only ExternalSecret references
- ✅ **Central management** - update once, sync everywhere
- ✅ **Automatic rotation** - update source, all clusters get it
- ✅ **Simplified template** - no secret form fields
- ✅ **Better security** - secrets centrally controlled
- ✅ **Production-ready** - easily upgrade to Vault

**What's different for users:**
- ❌ **No longer paste secrets** in Developer Hub form
- ❌ **No manual sealing step** required
- ✅ **Just merge the PR** - everything else is automatic!

## Support

For issues or questions:
- Check ExternalSecret status: `oc get externalsecret -A`
- Check ESO logs: `oc logs -n external-secrets-operator deployment/external-secrets`
- Verify ClusterSecretStore: `oc get clustersecretstore`
