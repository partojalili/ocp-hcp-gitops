#!/bin/bash
set -e

echo "=========================================="
echo "HCP Cluster Secrets Creation Script"
echo "=========================================="
echo

# Parse arguments
CLUSTER_NAME="$1"
PULL_SECRET_FILE="$2"
SSH_KEY_FILE="${3:-$HOME/.ssh/id_rsa.pub}"

if [ -z "$CLUSTER_NAME" ]; then
    echo "Usage: $0 <cluster-name> [pull-secret-file] [ssh-key-file]"
    echo
    echo "Examples:"
    echo "  $0 devhub2 ~/Downloads/pull-secret.json"
    echo "  $0 devhub3 ~/Downloads/pull-secret.json ~/.ssh/id_ed25519.pub"
    echo
    echo "Arguments:"
    echo "  cluster-name      : Name of the HCP cluster"
    echo "  pull-secret-file  : Path to Red Hat pull secret (optional if already exists)"
    echo "  ssh-key-file      : Path to SSH public key (default: ~/.ssh/id_rsa.pub)"
    echo
    exit 1
fi

NAMESPACE="clusters-${CLUSTER_NAME}"

echo "Cluster: $CLUSTER_NAME"
echo "Namespace: $NAMESPACE"
echo

# Check if logged in to OpenShift
if ! oc whoami &> /dev/null; then
    echo "ERROR: Not logged into an OpenShift cluster"
    echo "Please login first: oc login"
    exit 1
fi

echo "✓ Connected to cluster: $(oc whoami --show-server)"
echo

# Check if namespace exists
if ! oc get namespace "$NAMESPACE" &> /dev/null; then
    echo "WARNING: Namespace $NAMESPACE does not exist"
    echo
    read -p "Create namespace now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        oc create namespace "$NAMESPACE"
        echo "✓ Created namespace: $NAMESPACE"
    else
        echo "ERROR: Namespace must exist to create secrets"
        exit 1
    fi
else
    echo "✓ Namespace exists: $NAMESPACE"
fi
echo

# Create Pull Secret
echo "=========================================="
echo "1. Creating Pull Secret"
echo "=========================================="
echo

# Check if secret already exists
if oc get secret hcp-pull-secret -n "$NAMESPACE" &> /dev/null; then
    echo "⚠️  Secret 'hcp-pull-secret' already exists in $NAMESPACE"
    read -p "Do you want to replace it? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        oc delete secret hcp-pull-secret -n "$NAMESPACE"
        echo "✓ Deleted existing secret"
    else
        echo "⏭️  Skipping pull secret creation"
        SKIP_PULL_SECRET=true
    fi
fi

if [ -z "$SKIP_PULL_SECRET" ]; then
    # If pull secret file not provided, prompt for it
    if [ -z "$PULL_SECRET_FILE" ]; then
        echo "Pull secret file not provided"
        echo
        echo "Download your pull secret from:"
        echo "  https://console.redhat.com/openshift/install/pull-secret"
        echo
        read -p "Enter path to pull secret file: " PULL_SECRET_FILE

        # Expand ~ to home directory
        PULL_SECRET_FILE="${PULL_SECRET_FILE/#\~/$HOME}"
    fi

    # Validate pull secret file exists
    if [ ! -f "$PULL_SECRET_FILE" ]; then
        echo "ERROR: Pull secret file not found: $PULL_SECRET_FILE"
        exit 1
    fi

    echo "Found pull secret: $PULL_SECRET_FILE"
    echo "Creating secret..."

    oc create secret docker-registry hcp-pull-secret \
      --from-file=.dockerconfigjson="$PULL_SECRET_FILE" \
      --namespace="$NAMESPACE"

    echo "✓ Created pull secret in namespace: $NAMESPACE"
fi
echo

# Create SSH Key Secret
echo "=========================================="
echo "2. Creating SSH Key Secret"
echo "=========================================="
echo

# Check if secret already exists
if oc get secret hcp-ssh-key -n "$NAMESPACE" &> /dev/null; then
    echo "⚠️  Secret 'hcp-ssh-key' already exists in $NAMESPACE"
    read -p "Do you want to replace it? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        oc delete secret hcp-ssh-key -n "$NAMESPACE"
        echo "✓ Deleted existing secret"
    else
        echo "⏭️  Skipping SSH key creation"
        SKIP_SSH_KEY=true
    fi
fi

if [ -z "$SKIP_SSH_KEY" ]; then
    # Validate SSH key file exists
    if [ ! -f "$SSH_KEY_FILE" ]; then
        echo "⚠️  SSH key file not found: $SSH_KEY_FILE"
        echo
        echo "Looked for: $SSH_KEY_FILE"
        echo
        read -p "Enter path to SSH public key (or press Enter to skip): " SSH_KEY_INPUT

        if [ -z "$SSH_KEY_INPUT" ]; then
            echo "⏭️  Skipping SSH key creation"
            SKIP_SSH_KEY=true
        else
            SSH_KEY_FILE="${SSH_KEY_INPUT/#\~/$HOME}"
            if [ ! -f "$SSH_KEY_FILE" ]; then
                echo "ERROR: SSH key file not found: $SSH_KEY_FILE"
                exit 1
            fi
        fi
    fi

    if [ -z "$SKIP_SSH_KEY" ]; then
        echo "Found SSH key: $SSH_KEY_FILE"
        echo "Creating secret..."

        oc create secret generic hcp-ssh-key \
          --from-file=id_rsa.pub="$SSH_KEY_FILE" \
          --namespace="$NAMESPACE"

        echo "✓ Created SSH key secret in namespace: $NAMESPACE"
    fi
fi
echo

# Summary
echo "=========================================="
echo "✅ Secrets Created Successfully!"
echo "=========================================="
echo
echo "Namespace: $NAMESPACE"
echo "Secrets:"
oc get secrets -n "$NAMESPACE" | grep hcp || echo "  (none created)"
echo

# Check for ArgoCD application
echo "Checking for ArgoCD application..."
if oc get application "${CLUSTER_NAME}-hosted-cluster" -n openshift-gitops &> /dev/null; then
    echo "✓ ArgoCD Application found: ${CLUSTER_NAME}-hosted-cluster"
    echo

    APP_STATUS=$(oc get application "${CLUSTER_NAME}-hosted-cluster" -n openshift-gitops -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
    echo "Sync Status: $APP_STATUS"
    echo

    if [ "$APP_STATUS" != "Synced" ]; then
        read -p "Trigger ArgoCD sync now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            oc patch application "${CLUSTER_NAME}-hosted-cluster" -n openshift-gitops \
              --type merge -p '{"operation":{"sync":{}}}'
            echo "✓ Triggered ArgoCD sync"
        fi
    fi
else
    echo "⚠️  ArgoCD Application not found: ${CLUSTER_NAME}-hosted-cluster"
    echo
    echo "Expected application at:"
    echo "  clusters/devhub/${CLUSTER_NAME}/argocd/application.yaml"
    echo
    echo "Apply it manually:"
    echo "  oc apply -f clusters/devhub/${CLUSTER_NAME}/argocd/application.yaml"
fi
echo

# Monitoring commands
echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo
echo "Monitor cluster creation:"
echo
echo "  # Watch HostedCluster status"
echo "  oc get hostedcluster $CLUSTER_NAME -n $NAMESPACE -w"
echo
echo "  # Check control plane pods"
echo "  oc get pods -n $NAMESPACE"
echo
echo "  # Watch worker VMs (takes ~5-10 min)"
echo "  watch 'oc get vm -n $NAMESPACE'"
echo
echo "  # Check ArgoCD Application"
echo "  oc get application ${CLUSTER_NAME}-hosted-cluster -n openshift-gitops"
echo
echo "Expected timeline:"
echo "  - Control plane ready: ~5 minutes"
echo "  - Workers ready: ~10 minutes"
echo "  - Total: ~15-20 minutes"
echo
