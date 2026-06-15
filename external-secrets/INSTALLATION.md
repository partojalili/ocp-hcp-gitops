# External Secrets Operator Installation Guide

This guide provides step-by-step instructions to install and configure External Secrets Operator for automated secret management in OpenShift HCP clusters.

## Prerequisites

- OpenShift cluster with admin access
- `oc` CLI installed and logged in
- Helm 3.x installed
- Red Hat pull secret (download from https://console.redhat.com/openshift/install/pull-secret)
- SSH public key for node access

## Installation Steps

### Step 1: Install External Secrets Operator

**Option A: Red Hat OpenShift Operator (Recommended for OpenShift)**

Install via the OpenShift OperatorHub:

```bash
# Install the Red Hat External Secrets Operator from OperatorHub
# This can be done through the OpenShift Console:
# 1. Navigate to Operators → OperatorHub
# 2. Search for "External Secrets Operator"
# 3. Install the Red Hat certified version

# Or via CLI:
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: external-secrets-operator
  namespace: openshift-operators
spec:
  channel: stable
  installPlanApproval: Automatic
  name: external-secrets-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
```

**Create ExternalSecretsConfig (Required for Red Hat Operator):**

```bash
cat <<EOF | oc apply -f -
apiVersion: operator.openshift.io/v1alpha1
kind: ExternalSecretsConfig
metadata:
  name: cluster
spec:
  logLevel: Normal
EOF
```

**Verify installation:**
```bash
# Check operator pod is running
oc get pods -n external-secrets-operator

# Check that External Secrets controllers are deployed
oc get pods -n external-secrets

# Expected output in external-secrets namespace:
# external-secrets-*                    1/1     Running
# external-secrets-cert-controller-*    1/1     Running
# external-secrets-webhook-*            1/1     Running
```

**Option B: Upstream Helm Installation**

```bash
# Add the External Secrets Helm repository
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# Install External Secrets Operator
helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets-operator \
  --create-namespace \
  --set installCRDs=true \
  --set webhook.port=9443
```

### Step 2: Create Central Secrets Namespace

```bash
# Create the namespace for storing central secrets
oc create namespace hcp-secrets
```

### Step 3: Create Source Secrets

#### Create Pull Secret

```bash
# Download your pull secret from https://console.redhat.com/openshift/install/pull-secret
# Save it as pull-secret.txt

# Create the pull secret in hcp-secrets namespace
oc create secret generic ocp-pull-secret \
  --from-file=.dockerconfigjson=pull-secret.txt \
  --type=kubernetes.io/dockerconfigjson \
  -n hcp-secrets
```

#### Create SSH Key

```bash
# If you don't have an SSH key, generate one:
ssh-keygen -t rsa -b 4096 -f ~/.ssh/ocp-nodes -N ""

# Create the SSH key secret
oc create secret generic ocp-ssh-key \
  --from-file=ssh-publickey=~/.ssh/ocp-nodes.pub \
  -n hcp-secrets
```

**Verify secrets:**
```bash
oc get secrets -n hcp-secrets

# Expected output:
# NAME              TYPE                             DATA   AGE
# ocp-pull-secret   kubernetes.io/dockerconfigjson   1      10s
# ocp-ssh-key       Opaque                           1      5s
```

### Step 4: Create ClusterSecretStore

Create a file named `clustersecretstore.yaml`:

```yaml
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: hcp-secrets-store
spec:
  provider:
    kubernetes:
      # Read secrets from hcp-secrets namespace
      remoteNamespace: hcp-secrets
      server:
        # Use in-cluster Kubernetes API
        url: kubernetes.default
        # CA certificate for API server verification
        caProvider:
          type: ConfigMap
          name: kube-root-ca.crt
          key: ca.crt
          namespace: hcp-secrets  # REQUIRED: namespace where ConfigMap is located
      auth:
        # Use a service account with read access to hcp-secrets
        serviceAccount:
          name: external-secrets-sa
          namespace: hcp-secrets
```

Apply the ClusterSecretStore:
```bash
oc apply -f clustersecretstore.yaml
```

**Verify ClusterSecretStore:**
```bash
oc get clustersecretstore hcp-secrets-store

# Expected output:
# NAME                AGE   STATUS   READY
# hcp-secrets-store   10s   Valid    True
```

### Step 5: Create Service Account and RBAC

Create a file named `external-secrets-rbac.yaml`:

```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-secrets-sa
  namespace: hcp-secrets
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: external-secrets-reader
  namespace: hcp-secrets
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: external-secrets-reader
  namespace: hcp-secrets
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: external-secrets-reader
subjects:
  - kind: ServiceAccount
    name: external-secrets-sa
    namespace: hcp-secrets
---
# Token creator role - allows External Secrets controller to create service account tokens
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: external-secrets-token-creator
  namespace: hcp-secrets
rules:
  - apiGroups: [""]
    resources: ["serviceaccounts/token"]
    verbs: ["create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: external-secrets-token-creator
  namespace: hcp-secrets
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: external-secrets-token-creator
subjects:
  # Red Hat operator uses 'external-secrets' SA in 'external-secrets' namespace
  - kind: ServiceAccount
    name: external-secrets
    namespace: external-secrets
```

Apply the RBAC configuration:
```bash
oc apply -f external-secrets-rbac.yaml
```

### Step 6: Configure ArgoCD RBAC for ExternalSecrets

Create a file named `argocd-externalsecrets-rbac.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argocd-externalsecrets-manager
rules:
  - apiGroups:
      - external-secrets.io
    resources:
      - externalsecrets
      - secretstores
      - clustersecretstores
    verbs:
      - get
      - list
      - watch
      - create
      - update
      - patch
      - delete
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argocd-externalsecrets-manager
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argocd-externalsecrets-manager
subjects:
  - kind: ServiceAccount
    name: openshift-gitops-argocd-application-controller
    namespace: openshift-gitops
```

Apply the ArgoCD RBAC configuration:
```bash
oc apply -f argocd-externalsecrets-rbac.yaml
```

## Verification

### Test with a Sample ExternalSecret

Create a test namespace and ExternalSecret:

```bash
# Create test namespace
oc create namespace test-externalsecret

# Create a test ExternalSecret
cat <<EOF | oc apply -f -
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: test-pull-secret
  namespace: test-externalsecret
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: hcp-secrets-store
    kind: ClusterSecretStore
  target:
    name: test-pull-secret
    creationPolicy: Owner
    template:
      type: kubernetes.io/dockerconfigjson
  dataFrom:
    - extract:
        key: ocp-pull-secret
EOF
```

**Check if the secret was created:**
```bash
# Wait a few seconds, then check
oc get externalsecret test-pull-secret -n test-externalsecret

# Should show:
# NAME                STORE               STATUS         READY
# test-pull-secret    hcp-secrets-store   SecretSynced   True

# Verify the Kubernetes secret was created
oc get secret test-pull-secret -n test-externalsecret

# Should show:
# NAME               TYPE                             DATA   AGE
# test-pull-secret   kubernetes.io/dockerconfigjson   1      10s
```

**Clean up test resources:**
```bash
oc delete namespace test-externalsecret
```

## Next Steps

Once External Secrets Operator is installed and verified:

1. **Update Developer Hub template** - Template should create ExternalSecret resources instead of plain Secrets
2. **Remove manual sealing step** - No longer need to run `seal-pr-secrets.sh`
3. **Provision clusters** - New clusters will automatically get secrets synced

See [EXTERNAL-SECRETS-SETUP.md](../developer-hub/EXTERNAL-SECRETS-SETUP.md) for details on how the automated workflow works.

## Troubleshooting

### ClusterSecretStore shows "Invalid" or "Not Ready" status

```bash
# Check ClusterSecretStore details
oc describe clustersecretstore hcp-secrets-store

# Check ClusterSecretStore status
oc get clustersecretstore hcp-secrets-store -o jsonpath='{.status}'

# Common issues:
# 1. Service account doesn't exist or lacks permissions
# 2. hcp-secrets namespace doesn't exist
# 3. RBAC not configured correctly
# 4. Missing namespace field in caProvider (Red Hat operator issue)
# 5. External Secrets controllers not running (check ExternalSecretsConfig)

# Fix: Verify service account and RBAC
oc get sa external-secrets-sa -n hcp-secrets
oc get role external-secrets-reader -n hcp-secrets
oc get rolebinding external-secrets-reader -n hcp-secrets
oc get role external-secrets-token-creator -n hcp-secrets
oc get rolebinding external-secrets-token-creator -n hcp-secrets

# For Red Hat operator: Check if controllers are deployed
oc get externalsecretsconfig cluster
oc get pods -n external-secrets

# If controllers are missing, ensure ExternalSecretsConfig exists
```

### Error: "missing namespace on caProvider secret"

This error occurs when using a ClusterSecretStore (cluster-scoped) without specifying the namespace for the ConfigMap.

**Fix:**
```bash
# Add namespace to caProvider in ClusterSecretStore
oc patch clustersecretstore hcp-secrets-store --type='json' \
  -p='[{"op": "add", "path": "/spec/provider/kubernetes/server/caProvider/namespace", "value": "hcp-secrets"}]'
```

### Red Hat Operator: Controllers Not Running

If you installed the Red Hat External Secrets Operator but the controllers aren't running:

```bash
# Check if ExternalSecretsConfig exists
oc get externalsecretsconfig cluster

# If it doesn't exist, create it
cat <<EOF | oc apply -f -
apiVersion: operator.openshift.io/v1alpha1
kind: ExternalSecretsConfig
metadata:
  name: cluster
spec:
  logLevel: Normal
EOF

# Wait for controllers to be deployed
oc get pods -n external-secrets -w
```

### ExternalSecret shows "SecretSyncedError"

```bash
# Check ExternalSecret status
oc describe externalsecret <name> -n <namespace>

# Common issues:
# 1. Source secret doesn't exist in hcp-secrets namespace
# 2. ClusterSecretStore not ready
# 3. Permission issues

# Fix: Verify source secret exists
oc get secret ocp-pull-secret -n hcp-secrets
oc get secret ocp-ssh-key -n hcp-secrets
```

### ArgoCD Cannot Create ExternalSecrets

```bash
# Check if ArgoCD has RBAC permissions
oc get clusterrole argocd-externalsecrets-manager
oc get clusterrolebinding argocd-externalsecrets-manager

# If missing, apply argocd-externalsecrets-rbac.yaml again
```

## Maintenance

### Updating Pull Secret

```bash
# Update the central pull secret
oc create secret generic ocp-pull-secret \
  --from-file=.dockerconfigjson=new-pull-secret.txt \
  --type=kubernetes.io/dockerconfigjson \
  -n hcp-secrets \
  --dry-run=client -o yaml | oc apply -f -

# All ExternalSecrets will sync within 1 hour
# Or force immediate sync:
oc annotate externalsecret <cluster-name>-pull-secret \
  -n clusters-<cluster-name> \
  force-sync="$(date +%s)" --overwrite
```

### Updating SSH Key

```bash
# Update the central SSH key
oc create secret generic ocp-ssh-key \
  --from-file=ssh-publickey=new-key.pub \
  -n hcp-secrets \
  --dry-run=client -o yaml | oc apply -f -

# Syncs automatically within 1 hour
```

## Uninstall

To remove External Secrets Operator:

```bash
# Delete all ExternalSecrets first
oc get externalsecret -A -o json | \
  jq -r '.items[] | "\(.metadata.namespace) \(.metadata.name)"' | \
  while read ns name; do oc delete externalsecret $name -n $ns; done

# Delete ClusterSecretStore
oc delete clustersecretstore hcp-secrets-store

# Uninstall Helm chart
helm uninstall external-secrets -n external-secrets-operator

# Delete namespace
oc delete namespace external-secrets-operator

# Optionally delete central secrets namespace
# WARNING: This deletes your pull secret and SSH key!
oc delete namespace hcp-secrets
```

## Reference

- [External Secrets Operator Documentation](https://external-secrets.io/)
- [Kubernetes Provider Guide](https://external-secrets.io/latest/provider/kubernetes/)
- [External Secrets API Reference](https://external-secrets.io/latest/api/externalsecret/)
