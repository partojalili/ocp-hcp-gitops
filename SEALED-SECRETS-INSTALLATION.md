# Sealed Secrets Installation Guide

This guide will walk you through installing Sealed Secrets on your OpenShift cluster.

## What is Sealed Secrets?

Sealed Secrets allows you to encrypt Kubernetes secrets so they can be safely stored in Git repositories. Only the Sealed Secrets controller running in your cluster can decrypt them.

## Prerequisites

- OpenShift cluster with admin access
- `oc` CLI installed and logged in
- `kubectl` CLI installed (optional, but recommended)

## Installation Steps

### Step 1: Install Sealed Secrets Controller

Install the Sealed Secrets controller on your cluster:

```bash
# Install the latest version of Sealed Secrets controller
oc apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.36.6/controller.yaml

# Wait for the controller to be ready
oc wait --for=condition=Available deployment/sealed-secrets-controller -n kube-system --timeout=300s
```

**Verify installation:**

```bash
# Check the controller pod is running
oc get pods -n kube-system -l name=sealed-secrets-controller

# Expected output:
# NAME                                         READY   STATUS    RESTARTS   AGE
# sealed-secrets-controller-xxxxxxxxxx-xxxxx   1/1     Running   0          1m

# Check the service
oc get svc -n kube-system sealed-secrets-controller

# Check the deployment
oc get deployment -n kube-system sealed-secrets-controller
```

### Step 2: Install kubeseal CLI Tool

The `kubeseal` CLI is used to encrypt secrets.

**macOS:**

```bash
# Using Homebrew
brew install kubeseal
```

**Linux:**

```bash
# Download and install kubeseal
KUBESEAL_VERSION='0.36.6'
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz

# Extract
tar -xvzf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal

# Install to /usr/local/bin
sudo install -m 755 kubeseal /usr/local/bin/kubeseal

# Clean up
rm kubeseal kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz
```

**Windows:**

Download the Windows binary from:
https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.36.6/kubeseal-0.36.6-windows-amd64.tar.gz

**Verify installation:**

```bash
kubeseal --version

# Expected output:
# kubeseal version: v0.36.6
```

### Step 3: Test Sealed Secrets

Create a test secret and seal it:

```bash
# Create a test namespace
oc create namespace test-sealed-secrets

# Create a regular secret (don't commit this!)
echo -n "super-secret-password" | oc create secret generic test-secret \
  --dry-run=client \
  --from-file=password=/dev/stdin \
  -n test-sealed-secrets \
  -o yaml > /tmp/test-secret.yaml

# Seal the secret
kubeseal -f /tmp/test-secret.yaml -o yaml > /tmp/test-sealed-secret.yaml

# Apply the sealed secret
oc apply -f /tmp/test-sealed-secret.yaml

# Wait a moment for the controller to decrypt it
sleep 5

# Verify the regular secret was created
oc get secret test-secret -n test-sealed-secrets

# Expected output:
# NAME          TYPE     DATA   AGE
# test-secret   Opaque   1      5s

# Verify the content
oc get secret test-secret -n test-sealed-secrets -o jsonpath='{.data.password}' | base64 -d
# Should output: super-secret-password
```

**Clean up test resources:**

```bash
oc delete namespace test-sealed-secrets
rm /tmp/test-secret.yaml /tmp/test-sealed-secret.yaml
```

## Usage Examples

### Sealing a Pull Secret

```bash
# Assuming you have a pull secret file: pull-secret.txt
oc create secret generic my-pull-secret \
  --from-file=.dockerconfigjson=pull-secret.txt \
  --type=kubernetes.io/dockerconfigjson \
  --dry-run=client \
  -n my-namespace \
  -o yaml | kubeseal -o yaml > sealed-pull-secret.yaml

# Now you can safely commit sealed-pull-secret.yaml to Git
git add sealed-pull-secret.yaml
```

### Sealing an SSH Key

```bash
# Seal an SSH public key
oc create secret generic my-ssh-key \
  --from-file=ssh-publickey=~/.ssh/id_rsa.pub \
  --dry-run=client \
  -n my-namespace \
  -o yaml | kubeseal -o yaml > sealed-ssh-key.yaml

# Safe to commit
git add sealed-ssh-key.yaml
```

### Using a Different Namespace/Name

When sealing, you must specify the exact namespace and name where the secret will be created:

```bash
kubeseal \
  --namespace my-namespace \
  --name my-secret-name \
  -f secret.yaml \
  -o yaml > sealed-secret.yaml
```

## Important Notes

### Scope and Constraints

By default, Sealed Secrets are **namespace and name scoped**:
- The sealed secret can ONLY be decrypted in the namespace specified during sealing
- The secret name must match what was specified during sealing

**To change scope:**

```bash
# Cluster-wide (can be decrypted in any namespace with any name)
kubeseal --scope cluster-wide -f secret.yaml -o yaml

# Namespace-wide (can be decrypted in the specified namespace with any name)
kubeseal --scope namespace-wide -f secret.yaml -o yaml

# Strict (default - specific namespace and name)
kubeseal --scope strict -f secret.yaml -o yaml
```

### Backup Your Keys

The Sealed Secrets controller generates a key pair. If you lose this key, you cannot decrypt your sealed secrets!

**Backup the sealing key:**

```bash
# Backup the sealing key
oc get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > sealed-secrets-key-backup.yaml

# Store this file in a SECURE location (NOT in Git!)
# You'll need it to restore if you rebuild the cluster
```

**Restore the sealing key:**

```bash
# Restore from backup
oc apply -f sealed-secrets-key-backup.yaml

# Restart the controller to pick up the key
oc rollout restart deployment/sealed-secrets-controller -n kube-system
```

## Troubleshooting

### Secret Not Being Created

```bash
# Check controller logs
oc logs -n kube-system -l name=sealed-secrets-controller

# Common issues:
# 1. Namespace doesn't exist
# 2. Sealed secret has wrong namespace/name scope
# 3. Sealed secret was encrypted with a different cluster's key
```

### Cannot Seal Secrets (Connection Error)

```bash
# Verify you can reach the controller
oc get svc -n kube-system sealed-secrets-controller

# Try specifying the controller URL explicitly
kubeseal --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  -f secret.yaml -o yaml
```

### Re-sealing Secrets After Key Rotation

If the sealing key changes (cluster rebuild, key rotation), you need to re-seal all secrets:

```bash
# Fetch the new public cert
kubeseal --fetch-cert > pub-cert.pem

# Re-seal using the new cert
kubeseal --cert pub-cert.pem -f secret.yaml -o yaml > new-sealed-secret.yaml
```

## Upgrading

To upgrade Sealed Secrets controller:

```bash
# Apply the new version
oc apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v<NEW_VERSION>/controller.yaml

# Wait for rollout
oc rollout status deployment/sealed-secrets-controller -n kube-system
```

## Uninstallation

To remove Sealed Secrets:

```bash
# WARNING: This will make all SealedSecrets unrecoverable!
# Backup your sealing key first!

# Delete the controller
oc delete -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.36.6/controller.yaml

# Delete any sealed secrets in your cluster
oc get sealedsecrets -A -o json | \
  jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' | \
  while read ns name; do oc delete sealedsecret $name -n $ns; done
```

## References

- [Sealed Secrets GitHub](https://github.com/bitnami-labs/sealed-secrets)
- [Sealed Secrets Documentation](https://sealed-secrets.netlify.app/)
- [Release Notes](https://github.com/bitnami-labs/sealed-secrets/releases)

## Next Steps

After installing Sealed Secrets, see:
- [SEAL-SECRETS-USAGE.md](./SEAL-SECRETS-USAGE.md) - How to use sealed secrets in this repository
- [SEAL-SECRETS-AFTER-PR.md](./SEAL-SECRETS-AFTER-PR.md) - Sealing secrets after PR merge
