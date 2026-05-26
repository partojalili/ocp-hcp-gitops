# Self-Service HCP Cluster Provisioning

Complete workflow for provisioning OpenShift Hosted Control Plane (HCP) clusters through Red Hat Developer Hub.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│  User fills form in Developer Hub                               │
│  (cluster name, base domain, worker specs)                      │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│  Developer Hub commits to Git:                                  │
│    clusters/devhub/{cluster-name}/                              │
│      ├── base/                                                   │
│      │   ├── namespace.yaml                                     │
│      │   ├── hostedcluster.yaml                                 │
│      │   ├── nodepool.yaml                                      │
│      │   └── kustomization.yaml                                 │
│      └── argocd/                                                │
│          └── application.yaml                                   │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│  Admin creates secrets (automated script)                       │
│    oc apply -f clusters/devhub/{cluster}/argocd/application.yaml│
│    ./scripts/create-cluster-secrets.sh {cluster} {pull-secret}  │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│  ArgoCD auto-syncs cluster config                              │
│    - Creates namespace: clusters-{cluster-name}                 │
│    - Deploys HostedCluster CR                                   │
│    - Deploys NodePool CR                                        │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│  HyperShift/ACM provisions cluster                              │
│    - Control plane pods (~5 min)                                │
│    - Worker VMs (~10 min)                                       │
│    - Total: ~15-20 minutes                                      │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

### One-Time Setup

1. **Red Hat Developer Hub** deployed and configured
   - See: `developer-hub/README.md`
   - GitHub integration configured
   - Software template loaded

2. **OpenShift GitOps (ArgoCD)** installed
   ```bash
   oc get operator openshift-gitops-operator -n openshift-operators
   ```

3. **HyperShift Operator** installed
   ```bash
   oc get operator multicluster-engine -n multicluster-engine
   ```

4. **Download Pull Secret** (required for each cluster)
   - Go to: https://console.redhat.com/openshift/install/pull-secret
   - Save as: `~/Downloads/pull-secret.json`
   - **Security:** Never commit this to Git!

## Provisioning Workflow

### Step 1: User Submits Cluster Request

1. Open Developer Hub:
   ```bash
   oc get route backstage-developer-hub -n rhdh-operator -o jsonpath='{.spec.host}'
   ```

2. Click **"Create"** → Select **"OpenShift HCP Cluster"**

3. Fill the form:
   - **Cluster Name:** `devhub3` (lowercase, alphanumeric, hyphens)
   - **Base Domain:** `apps.cluster-xyz.redhat.com`
   - **Worker Nodes:** `2`
   - **CPU Cores:** `4`
   - **Memory:** `8` GiB
   - **Repository URL:** (pre-filled)

4. Submit → Developer Hub creates a PR

5. **Merge the PR** (or it auto-merges based on repo settings)

### Step 2: Admin Creates Secrets

After the PR is merged, run the automated script:

```bash
cd ~/ocp-hcp-gitops

# Create secrets for the new cluster
./scripts/create-cluster-secrets.sh devhub3 ~/Downloads/pull-secret.json

# The script will:
# 1. Check if namespace exists (create if needed)
# 2. Create hcp-pull-secret in clusters-devhub3 namespace
# 3. Create hcp-ssh-key in clusters-devhub3 namespace
# 4. Check for ArgoCD application
# 5. Optionally trigger ArgoCD sync
```

**Example output:**
```
==========================================
HCP Cluster Secrets Creation Script
==========================================

Cluster: devhub3
Namespace: clusters-devhub3

✓ Connected to cluster: https://api.cluster.example.com:6443
✓ Namespace exists: clusters-devhub3

==========================================
1. Creating Pull Secret
==========================================

Found pull secret: /Users/pjalili/Downloads/pull-secret.json
Creating secret...
✓ Created pull secret in namespace: clusters-devhub3

==========================================
2. Creating SSH Key Secret
==========================================

Found SSH key: /Users/pjalili/.ssh/id_rsa.pub
Creating secret...
✓ Created SSH key secret in namespace: clusters-devhub3

✅ Secrets Created Successfully!
```

### Step 3: ArgoCD Auto-Deploys

ArgoCD will automatically sync the cluster config:

```bash
# Watch ArgoCD sync progress
oc get application devhub3-hosted-cluster -n openshift-gitops -w

# Expected status: Synced, Healthy
```

If ArgoCD doesn't auto-sync, apply the application manually:

```bash
oc apply -f clusters/devhub/devhub3/argocd/application.yaml
```

### Step 4: Monitor Cluster Creation

```bash
# Watch HostedCluster status
oc get hostedcluster devhub3 -n clusters-devhub3 -w

# Check control plane pods
oc get pods -n clusters-devhub3

# Watch worker VMs
watch 'oc get vm -n clusters-devhub3'
```

**Timeline:**
- ArgoCD sync: ~1-2 minutes
- Control plane ready: ~5 minutes
- Worker VMs ready: ~10 minutes
- **Total: ~15-20 minutes**

## Manual Secret Creation (Alternative)

If you prefer manual secret creation instead of using the script:

```bash
CLUSTER_NAME="devhub3"
NAMESPACE="clusters-${CLUSTER_NAME}"

# Create namespace
oc create namespace "$NAMESPACE"

# Create pull secret
oc create secret docker-registry hcp-pull-secret \
  --from-file=.dockerconfigjson=~/Downloads/pull-secret.json \
  --namespace="$NAMESPACE"

# Create SSH key
oc create secret generic hcp-ssh-key \
  --from-file=id_rsa.pub=$HOME/.ssh/id_rsa.pub \
  --namespace="$NAMESPACE"

# Apply ArgoCD application
oc apply -f clusters/devhub/${CLUSTER_NAME}/argocd/application.yaml
```

## Cluster Access

Once the cluster is ready:

```bash
# Get kubeadmin password
oc get secret devhub3-kubeadmin-password \
  -n clusters-devhub3 \
  -o jsonpath='{.data.password}' | base64 -d

# Get console URL
oc get hostedcluster devhub3 \
  -n clusters-devhub3 \
  -o jsonpath='{.status.controlPlaneEndpoint.host}'

# Get kubeconfig
oc get secret devhub3-admin-kubeconfig \
  -n clusters-devhub3 \
  -o jsonpath='{.data.kubeconfig}' | base64 -d > ~/devhub3-kubeconfig.yaml

# Login to the hosted cluster
export KUBECONFIG=~/devhub3-kubeconfig.yaml
oc login
```

## Troubleshooting

### Issue: ArgoCD Application Not Syncing

```bash
# Check application status
oc describe application devhub3-hosted-cluster -n openshift-gitops

# Check for errors in conditions
oc get application devhub3-hosted-cluster -n openshift-gitops \
  -o jsonpath='{.status.conditions}' | jq

# Force sync
oc patch application devhub3-hosted-cluster -n openshift-gitops \
  --type merge -p '{"operation":{"sync":{}}}'
```

### Issue: Secrets Not Found

```bash
# Verify secrets exist
oc get secrets -n clusters-devhub3 | grep hcp

# Expected output:
# hcp-pull-secret   kubernetes.io/dockerconfigjson   1      2m
# hcp-ssh-key       Opaque                           1      2m
```

### Issue: HostedCluster Not Creating

```bash
# Check HostedCluster events
oc describe hostedcluster devhub3 -n clusters-devhub3

# Check HyperShift operator logs
oc logs -n hypershift -l app=operator --tail=50

# Verify pull secret is valid
oc get secret hcp-pull-secret -n clusters-devhub3 -o yaml
```

### Issue: Worker VMs Not Starting

```bash
# Check NodePool status
oc describe nodepool devhub3 -n clusters-devhub3

# Check VM events
oc get events -n clusters-devhub3 --sort-by='.lastTimestamp'

# Check KubeVirt capacity
oc get nodes -l node-role.kubernetes.io/worker \
  -o custom-columns=NAME:.metadata.name,CPU:.status.capacity.cpu,MEMORY:.status.capacity.memory
```

## Security Notes

### ✅ Safe to Commit
- All files in `clusters/devhub/` directory
- ArgoCD application manifests
- HostedCluster and NodePool CRs

### ❌ NEVER Commit
- Pull secret files (`.json`, `.txt`)
- SSH private keys
- Any file with plain-text credentials
- Unsealed Secret manifests

### Why This Approach?

**Before (Insecure):**
- Template accepted pull secret in form
- Plain-text secret committed to Git
- **Security risk:** Credentials exposed in Git history

**Now (Secure):**
- Template generates cluster config only
- Admin creates secrets directly in cluster
- **No credentials in Git ever**
- Secrets stay in Kubernetes only

## Scripts Reference

### `scripts/create-cluster-secrets.sh`

**Purpose:** Automate secret creation for new HCP cluster namespaces

**Usage:**
```bash
./scripts/create-cluster-secrets.sh <cluster-name> [pull-secret-file] [ssh-key-file]
```

**Features:**
- Creates namespace if needed
- Validates files exist before creating secrets
- Checks for existing secrets (prompts to replace)
- Optionally triggers ArgoCD sync
- Shows monitoring commands

**Examples:**
```bash
# Basic usage
./scripts/create-cluster-secrets.sh devhub3 ~/Downloads/pull-secret.json

# Custom SSH key
./scripts/create-cluster-secrets.sh devhub3 \
  ~/Downloads/pull-secret.json \
  ~/.ssh/id_ed25519.pub

# Interactive mode (prompts for pull secret)
./scripts/create-cluster-secrets.sh devhub3
```

### `scripts/seal-secrets.sh`

**Purpose:** Create sealed secrets for GitOps (NOT used for HCP clusters)

**Note:** This script is for base repository secrets only. HCP clusters use direct secret creation instead.

## Future Improvements

### Potential Automation

1. **GitOps Hook for Secrets**
   - Watch for new ArgoCD applications
   - Auto-create secrets from vault/1Password
   - Fully automated end-to-end

2. **Webhook Integration**
   - Developer Hub triggers webhook on PR merge
   - Webhook calls script to create secrets
   - Notifies user when cluster is ready

3. **UI for Secret Management**
   - Web interface for admins
   - Upload pull secret once
   - Reuse for all clusters

## Related Documentation

- [Developer Hub Setup](developer-hub/README.md)
- [GitHub App Authentication](developer-hub/GITHUB-APP-SECRET-SETUP.md)
- [Sealed Secrets Usage](SEAL-SECRETS-USAGE.md)
- [Template Seal Secrets Guide](TEMPLATE-SEAL-SECRETS-GUIDE.md)

## Support

For issues:
- HyperShift: https://hypershift-docs.netlify.app/
- ArgoCD: https://argo-cd.readthedocs.io/
- Developer Hub: https://access.redhat.com/documentation/en-us/red_hat_developer_hub
