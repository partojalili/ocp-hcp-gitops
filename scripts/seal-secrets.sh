#!/bin/bash
set -e

echo "=========================================="
echo "Sealed Secrets Helper Script"
echo "=========================================="
echo

# Check if kubeseal is installed
if ! command -v kubeseal &> /dev/null; then
    echo "ERROR: kubeseal is not installed"
    echo
    echo "Install kubeseal:"
    echo "  macOS:   brew install kubeseal"
    echo "  Linux:   wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.36.6/kubeseal-0.36.6-linux-amd64.tar.gz"
    echo "           tar -xvzf kubeseal-0.36.6-linux-amd64.tar.gz kubeseal"
    echo "           sudo install -m 755 kubeseal /usr/local/bin/kubeseal"
    echo
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

# Check if Sealed Secrets controller is installed
if ! oc get deployment sealed-secrets-controller -n kube-system &> /dev/null; then
    echo "WARNING: Sealed Secrets controller not found in kube-system namespace"
    echo
    echo "Install Sealed Secrets controller:"
    echo "  oc apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.36.6/controller.yaml"
    echo
    read -p "Do you want to install it now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        oc apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.36.6/controller.yaml
        echo "Waiting for controller to be ready..."
        oc wait --for=condition=Available deployment/sealed-secrets-controller -n kube-system --timeout=300s
    else
        echo "Exiting. Please install Sealed Secrets controller first."
        exit 1
    fi
fi

echo "✓ Sealed Secrets controller found"
echo

# Seal Pull Secret
echo "=========================================="
echo "1. Sealing Pull Secret"
echo "=========================================="
echo

if [ ! -f "pull-secret.txt" ] && [ ! -f "pull-secret.json" ]; then
    echo "ERROR: pull-secret.txt or pull-secret.json not found"
    echo
    echo "Download your pull secret from: https://console.redhat.com/openshift/install/pull-secret"
    echo "Save it as pull-secret.txt or pull-secret.json in this directory"
    exit 1
fi

PULL_SECRET_FILE="pull-secret.txt"
if [ -f "pull-secret.json" ]; then
    PULL_SECRET_FILE="pull-secret.json"
fi

echo "Found pull secret: $PULL_SECRET_FILE"
echo "Creating temporary secret..."

oc create secret docker-registry hcp-pull-secret \
  --from-file=.dockerconfigjson=$PULL_SECRET_FILE \
  --namespace=clusters \
  --dry-run=client -o yaml > pull-secret-temp.yaml

echo "Sealing secret..."
kubeseal --format=yaml < pull-secret-temp.yaml > base/pull-secret-sealed.yaml

rm pull-secret-temp.yaml

echo "✓ Created base/pull-secret-sealed.yaml"
echo

# Seal SSH Key
echo "=========================================="
echo "2. Sealing SSH Key (optional)"
echo "=========================================="
echo

# Look for SSH public key in common locations
SSH_KEY=""
if [ -f "$HOME/.ssh/id_rsa.pub" ]; then
    SSH_KEY="$HOME/.ssh/id_rsa.pub"
elif [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
    SSH_KEY="$HOME/.ssh/id_ed25519.pub"
elif [ -f "$HOME/.ssh/id_ecdsa.pub" ]; then
    SSH_KEY="$HOME/.ssh/id_ecdsa.pub"
fi

if [ -n "$SSH_KEY" ]; then
    echo "Found SSH key: $SSH_KEY"
    echo "Creating temporary secret..."

    oc create secret generic hcp-ssh-key \
      --from-file=id_rsa.pub=$SSH_KEY \
      --namespace=clusters \
      --dry-run=client -o yaml > ssh-key-temp.yaml

    echo "Sealing secret..."
    kubeseal --format=yaml < ssh-key-temp.yaml > base/ssh-key-sealed.yaml

    rm ssh-key-temp.yaml

    echo "✓ Created base/ssh-key-sealed.yaml"
else
    echo "⚠️  No SSH public key found in $HOME/.ssh/"
    echo "   Looked for: id_rsa.pub, id_ed25519.pub, id_ecdsa.pub"
    echo "   Skipping SSH key sealing (you can add it later)"
fi

echo
echo "=========================================="
echo "✅ Success!"
echo "=========================================="
echo
echo "Sealed secrets created:"
echo "  - base/pull-secret-sealed.yaml"
if [ -f "base/ssh-key-sealed.yaml" ]; then
    echo "  - base/ssh-key-sealed.yaml"
fi
echo
echo "These sealed secrets are SAFE to commit to Git!"
echo "They can only be decrypted by the Sealed Secrets controller in your cluster."
echo
echo "Next steps:"
echo "  1. Review the sealed secrets:"
echo "     cat base/pull-secret-sealed.yaml"
echo
echo "  2. Commit to Git:"
echo "     git add base/pull-secret-sealed.yaml base/ssh-key-sealed.yaml"
echo "     git commit -m 'Add sealed secrets'"
echo "     git push"
echo
echo "  3. Deploy your cluster:"
echo "     oc apply -k overlays/production/"
echo
