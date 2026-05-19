#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Usage function
usage() {
    cat <<EOF
Usage: $0 -n CLUSTER_NAME [-d BASE_DOMAIN] [-r REPLICAS] [-c CORES] [-m MEMORY]

Provision a new Hosted Control Plane cluster

Required:
  -n CLUSTER_NAME    Name of the cluster (e.g., dev-hcp, prod-hcp)

Optional:
  -d BASE_DOMAIN     Base domain (default: auto-detected from hub cluster)
  -r REPLICAS        Number of worker nodes (default: 2)
  -c CORES           CPU cores per worker (default: 4)
  -m MEMORY          Memory per worker in Gi (default: 8)
  -h                 Show this help message

Example:
  $0 -n dev-hcp
  $0 -n prod-hcp -r 3 -c 8 -m 16
EOF
    exit 1
}

# Parse command line arguments
CLUSTER_NAME=""
BASE_DOMAIN=""
REPLICAS=2
CORES=4
MEMORY=8

while getopts "n:d:r:c:m:h" opt; do
    case $opt in
        n) CLUSTER_NAME="$OPTARG" ;;
        d) BASE_DOMAIN="$OPTARG" ;;
        r) REPLICAS="$OPTARG" ;;
        c) CORES="$OPTARG" ;;
        m) MEMORY="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Validate required parameters
if [ -z "$CLUSTER_NAME" ]; then
    print_error "Cluster name is required"
    usage
fi

# Validate cluster name format (lowercase alphanumeric and hyphens only)
if ! [[ "$CLUSTER_NAME" =~ ^[a-z0-9-]+$ ]]; then
    print_error "Cluster name must contain only lowercase letters, numbers, and hyphens"
    exit 1
fi

print_info "Starting cluster provisioning for: $CLUSTER_NAME"

# Auto-detect base domain if not provided
if [ -z "$BASE_DOMAIN" ]; then
    print_info "Auto-detecting base domain from hub cluster..."
    BASE_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null || echo "")

    if [ -z "$BASE_DOMAIN" ]; then
        print_error "Failed to auto-detect base domain. Please provide it using -d flag"
        exit 1
    fi

    print_info "Detected base domain: $BASE_DOMAIN"
fi

# Create cluster-specific directory
CLUSTER_DIR="../clusters/${CLUSTER_NAME}"
print_info "Creating cluster directory: $CLUSTER_DIR"
mkdir -p "$CLUSTER_DIR"

# Copy template files
print_info "Copying template files..."
cp -r base overlays-production argocd scripts "$CLUSTER_DIR/"

# Rename overlays-production to overlays/production
mkdir -p "$CLUSTER_DIR/overlays/production"
mv "$CLUSTER_DIR/overlays-production"/* "$CLUSTER_DIR/overlays/production/"
rmdir "$CLUSTER_DIR/overlays-production"

# Replace CLUSTER_NAME placeholder in all files
print_info "Configuring cluster name: $CLUSTER_NAME"
find "$CLUSTER_DIR" -type f -exec sed -i '' "s/CLUSTER_NAME/$CLUSTER_NAME/g" {} \;

# Update base domain
print_info "Configuring base domain: $BASE_DOMAIN"
sed -i '' "s/BASE_DOMAIN_PLACEHOLDER/$BASE_DOMAIN/g" "$CLUSTER_DIR/overlays/production/hostedcluster-patch.yaml"

# Update worker node configuration
print_info "Configuring worker nodes: $REPLICAS replicas, $CORES cores, ${MEMORY}Gi memory"
sed -i '' "s/replicas: 2/replicas: $REPLICAS/g" "$CLUSTER_DIR/base/nodepool.yaml"
sed -i '' "s/cores: 4/cores: $CORES/g" "$CLUSTER_DIR/base/nodepool.yaml"
sed -i '' "s/memory: 8Gi/memory: ${MEMORY}Gi/g" "$CLUSTER_DIR/base/nodepool.yaml"

# Create kustomization.yaml in cluster directory
cat > "$CLUSTER_DIR/kustomization.yaml" <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - overlays/production
EOF

print_info "Cluster configuration created successfully!"
echo ""
print_warning "NEXT STEPS:"
echo "1. Place your pull-secret.txt in: $CLUSTER_DIR/"
echo "2. Run: cd $CLUSTER_DIR && ./scripts/seal-secrets.sh"
echo "3. Deploy: oc apply -f argocd/application.yaml"
echo ""
print_info "Cluster directory: $CLUSTER_DIR"
