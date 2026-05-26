# Template Seal Secrets Script Guide

## Understanding the Different seal-secrets.sh Scripts

Your repository has **three** `seal-secrets.sh` scripts with different purposes:

### 1. `scripts/seal-secrets.sh` ✅ Main Script
**Purpose:** Seal secrets for the **base cluster configuration**  
**When to use:** When setting up your GitOps repository initially  
**Location:** `scripts/seal-secrets.sh`  
**What it seals:**
- Pull secret → `base/pull-secret-sealed.yaml`
- SSH key → `base/ssh-key-sealed.yaml`

**Usage:**
```bash
cd ~/ocp-hcp-gitops
./scripts/seal-secrets.sh
```

---

### 2. `developer-hub/templates/hcp-cluster-template/seal-secrets.sh`
**Purpose:** Manual sealing for template-generated clusters  
**When to use:** Rarely - only if you need to manually seal secrets for a specific cluster  
**Location:** `developer-hub/templates/hcp-cluster-template/seal-secrets.sh`

**Usage:**
```bash
cd developer-hub/templates/hcp-cluster-template

./seal-secrets.sh <cluster-name> "$(cat /path/to/pull-secret.json)" "$(cat ~/.ssh/id_rsa.pub)"

# Example:
./seal-secrets.sh my-cluster "$(cat ~/pull-secret.json)" "$(cat ~/.ssh/id_rsa.pub)"
```

**Note:** Developer Hub usually handles this automatically when you submit a form.

---

### 3. `hcp-template/scripts/seal-secrets.sh`
**Purpose:** Legacy/alternative template location  
**When to use:** Same as `scripts/seal-secrets.sh`  
**Location:** `hcp-template/scripts/seal-secrets.sh`

This is a duplicate of the main script for backwards compatibility.

---

## Which Script Should You Use?

### For Initial Setup → Use `scripts/seal-secrets.sh`

This is what you need for setting up secrets that will be used by clusters:

```bash
cd ~/ocp-hcp-gitops

# 1. Download pull secret to repository root
# From: https://console.redhat.com/openshift/install/pull-secret
# Save as: pull-secret.txt

# 2. Run the script
./scripts/seal-secrets.sh

# 3. Commit the sealed secrets
git add base/pull-secret-sealed.yaml base/ssh-key-sealed.yaml
git commit -m "Add sealed secrets"
git push
```

**Output:**
```
✅ Created: base/pull-secret-sealed.yaml
✅ Created: base/ssh-key-sealed.yaml
```

---

### For Developer Hub Provisioning → No Manual Action Needed

When users submit the cluster provisioning form in Developer Hub:

1. **User fills form** with pull secret and SSH key
2. **Developer Hub automatically:**
   - Creates secret YAML files
   - Commits to Git (not sealed - they're in the form)
   - ArgoCD syncs
   - Cluster is created

**The template files** in `skeleton/base/` are **placeholders**:
- `pull-secret.yaml` - Has `${{ values.pullSecret }}`
- `ssh-key.yaml` - Has `${{ values.sshKey }}`

Developer Hub replaces these when the user submits the form.

---

## Template Directory Structure

```
developer-hub/templates/hcp-cluster-template/
├── template.yaml                    # Form definition
├── seal-secrets.sh                  # Manual sealing (rarely used)
└── skeleton/                        # Template files
    └── base/
        ├── pull-secret.yaml         # Template (not actual secret!)
        ├── ssh-key.yaml             # Template (not actual secret!)
        ├── hostedcluster.yaml       # Template with ${{ values.* }}
        ├── nodepool.yaml            # Template with ${{ values.* }}
        ├── namespace.yaml           # Template
        └── kustomization.yaml       # Template
```

**Key Point:** The files in `skeleton/base/` are **templates**, not actual secrets!

Example from `skeleton/base/pull-secret.yaml`:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ${{ values.clusterName }}-pull-secret  # ← Placeholder!
  namespace: clusters-${{ values.clusterName }}
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: |
    ${{ values.pullSecret }}  # ← Gets replaced by form data
```

---

## Common Scenarios

### Scenario 1: Setting Up GitOps Repository (First Time)

**Goal:** Create sealed secrets for cluster provisioning

```bash
# 1. Clone repo
git clone https://github.com/partojalili/ocp-hcp-gitops.git
cd ocp-hcp-gitops

# 2. Download pull secret
# From: https://console.redhat.com/openshift/install/pull-secret
# Save as: pull-secret.txt in repository root

# 3. Login to OpenShift
oc login --token=YOUR_TOKEN --server=https://api.cluster.example.com:6443

# 4. Run seal script
./scripts/seal-secrets.sh

# 5. Commit
git add base/pull-secret-sealed.yaml base/ssh-key-sealed.yaml
git commit -m "Add sealed secrets for HCP clusters"
git push

# 6. Clean up
rm pull-secret.txt  # Important!
```

---

### Scenario 2: Using Developer Hub (Self-Service)

**Goal:** Provision a cluster through the web UI

```bash
# 1. Open Developer Hub
open https://backstage-developer-hub-rhdh-operator.apps.your-cluster.com

# 2. Click "Create" → Select "OpenShift HCP Cluster"

# 3. Fill form:
   - Cluster Name: dev-cluster
   - Pull Secret: [Paste from Red Hat Console]
   - SSH Key: [Paste from ~/.ssh/id_rsa.pub]
   - CPU/Memory: 4/8

# 4. Submit
   → Developer Hub creates files
   → Commits to Git
   → ArgoCD syncs
   → Cluster provisions (~15-20 min)
```

**No manual sealing needed!** Developer Hub handles it.

---

### Scenario 3: Manually Creating Cluster Config (Advanced)

**Goal:** Manually create cluster config without Developer Hub

```bash
cd ~/ocp-hcp-gitops/developer-hub/templates/hcp-cluster-template

# Create sealed secrets for specific cluster
./seal-secrets.sh my-cluster \
  "$(cat ~/pull-secret.json)" \
  "$(cat ~/.ssh/id_rsa.pub)"

# This creates:
# - base/pull-secret.yaml (sealed)
# - base/ssh-key.yaml (sealed)

# Then manually create other manifests:
# - hostedcluster.yaml
# - nodepool.yaml
# - namespace.yaml
# etc.
```

**Rarely needed** - use Developer Hub instead!

---

## All Scripts Now Fixed

All three scripts now use the correct namespace:

```bash
kubeseal --format=yaml \
  --controller-namespace=kube-system \  # ✅ Correct!
  --controller-name=sealed-secrets-controller \
  < input.yaml > output.yaml
```

**Before (broken):**
```bash
kubeseal --format=yaml < input.yaml > output.yaml
# Error: services "sealed-secrets-controller" not found
```

---

## Security Notes

### ✅ Safe to Commit (Encrypted):
- `base/pull-secret-sealed.yaml`
- `base/ssh-key-sealed.yaml`
- Any file with `-sealed.yaml` suffix

### ❌ NEVER Commit (Plain Text):
- `pull-secret.txt`
- `pull-secret.json`
- Any `-temp.yaml` files
- Any file in `skeleton/` with actual secrets (should only have `${{ }}` placeholders)

### 🔒 How Sealing Works:

1. **Your secrets** (pull-secret.txt) are **plain text**
2. **kubeseal** encrypts them with your **cluster's public key**
3. **Sealed secrets** can **only** be decrypted by **your cluster's controller**
4. **Safe to commit** to public Git - even if leaked, they're useless without your cluster

---

## Troubleshooting

### Error: "services sealed-secrets-controller not found"

**Fixed!** All scripts now use `--controller-namespace=kube-system`

### Error: "pull-secret.txt not found"

```bash
# Download from Red Hat Console
open https://console.redhat.com/openshift/install/pull-secret

# Save to repository root
cd ~/ocp-hcp-gitops
# Place pull-secret.txt here (not in subdirectories!)
```

### Template Files Look Like Plain Secrets

**This is normal!** Template files have `${{ values.* }}` placeholders:

```yaml
stringData:
  .dockerconfigjson: |
    ${{ values.pullSecret }}  # ← This is a PLACEHOLDER, not a secret!
```

Developer Hub replaces these when you submit the form.

---

## Summary

**For most users:**
- ✅ Use `scripts/seal-secrets.sh` for initial setup
- ✅ Use Developer Hub UI for cluster provisioning
- ❌ Don't manually edit `skeleton/` files
- ❌ Don't commit plain text secrets

**The `skeleton/` directory is for Developer Hub templates only!**

---

## Additional Resources

- [SEAL-SECRETS-USAGE.md](../SEAL-SECRETS-USAGE.md) - Detailed guide for main script
- [Developer Hub README](../developer-hub/README.md) - Self-service provisioning
- [Sealed Secrets Docs](https://github.com/bitnami-labs/sealed-secrets)
