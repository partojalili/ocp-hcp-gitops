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

## Support

For issues and questions:
- Red Hat Support Portal: https://access.redhat.com/support
- RHDH GitHub Issues: https://github.com/redhat-developer/rhdh-operator/issues
