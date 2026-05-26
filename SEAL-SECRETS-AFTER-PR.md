# How to Seal Secrets After Submitting Cluster Form

## Overview

When you submit a cluster provisioning request through Developer Hub, it creates a PR with **plain-text secrets**. You MUST seal these secrets before merging the PR.

## Why?

- **Plain-text secrets in Git = Security vulnerability**
- **Sealed secrets** can only be decrypted by your cluster's Sealed Secrets controller
- Safe to commit to public repositories

## Step-by-Step Instructions

### 1. Submit the Form in Developer Hub

Fill out the cluster provisioning form with:
- Cluster Name
- Base Domain  
- Pull Secret (from https://console.redhat.com/openshift/install/pull-secret)
- SSH Public Key
- Worker configuration

Click **Submit** → A PR will be created

### 2. Get the PR Number

Find the PR number from:
- The success page after submitting
- GitHub notifications
- Or run: `gh pr list --repo partojalili/ocp-hcp-gitops`

### 3. Checkout the PR

```bash
# Replace <PR-NUMBER> with your actual PR number
gh pr checkout <PR-NUMBER>
```

### 4. Navigate to Cluster Directory

```bash
# Replace <CLUSTER-NAME> with your cluster name
cd clusters/devhub/<CLUSTER-NAME>/base
```

### 5. Seal the Pull Secret

```bash
# Extract the pull secret from YAML and seal it
CLUSTER_NAME=$(basename $(dirname $(pwd)))

oc create secret docker-registry ${CLUSTER_NAME}-pull-secret \
  --from-literal=.dockerconfigjson="$(cat pull-secret.yaml | grep -A 100 '.dockerconfigjson:' | tail -n +2 | sed 's/^    //')" \
  --namespace=clusters-${CLUSTER_NAME} \
  --dry-run=client -o yaml | \
kubeseal --controller-namespace=kube-system \
  --controller-name=sealed-secrets-controller \
  --format=yaml > pull-secret-sealed.yaml
```

### 6. Seal the SSH Key

```bash
# Extract the SSH key from YAML and seal it
oc create secret generic ${CLUSTER_NAME}-ssh-key \
  --from-literal=id_rsa.pub="$(cat ssh-key.yaml | grep -A 100 'id_rsa.pub:' | tail -n +2 | sed 's/^    //')" \
  --namespace=clusters-${CLUSTER_NAME} \
  --dry-run=client -o yaml | \
kubeseal --controller-namespace=kube-system \
  --controller-name=sealed-secrets-controller \
  --format=yaml > ssh-key-sealed.yaml
```

### 7. Replace Plain-Text Secrets with Sealed Secrets

```bash
# Remove plain-text secrets
rm pull-secret.yaml ssh-key.yaml

# Rename sealed secrets
mv pull-secret-sealed.yaml pull-secret.yaml
mv ssh-key-sealed.yaml ssh-key.yaml
```

### 8. Commit and Push

```bash
git add pull-secret.yaml ssh-key.yaml
git commit -m "Seal secrets with Kubeseal"
git push
```

### 9. Merge the PR

```bash
gh pr merge --squash
```

Or merge through the GitHub web UI.

### 10. Monitor Cluster Deployment

```bash
# Watch ArgoCD sync
oc get application ${CLUSTER_NAME}-hosted-cluster -n openshift-gitops -w

# Watch HostedCluster status
oc get hostedcluster ${CLUSTER_NAME} -n clusters-${CLUSTER_NAME} -w

# Check control plane pods (after ~2-3 minutes)
oc get pods -n clusters-${CLUSTER_NAME}

# Watch worker VMs (after ~5-10 minutes)
watch "oc get vm -n clusters-${CLUSTER_NAME}"
```

## Timeline

- PR created: Instant
- Seal secrets: ~1 minute
- ArgoCD sync: ~2-3 minutes after merge
- Control plane ready: ~5 minutes
- Workers ready: ~10 minutes
- **Total: ~15-20 minutes**

## Simplified Script (All-in-One)

Save this as `seal-cluster-secrets.sh` and run it from the cluster base directory:

```bash
#!/bin/bash
set -e

CLUSTER_NAME=$(basename $(dirname $(pwd)))

echo "Sealing secrets for cluster: $CLUSTER_NAME"

# Seal pull secret
echo "Sealing pull secret..."
oc create secret docker-registry ${CLUSTER_NAME}-pull-secret \
  --from-literal=.dockerconfigjson="$(cat pull-secret.yaml | grep -A 100 '.dockerconfigjson:' | tail -n +2 | sed 's/^    //')" \
  --namespace=clusters-${CLUSTER_NAME} \
  --dry-run=client -o yaml | \
kubeseal --controller-namespace=kube-system \
  --controller-name=sealed-secrets-controller \
  --format=yaml > pull-secret-sealed.yaml

# Seal SSH key
echo "Sealing SSH key..."
oc create secret generic ${CLUSTER_NAME}-ssh-key \
  --from-literal=id_rsa.pub="$(cat ssh-key.yaml | grep -A 100 'id_rsa.pub:' | tail -n +2 | sed 's/^    //')" \
  --namespace=clusters-${CLUSTER_NAME} \
  --dry-run=client -o yaml | \
kubeseal --controller-namespace=kube-system \
  --controller-name=sealed-secrets-controller \
  --format=yaml > ssh-key-sealed.yaml

# Replace files
echo "Replacing plain-text secrets with sealed secrets..."
rm pull-secret.yaml ssh-key.yaml
mv pull-secret-sealed.yaml pull-secret.yaml
mv ssh-key-sealed.yaml ssh-key.yaml

echo "✅ Secrets sealed!"
echo
echo "Next steps:"
echo "  git add pull-secret.yaml ssh-key.yaml"
echo "  git commit -m 'Seal secrets with Kubeseal'"
echo "  git push"
echo "  gh pr merge --squash"
```

## Troubleshooting

### Error: "kubeseal: command not found"

Install kubeseal:
```bash
# macOS
brew install kubeseal

# Linux
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.36.6/kubeseal-0.36.6-linux-amd64.tar.gz
tar -xvzf kubeseal-0.36.6-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

### Error: "sealed-secrets-controller not found"

Check the controller namespace:
```bash
oc get deployment sealed-secrets-controller -n kube-system
```

If it's in a different namespace, update the `--controller-namespace` flag.

### Error: "Failed to extract secret from YAML"

Check the YAML structure:
```bash
cat pull-secret.yaml
```

The `.dockerconfigjson:` should be followed by the JSON data indented with spaces.

### Cannot checkout PR

Make sure you have GitHub CLI authenticated:
```bash
gh auth login
```

## Security Notes

### ✅ Safe to Commit
- Sealed secret files (after running kubeseal)
- Any file ending in `-sealed.yaml`
- ArgoCD application manifests
- HostedCluster and NodePool CRs

### ❌ NEVER Commit
- Plain-text `pull-secret.yaml` (before sealing)
- Plain-text `ssh-key.yaml` (before sealing)
- Pull secret JSON/TXT files
- SSH private keys

## Related Documentation

- [Developer Hub README](developer-hub/README.md)
- [Cluster Provisioning Guide](CLUSTER-PROVISIONING.md)
- [Sealed Secrets Usage](SEAL-SECRETS-USAGE.md)
