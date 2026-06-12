# GCP OpenShift Cluster Template Setup

This guide walks you through setting up the prerequisites for provisioning OpenShift clusters on Google Cloud Platform.

## Prerequisites

- GCP Project with billing enabled
- `gcloud` CLI installed and authenticated
- OpenShift pull secret from Red Hat
- GitHub repository access

## Step 1: Configure GCP Service Account

### Create Service Account

```bash
export GCP_PROJECT_ID="openenv-jdpff"
export SERVICE_ACCOUNT_NAME="openshift-installer"
export SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

# Create service account
gcloud iam service-accounts create ${SERVICE_ACCOUNT_NAME} \
  --display-name="OpenShift Installer Service Account" \
  --project=${GCP_PROJECT_ID}
```

### Grant Required Roles

```bash
# List of required roles
ROLES=(
  "roles/compute.admin"
  "roles/dns.admin"
  "roles/iam.securityAdmin"
  "roles/iam.serviceAccountAdmin"
  "roles/iam.serviceAccountKeyAdmin"
  "roles/iam.serviceAccountUser"
  "roles/storage.admin"
  "roles/deploymentmanager.editor"
  "roles/iam.roleAdmin"
)

# Grant each role
for ROLE in "${ROLES[@]}"; do
  gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
    --role="${ROLE}"
done
```

### Create and Download Service Account Key

```bash
# Create key
gcloud iam service-accounts keys create ~/gcp-openshift-installer-key.json \
  --iam-account=${SERVICE_ACCOUNT_EMAIL}

echo "✅ Service account key saved to: ~/gcp-openshift-installer-key.json"
echo "⚠️  Keep this file secure - it provides admin access to your GCP project"
```

## Step 2: Enable Required GCP APIs

```bash
# Enable required APIs
gcloud services enable compute.googleapis.com \
  dns.googleapis.com \
  iamcredentials.googleapis.com \
  iam.googleapis.com \
  servicemanagement.googleapis.com \
  serviceusage.googleapis.com \
  storage-api.googleapis.com \
  storage-component.googleapis.com \
  --project=${GCP_PROJECT_ID}

echo "✅ GCP APIs enabled"
```

## Step 3: Configure DNS (Cloud DNS)

### Option A: New Domain

If you're creating a new domain for OpenShift:

```bash
export BASE_DOMAIN="gcp.openshift.example.com"
export DNS_ZONE_NAME="openshift-gcp-zone"

# Create Cloud DNS zone
gcloud dns managed-zones create ${DNS_ZONE_NAME} \
  --dns-name="${BASE_DOMAIN}." \
  --description="OpenShift clusters on GCP" \
  --project=${GCP_PROJECT_ID}

# Get name servers
gcloud dns managed-zones describe ${DNS_ZONE_NAME} \
  --project=${GCP_PROJECT_ID} \
  --format="value(nameServers)"
```

**Action Required**: Update your domain registrar to use the name servers listed above.

### Option B: Existing Domain

If you already have a Cloud DNS zone:

```bash
# List existing zones
gcloud dns managed-zones list --project=${GCP_PROJECT_ID}

# Use the zone name that matches your domain
export DNS_ZONE_NAME="<your-existing-zone-name>"
```

## Step 4: Verify GCP Quotas

Check that your GCP project has sufficient quotas:

```bash
# Check compute quotas
gcloud compute project-info describe --project=${GCP_PROJECT_ID} \
  --format="table(quotas.metric,quotas.usage,quotas.limit)"
```

### Minimum Required Quotas (per region):

| Resource | Minimum Required | Recommended |
|----------|------------------|-------------|
| CPUs | 28 | 50 |
| In-use IP addresses | 5 | 10 |
| Persistent Disk SSD (GB) | 896 | 2000 |
| Persistent Disk Standard (GB) | 896 | 2000 |

### Request Quota Increase (if needed):

1. Go to: https://console.cloud.google.com/iam-admin/quotas?project=openenv-jdpff
2. Filter by the required resource
3. Select the quota and click "EDIT QUOTAS"
4. Request increase

## Step 5: Create Secrets in OpenShift (Management Cluster)

Store the GCP service account credentials in your management cluster:

```bash
# Switch to management cluster
oc login <your-management-cluster>

# Create namespace for secrets
oc create namespace openshift-gcp-credentials

# Create secret
oc create secret generic gcp-service-account \
  --from-file=service-account.json=~/gcp-openshift-installer-key.json \
  -n openshift-gcp-credentials

# Optionally seal it for GitOps
kubectl create secret generic gcp-service-account \
  --from-file=service-account.json=~/gcp-openshift-installer-key.json \
  --dry-run=client -o yaml > /tmp/gcp-secret.yaml

kubeseal --format=yaml \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  < /tmp/gcp-secret.yaml \
  > developer-hub/secrets/gcp-service-account-sealed.yaml

# Clean up temp file
rm /tmp/gcp-secret.yaml
```

## Step 6: Get OpenShift Pull Secret

1. Go to: https://console.redhat.com/openshift/install/pull-secret
2. Log in with your Red Hat account
3. Click "Copy pull secret"
4. Save to a secure location

```bash
# Save pull secret (paste your actual pull secret)
cat > ~/.openshift/pull-secret.json <<'EOF'
{paste-your-pull-secret-here}
EOF

chmod 600 ~/.openshift/pull-secret.json
```

## Step 7: Register Template in Developer Hub

Update the catalog locations to include the new template:

```yaml
# In developer-hub/catalog-locations-config.yaml
catalog:
  locations:
    - type: url
      target: https://github.com/partojalili/ocp-hcp-gitops/blob/main/developer-hub/templates/gcp-openshift-template/template.yaml
```

Apply the updated config:

```bash
oc apply -f developer-hub/catalog-locations-config.yaml

# Trigger catalog refresh (optional - it auto-refreshes every 5 minutes)
oc rollout restart deployment backstage-developer-hub -n rhdh-operator
```

## Step 8: Verify Setup

Check that everything is configured:

```bash
# ✅ GCP Service Account exists
gcloud iam service-accounts describe ${SERVICE_ACCOUNT_EMAIL} --project=${GCP_PROJECT_ID}

# ✅ Service account has required roles
gcloud projects get-iam-policy ${GCP_PROJECT_ID} \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --format="table(bindings.role)"

# ✅ Required APIs are enabled
gcloud services list --enabled --project=${GCP_PROJECT_ID} | grep -E "compute|dns|iam|storage"

# ✅ DNS zone exists
gcloud dns managed-zones list --project=${GCP_PROJECT_ID}

# ✅ Secret exists in OpenShift
oc get secret gcp-service-account -n openshift-gcp-credentials
```

## Security Best Practices

1. **Rotate Service Account Keys** regularly (every 90 days recommended)
2. **Use Sealed Secrets** for storing credentials in Git
3. **Limit Service Account Permissions** to only what's needed
4. **Enable Audit Logging** in GCP
5. **Store Pull Secret Securely** - never commit to Git

## Cost Estimation

Typical OpenShift cluster costs on GCP (us-east1):

| Component | Configuration | Monthly Cost (estimate) |
|-----------|---------------|-------------------------|
| Control Plane (3x n2-standard-4) | 4 vCPU, 16 GB each | ~$290 |
| Workers (3x n2-standard-4) | 4 vCPU, 16 GB each | ~$290 |
| Persistent Storage (500 GB SSD) | - | ~$85 |
| Load Balancers (2) | - | ~$40 |
| **Total** | | **~$705/month** |

💡 Use Preemptible VMs for non-production to save ~80% on compute costs.

## Troubleshooting

### Service Account Permissions

If cluster installation fails with permission errors:

```bash
# Check current roles
gcloud projects get-iam-policy ${GCP_PROJECT_ID} \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:${SERVICE_ACCOUNT_EMAIL}"
```

### API Not Enabled

```bash
# Check if specific API is enabled
gcloud services list --enabled --project=${GCP_PROJECT_ID} | grep <api-name>

# Enable if missing
gcloud services enable <api-name>.googleapis.com --project=${GCP_PROJECT_ID}
```

### Quota Exceeded

Check current usage:

```bash
gcloud compute regions describe us-east1 --project=${GCP_PROJECT_ID}
```

Request increase at: https://console.cloud.google.com/iam-admin/quotas

## Next Steps

Once setup is complete:

1. ✅ Go to Developer Hub
2. ✅ Navigate to "Create" → "OpenShift Cluster on GCP"
3. ✅ Fill in cluster details
4. ✅ Click "Create"
5. ✅ Follow the generated README for cluster installation

## References

- [OpenShift GCP Installation Docs](https://docs.openshift.com/container-platform/latest/installing/installing_gcp/installing-gcp-customizations.html)
- [GCP Service Account Best Practices](https://cloud.google.com/iam/docs/best-practices-service-accounts)
- [OpenShift Pull Secret](https://console.redhat.com/openshift/install/pull-secret)
