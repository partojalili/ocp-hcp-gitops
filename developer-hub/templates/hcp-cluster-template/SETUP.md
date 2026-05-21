# Quick Setup Guide

## What Changed

The HCP cluster template now **automatically seals secrets** before committing them to Git. This means:

✅ Pull secrets and SSH keys are encrypted using Sealed Secrets  
✅ Only encrypted data is stored in your Git repository  
✅ Secrets can only be decrypted by the target OpenShift cluster  
✅ Safe to store in public or private Git repos without exposing credentials  

## Prerequisites Setup

### 1. Install Kubeseal CLI

**macOS:**
```bash
brew install kubeseal
```

**Linux:**
```bash
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz
tar -xvzf kubeseal-0.24.0-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

Verify installation:
```bash
kubeseal --version
```

### 2. Verify Sealed Secrets Controller

Check that the controller is running on your management cluster:

```bash
oc get pods -n sealed-secrets
oc get svc -n sealed-secrets sealed-secrets-controller
```

If not installed:
```bash
oc apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
```

### 3. Configure Backstage (Developer Hub)

The template uses the `shell:command` action which requires a plugin.

**Option A: If you control the Backstage installation**

Add to `packages/backend/package.json`:
```json
{
  "dependencies": {
    "@backstage/plugin-scaffolder-backend-module-exec": "^0.2.0"
  }
}
```

Update `packages/backend/src/index.ts`:
```typescript
backend.add(import('@backstage/plugin-scaffolder-backend-module-exec'));
```

**Option B: Manual sealing (if exec plugin not available)**

If the Backstage instance doesn't have the exec plugin, you can seal secrets manually after the template runs:

```bash
cd /path/to/generated/cluster/folder

# Run the sealing script
../../../developer-hub/templates/hcp-cluster-template/seal-secrets.sh \
  "cluster-name" \
  "$(cat pull-secret.json)" \
  "$(cat ~/.ssh/id_rsa.pub)"

# Commit and push the sealed secrets
git add base/pull-secret.yaml base/ssh-key.yaml
git commit -m "Seal secrets for cluster"
git push
```

## How to Use

### Using the Template

1. Open Red Hat Developer Hub
2. Navigate to "Create" → "HCP Cluster Template"
3. Fill in the form:
   - **Cluster Name**: e.g., `dev-cluster`
   - **Base Domain**: e.g., `apps.cluster-abc.redhat.com`
   - **Pull Secret**: Paste from https://console.redhat.com/openshift/install/pull-secret
   - **SSH Public Key**: Paste from `~/.ssh/id_rsa.pub`
   - **Worker configuration**: nodes, CPU, memory
4. Click "Create"

The template will:
- Generate cluster manifests
- **Seal the secrets using Kubeseal** ← NEW!
- Create a pull request with sealed secrets
- Trigger ArgoCD deployment

### Verifying Sealed Secrets

After the PR is created, check the generated files:

```bash
# Clone/pull the repo
cd clusters/your-cluster-name/base

# Check that secrets are SealedSecrets
head pull-secret.yaml
# Should show: kind: SealedSecret (not kind: Secret)

head ssh-key.yaml
# Should show: kind: SealedSecret (not kind: Secret)
```

## Troubleshooting

### Error: "kubeseal: command not found"

Install kubeseal (see step 1 above) or use manual sealing method.

### Error: "cannot get sealed secret controller service"

The Sealed Secrets controller is not running. Install it:
```bash
oc apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
```

### Error: "shell:command action not found"

The Backstage exec plugin is not installed. Use manual sealing (Option B above).

### Secrets not being decrypted in cluster

Check the Sealed Secrets controller logs:
```bash
oc logs -n sealed-secrets -l name=sealed-secrets-controller -f
```

Verify the SealedSecret was created:
```bash
oc get sealedsecrets -n clusters-your-cluster-name
oc get secrets -n clusters-your-cluster-name
```

## Files Modified

| File | Changes |
|------|---------|
| `template.yaml` | Added `sshPublicKey` parameter, added `seal-secrets` step |
| `skeleton/base/ssh-key.yaml` | Updated to use `${{ values.sshPublicKey }}` |
| `seal-secrets.sh` | New standalone script for manual sealing |
| `README.md` | Full documentation |

## Next Steps

1. Test the template in Developer Hub
2. Verify sealed secrets are created
3. Confirm secrets are decrypted in the target namespace
4. Monitor the cluster provisioning process

## Support

- [Sealed Secrets Documentation](https://github.com/bitnami-labs/sealed-secrets)
- [Backstage Scaffolder Docs](https://backstage.io/docs/features/software-templates/)
- [HyperShift Documentation](https://hypershift-docs.netlify.app/)
