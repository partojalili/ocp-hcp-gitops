# Using seal-secrets.sh - Cluster Secrets Helper

This script automates sealing your OpenShift pull secret and SSH key for HCP cluster provisioning.

## Prerequisites

1. **kubeseal installed:**
   ```bash
   # macOS
   brew install kubeseal
   
   # Linux
   wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.36.6/kubeseal-0.36.6-linux-amd64.tar.gz
   tar -xvzf kubeseal-0.36.6-linux-amd64.tar.gz kubeseal
   sudo install -m 755 kubeseal /usr/local/bin/kubeseal
   ```

2. **OpenShift pull secret downloaded:**
   - Go to: https://console.redhat.com/openshift/install/pull-secret
   - Click "Download pull secret"
   - Save as `pull-secret.txt` or `pull-secret.json`

3. **Logged into OpenShift cluster:**
   ```bash
   oc login --token=YOUR_TOKEN --server=https://api.cluster.example.com:6443
   ```

4. **SSH key (optional but recommended):**
   - The script will auto-detect keys in `~/.ssh/`
   - Looks for: `id_rsa.pub`, `id_ed25519.pub`, or `id_ecdsa.pub`

---

## Step-by-Step Usage

### Step 1: Navigate to Repository Root

```bash
cd ~/ocp-hcp-gitops
```

### Step 2: Place Your Pull Secret

Download and place your pull secret in the repository root:

```bash
# Download from https://console.redhat.com/openshift/install/pull-secret
# Save to ~/Downloads/pull-secret.txt

# Move to repository root
mv ~/Downloads/pull-secret.txt ~/ocp-hcp-gitops/pull-secret.txt
```

**OR if you downloaded JSON format:**
```bash
mv ~/Downloads/pull-secret.json ~/ocp-hcp-gitops/pull-secret.json
```

### Step 3: Make Script Executable

```bash
chmod +x scripts/seal-secrets.sh
```

### Step 4: Run the Script

```bash
./scripts/seal-secrets.sh
```

**Expected output:**
```
==========================================
Sealed Secrets Helper Script
==========================================

✓ Connected to cluster: https://api.cluster-gzk6k.dynamic2.redhatworkshops.io:6443

✓ Sealed Secrets controller found

==========================================
1. Sealing Pull Secret
==========================================

Found pull secret: pull-secret.txt
Creating temporary secret...
Sealing secret...
✓ Created base/pull-secret-sealed.yaml

==========================================
2. Sealing SSH Key (optional)
==========================================

Found SSH key: /Users/pjalili/.ssh/id_rsa.pub
Creating temporary secret...
Sealing secret...
✓ Created base/ssh-key-sealed.yaml

==========================================
✅ Success!
==========================================

Sealed secrets created:
  - base/pull-secret-sealed.yaml
  - base/ssh-key-sealed.yaml

These sealed secrets are SAFE to commit to Git!
```

### Step 5: Review Generated Files

```bash
# Check the sealed secrets
cat base/pull-secret-sealed.yaml | head -20
cat base/ssh-key-sealed.yaml | head -20
```

You should see encrypted data like:
```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: hcp-pull-secret
  namespace: clusters
spec:
  encryptedData:
    .dockerconfigjson: AgA8j3k2l... [encrypted data]
```

### Step 6: Delete Plain Text Secrets

**Important:** Remove the unencrypted pull secret file!

```bash
# Delete plain text files (DO NOT COMMIT THESE!)
rm pull-secret.txt  # or pull-secret.json
```

### Step 7: Commit to Git

```bash
# Add sealed secrets (safe to commit - they're encrypted!)
git add base/pull-secret-sealed.yaml
git add base/ssh-key-sealed.yaml

# Commit
git commit -m "Add sealed secrets for HCP cluster provisioning"

# Push to GitHub
git push origin main
```

---

## What the Script Does

1. **Checks prerequisites:**
   - Verifies `kubeseal` is installed
   - Confirms you're logged into OpenShift
   - Checks if Sealed Secrets controller is running

2. **Seals pull secret:**
   - Creates a temporary Kubernetes secret from your pull-secret file
   - Encrypts it using the cluster's Sealed Secrets controller
   - Saves to `base/pull-secret-sealed.yaml`
   - Deletes the temporary file

3. **Seals SSH key (optional):**
   - Auto-detects SSH public key in `~/.ssh/`
   - Creates and encrypts the secret
   - Saves to `base/ssh-key-sealed.yaml`

4. **Cleanup:**
   - Removes all temporary files
   - Leaves only the encrypted sealed secrets

---

## Troubleshooting

### Error: "kubeseal is not installed"

**Solution:**
```bash
# macOS
brew install kubeseal

# Verify installation
kubeseal --version
```

### Error: "Not logged into an OpenShift cluster"

**Solution:**
```bash
# Log in to your cluster
oc login --token=YOUR_TOKEN --server=https://api.cluster.example.com:6443

# Verify
oc whoami
```

### Error: "Sealed Secrets controller not found"

**Check which namespace it's in:**
```bash
oc get deployment -A | grep sealed-secrets-controller
```

**If it shows `kube-system`, you need to fix the script** (see below).

### Error: "pull-secret.txt or pull-secret.json not found"

**Solution:**
```bash
# Download from Red Hat Console
open https://console.redhat.com/openshift/install/pull-secret

# Save to repository root (not in downloads!)
cd ~/ocp-hcp-gitops
# Place pull-secret.txt here
```

### Error: "cannot get sealed secret service"

This means the script is looking in the wrong namespace.

**Fix the script:**
```bash
# Edit the script
nano scripts/seal-secrets.sh

# Find line 82 and 115, change:
kubeseal --format=yaml < pull-secret-temp.yaml > base/pull-secret-sealed.yaml

# To:
kubeseal --format=yaml \
  --controller-namespace=kube-system \
  --controller-name=sealed-secrets-controller \
  < pull-secret-temp.yaml > base/pull-secret-sealed.yaml

# And line 115:
kubeseal --format=yaml \
  --controller-namespace=kube-system \
  --controller-name=sealed-secrets-controller \
  < ssh-key-temp.yaml > base/ssh-key-sealed.yaml
```

### Warning: "No SSH public key found"

This is optional. The script will skip SSH key sealing.

**To generate an SSH key:**
```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
# Press Enter to accept defaults
# Re-run the script
```

---

## Security Notes

### ✅ SAFE to Commit to Git:
- `base/pull-secret-sealed.yaml` - Encrypted
- `base/ssh-key-sealed.yaml` - Encrypted

### ❌ NEVER Commit to Git:
- `pull-secret.txt` - Plain text credentials!
- `pull-secret.json` - Plain text credentials!
- Any file ending in `-temp.yaml` - Temporary secrets

### Why Sealed Secrets Are Safe:

1. **Encrypted specifically for your cluster**
   - Only YOUR cluster's Sealed Secrets controller can decrypt them
   - Even if someone steals the sealed secret, they can't use it

2. **Uses asymmetric encryption**
   - Your cluster has a private key
   - The sealed secret uses the public key
   - Only the cluster can decrypt

3. **Safe in public repositories**
   - You can commit these to GitHub
   - Share them in pull requests
   - No risk of credential exposure

---

## After Sealing Secrets

Your repository structure should look like:
```
ocp-hcp-gitops/
├── base/
│   ├── pull-secret-sealed.yaml    ✅ Encrypted, safe to commit
│   ├── ssh-key-sealed.yaml        ✅ Encrypted, safe to commit
│   ├── hostedcluster.yaml
│   ├── nodepool.yaml
│   └── kustomization.yaml
└── scripts/
    └── seal-secrets.sh
```

**Next steps:**
1. Deploy your HCP cluster using the sealed secrets
2. The Sealed Secrets controller will automatically decrypt them
3. Your cluster will use the credentials to provision

---

## Using with Developer Hub

These sealed secrets are referenced in your HCP cluster template.

When you submit a cluster provisioning form in Developer Hub:
1. Developer Hub commits cluster config to Git
2. ArgoCD syncs the config
3. Sealed Secrets controller decrypts the pull secret
4. HyperShift uses the credentials to create the cluster

**Full workflow:**
```
Developer Hub → Git commit → ArgoCD sync → Sealed secret decrypted → Cluster provisioned
```

---

## Additional Resources

- [Sealed Secrets GitHub](https://github.com/bitnami-labs/sealed-secrets)
- [Red Hat Pull Secret](https://console.redhat.com/openshift/install/pull-secret)
- [HyperShift Documentation](https://hypershift-docs.netlify.app/)
