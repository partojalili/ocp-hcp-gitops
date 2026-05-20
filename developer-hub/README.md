# Red Hat Developer Hub (RHDH) Deployment

This directory contains the manifests and instructions for deploying Red Hat Developer Hub on OpenShift.

## Overview

Red Hat Developer Hub is based on Backstage and provides a centralized platform for developers to discover, create, and manage software components, services, and documentation.

## Prerequisites

- OpenShift cluster with cluster-admin access
- `oc` CLI installed and logged in

## Deployment Steps

### Step 1: Install the Red Hat Developer Hub Operator

The operator manages the lifecycle of Developer Hub instances.

```bash
# Create namespace and install operator
oc apply -f operator-subscription.yaml

# Wait for operator to be ready (takes ~2-3 minutes)
oc get csv -n rhdh-operator -w
```

**Verify operator installation:**
```bash
oc get pods -n rhdh-operator
```

You should see the `rhdh-operator` pod running.

### Step 2: Create Guest Authentication ConfigMap

Developer Hub requires authentication configuration. This ConfigMap enables guest access (no login required).

```bash
oc apply -f guest-auth-config.yaml
```

**What this does:**
- Enables guest authentication provider
- Allows users to access Developer Hub without credentials
- Configures the sign-in page to show "Enter as Guest" button

### Step 3: Deploy Developer Hub Instance

Create the Developer Hub instance with guest authentication enabled:

```bash
oc apply -f backstage-instance.yaml
```

**This will:**
- Deploy a PostgreSQL database for Developer Hub
- Deploy the Developer Hub application (Backstage)
- Create an OpenShift Route for external access
- Mount the guest auth configuration

### Step 4: Monitor Deployment

Wait for Developer Hub to be ready (~3-5 minutes):

```bash
# Watch pods
oc get pods -n rhdh-operator -w

# Check Backstage CR status
oc get backstage developer-hub -n rhdh-operator

# Get the route URL
oc get route backstage-developer-hub -n rhdh-operator
```

**Expected output:**
```
NAME                                       READY   STATUS    RESTARTS   AGE
backstage-developer-hub-XXXXXXXXXX-XXXXX   1/1     Running   0          4m
backstage-psql-developer-hub-0             1/1     Running   0          4m
rhdh-operator-XXXXXXXXXX-XXXXX             1/1     Running   0          10m
```

### Step 5: Access Developer Hub

Get the URL:

```bash
echo "https://$(oc get route backstage-developer-hub -n rhdh-operator -o jsonpath='{.spec.host}')"
```

**Example URL:**
```
https://backstage-developer-hub-rhdh-operator.apps.cluster-XXXXX.domain.com
```

Open the URL in your browser and click **"Enter as Guest"** to access Developer Hub.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Developer Hub UI                      │
│              (Backstage Frontend + Backend)             │
└─────────────────────────────────────────────────────────┘
                          │
                          │ (config)
                          ▼
┌─────────────────────────────────────────────────────────┐
│            backstage-guest-auth-config                   │
│                  (ConfigMap)                             │
│  - Enables guest authentication                          │
│  - No login required                                     │
└─────────────────────────────────────────────────────────┘
                          │
                          │ (data)
                          ▼
┌─────────────────────────────────────────────────────────┐
│              PostgreSQL Database                         │
│         (backstage-psql-developer-hub)                   │
│  - Stores catalog entities                               │
│  - Stores user preferences                               │
└─────────────────────────────────────────────────────────┘
```

## Files in This Directory

| File | Purpose |
|------|---------|
| `operator-subscription.yaml` | Installs Red Hat Developer Hub Operator |
| `guest-auth-config.yaml` | ConfigMap for guest authentication |
| `backstage-instance.yaml` | Developer Hub instance with guest auth |
| `README.md` | This file - deployment instructions |

## Configuration

### Authentication

**Current:** Guest authentication (no login required)

**To enable other authentication providers** (GitHub, GitLab, LDAP, etc.), update the `guest-auth-config.yaml` ConfigMap:

```yaml
auth:
  environment: production
  providers:
    github:
      production:
        clientId: ${GITHUB_CLIENT_ID}
        clientSecret: ${GITHUB_CLIENT_SECRET}
```

Then recreate the Developer Hub pod:
```bash
oc delete pod -l app.kubernetes.io/name=backstage -n rhdh-operator
```

### Scaling

To scale Developer Hub replicas:

```bash
oc patch backstage developer-hub -n rhdh-operator --type=merge -p '{"spec":{"application":{"replicas":3}}}'
```

### Custom Plugins

To add custom plugins, create a ConfigMap with dynamic plugins configuration and reference it in the Backstage CR.

## Troubleshooting

### Issue: Pod stuck in Init phase

**Check init container logs:**
```bash
oc logs -n rhdh-operator -l app.kubernetes.io/name=backstage -c install-dynamic-plugins --tail=50
```

### Issue: Authentication error on UI

**Error:** "Failed to sign in as a guest using the auth backend"

**Solution:**
1. Verify guest auth ConfigMap exists:
   ```bash
   oc get configmap backstage-guest-auth-config -n rhdh-operator
   ```

2. Check if ConfigMap is mounted in deployment:
   ```bash
   oc get deployment backstage-developer-hub -n rhdh-operator -o yaml | grep -A 5 "configMaps"
   ```

3. Force pod restart:
   ```bash
   oc delete pod -l app.kubernetes.io/name=backstage -n rhdh-operator
   ```

### Issue: Pod not starting

**Check events:**
```bash
oc get events -n rhdh-operator --sort-by='.lastTimestamp' | tail -20
```

**Check operator logs:**
```bash
oc logs deployment/rhdh-operator -n rhdh-operator --tail=50
```

### Issue: Route not accessible

**Verify route exists:**
```bash
oc get route backstage-developer-hub -n rhdh-operator
```

**Check if route is properly configured:**
```bash
oc describe route backstage-developer-hub -n rhdh-operator
```

## Uninstallation

To remove Developer Hub:

```bash
# Delete Developer Hub instance
oc delete -f backstage-instance.yaml

# Delete ConfigMap
oc delete -f guest-auth-config.yaml

# Delete operator (optional - removes all RHDH instances)
oc delete subscription rhdh-operator -n rhdh-operator
oc delete csv -n rhdh-operator -l operators.coreos.com/rhdh.rhdh-operator

# Delete namespace
oc delete namespace rhdh-operator
```

## Additional Resources

- [Red Hat Developer Hub Documentation](https://access.redhat.com/documentation/en-us/red_hat_developer_hub)
- [Backstage Official Docs](https://backstage.io/docs)
- [RHDH Operator GitHub](https://github.com/redhat-developer/rhdh-operator)

## Self-Service Cluster Provisioning

Developer Hub includes a Software Template for provisioning OpenShift Hosted Control Plane (HCP) clusters through a web form.

### Prerequisites for Self-Service

#### Option 1: Automated Setup with Sealed Secrets (Recommended)

Use the provided script to securely create and seal your GitHub token:

```bash
cd developer-hub
./seal-github-token.sh

# The script will:
# 1. Prompt for your GitHub token
# 2. Create a sealed secret (encrypted)
# 3. Save to github-integration-sealed-secret.yaml
# 4. Show next steps

# Then apply the sealed secret and configs:
oc apply -f github-integration-sealed-secret.yaml
oc apply -f github-integration-config.yaml
oc apply -f catalog-locations-config.yaml
oc apply -f backstage-instance.yaml

# Wait for pod to restart (~2 minutes)
oc get pods -n rhdh-operator -w
```

**Why Sealed Secrets?**
- ✅ Safe to commit encrypted secret to git
- ✅ Can only be decrypted by your cluster
- ✅ No risk of token exposure
- ✅ GitOps-friendly

#### Option 2: Manual Sealed Secret Creation

```bash
# 1. Create GitHub token at: https://github.com/settings/tokens/new
#    Required scope: 'repo' (Full control of private repositories)

# 2. Create temporary secret file
cat > /tmp/github-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: backstage-github-secret
  namespace: rhdh-operator
type: Opaque
stringData:
  GITHUB_TOKEN: "ghp_YOUR_TOKEN_HERE"
EOF

# 3. Seal the secret
kubeseal -f /tmp/github-secret.yaml \
         -w developer-hub/github-integration-sealed-secret.yaml \
         --controller-namespace sealed-secrets \
         --controller-name sealed-secrets-controller

# 4. Clean up
rm /tmp/github-secret.yaml

# 5. Apply all configs
oc apply -f developer-hub/github-integration-sealed-secret.yaml
oc apply -f developer-hub/github-integration-config.yaml
oc apply -f developer-hub/catalog-locations-config.yaml
oc apply -f developer-hub/backstage-instance.yaml

# Wait for pod to restart
oc get pods -n rhdh-operator -w
```

### Using the Self-Service Portal

1. **Open Developer Hub**:
   ```bash
   echo "https://$(oc get route backstage-developer-hub -n rhdh-operator -o jsonpath='{.spec.host}')"
   ```

2. **Create a New Cluster**:
   - Click **"Create Component"** or **"Create..."**
   - Select **"OpenShift HCP Cluster"** template
   
3. **Fill the Form**:
   - **Cluster Name**: e.g., `dev-cluster` (lowercase, alphanumeric, hyphens)
   - **Base Domain**: e.g., `apps.cluster-abc.redhat.com`
   - **Pull Secret**: Paste from https://console.redhat.com/openshift/install/pull-secret
   - **Worker Nodes**: Number of worker VMs (default: 2)
   - **CPU Cores**: Cores per worker (default: 4)
   - **Memory**: GiB per worker (default: 8)
   - **Repository URL**: Git repo for cluster configs

4. **Submit**:
   - Developer Hub commits the config to `clusters/{cluster-name}/`
   - ArgoCD detects changes (~2-3 minutes)
   - ACM/HyperShift provisions the cluster (~15-20 minutes)

5. **Monitor Progress**:
   ```bash
   # Watch HostedCluster status
   oc get hostedcluster {cluster-name} -n clusters-{cluster-name} -w
   
   # Check ArgoCD Application
   oc get application {cluster-name}-hosted-cluster -n openshift-gitops
   
   # View worker VMs
   oc get vm -n clusters-{cluster-name}
   ```

### What Gets Created

When you submit the form, Developer Hub automatically creates:

```
clusters/{cluster-name}/
├── base/
│   ├── namespace.yaml              # Namespace: clusters-{cluster-name}
│   ├── pull-secret.yaml            # Pull secret from form
│   ├── ssh-key.yaml                # SSH key for node access
│   ├── hostedcluster.yaml          # HostedCluster CR with your specs
│   ├── nodepool.yaml               # NodePool with CPU/memory from form
│   └── kustomization.yaml          # Kustomize config
└── argocd/
    └── application.yaml            # ArgoCD Application for auto-sync
```

### End-to-End Flow

```
User fills form → Developer Hub commits to Git → ArgoCD syncs → ACM deploys → Cluster ready
```

**Timeline**:
- Git commit: Instant
- ArgoCD detection: ~2-3 minutes
- Control plane deployment: ~5 minutes
- Worker VMs creation: ~5 minutes
- Full cluster available: **~15-20 minutes**

### Template Location

The cluster provisioning template is stored at:
```
developer-hub/templates/hcp-cluster-template/
├── template.yaml                   # Software Template definition
└── skeleton/                       # Template files
    ├── base/                       # Kubernetes manifests
    └── argocd/                     # ArgoCD Application
```

To modify the template form or default values, edit `template.yaml`.

---

## Support

For issues and questions:
- Red Hat Support Portal: https://access.redhat.com/support
- RHDH GitHub Issues: https://github.com/redhat-developer/rhdh-operator/issues
