#!/bin/bash
# Script to seal secrets for HCP cluster provisioning
# This script is called automatically by the Backstage template
# or can be run manually if needed

set -e

CLUSTER_NAME="$1"
PULL_SECRET="$2"
SSH_PUBLIC_KEY="$3"
NAMESPACE="clusters-${CLUSTER_NAME}"

if [ -z "$CLUSTER_NAME" ] || [ -z "$PULL_SECRET" ] || [ -z "$SSH_PUBLIC_KEY" ]; then
  echo "Usage: $0 <cluster-name> <pull-secret> <ssh-public-key>"
  echo "Example: $0 my-cluster '\$(cat pull-secret.json)' '\$(cat ~/.ssh/id_rsa.pub)'"
  exit 1
fi

echo "Sealing secrets for cluster: $CLUSTER_NAME"

# Check if kubeseal is installed
if ! command -v kubeseal &> /dev/null; then
  echo "ERROR: kubeseal is not installed"
  echo "Install it with: brew install kubeseal (macOS) or download from https://github.com/bitnami-labs/sealed-secrets/releases"
  exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
  echo "ERROR: kubectl is not installed"
  exit 1
fi

# Create sealed pull secret
echo "Sealing pull secret..."
kubectl create secret docker-registry "${CLUSTER_NAME}-pull-secret" \
  --docker-server=registry.redhat.io \
  --docker-username=unused \
  --docker-password=unused \
  --from-literal=.dockerconfigjson="${PULL_SECRET}" \
  --namespace="${NAMESPACE}" \
  --dry-run=client -o yaml | \
kubeseal --controller-namespace=kube-system \
  --controller-name=sealed-secrets-controller \
  --format=yaml > "base/pull-secret.yaml"

echo "✓ Pull secret sealed to base/pull-secret.yaml"

# Create sealed SSH key
echo "Sealing SSH key..."
kubectl create secret generic "${CLUSTER_NAME}-ssh-key" \
  --from-literal=id_rsa.pub="${SSH_PUBLIC_KEY}" \
  --namespace="${NAMESPACE}" \
  --dry-run=client -o yaml | \
kubeseal --controller-namespace=kube-system \
  --controller-name=sealed-secrets-controller \
  --format=yaml > "base/ssh-key.yaml"

echo "✓ SSH key sealed to base/ssh-key.yaml"

echo ""
echo "✅ Secrets successfully sealed!"
echo "You can now commit these SealedSecret files to Git safely."
