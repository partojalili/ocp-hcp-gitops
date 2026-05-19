# Sealed Secrets Guide

This repository uses **Sealed Secrets** to safely store sensitive data in Git without exposing credentials.

## ⚠️ Important: Generic Secret Naming

As of the latest version, this repository uses **generic, version-agnostic secret names**:
- `hcp-pull-secret` (instead of `ocp420-hcp-pull-secret`)
- `hcp-ssh-key` (instead of `ocp420-hcp-ssh-key`)

**If you have existing sealed secrets**, you need to **regenerate them** using the updated script:
```bash
./scripts/seal-secrets.sh
```

This ensures your secrets work with the new naming convention.

## What are Sealed Secrets?

Sealed Secrets is a Kubernetes controller that allows you to encrypt secrets so they can be safely committed to Git. Only the controller running in your cluster can decrypt them.

**Benefits**:
- ✅ Safe to commit to public/private Git repositories
- ✅ GitOps-friendly (declarative secrets management)
- ✅ Encrypted with cluster-specific keys
- ✅ No manual secret management needed

## Architecture

```
┌─────────────────┐
│  Pull Secret    │
│  (plaintext)    │
└────────┬────────┘
         │
         │ kubeseal
         │ (encrypts)
         ▼
┌─────────────────┐
│ SealedSecret    │
│  (encrypted)    │  ─────► Git Repository (safe!)
└────────┬────────┘
         │
         │ Deploy to cluster
         ▼
┌─────────────────┐
│ Sealed Secrets  │
│  Controller     │ ─────► Decrypts SealedSecret
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Regular Secret  │
│  (usable)       │  ─────► Used by HostedCluster
└─────────────────┘
```

## Prerequisites

### 1. Install Sealed Secrets Controller

The controller must be installed on your **ACM hub cluster**:

```bash
# Install the controller
oc apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.36.6/controller.yaml

# Wait for it to be ready
oc wait --for=condition=Available deployment/sealed-secrets-controller -n kube-system --timeout=300s

# Verify installation
oc get deployment sealed-secrets-controller -n kube-system
```

### 2. Install kubeseal CLI

Install the `kubeseal` command-line tool:

**macOS**:
```bash
brew install kubeseal
```

**Linux**:
```bash
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.36.6/kubeseal-0.36.6-linux-amd64.tar.gz
tar -xvzf kubeseal-0.36.6-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

**Verify**:
```bash
kubeseal --version
```

## Quick Start (Automated)

Use the provided helper script:

```bash
cd ocp-hcp-gitops

# 1. Download your pull secret to this directory
# From: https://console.redhat.com/openshift/install/pull-secret
# Save as: pull-secret.txt

# 2. Generate SSH key (if you haven't already)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/ocp420-hcp -N ""

# 3. Run the sealing script
./scripts/seal-secrets.sh

# 4. Commit the sealed secrets (safe!)
git add base/pull-secret-sealed.yaml base/ssh-key-sealed.yaml
git commit -m "Add sealed secrets for OCP 4.20 HCP deployment"
git push
```

## Manual Process

If you prefer to seal secrets manually:

### Seal Pull Secret

```bash
# 1. Create a temporary secret (dry-run, not applied)
oc create secret docker-registry ocp420-hcp-pull-secret \
  --from-file=.dockerconfigjson=pull-secret.txt \
  --namespace=clusters \
  --dry-run=client -o yaml > pull-secret-temp.yaml

# 2. Seal the secret
kubeseal --format=yaml < pull-secret-temp.yaml > base/pull-secret-sealed.yaml

# 3. Clean up temporary file
rm pull-secret-temp.yaml

# 4. Verify the sealed secret
cat base/pull-secret-sealed.yaml
```

### Seal SSH Key

```bash
# 1. Create a temporary secret
oc create secret generic ocp420-hcp-ssh-key \
  --from-file=id_rsa.pub=~/.ssh/ocp420-hcp.pub \
  --namespace=clusters \
  --dry-run=client -o yaml > ssh-key-temp.yaml

# 2. Seal the secret
kubeseal --format=yaml < ssh-key-temp.yaml > base/ssh-key-sealed.yaml

# 3. Clean up
rm ssh-key-temp.yaml
```

## Using a Specific Sealed Secrets Controller

If you have multiple clusters or a specific controller:

```bash
# Fetch the public key from the controller
kubeseal --fetch-cert \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system > pub-cert.pem

# Seal using the specific certificate
kubeseal --cert=pub-cert.pem --format=yaml < secret.yaml > sealed-secret.yaml
```

## Deployment

Once your sealed secrets are created and committed to Git:

### Option 1: GitOps (ArgoCD)

ArgoCD will automatically:
1. Sync the `SealedSecret` resources to the cluster
2. The Sealed Secrets controller decrypts them
3. Regular `Secret` resources are created
4. HostedCluster uses the decrypted secrets

```bash
oc apply -f argocd/application.yaml
```

### Option 2: Direct Kustomize

```bash
oc apply -k overlays/production/
```

The `SealedSecret` resources will be created, then automatically decrypted by the controller.

## Verification

Check that secrets are properly decrypted:

```bash
# Check SealedSecret resource
oc get sealedsecret -n clusters

# Check that regular Secret was created
oc get secret ocp420-hcp-pull-secret -n clusters
oc get secret ocp420-hcp-ssh-key -n clusters

# Verify secret content (be careful - this shows the decrypted data!)
oc get secret ocp420-hcp-pull-secret -n clusters -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq .
```

## Updating Sealed Secrets

If you need to update a secret:

```bash
# 1. Create new temporary secret with updated data
oc create secret docker-registry ocp420-hcp-pull-secret \
  --from-file=.dockerconfigjson=new-pull-secret.txt \
  --namespace=clusters \
  --dry-run=client -o yaml > pull-secret-temp.yaml

# 2. Seal it
kubeseal --format=yaml < pull-secret-temp.yaml > base/pull-secret-sealed.yaml

# 3. Clean up
rm pull-secret-temp.yaml

# 4. Commit and push
git add base/pull-secret-sealed.yaml
git commit -m "Update pull secret"
git push
```

ArgoCD will detect the change and re-sync, or manually apply:
```bash
oc apply -k overlays/production/
```

## Rotating Sealed Secrets Keys

The Sealed Secrets controller generates a new key every 30 days by default, but keeps old keys to decrypt existing secrets.

To manually rotate:
```bash
# Delete the old key (creates a new one automatically)
oc delete secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key

# Re-seal all your secrets with the new key
./scripts/seal-secrets.sh
```

## Troubleshooting

### SealedSecret not decrypting

**Check controller logs**:
```bash
oc logs -n kube-system deployment/sealed-secrets-controller
```

**Common issues**:
- Controller not running: `oc get deployment -n kube-system sealed-secrets-controller`
- Wrong namespace: Ensure `SealedSecret` and target `Secret` are in the same namespace
- Certificate mismatch: Re-seal using the current cluster certificate

### Cannot seal secret

**Error**: `cannot fetch certificate: error fetching certificate`

**Solution**: Ensure Sealed Secrets controller is running:
```bash
oc get pods -n kube-system | grep sealed-secrets
```

### Secret not appearing after applying SealedSecret

**Check events**:
```bash
oc get events -n clusters --sort-by='.lastTimestamp' | grep -i sealed
```

**Check SealedSecret status**:
```bash
oc describe sealedsecret ocp420-hcp-pull-secret -n clusters
```

## Security Best Practices

1. ✅ **Never commit plaintext secrets** to Git
   - Use `.gitignore` to exclude `pull-secret.txt`, `*-temp.yaml`

2. ✅ **Sealed secrets are cluster-specific**
   - Don't reuse sealed secrets across different clusters
   - Re-seal for each target cluster

3. ✅ **Rotate secrets regularly**
   - Update pull secrets when they expire
   - Re-seal and commit updated secrets

4. ✅ **Backup encryption keys**
   - Export sealed secrets keys for disaster recovery:
     ```bash
     oc get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > sealed-secrets-keys-backup.yaml
     ```
   - Store backup in a secure location (NOT in Git!)

5. ✅ **Use RBAC**
   - Restrict who can view/modify secrets in the cluster
   - SealedSecrets can be viewed by anyone, but only the controller can decrypt

## Files in This Repository

| File | Purpose | Safe to Commit? |
|------|---------|-----------------|
| `base/pull-secret-sealed.yaml` | Encrypted pull secret | ✅ Yes |
| `base/ssh-key-sealed.yaml` | Encrypted SSH key | ✅ Yes |
| `pull-secret.txt` | Plaintext pull secret | ❌ No (gitignored) |
| `pull-secret-temp.yaml` | Temporary unsealed secret | ❌ No (gitignored) |
| `scripts/seal-secrets.sh` | Helper script to seal secrets | ✅ Yes |

## Resources

- [Sealed Secrets GitHub](https://github.com/bitnami-labs/sealed-secrets)
- [Sealed Secrets Documentation](https://github.com/bitnami-labs/sealed-secrets#readme)
- [kubeseal Releases](https://github.com/bitnami-labs/sealed-secrets/releases)

## Alternative: External Secrets Operator

If you prefer using external secret management systems (Vault, AWS Secrets Manager, etc.), consider:
- [External Secrets Operator](https://external-secrets.io/)

For most GitOps use cases, Sealed Secrets provides the best balance of security and simplicity.
