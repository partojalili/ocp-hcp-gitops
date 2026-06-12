# Setup Instructions for Automated GCP Cluster Provisioning

Follow these steps to enable automated OpenShift cluster provisioning on GCP using External Secrets Operator.

## Prerequisites

This automation uses the same External Secrets Operator setup as the HCP cluster template. You should already have:

1. **External Secrets Operator** installed
2. **ClusterSecretStore** named `hcp-secrets-store` configured
3. **Secrets stored** in your secret backend (e.g., Vault, AWS Secrets Manager, Google Secret Manager)

## Required Secrets

The following secrets must exist in your secret backend and be accessible via the `hcp-secrets-store`:

### 1. GCP Service Account (`gcp-service-account`)

Store your GCP service account JSON key with these properties:
- **Key name**: `gcp-service-account`
- **Format**: Complete service account JSON file content

The service account must have these IAM roles:
- `roles/compute.admin`
- `roles/dns.admin`
- `roles/iam.securityAdmin`
- `roles/iam.serviceAccountAdmin`
- `roles/iam.serviceAccountUser`
- `roles/storage.admin`

### 2. OpenShift Pull Secret (`ocp-pull-secret`)

Store your OpenShift pull secret:
- **Key name**: `ocp-pull-secret`
- **Format**: Docker config JSON from https://console.redhat.com/openshift/install/pull-secret
- **Example**:
  ```json
  {
    "auths": {
      "cloud.openshift.com": {
        "auth": "...",
        "email": "..."
      },
      "quay.io": {
        "auth": "...",
        "email": "..."
      }
    }
  }
  ```

### 3. SSH Key (`ocp-ssh-key`)

Store SSH public key for cluster node access:
- **Key name**: `ocp-ssh-key`
- **Property**: `ssh-publickey`
- **Format**: SSH public key string (e.g., `ssh-ed25519 AAAA...`)

## Verify External Secrets Setup

Check that External Secrets Operator is working:

```bash
# Check ClusterSecretStore exists
oc get clustersecretstore hcp-secrets-store -o yaml

# Verify it's ready
oc get clustersecretstore hcp-secrets-store -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
# Should output: True
```

## How It Works

When you create a GCP cluster using the Developer Hub template:

1. **Template creates PR** with cluster configuration including ExternalSecret resources
2. **Merge PR** → ApplicationSet discovers new cluster directory
3. **ArgoCD syncs** manifests directory
4. **ExternalSecrets sync** - pulls credentials from secret backend:
   - `gcp-service-account` → `<cluster-name>-gcp-credentials`
   - `ocp-pull-secret` → `<cluster-name>-pull-secret`
   - `ocp-ssh-key` → `<cluster-name>-ssh-key`
5. **Installer Job triggers** (ArgoCD PostSync hook)
6. **Job provisions cluster** using synced credentials (30-40 mins)
7. **Output secrets created**:
   - `<cluster-name>-kubeconfig`
   - `<cluster-name>-kubeadmin`
   - `<cluster-name>-metadata` (ConfigMap)

## Test the Automation

### Create a Test Cluster

1. Go to Developer Hub
2. Navigate to **Create** → **Templates**
3. Select **OpenShift Cluster on GCP (IPI)**
4. Fill in the form:
   - **Cluster Name**: `test-cluster`
   - **GCP Project**: `openenv-jdpff`
   - **GCP Region**: `us-central1`
   - **Base Domain**: `gcp.lab.mjbz.dev`
   - **Worker Count**: `3`
   - **Machine Types**: `n2-standard-4`
5. Click **Create**

### Monitor Installation

```bash
# Wait for ArgoCD to sync (takes ~5 minutes)
oc get applications -n openshift-gitops | grep test-cluster

# Check ExternalSecrets synced
oc get externalsecrets -n gcp-test-cluster
oc get secrets -n gcp-test-cluster

# Check if installer job started
oc get jobs -n gcp-test-cluster

# Watch installation logs
oc logs -n gcp-test-cluster job/install-test-cluster -f
```

Installation takes approximately 30-40 minutes.

### Access the New Cluster

```bash
# Get kubeconfig
oc get secret test-cluster-kubeconfig -n gcp-test-cluster \
  -o jsonpath='{.data.kubeconfig}' | base64 -d > /tmp/test-cluster-kubeconfig

# Get kubeadmin password
oc get secret test-cluster-kubeadmin -n gcp-test-cluster \
  -o jsonpath='{.data.password}' | base64 -d

# Use the cluster
export KUBECONFIG=/tmp/test-cluster-kubeconfig
oc whoami
oc get nodes
oc get co
```

## Troubleshooting

### ExternalSecrets Not Syncing

Check the ExternalSecret status:
```bash
oc get externalsecret -n gcp-test-cluster -o yaml
```

Common issues:
- ClusterSecretStore not ready
- Secret backend authentication failed
- Secret key doesn't exist in backend
- Wrong property names

### Job Fails with "secret not found"

ExternalSecrets haven't synced yet. Check:
```bash
# Should show 3 secrets
oc get secrets -n gcp-test-cluster | grep -E '(gcp-credentials|pull-secret|ssh-key)'
```

Wait for ExternalSecrets to sync (usually < 1 minute).

### Job Fails with GCP Permission Errors

Verify the GCP service account has required IAM roles:
```bash
# Extract service account email from secret
oc get secret test-cluster-gcp-credentials -n gcp-test-cluster \
  -o jsonpath='{.data.service-account\.json}' | base64 -d | jq -r '.client_email'

# Check IAM policy
gcloud projects get-iam-policy openenv-jdpff \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:<email>" \
  --format="table(bindings.role)"
```

### Job Fails with Pull Secret Error

Verify pull secret format:
```bash
oc get secret test-cluster-pull-secret -n gcp-test-cluster \
  -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq '.'
```

Should be valid Docker config JSON with `.auths` key.

### Check Job Logs

```bash
# View pod logs
oc get pods -n gcp-test-cluster
oc logs -n gcp-test-cluster <pod-name>

# View all events
oc get events -n gcp-test-cluster --sort-by='.lastTimestamp'
```

## Adding Secrets to Your Backend

### Example: Adding to Vault

```bash
# GCP Service Account
vault kv put secret/gcp-service-account \
  service-account.json=@~/gcp-openshift-installer-key.json

# Pull Secret
vault kv put secret/ocp-pull-secret \
  .dockerconfigjson=@~/pull-secret.json

# SSH Key
vault kv put secret/ocp-ssh-key \
  ssh-publickey="$(cat ~/.ssh/openshift-clusters.pub)"
```

### Example: Adding to AWS Secrets Manager

```bash
# GCP Service Account
aws secretsmanager create-secret \
  --name gcp-service-account \
  --secret-string file://~/gcp-openshift-installer-key.json

# Pull Secret
aws secretsmanager create-secret \
  --name ocp-pull-secret \
  --secret-string file://~/pull-secret.json

# SSH Key
aws secretsmanager create-secret \
  --name ocp-ssh-key \
  --secret-string "{\"ssh-publickey\":\"$(cat ~/.ssh/openshift-clusters.pub)\"}"
```

## Cluster Deletion

To delete a cluster:

```bash
# 1. Delete cluster directory from Git
cd /tmp/ocp-hcp-gitops
git pull
git rm -r clusters/gcp/test-cluster
git commit -m "Delete test-cluster"
git push

# 2. ArgoCD auto-deletes Application and namespace

# 3. Manually destroy GCP resources (Job doesn't do this)
# Get kubeconfig first
oc get secret test-cluster-kubeconfig -n gcp-test-cluster \
  -o jsonpath='{.data.kubeconfig}' | base64 -d > /tmp/kubeconfig

# Download openshift-install
curl -sfL "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-install-linux.tar.gz" | tar xzf -

# You need the install directory - use GCP Console instead to delete resources
# Or keep the install directory backed up somewhere
```

**Note**: Cluster destruction is currently manual. Consider implementing a destruction Job in the future.

## Important Notes

- **Same secret backend as HCP**: Uses existing External Secrets infrastructure
- **Per-cluster secrets**: Each cluster gets its own secret copies via ExternalSecrets
- **Automatic sync**: Secrets auto-refresh every 1 hour
- **Installation time**: 30-40 minutes per cluster
- **Cost**: ~$705/month per 3-worker cluster on GCP
- **Concurrent installs**: One job per cluster, no queuing
- **Failure recovery**: Jobs have 2 retries, 2-hour timeout
- **Deletion**: Manual GCP resource cleanup required

## Security Best Practices

1. **Rotate credentials regularly**:
   - GCP service account keys: every 90 days
   - OpenShift pull secrets: before expiration
   - SSH keys: yearly or when compromised

2. **Limit secret access**:
   - Use namespace-scoped secrets
   - Configure RBAC for secret access
   - Audit secret usage

3. **Monitor secret sync**:
   - Set up alerts for failed ExternalSecret syncs
   - Monitor ClusterSecretStore health

## Next Steps

Once automation is working:

1. **Document runbooks**: Cluster lifecycle procedures
2. **Set up monitoring**: Alerts for failed installations
3. **Cost tracking**: Tag GCP resources, billing alerts
4. **Automate destruction**: Add cleanup Jobs
5. **Backup strategy**: Install directory preservation
6. **Upgrade automation**: Automated cluster upgrades

## Support

If you encounter issues:

1. Check ExternalSecret sync status
2. Verify ClusterSecretStore is ready
3. Check installer job logs
4. Verify GCP service account permissions
5. Review ArgoCD sync status
