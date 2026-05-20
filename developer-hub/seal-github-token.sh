#!/bin/bash

# Script to create and seal GitHub token for Developer Hub
# This automates the process of creating a sealed secret for the GitHub integration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check prerequisites
print_info "Checking prerequisites..."

if ! command -v kubeseal &> /dev/null; then
    print_error "kubeseal CLI is not installed"
    echo ""
    echo "Install kubeseal:"
    echo "  macOS:   brew install kubeseal"
    echo "  Linux:   https://github.com/bitnami-labs/sealed-secrets/releases"
    exit 1
fi

if ! command -v oc &> /dev/null && ! command -v kubectl &> /dev/null; then
    print_error "Neither oc nor kubectl CLI is installed"
    exit 1
fi

print_info "Prerequisites OK"
echo ""

# Check if logged into cluster
print_info "Checking cluster connection..."
if ! oc whoami &> /dev/null; then
    print_error "Not logged into OpenShift cluster"
    echo "Run: oc login <cluster-url>"
    exit 1
fi

CLUSTER=$(oc whoami --show-server)
print_info "Connected to: $CLUSTER"
echo ""

# Check if Sealed Secrets controller exists
print_step "Verifying Sealed Secrets controller..."
if ! oc get deployment sealed-secrets-controller -n sealed-secrets &> /dev/null; then
    print_warning "Sealed Secrets controller not found in sealed-secrets namespace"
    print_info "Checking for controller in other namespaces..."

    CONTROLLER_NS=$(oc get deployment -A | grep sealed-secrets-controller | awk '{print $1}' | head -1)

    if [ -z "$CONTROLLER_NS" ]; then
        print_error "Sealed Secrets controller not found on cluster"
        echo ""
        echo "Install Sealed Secrets first:"
        echo "  oc apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.36.6/controller.yaml"
        exit 1
    fi

    print_info "Found controller in namespace: $CONTROLLER_NS"
    SEALED_SECRETS_NS="$CONTROLLER_NS"
else
    SEALED_SECRETS_NS="sealed-secrets"
    print_info "Found controller in namespace: $SEALED_SECRETS_NS"
fi

echo ""

# Prompt for GitHub token
print_step "GitHub Token Setup"
echo ""
echo "Create a GitHub Personal Access Token at:"
echo "  https://github.com/settings/tokens/new"
echo ""
echo "Required settings:"
echo "  - Name: Developer Hub GitOps"
echo "  - Expiration: 90 days (recommended)"
echo "  - Scope: ✓ repo (Full control of private repositories)"
echo ""

read -p "Enter your GitHub Personal Access Token: " -s GITHUB_TOKEN
echo ""

if [ -z "$GITHUB_TOKEN" ]; then
    print_error "Token cannot be empty"
    exit 1
fi

if [[ ! "$GITHUB_TOKEN" =~ ^(ghp_|github_pat_) ]]; then
    print_warning "Token doesn't start with 'ghp_' or 'github_pat_' - are you sure this is a GitHub token?"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Aborted"
        exit 0
    fi
fi

echo ""

# Create temporary secret file
print_step "Creating temporary secret..."
TEMP_SECRET="/tmp/github-secret-$$.yaml"

cat > "$TEMP_SECRET" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: backstage-github-secret
  namespace: rhdh-operator
type: Opaque
stringData:
  GITHUB_TOKEN: "$GITHUB_TOKEN"
EOF

print_info "Temporary secret created: $TEMP_SECRET"

# Seal the secret
print_step "Sealing the secret..."
OUTPUT_FILE="developer-hub/github-integration-sealed-secret.yaml"

kubeseal -f "$TEMP_SECRET" \
         -w "$OUTPUT_FILE" \
         --controller-namespace "$SEALED_SECRETS_NS" \
         --controller-name sealed-secrets-controller

if [ $? -ne 0 ]; then
    print_error "Failed to seal secret"
    rm -f "$TEMP_SECRET"
    exit 1
fi

print_info "Sealed secret created: $OUTPUT_FILE"

# Clean up temporary file
print_step "Cleaning up..."
rm -f "$TEMP_SECRET"
print_info "Temporary file removed"

echo ""
print_info "✅ Success! Sealed secret created."
echo ""
echo "Next steps:"
echo ""
echo "1. Apply the sealed secret to your cluster:"
echo "   oc apply -f $OUTPUT_FILE"
echo ""
echo "2. Verify the secret was created:"
echo "   oc get secret backstage-github-secret -n rhdh-operator"
echo ""
echo "3. Commit the sealed secret to git (safe - encrypted):"
echo "   git add $OUTPUT_FILE"
echo "   git commit -m 'Add sealed GitHub token for Developer Hub'"
echo "   git push"
echo ""
echo "4. Apply other Developer Hub configs:"
echo "   oc apply -f developer-hub/github-integration-config.yaml"
echo "   oc apply -f developer-hub/catalog-locations-config.yaml"
echo "   oc apply -f developer-hub/backstage-instance.yaml"
echo ""
print_info "The sealed secret is encrypted and safe to commit to git!"
