# Setup Instructions for Automated Cluster Provisioning

Follow these steps to enable automated OpenShift cluster provisioning.

## 1. Create Required Secrets

The automation requires three secrets in the `openshift-gitops` namespace.

### Get Your Pull Secret

1. Visit https://console.redhat.com/openshift/install/pull-secret
2. Copy your pull secret (it's a JSON object)

### Create the Secrets

```bash
# 1. GCP Service Account (you should already have this)
oc create secret generic gcp-service-account \
  --from-file=service-account.json=~/gcp-openshift-installer-key.json \
  -n openshift-gitops

# 2. OpenShift Pull Secret
# Replace the entire JSON below with your pull secret
oc create secret generic openshift-pull-secret \
  --from-literal='pull-secret={"auths":{"cloud.openshift.com":{"auth":"..."}}}' \
  -n openshift-gitops

# 3. SSH Key for cluster access
# Generate new key if needed
ssh-keygen -t ed25519 -N '' -f ~/.ssh/openshift-clusters

# Create secret
oc create secret generic cluster-ssh-key \
  --from-file=ssh-public-key=~/.ssh/openshift-clusters.pub \
  --from-file=ssh-private-key=~/.ssh/openshift-clusters \
  -n openshift-gitops
```

## 2. Verify Secrets

```bash
# Check all three secrets exist
oc get secrets -n openshift-gitops | grep -E '(gcp-service-account|openshift-pull-secret|cluster-ssh-key)'
```

Expected output:
```
cluster-ssh-key          Opaque   2      10s
gcp-service-account      Opaque   1      5m
openshift-pull-secret    Opaque   1      15s
```

## 3. Test the Automation

### Create a Test Cluster

1. Go to Developer Hub
2. Navigate to **Create** → **Templates**
3. Select **OpenShift Cluster on GCP (IPI)**
4. Fill in the form:
   - Cluster Name: `test-cluster`
   - GCP Project: `openenv-jdpff`
   - GCP Region: `us-central1`
   - Base Domain: `gcp.lab.mjbz.dev`
   - Worker Count: `3`
   - Machine Types: `n2-standard-4`
5. Click **Create**

### Monitor Installation

```bash
# Wait for ArgoCD to discover the cluster (takes ~5 minutes)
oc get applications -n openshift-gitops | grep test-cluster

# Check if the job was created
oc get jobs -n gcp-test-cluster

# Watch the installation logs (once job starts)
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

## 4. Troubleshooting

### Job Not Created

Check if the ApplicationSet synced:
```bash
oc get application gcp-cluster-test-cluster -n openshift-gitops -o yaml | grep -A 10 status
```

### Job Fails with "secret not found"

One of the three secrets is missing:
```bash
# Check which secret is missing
oc get job install-test-cluster -n gcp-test-cluster -o yaml | grep -A 5 volumes
```

### Job Fails with GCP Permission Errors

Verify your GCP service account has required IAM roles:
```bash
gcloud projects get-iam-policy openenv-jdpff \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:openshift-installer@*" \
  --format="table(bindings.role)"
```

Required roles:
- `roles/compute.admin`
- `roles/dns.admin`
- `roles/iam.securityAdmin`
- `roles/iam.serviceAccountAdmin`
- `roles/iam.serviceAccountUser`
- `roles/storage.admin`

### Check Job Logs

```bash
# View all events
oc get events -n gcp-test-cluster --sort-by='.lastTimestamp'

# View pod logs
oc get pods -n gcp-test-cluster
oc logs -n gcp-test-cluster <pod-name>
```

## 5. Clean Up Test Cluster

```bash
# 1. Destroy the GCP resources
oc get secret test-cluster-kubeconfig -n gcp-test-cluster \
  -o jsonpath='{.data.kubeconfig}' | base64 -d > /tmp/kubeconfig

# Download openshift-install
curl -sfL "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-install-linux.tar.gz" | tar xzf -

# You'll need the original install directory - this is tricky
# Alternative: use GCP console to delete the cluster manually

# 2. Remove from Git
cd /tmp/ocp-hcp-gitops
git pull
git rm -r clusters/gcp/test-cluster
git commit -m "Remove test cluster"
git push

# 3. ArgoCD will auto-delete the Application
```

## Next Steps

Once automation is working:

1. **Document your process**: Update team runbooks
2. **Set up monitoring**: Add alerts for failed installations
3. **Cost tracking**: Tag GCP resources, set up billing alerts
4. **Cluster lifecycle**: Document upgrade and deletion procedures
5. **Security**: Rotate secrets regularly (90 days for GCP keys)

## Important Notes

- **Installation time**: 30-40 minutes per cluster
- **Cost**: ~$705/month per 3-worker cluster
- **Concurrent installs**: One job per cluster, no queue
- **Failure recovery**: Jobs have 2 retries, 2-hour timeout
- **Credentials**: Stored as Kubernetes secrets in cluster namespace
- **Deletion**: Manual process using openshift-install destroy

## Support

If you encounter issues:

1. Check job logs: `oc logs -n gcp-<cluster-name> job/install-<cluster-name>`
2. Check ArgoCD sync status
3. Verify secrets exist and are properly formatted
4. Check GCP quotas and permissions
