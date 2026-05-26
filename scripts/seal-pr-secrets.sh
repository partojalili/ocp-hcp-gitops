#!/bin/bash
set -e

echo "=========================================="
echo "Seal Cluster Secrets After PR Creation"
echo "=========================================="
echo

# Check if PR number or cluster name is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <PR-NUMBER> [cluster-name]"
    echo "   OR: $0 <cluster-name> (if already on PR branch)"
    echo
    echo "Examples:"
    echo "  $0 13                    # Checkout PR #13 and seal secrets"
    echo "  $0 devhub3               # Seal secrets for devhub3 (already on branch)"
    echo "  $0 13 devhub3            # Checkout PR #13 for devhub3 cluster"
    echo
    exit 1
fi

# Parse arguments
if [[ "$1" =~ ^[0-9]+$ ]]; then
    PR_NUMBER="$1"
    CLUSTER_NAME="${2:-}"
    CHECKOUT_PR=true
else
    CLUSTER_NAME="$1"
    CHECKOUT_PR=false
fi

# Checkout PR if PR number provided
if [ "$CHECKOUT_PR" = true ]; then
    echo "Checking out PR #${PR_NUMBER}..."
    gh pr checkout "$PR_NUMBER"
    echo "✓ PR checked out"
    echo
fi

# If cluster name not provided, try to detect it
if [ -z "$CLUSTER_NAME" ]; then
    echo "Detecting cluster name from recent changes..."
    CLUSTER_DIRS=$(git diff --name-only origin/main | grep "clusters/devhub/" | cut -d'/' -f3 | sort -u)
    CLUSTER_COUNT=$(echo "$CLUSTER_DIRS" | wc -l | tr -d ' ')

    if [ "$CLUSTER_COUNT" -eq 1 ]; then
        CLUSTER_NAME="$CLUSTER_DIRS"
        echo "✓ Detected cluster: $CLUSTER_NAME"
    else
        echo "ERROR: Could not auto-detect cluster name"
        echo "Multiple clusters found in changes:"
        echo "$CLUSTER_DIRS"
        echo
        echo "Please specify cluster name:"
        echo "  $0 $PR_NUMBER <cluster-name>"
        exit 1
    fi
    echo
fi

CLUSTER_DIR="clusters/devhub/${CLUSTER_NAME}/base"

# Validate cluster directory exists
if [ ! -d "$CLUSTER_DIR" ]; then
    echo "ERROR: Cluster directory not found: $CLUSTER_DIR"
    echo
    echo "Available clusters:"
    ls -1 clusters/devhub/ 2>/dev/null || echo "  (none)"
    exit 1
fi

echo "Cluster: $CLUSTER_NAME"
echo "Directory: $CLUSTER_DIR"
echo

# Check if secrets exist
if [ ! -f "$CLUSTER_DIR/pull-secret.yaml" ]; then
    echo "ERROR: pull-secret.yaml not found in $CLUSTER_DIR"
    exit 1
fi

if [ ! -f "$CLUSTER_DIR/ssh-key.yaml" ]; then
    echo "ERROR: ssh-key.yaml not found in $CLUSTER_DIR"
    exit 1
fi

# Check if already sealed
if grep -q "kind: SealedSecret" "$CLUSTER_DIR/pull-secret.yaml" 2>/dev/null; then
    echo "⚠️  Secrets appear to be already sealed!"
    echo
    head -5 "$CLUSTER_DIR/pull-secret.yaml"
    echo
    read -p "Do you want to re-seal them? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Exiting without changes."
        exit 0
    fi
fi

# Check if kubeseal is installed
if ! command -v kubeseal &> /dev/null; then
    echo "ERROR: kubeseal is not installed"
    echo
    echo "Install kubeseal:"
    echo "  macOS:   brew install kubeseal"
    echo "  Linux:   wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.36.6/kubeseal-0.36.6-linux-amd64.tar.gz"
    echo "           tar -xvzf kubeseal-0.36.6-linux-amd64.tar.gz kubeseal"
    echo "           sudo install -m 755 kubeseal /usr/local/bin/kubeseal"
    exit 1
fi

# Check if connected to cluster
if ! oc whoami &> /dev/null; then
    echo "ERROR: Not logged into an OpenShift cluster"
    echo "Please login first: oc login"
    exit 1
fi

echo "✓ Connected to cluster: $(oc whoami --show-server)"
echo

# Navigate to cluster directory
cd "$CLUSTER_DIR"

echo "=========================================="
echo "Sealing Pull Secret"
echo "=========================================="
echo

# Extract pull secret to temp file
echo "Extracting pull secret from YAML..."
cat pull-secret.yaml | grep -A 1000 '.dockerconfigjson:' | tail -n +2 | sed 's/^    //' > /tmp/pull-secret-data-${CLUSTER_NAME}.json

# Verify extraction
if [ ! -s /tmp/pull-secret-data-${CLUSTER_NAME}.json ]; then
    echo "ERROR: Failed to extract pull secret data"
    echo "Check the format of pull-secret.yaml"
    cat pull-secret.yaml
    exit 1
fi

echo "✓ Pull secret extracted"

# Create and seal pull secret
echo "Sealing pull secret with kubeseal..."
oc create secret docker-registry ${CLUSTER_NAME}-pull-secret \
  --from-file=.dockerconfigjson=/tmp/pull-secret-data-${CLUSTER_NAME}.json \
  --namespace=clusters-${CLUSTER_NAME} \
  --dry-run=client -o yaml | \
kubeseal --controller-namespace=kube-system \
  --controller-name=sealed-secrets-controller \
  --format=yaml > pull-secret-sealed.yaml

echo "✓ Pull secret sealed"
echo

echo "=========================================="
echo "Sealing SSH Key"
echo "=========================================="
echo

# Extract SSH key to temp file
echo "Extracting SSH key from YAML..."
cat ssh-key.yaml | grep -A 1000 'id_rsa.pub:' | tail -n +2 | sed 's/^    //' > /tmp/ssh-key-data-${CLUSTER_NAME}.pub

# Verify extraction
if [ ! -s /tmp/ssh-key-data-${CLUSTER_NAME}.pub ]; then
    echo "ERROR: Failed to extract SSH key data"
    echo "Check the format of ssh-key.yaml"
    cat ssh-key.yaml
    exit 1
fi

echo "✓ SSH key extracted"

# Create and seal SSH key
echo "Sealing SSH key with kubeseal..."
oc create secret generic ${CLUSTER_NAME}-ssh-key \
  --from-file=id_rsa.pub=/tmp/ssh-key-data-${CLUSTER_NAME}.pub \
  --namespace=clusters-${CLUSTER_NAME} \
  --dry-run=client -o yaml | \
kubeseal --controller-namespace=kube-system \
  --controller-name=sealed-secrets-controller \
  --format=yaml > ssh-key-sealed.yaml

echo "✓ SSH key sealed"
echo

# Clean up temp files
echo "Cleaning up temporary files..."
rm /tmp/pull-secret-data-${CLUSTER_NAME}.json /tmp/ssh-key-data-${CLUSTER_NAME}.pub
echo "✓ Temp files removed"
echo

# Show before/after comparison
echo "=========================================="
echo "Verification"
echo "=========================================="
echo

echo "BEFORE (plain-text):"
echo "-------------------"
head -6 pull-secret.yaml | grep -v "dockerconfigjson"
echo

echo "AFTER (sealed):"
echo "---------------"
head -6 pull-secret-sealed.yaml
echo

# Ask for confirmation
read -p "Replace plain-text secrets with sealed secrets? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cancelled. Sealed secrets saved as *-sealed.yaml files."
    echo
    echo "To manually replace:"
    echo "  rm pull-secret.yaml ssh-key.yaml"
    echo "  mv pull-secret-sealed.yaml pull-secret.yaml"
    echo "  mv ssh-key-sealed.yaml ssh-key.yaml"
    exit 0
fi

# Replace files
echo
echo "Replacing plain-text secrets with sealed secrets..."
rm pull-secret.yaml ssh-key.yaml
mv pull-secret-sealed.yaml pull-secret.yaml
mv ssh-key-sealed.yaml ssh-key.yaml
echo "✓ Files replaced"
echo

# Show git status
echo "=========================================="
echo "Git Status"
echo "=========================================="
echo

cd ../../../../  # Back to repo root
git status --short

echo
echo "=========================================="
echo "✅ Secrets Successfully Sealed!"
echo "=========================================="
echo

echo "Next steps:"
echo
echo "  1. Review the changes:"
echo "     git diff clusters/devhub/${CLUSTER_NAME}/base/"
echo
echo "  2. Commit the sealed secrets:"
echo "     git add clusters/devhub/${CLUSTER_NAME}/base/pull-secret.yaml clusters/devhub/${CLUSTER_NAME}/base/ssh-key.yaml"
echo "     git commit -m 'Seal secrets with SealedSecret'"
echo "     git push"
echo
if [ "$CHECKOUT_PR" = true ]; then
    echo "  3. Merge the PR:"
    echo "     gh pr merge ${PR_NUMBER} --squash"
else
    echo "  3. Merge the PR through GitHub web UI"
fi
echo
echo "  4. Apply ArgoCD application (after merge):"
echo "     oc apply -f clusters/devhub/${CLUSTER_NAME}/argocd/application.yaml"
echo
echo "  5. Monitor deployment:"
echo "     oc get application.argoproj.io ${CLUSTER_NAME}-hosted-cluster -n openshift-gitops -w"
echo
