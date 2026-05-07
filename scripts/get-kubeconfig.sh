#!/bin/bash
set -e

CLUSTER_NAME=${1:-ocp420-hcp}
NAMESPACE=${2:-clusters}

echo "Extracting kubeconfig for hosted cluster: $CLUSTER_NAME"

if ! oc get hostedcluster $CLUSTER_NAME -n $NAMESPACE &> /dev/null; then
    echo "ERROR: HostedCluster '$CLUSTER_NAME' not found in namespace '$NAMESPACE'"
    exit 1
fi

# Wait for kubeconfig secret to be created
echo "Waiting for kubeconfig secret..."
timeout 300 bash -c "until oc get secret ${CLUSTER_NAME}-admin-kubeconfig -n $NAMESPACE &> /dev/null; do sleep 5; done"

# Extract kubeconfig
oc extract secret/${CLUSTER_NAME}-admin-kubeconfig -n $NAMESPACE --to=- > ${CLUSTER_NAME}-kubeconfig.yaml

echo "Kubeconfig saved to: ${CLUSTER_NAME}-kubeconfig.yaml"
echo
echo "To use it:"
echo "  export KUBECONFIG=${CLUSTER_NAME}-kubeconfig.yaml"
echo "  oc get nodes"
